import requests
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import logging
import time
from config import HEADERS, APP_DEVICES, DB_CONFIG

# Logging konfigurasi dasar
logging.basicConfig(
    filename="middleware.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

# Session untuk koneksi HTTP reuse
session = requests.Session()
session.headers.update(HEADERS)

def get_latest_data(app_name, device_name, retries=3, delay=5):
    """
    Ambil data terakhir dari Antares dengan retry
    """
    url = f"https://platform.antares.id:8443/~/antares-cse/antares-id/{app_name}/{device_name}/la"
    
    for attempt in range(retries):
        try:
            timeout = 30 + (attempt * 10)
            response = session.get(url, timeout=timeout)

            if response.status_code == 200:
                raw = response.json()["m2m:cin"]["con"]
                parsed = json.loads(raw)
                return {
                    "dev_eui": parsed.get("devEui"),
                    "encoded_data": parsed.get("data"),
                    "timestamp": datetime.now()
                }
            else:
                logging.error(f"{app_name}/{device_name} - HTTP {response.status_code} (attempt {attempt+1})")
                
        except requests.exceptions.Timeout:
            logging.error(f"{app_name}/{device_name} - Timeout (attempt {attempt+1})")
        except requests.exceptions.ConnectionError as e:
            logging.error(f"{app_name}/{device_name} - Connection error: {str(e)[:100]}")
        except requests.exceptions.SSLError as e:
            logging.error(f"{app_name}/{device_name} - SSL error: {str(e)[:100]}")
        except Exception as e:
            logging.error(f"{app_name}/{device_name} - Unexpected error: {e}")
        
        if attempt < retries - 1:
            time.sleep(delay * (2 ** attempt))
    
    logging.error(f"{app_name}/{device_name} - Gagal ambil data setelah {retries} percobaan")
    return None

def save_to_database(payload, app_name, device_name, retries=3):
    """
    Simpan data ke database dengan retry
    """
    for attempt in range(retries):
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
                cur.close()
                return True
            else:
                logging.error(f"{app_name}/{device_name} - devEUI tidak ditemukan: {payload['dev_eui']}")
                cur.close()
                return False

        except psycopg2.OperationalError as e:
            logging.error(f"{app_name}/{device_name} - DB connection error: {e}")
            time.sleep(2 * (attempt + 1))
        except Exception as e:
            logging.error(f"{app_name}/{device_name} - DB Error: {e}")
            break
        finally:
            if conn:
                conn.close()
    
    logging.error(f"{app_name}/{device_name} - Gagal simpan data ke DB setelah {retries} percobaan")
    return False

def run_middleware():
    """
    Proses utama
    """
    total_devices = sum(len(devices) for devices in APP_DEVICES.values())
    successful = 0
    
    logging.info(f"Memulai middleware - total {total_devices} device")
    
    for app_name, device_names in APP_DEVICES.items():
        for device_name in device_names:
            data = get_latest_data(app_name, device_name)
            if data and save_to_database(data, app_name, device_name):
                successful += 1
            time.sleep(3)
    
    logging.info(f"Selesai - {successful}/{total_devices} berhasil")

if __name__ == "__main__":
    try:
        run_middleware()
    except KeyboardInterrupt:
        logging.info("Middleware dihentikan oleh user")
    except Exception as e:
        logging.critical(f"Critical error: {e}")
    finally:
        session.close()
