import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    FLASK_ENV = os.getenv("FLASK_ENV", "production")
    API_KEY = os.getenv("API_KEY")
    DATABASE_URL = os.getenv("DATABASE_URL")
    POOL_MINCONN = int(os.getenv("POOL_MINCONN"))
    POOL_MAXCONN = int(os.getenv("POOL_MAXCONN"))
