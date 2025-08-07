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
    "Tanaman_Cabe": ["Zona_1", "Zona_2", "Zona_3", "Zona_4", "Zona_5", "Zona_6"],
    # "Tanaman_Melon": ["Zona_1", "Zona_2", "Zona_3", "Zona_4", "Zona_5"],
    "Tanaman_Selada": ["Zona_1", "Zona_2"]
    # "Greenhouse": ["Zona_1"]
}

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST"),
    "port": os.getenv("DB_PORT")
}
