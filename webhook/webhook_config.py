import os
from dotenv import load_dotenv

load_dotenv()

class WebhookConfig:
    """Webhook configuration for Antares platform"""
    
    # Authentication
    API_KEY = os.getenv("API_KEY", "")
    
    # Rate limiting (very permissive)
    RATE_LIMIT_PER_MINUTE = int(os.getenv("WEBHOOK_RATE_LIMIT", "1000"))
    
    # Payload size limit (generous)
    MAX_PAYLOAD_SIZE = int(os.getenv("WEBHOOK_MAX_PAYLOAD_SIZE", "5242880"))  # 5MB
    
    # Logging
    LOG_FILE = os.getenv("WEBHOOK_LOG_FILE", "/home/elektro1/smart_greenhouse/logs/webhook.log")
    
    # Your Antares applications and their devices
    DEVICE_MAPPING = {
        "CABAI": ["CZ1", "CZ2", "CZ3", "CZ4"],
        "MELON": ["MZ1", "MZ2"],  
        "SELADA": ["SZ12", "SZ3", "SZ4"],
        "GREENHOUSE": ["GZ1"],
        "DRTPM-Hidroponik": ["Monitoring_Hidroponik"]
    }
    
    @classmethod
    def validate_device(cls, device_name):
        """Check if device name is valid"""
        all_devices = []
        for devices in cls.DEVICE_MAPPING.values():
            all_devices.extend(devices)
        return device_name in all_devices
    
    @classmethod
    def get_app_for_device(cls, device_name):
        """Get application name for a device"""
        for app_name, devices in cls.DEVICE_MAPPING.items():
            if device_name in devices:
                return app_name
        return None