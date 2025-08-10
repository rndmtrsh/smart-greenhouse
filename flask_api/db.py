# flask_api/db.py
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2 import pool
from config import Config
import logging

# Connection pool for better performance
connection_pool = None

def init_connection_pool():
    """Initialize database connection pool"""
    global connection_pool
    try:
        connection_pool = psycopg2.pool.ThreadedConnectionPool(
            1, Config.DB_POOL_SIZE,
            dsn=Config.DATABASE_URL,
            cursor_factory=RealDictCursor
        )
        logging.info("Database connection pool initialized")
    except Exception as e:
        logging.error(f"Error initializing connection pool: {e}")
        raise

def get_db_connection():
    """Get database connection from pool"""
    global connection_pool
    if connection_pool is None:
        init_connection_pool()
    
    try:
        return connection_pool.getconn()
    except Exception as e:
        logging.error(f"Error getting database connection: {e}")
        # Fallback to direct connection
        return psycopg2.connect(
            dsn=Config.DATABASE_URL,
            cursor_factory=RealDictCursor
        )

def return_db_connection(conn):
    """Return database connection to pool"""
    global connection_pool
    if connection_pool and conn:
        connection_pool.putconn(conn)