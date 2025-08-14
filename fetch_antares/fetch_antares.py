import requests
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import logging
import time
from config import HEADERS, APP_DEVICES, DB_CONFIG

# Logging
logging.basicConfig(
    filename="middleware.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

# Fetch data from Antares
def get_latest_data(app_name, device_name, retries=3, delay=2):
    try:
        url = f"https://platform.antares.id:8443/~/antares-cse/antares-id/{app_name}/{device_name}/la"
        response = requests.get(url, headers=HEADERS, timeout=10)

        if response.status_code == 200:
            raw = response.json()["m2m:cin"]["con"]
            parsed = json.loads(raw)
            return {
                "dev_eui": parsed.get("devEui"),
                "encoded_data": parsed.get("data"),
                "timestamp": datetime.now()
            }
        else:
            logging.warning(f"Gagal request [{device_name}] code {response.status_code}")
    except Exception as e:
        logging.error(f"Exception [{device_name}]: {e}")
    return None

# Save to PostgreSQL
def save_to_database(payload):
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)

        cur.execute("SELECT device_id FROM devices WHERE dev_eui = %s", (payload['dev_eui'],))
        result = cur.fetchone()

        if result:
            device_id = result["device_id"]
            cur.execute("""
                INSERT INTO sensor_readings (device_id, encoded_data, timestamp)
                VALUES (%s, %s, %s)
            """, (device_id, payload['encoded_data'], payload['timestamp']))
            conn.commit()
            logging.info(f"Data tersimpan: devEUI={payload['dev_eui']}")
        else:
            logging.warning(f"devEUI tidak dikenali: {payload['dev_eui']}")

        cur.close()
    except Exception as e:
        logging.error(f"DB Error: {e}")
    finally:
        if conn:
            conn.close()

# Main Loop
def run_middleware():
    for app_name, device_names in APP_DEVICES.items():
        for device_name in device_names:
            logging.info(f"Memproses {app_name}/{device_name}")
            data = get_latest_data(app_name, device_name)
            if data:
                save_to_database(data)
                time.sleep(3)

# Execution
if __name__ == "__main__":
    run_middleware()
