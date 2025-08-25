# webhook/webhook_routes.py (Simplified)
import logging
from datetime import datetime
from flask import request, jsonify, Blueprint
from .webhook_handler import webhook_handler
from .webhook_auth import webhook_auth_required, validate_payload_size, check_rate_limit

logger = logging.getLogger('webhook')

# Create webhook blueprint
webhook_bp = Blueprint('webhook', __name__, url_prefix='/webhook')

@webhook_bp.before_request
def before_request():
    """Simple request validation"""
    # Check payload size
    if not validate_payload_size():
        return jsonify({"status": "error", "message": "Payload too large"}), 413
    
    # Simple rate limiting
    if not check_rate_limit():
        return jsonify({"status": "error", "message": "Rate limit exceeded"}), 429

@webhook_bp.route('/antares', methods=['POST'])
@webhook_auth_required
def antares_webhook():
    """Main webhook endpoint for Antares platform"""
    try:
        payload = request.get_json()
        if not payload:
            return jsonify({"status": "error", "message": "No JSON payload"}), 400
        
        # Process webhook
        success, message = webhook_handler.process_webhook(payload)
        
        if success:
            return jsonify({
                "status": "success",
                "message": message,
                "timestamp": datetime.now().isoformat()
            }), 200
        else:
            return jsonify({
                "status": "error", 
                "message": message,
                "timestamp": datetime.now().isoformat()
            }), 400
            
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return jsonify({
            "status": "error",
            "message": "Processing failed",
            "timestamp": datetime.now().isoformat()
        }), 500

@webhook_bp.route('/test', methods=['GET', 'POST'])
def webhook_test():
    """Test webhook endpoint"""
    if request.method == 'GET':
        return jsonify({
            "status": "success",
            "message": "Webhook endpoint is active",
            "timestamp": datetime.now().isoformat()
        }), 200
    
    # POST test with sample data
    test_data = request.get_json() or {
        "deviceName": "CZ1",
        "data": "01F402BC006400C8",
        "timestamp": datetime.now().isoformat()
    }
    
    success, message = webhook_handler.process_webhook(test_data)
    
    return jsonify({
        "status": "success" if success else "error",
        "message": f"Test: {message}",
        "test_data": test_data,
        "timestamp": datetime.now().isoformat()
    }), 200 if success else 400

@webhook_bp.route('/status', methods=['GET'])
def webhook_status():
    """System status check"""
    status = webhook_handler.get_status()
    return jsonify(status), 200 if status["status"] == "healthy" else 503

def register_webhook_routes(app):
    """Register webhook routes with Flask app"""
    app.register_blueprint(webhook_bp)
    logger.info("Webhook routes registered")
    return webhook_bp