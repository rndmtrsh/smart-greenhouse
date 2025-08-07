from flask import Blueprint, request, jsonify
from db import get_db_connection
from config import Config

bp = Blueprint("api", __name__)

@bp.route("/api/latest-readings", methods=["GET"])
def get_latest_readings():
    # Otentikasi via API Key
    client_api_key = request.headers.get("X-API-KEY")
    if client_api_key != Config.API_KEY:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        query = """
            SELECT DISTINCT ON (d.device_id)
                sr.reading_id,
                d.code AS device_code,
                sr.encoded_data,
                sr.timestamp
            FROM sensor_readings sr
            JOIN devices d ON sr.device_id = d.device_id
            ORDER BY d.device_id, sr.timestamp DESC;
        """

        cur.execute(query)
        results = cur.fetchall()

        cur.close()
        conn.close()

        return jsonify(results), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@bp.route("/api/ping")
def ping():
    return {"message": "API is up"}, 200

