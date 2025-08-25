# flask_api/app.py (Simplified Update)
import sys
import os
import logging
from flask import Flask
from flask_cors import CORS

# Add parent directory to path for webhook imports
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# Import existing routes
from routes import bp

# Import webhook functionality  
from webhook import register_webhook_routes

def create_app():
    """Create Flask application with webhook support"""
    app = Flask(__name__)
    CORS(app)
    
    # Simple logging setup
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.FileHandler('/home/elektro1/smart_greenhouse/logs/app.log'),
            logging.StreamHandler()
        ]
    )
    
    # Register existing API routes
    app.register_blueprint(bp)
    app.logger.info("API routes registered")
    
    # Register webhook routes
    register_webhook_routes(app)
    app.logger.info("Webhook routes registered")
    
    return app

app = create_app()

# Combined health check
@app.route('/health')
def health_check():
    """Simple health check for both API and webhook systems"""
    try:
        from db import get_db_connection, return_db_connection
        
        # Test database connection
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.close()
        return_db_connection(conn)
        
        return {
            "status": "healthy",
            "database": "connected",
            "timestamp": "2025-08-25T10:30:25.000Z"
        }, 200
        
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": "2025-08-25T10:30:25.000Z"
        }, 500

if __name__ == "__main__":
    # Ensure logs directory exists
    os.makedirs('/home/elektro1/smart_greenhouse/logs', exist_ok=True)
    
    app.logger.info("Starting Smart Greenhouse API with Webhook Support")
    app.run(host="0.0.0.0", port=5000, debug=False)