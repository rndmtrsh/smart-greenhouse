import sys
import os
import logging
from datetime import datetime
from typing import Dict, Any, Tuple

# Add parent directories to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask_api.db import get_db_connection, return_db_connection
from .webhook_config import WebhookConfig
from .webhook_utils import parse_webhook_payload, validate_hex_data

logger = logging.getLogger('webhook')

class WebhookDataHandler:
    """Simplified webhook data handler"""
    
    def process_webhook(self, payload: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Process webhook payload - simplified version
        Returns: (success, message)
        """
        try:
            # Parse the payload
            parsed_data = parse_webhook_payload(payload)
            if not parsed_data:
                return False, "Could not parse webhook data"
            
            device_name, encoded_data, timestamp = parsed_data
            
            # Map device name (handle M2 -> MZ2)
            device_code = WebhookConfig.get_device_code(device_name)
            
            # Basic validation
            if not WebhookConfig.validate_device(device_code):
                return False, f"Unknown device: {device_code}"
            
            if not validate_hex_data(encoded_data):
                return False, f"Invalid data format: {encoded_data}"
            
            # Save to database
            success = self.save_to_database(device_code, encoded_data, timestamp)
            
            if success:
                logger.info(f"Webhook processed: {device_code} -> {encoded_data}")
                return True, f"Data saved for {device_code}"
            else:
                return False, f"Database save failed for {device_code}"
                
        except Exception as e:
            logger.error(f"Webhook processing error: {e}")
            return False, "Processing failed"
    
    def save_to_database(self, device_code: str, encoded_data: str, timestamp: datetime) -> bool:
        """Save data to database"""
        conn = None
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            
            # Get device_id
            cur.execute("SELECT device_id FROM devices WHERE code = %s", (device_code,))
            result = cur.fetchone()
            
            if not result:
                logger.error(f"Device not found: {device_code}")
                return False
            
            device_id = result[0]
            
            # Insert reading
            cur.execute("""
                INSERT INTO sensor_readings (device_id, encoded_data, timestamp)
                VALUES (%s, %s, %s)
            """, (device_id, encoded_data, timestamp))
            
            conn.commit()
            return True
            
        except Exception as e:
            logger.error(f"Database error for {device_code}: {e}")
            if conn:
                conn.rollback()
            return False
            
        finally:
            if conn:
                return_db_connection(conn)
    
    def get_status(self) -> Dict[str, Any]:
        """Get simple system status"""
        try:
            # Test database
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM sensor_readings WHERE timestamp >= NOW() - INTERVAL '1 hour'")
            recent_count = cur.fetchone()[0]
            cur.close()
            return_db_connection(conn)
            
            return {
                "status": "healthy",
                "database": "connected",
                "recent_readings_1h": recent_count,
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                "status": "error",
                "database": "error",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

# Global instance
webhook_handler = WebhookDataHandler()