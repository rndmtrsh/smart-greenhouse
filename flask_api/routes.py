# flask_api/routes.py
from flask import Blueprint, jsonify
from .auth import auth_required
from .models import get_latest_device_readings

api_bp = Blueprint('api', __name__)

@api_bp.route('/latest-readings', methods=['GET'])
@auth_required
def latest_readings():
    try:
        results = get_latest_device_readings()
        return jsonify(results), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
