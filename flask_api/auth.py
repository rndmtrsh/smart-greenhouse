from flask import request, jsonify
from functools import wraps
from config import Config

def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        client_key = request.headers.get("X-API-KEY")
        if client_key != Config.API_KEY:
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated
