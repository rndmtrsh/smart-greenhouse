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
    "Tanaman_Cabe": ["CZ1", "CZ2", "CZ3", "CZ4"],
    "Tanaman_Melon": ["MZ1", "M2"],
    "Tanaman_Selada": ["SZ12", "SZ3", "SZ4"],
    "Greenhouse": ["GZ1"]
}

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT")
}
