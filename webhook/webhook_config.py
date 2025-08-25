# webhook/webhook_config.py
"""
Webhook-specific configuration settings
"""

import os
from dotenv import load_dotenv

load_dotenv()

class WebhookConfig:
    """Configuration class for webhook settings"""
    
    # Webhook authentication
    WEBHOOK_SECRET = os.getenv("ANTARES_WEBHOOK_SECRET", "")
    API_KEY = os.getenv("API_KEY", "")
    
    # Antares IP whitelist (for IP-based authentication)
    ANTARES_IPS = [
        ip.strip() 
        for ip in os.getenv("ANTARES_IPS", "").split(",") 
        if ip.strip()
    ]
    
    # Security settings
    MAX_PAYLOAD_SIZE = int(os.getenv("WEBHOOK_MAX_PAYLOAD_SIZE", "1048576"))  # 1MB
    REQUEST_TIMEOUT = int(os.getenv("WEBHOOK_TIMEOUT", "30"))  # seconds
    
    # Rate limiting
    RATE_LIMIT_PER_MINUTE = int(os.getenv("WEBHOOK_RATE_LIMIT", "100"))
    RATE_LIMIT_PER_HOUR = int(os.getenv("WEBHOOK_RATE_LIMIT_HOUR", "1000"))
    
    # Logging configuration
    LOG_LEVEL = os.getenv("WEBHOOK_LOG_LEVEL", "INFO")
    LOG_FILE = os.getenv("WEBHOOK_LOG_FILE", "/home/elektro1/smart_greenhouse/logs/webhook.log")
    LOG_MAX_SIZE = int(os.getenv("WEBHOOK_LOG_MAX_SIZE", "10485760"))  # 10MB
    LOG_BACKUP_COUNT = int(os.getenv("WEBHOOK_LOG_BACKUP_COUNT", "5"))
    
    # Device mapping from Antares to database
    DEVICE_MAPPING = {
        # Antares App Name -> Device Names
        "Tanaman_Cabe": ["CZ1", "CZ2", "CZ3", "CZ4"],
        "Tanaman_Melon": ["MZ1", "MZ2"],  
        "Tanaman_Selada": ["SZ12", "SZ3", "SZ4"], 
        "Greenhouse": ["GZ1"]
    }
    
    # Webhook retry configuration
    MAX_RETRIES = int(os.getenv("WEBHOOK_MAX_RETRIES", "3"))
    RETRY_DELAY = int(os.getenv("WEBHOOK_RETRY_DELAY", "1"))  # seconds
    
    # Health check settings
    HEALTH_CHECK_INTERVAL = int(os.getenv("WEBHOOK_HEALTH_INTERVAL", "300"))  # 5 minutes
    
    @classmethod
    def validate_config(cls):
        """Validate webhook configuration"""
        errors = []
        
        if not cls.API_KEY:
            errors.append("API_KEY is required")
            
        if cls.MAX_PAYLOAD_SIZE < 1024:  # Minimum 1KB
            errors.append("MAX_PAYLOAD_SIZE too small (minimum 1KB)")
            
        if cls.REQUEST_TIMEOUT < 5:  # Minimum 5 seconds
            errors.append("REQUEST_TIMEOUT too small (minimum 5 seconds)")
            
        if errors:
            raise ValueError(f"Webhook configuration errors: {', '.join(errors)}")
        
        return True
    
    @classmethod
    def get_device_code(cls, antares_device_name):
        """Map Antares device name to database device code"""
        return cls.ANTARES_TO_DB_MAPPING.get(antares_device_name, antares_device_name)
    
    @classmethod
    def is_valid_device(cls, device_name):
        """Check if device name is valid"""
        all_devices = []
        for devices in cls.DEVICE_MAPPING.values():
            all_devices.extend(devices)
        return device_name in all_devices or device_name in cls.ANTARES_TO_DB_MAPPING
    
    @classmethod
    def get_app_for_device(cls, device_name):
        """Get Antares app name for a device"""
        for app_name, devices in cls.DEVICE_MAPPING.items():
            if device_name in devices:
                return app_name
        return None