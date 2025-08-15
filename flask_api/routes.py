# flask_api/routes.py
from flask import Blueprint, request, jsonify
import logging
from functools import wraps
from db import get_db_connection
from config import Config

bp = Blueprint("api", __name__)

# Middleware Decorators
def require_api_key(f):
    """API key authentication decorator"""
    @wraps(f)
    def decorated(*args, **kwargs):
        if request.endpoint not in ("api.ping", "api.health"):
            client_key = request.headers.get("X-API-KEY")
            if client_key != Config.API_KEY:
                logging.warning(f"Unauthorized access attempt from {request.remote_addr}")
                return jsonify({"status": "error", "message": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return decorated

def handle_db_error(f):
    """Database error handler"""
    @wraps(f)
    def decorated(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            logging.error(f"DB error in {f.__name__}: {str(e)}")
            return jsonify({"status": "error", "message": "Internal server error"}), 500
    return decorated

# Health Check
@bp.route("/api/ping")
def ping():
    return jsonify({"status": "healthy", "message": "AMAN"}), 200

@bp.route("/health")
def health():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy", "database": "connected", "tunnel": "active"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

# Latest Readings (All Devices)
@bp.route("/api/latest-readings", methods=["GET"])
@require_api_key
@handle_db_error
def latest_readings():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT DISTINCT ON (d.device_id)
            sr.reading_id,
            z.zone_code,
            sr.encoded_data,
            sr.timestamp
        FROM sensor_readings sr
        JOIN devices d ON sr.device_id = d.device_id
        JOIN zones z ON d.zone_id = z.zone_id
        ORDER BY d.device_id, sr.timestamp DESC;
    """)
    data = cur.fetchall()
    conn.close()

    return jsonify({
        "status": "success",
        "count": len(data),
        "readings": data
    }), 200

# Latest Reading (Single Device)
@bp.route("/api/latest-readings/<device_code>", methods=["GET"])
@require_api_key
@handle_db_error
def latest_reading_device(device_code):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT sr.encoded_data, sr.timestamp
        FROM sensor_readings sr
        JOIN devices d ON sr.device_id = d.device_id
        WHERE d.code = %s
        ORDER BY sr.timestamp DESC
        LIMIT 1;
    """, (device_code,))
    row = cur.fetchone()
    conn.close()

    if not row:
        return jsonify({"status": "error", "message": "Device not found"}), 404

    return jsonify({"status": "success", "device_code": device_code, "reading": row}), 200

# 24-Hour Interval (4 Hours Step)
@bp.route("/api/<device_code>/24", methods=["GET"])
@require_api_key
@handle_db_error
def readings_24h(device_code):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT sr.encoded_data, sr.timestamp
        FROM sensor_readings sr
        JOIN devices d ON sr.device_id = d.device_id
        WHERE d.code = %s
          AND sr.timestamp >= NOW() - INTERVAL '24 HOURS'
        ORDER BY date_trunc('hour', sr.timestamp)::timestamp / INTERVAL '4 HOURS', sr.timestamp DESC;
    """, (device_code,))
    data = cur.fetchall()
    conn.close()

    return jsonify({"status": "success", "device_code": device_code, "interval": "4h", "readings": data}), 200

# 7-Day Average (Daily)
@bp.route("/api/<device_code>/7", methods=["GET"])
@require_api_key
@handle_db_error
def readings_7d(device_code):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT 
            to_char(date_trunc('day', sr.timestamp), 'YYYY-MM-DD') AS day,
            AVG((sr.encoded_data)::numeric) AS avg_encoded,
            MIN(sr.timestamp) AS sample_time
        FROM sensor_readings sr
        JOIN devices d ON sr.device_id = d.device_id
        WHERE d.code = %s
          AND sr.timestamp >= NOW() - INTERVAL '7 DAYS'
        GROUP BY date_trunc('day', sr.timestamp)
        ORDER BY day DESC;
    """, (device_code,))
    data = cur.fetchall()
    conn.close()

    return jsonify({"status": "success", "device_code": device_code, "interval": "1d", "readings": data}), 200

# Get all devices with their zone information
@bp.route("/api/devices", methods=["GET"])
@require_api_key
@handle_db_error
def get_devices():
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

#Get sensors for a specific device
@bp.route("/api/devices/<device_code>/sensors", methods=["GET"])
@require_api_key
@handle_db_error
def get_device_sensors(device_code):
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