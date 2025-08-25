
"""
Components:
- webhook_handler.py: Core data processing logic
- webhook_routes.py: Flask routes for webhook endpoints  
- webhook_config.py: Webhook-specific configuration
- webhook_auth.py: Authentication and security
- webhook_utils.py: Utility functions and helpers
"""

__version__ = "1.0.0"

# Import main components for easy access
from .webhook_handler import WebhookDataHandler
from .webhook_routes import register_webhook_routes
from .webhook_config import WebhookConfig
from .webhook_auth import webhook_auth_required

# Export public API
__all__ = [
    'WebhookDataHandler',
    'register_webhook_routes', 
    'WebhookConfig',
    'webhook_auth_required'
]