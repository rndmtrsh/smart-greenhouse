# flask_api/__init__.py
from flask import Flask
from flask_cors import CORS
from .config import Config
from .auth import auth_required
from .routes import api_bp

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app)
    app.register_blueprint(api_bp, url_prefix='/api')

    return app
