# flask_api/models.py
import psycopg2
from flask import current_app
from .utils import dictfetchall

def get_latest_device_readings():
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

    conn = psycopg2.connect(
        host=current_app.config['DB_HOST'],
        database=current_app.config['DB_NAME'],
        user=current_app.config['DB_USER'],
        password=current_app.config['DB_PASSWORD'],
        port=current_app.config['DB_PORT']
    )
    with conn.cursor() as cursor:
        cursor.execute(query)
        results = dictfetchall(cursor)
    conn.close()
    return results
