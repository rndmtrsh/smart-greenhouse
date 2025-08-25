# webhook/webhook_auth.py (Simplified)
import logging
from flask import request, jsonify
from functools import wraps
from .webhook_config import WebhookConfig

logger = logging.getLogger('webhook')

def webhook_auth_required(f):
    """Simple API key authentication decorator"""
    @wraps(f)
    def decorated(*args, **kwargs):
        # Check API key
        api_key = request.headers.get('X-API-KEY')
        if api_key != WebhookConfig.API_KEY:
            logger.warning(f"Unauthorized webhook attempt from {request.remote_addr}")
            return jsonify({"status": "error", "message": "Unauthorized"}), 401
        
        return f(*args, **kwargs)
    
    return decorated

def validate_payload_size():
    """Basic payload size validation"""
    content_length = request.content_length
    if content_length and content_length > WebhookConfig.MAX_PAYLOAD_SIZE:
        return False
    return True

# Simple rate limiting (very basic, in-memory)
request_counts = {}

def check_rate_limit():
    """Very simple rate limiting"""
    import time
    
    client_ip = request.remote_addr
    current_minute = int(time.time() // 60)
    key = f"{client_ip}:{current_minute}"
    
    # Clean old entries
    old_keys = [k for k in request_counts if int(k.split(':')[1]) < current_minute - 2]
    for k in old_keys:
        del request_counts[k]
    
    # Check current count
    current_count = request_counts.get(key, 0)
    if current_count >= WebhookConfig.RATE_LIMIT_PER_MINUTE:
        return False
    
    request_counts[key] = current_count + 1
    return True