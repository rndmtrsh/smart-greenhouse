# flask_api/routes.py
from flask import Blueprint, request, jsonify
import logging
from functools import wraps
from db import get_db_connection
from config import Config

bp = Blueprint("api", __name__)

def require_api_key(f):
    """Decorator for API key authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_api_key = request.headers.get("X-API-KEY")
        if client_api_key != Config.API_KEY:
            logging.warning(f"Unauthorized access attempt from {request.remote_addr}")
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated_function

def handle_db_error(f):
    """Decorator for database error handling"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            logging.error(f"Database error in {f.__name__}: {str(e)}")
            return jsonify({"error": "Internal server error"}), 500
    return decorated_function

@bp.route("/api/ping")
def ping():
    """Health check endpoint"""
    return jsonify({"message": "AMAN COK", "status": "healthy"}), 200

@bp.route("/api/zones", methods=["GET"])
@require_api_key
@handle_db_error
def get_zones():
    """Get all zones with their plant information"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        query = """
            SELECT 
                z.zone_id,
                z.zone_code,
                z.zone_label,
                z.location_description,
                p.name as plant_name,
                p.media_type,
                p.description as plant_description
            FROM zones z
            LEFT JOIN plants p ON z.plant_id = p.plant_id
            ORDER BY z.zone_code;
        """
        
        cur.execute(query)
        results = cur.fetchall()
        
        return jsonify({
            "zones": results,
            "count": len(results)
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/zones/<zone_code>", methods=["GET"])
@require_api_key
@handle_db_error
def get_zone_details(zone_code):
    """Get specific zone details with devices"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Get zone information
        zone_query = """
            SELECT 
                z.zone_id,
                z.zone_code,
                z.zone_label,
                z.location_description,
                p.name as plant_name,
                p.media_type,
                p.description as plant_description
            FROM zones z
            LEFT JOIN plants p ON z.plant_id = p.plant_id
            WHERE z.zone_code = %s;
        """
        
        cur.execute(zone_query, (zone_code,))
        zone_info = cur.fetchone()
        
        if not zone_info:
            return jsonify({"error": "Zone not found"}), 404
        
        # Get devices in this zone
        devices_query = """
            SELECT 
                d.device_id,
                d.dev_eui,
                d.code,
                d.description
            FROM devices d
            WHERE d.zone_id = %s;
        """
        
        cur.execute(devices_query, (zone_info['zone_id'],))
        devices = cur.fetchall()
        
        return jsonify({
            "zone": zone_info,
            "devices": devices
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/devices", methods=["GET"])
@require_api_key
@handle_db_error
def get_devices():
    """Get all devices with their zone information"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        query = """
            SELECT 
                d.device_id,
                d.dev_eui,
                d.code,
                d.description,
                z.zone_code,
                z.zone_label,
                p.name as plant_name
            FROM devices d
            JOIN zones z ON d.zone_id = z.zone_id
            LEFT JOIN plants p ON z.plant_id = p.plant_id
            ORDER BY d.code;
        """
        
        cur.execute(query)
        results = cur.fetchall()
        
        return jsonify({
            "devices": results,
            "count": len(results)
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/devices/<device_code>/sensors", methods=["GET"])
@require_api_key
@handle_db_error
def get_device_sensors(device_code):
    """Get sensors for a specific device"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        query = """
            SELECT 
                ds.device_sensor_id,
                ds.sensor_label,
                ds.sensor_order,
                s.sensor_type,
                s.unit,
                s.sensor_model
            FROM device_sensors ds
            JOIN devices d ON ds.device_id = d.device_id
            JOIN sensors s ON ds.sensor_id = s.sensor_id
            WHERE d.code = %s
            ORDER BY ds.sensor_order;
        """
        
        cur.execute(query, (device_code,))
        results = cur.fetchall()
        
        if not results:
            return jsonify({"error": "Device not found or no sensors"}), 404
        
        return jsonify({
            "device_code": device_code,
            "sensors": results
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/latest-readings", methods=["GET"])
@require_api_key
@handle_db_error
def get_latest_readings():
    """Get latest sensor readings for all devices"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()

        query = """
            SELECT DISTINCT ON (d.device_id)
                sr.reading_id,
                d.code AS device_code,
                d.dev_eui,
                z.zone_code,
                z.zone_label,
                p.name as plant_name,
                sr.encoded_data,
                sr.timestamp
            FROM sensor_readings sr
            JOIN devices d ON sr.device_id = d.device_id
            JOIN zones z ON d.zone_id = z.zone_id
            LEFT JOIN plants p ON z.plant_id = p.plant_id
            ORDER BY d.device_id, sr.timestamp DESC;
        """

        cur.execute(query)
        results = cur.fetchall()

        return jsonify({
            "readings": results,
            "count": len(results)
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/readings/<device_code>", methods=["GET"])
@require_api_key
@handle_db_error
def get_device_readings(device_code):
    """Get readings for a specific device with pagination"""
    limit = request.args.get('limit', 50, type=int)
    offset = request.args.get('offset', 0, type=int)
    
    # Validate pagination parameters
    if limit > 1000:
        limit = 1000
    if limit < 1:
        limit = 50
    if offset < 0:
        offset = 0
    
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        query = """
            SELECT 
                sr.reading_id,
                sr.encoded_data,
                sr.timestamp
            FROM sensor_readings sr
            JOIN devices d ON sr.device_id = d.device_id
            WHERE d.code = %s
            ORDER BY sr.timestamp DESC
            LIMIT %s OFFSET %s;
        """
        
        cur.execute(query, (device_code, limit, offset))
        results = cur.fetchall()
        
        # Get total count
        count_query = """
            SELECT COUNT(*)
            FROM sensor_readings sr
            JOIN devices d ON sr.device_id = d.device_id
            WHERE d.code = %s;
        """
        
        cur.execute(count_query, (device_code,))
        total_count = cur.fetchone()['count']
        
        return jsonify({
            "device_code": device_code,
            "readings": results,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "total": total_count,
                "has_more": offset + len(results) < total_count
            }
        }), 200
        
    finally:
        conn.close()

@bp.route("/api/plants", methods=["GET"])
@require_api_key
@handle_db_error
def get_plants():
    """Get all plants"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        query = """
            SELECT 
                p.plant_id,
                p.name,
                p.media_type,
                p.description,
                COUNT(z.zone_id) as zone_count
            FROM plants p
            LEFT JOIN zones z ON p.plant_id = z.plant_id
            GROUP BY p.plant_id, p.name, p.media_type, p.description
            ORDER BY p.name;
        """
        
        cur.execute(query)
        results = cur.fetchall()
        
        return jsonify({
            "plants": results,
            "count": len(results)
        }), 200
        
    finally:
        conn.close()

# Error handlers
@bp.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@bp.errorhandler(405)
def method_not_allowed(error):
    return jsonify({"error": "Method not allowed"}), 405

@bp.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500