import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("ANTARES_API_KEY")
HEADERS = {
    "X-M2M-Origin": API_KEY,
    "Content-Type": "application/json;ty=4",
    "Accept": "application/json"
}

APP_DEVICES = {
    # "CABAI": ["CZ1", "CZ2", "CZ3", "CZ4"],
    # "MELON": ["MZ1", "MZ2"],
    # "SELADA": ["SZ12", "SZ3", "SZ4"],
    # "GREENHOUSE": ["GZ1"]
}

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT")
}
