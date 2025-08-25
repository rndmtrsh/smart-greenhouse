# webhook/webhook_utils.py (Simplified)
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional, Tuple

logger = logging.getLogger('webhook')

def parse_webhook_payload(payload: Dict[str, Any]) -> Optional[Tuple[str, str, datetime]]:
    """
    Simple webhook payload parser for Antares data
    Returns: (device_name, encoded_data, timestamp) or None
    """
    try:
        # Try different common formats from Antares
        
        # Format 1: Simple direct format
        device_name = payload.get('deviceName') or payload.get('device')
        encoded_data = payload.get('data')
        timestamp_str = payload.get('timestamp')
        
        # Format 2: Check if data is nested in m2m:cin
        if not encoded_data and 'm2m:cin' in payload:
            try:
                con_data = json.loads(payload['m2m:cin'].get('con', '{}'))
                device_name = device_name or con_data.get('deviceName')
                encoded_data = con_data.get('data')
            except:
                pass
        
        # Format 3: Check payload nested structure
        if not encoded_data and 'payload' in payload:
            nested = payload['payload']
            device_name = device_name or nested.get('deviceName')
            encoded_data = encoded_data or nested.get('data')
            timestamp_str = timestamp_str or nested.get('timestamp')
        
        if not device_name or not encoded_data:
            return None
        
        # Simple timestamp parsing
        timestamp = parse_timestamp(timestamp_str)
        
        return device_name, encoded_data, timestamp
        
    except Exception as e:
        logger.error(f"Error parsing webhook payload: {e}")
        return None

def parse_timestamp(timestamp_str: Optional[str]) -> datetime:
    """Simple timestamp parser"""
    if not timestamp_str:
        return datetime.now()
    
    try:
        # Try ISO format first
        if 'T' in timestamp_str:
            # Remove 'Z' and parse
            clean_ts = timestamp_str.replace('Z', '+00:00')
            return datetime.fromisoformat(clean_ts.replace('Z', ''))
        
        # Try other formats
        for fmt in ["%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"]:
            try:
                return datetime.strptime(timestamp_str, fmt)
            except:
                continue
                
    except Exception as e:
        logger.debug(f"Timestamp parse error: {e}")
    
    # Fallback to current time
    return datetime.now()

def validate_hex_data(data: str) -> bool:
    """Simple hex data validation"""
    if not data or len(data) < 2:
        return False
    
    try:
        int(data, 16)
        return len(data) % 2 == 0  # Must be even length
    except ValueError:
        return False