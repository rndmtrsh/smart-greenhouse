from flask import Blueprint, request, jsonify
from db import get_db_connection, release_db_connection
from auth import require_api_key

from datetime import datetime, timedelta

bp = Blueprint("api", __name__)

# API Ping (public)
@bp.route("/api/ping")
def ping():
    return {"message": "API is up"}, 200

# Daftar Zona dan Device
@bp.route("/api/zones", methods=["GET"])
@require_api_key
def get_zones():
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT z.zone_code, z.zone_label, p.name AS plant_name, d.code AS device_code
            FROM zones z
            LEFT JOIN plants p ON z.plant_id = p.plant_id
            LEFT JOIN devices d ON z.zone_id = d.zone_id
            ORDER BY z.zone_code;
        """)
        zones = cur.fetchall()
        cur.close()
        return jsonify(zones), 200
    finally:
        release_db_connection(conn)

# Sensor pada Device
@bp.route("/api/devices/<device_code>/sensors", methods=["GET"])
@require_api_key
def get_device_sensors(device_code):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT s.sensor_type, s.unit, s.sensor_model, ds.sensor_order
            FROM devices d
            JOIN device_sensors ds ON d.device_id = ds.device_id
            JOIN sensors s ON ds.sensor_id = s.sensor_id
            WHERE d.code = %s
            ORDER BY ds.sensor_order;
        """, (device_code,))
        sensors = cur.fetchall()
        cur.close()
        return jsonify(sensors), 200
    finally:
        release_db_connection(conn)

# Data Historis Interval
@bp.route("/api/devices/<device_code>/readings", methods=["GET"])
@require_api_key
def get_device_readings(device_code):
    interval = request.args.get("interval", default=60, type=int)  # in minutes
    duration = request.args.get("duration", default=720, type=int)  # in minutes (720 = 12 jam)

    if interval <= 0 or duration <= 0 or duration < interval:
        return jsonify({"error": "Invalid interval/duration"}), 400

    conn = get_db_connection()
    try:
        cur = conn.cursor()

        cur.execute("""
            SELECT device_id FROM devices WHERE code = %s
        """, (device_code,))
        device = cur.fetchone()
        if not device:
            return jsonify({"error": "Device not found"}), 404

        device_id = device["device_id"]
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=duration)

        cur.execute("""
            SELECT 
                reading_id,
                encoded_data,
                timestamp
            FROM sensor_readings
            WHERE device_id = %s
              AND timestamp BETWEEN %s AND %s
            ORDER BY timestamp
        """, (device_id, start_time, end_time))
        all_readings = cur.fetchall()

        # Resample per interval
        interval_delta = timedelta(minutes=interval)
        next_bucket = start_time
        resampled = []
        idx = 0
        while next_bucket < end_time:
            # Cari data pertama setelah waktu interval
            while idx < len(all_readings) and all_readings[idx]["timestamp"] < next_bucket:
                idx += 1
            if idx < len(all_readings):
                resampled.append(all_readings[idx])
            next_bucket += interval_delta

        cur.close()
        return jsonify(resampled), 200
    finally:
        release_db_connection(conn)

#Data Terbaru per Zona
@bp.route("/api/zones/<zone_code>/latest", methods=["GET"])
@require_api_key
def get_latest_reading_by_zone(zone_code):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT sr.reading_id, d.code AS device_code, sr.encoded_data, sr.timestamp
            FROM zones z
            JOIN devices d ON z.zone_id = d.zone_id
            JOIN sensor_readings sr ON d.device_id = sr.device_id
            WHERE z.zone_code = %s
            ORDER BY sr.timestamp DESC
            LIMIT 1
        """, (zone_code,))
        data = cur.fetchone()
        cur.close()
        if not data:
            return jsonify({"error": "Data not found"}), 404
        return jsonify(data), 200
    finally:
        release_db_connection(conn)
