from psycopg2 import pool
from config import Config
from psycopg2.extras import RealDictCursor

# Simple connection pooling
db_pool = pool.SimpleConnectionPool(
    1, 10,
    dsn=Config.DATABASE_URL,
    cursor_factory=RealDictCursor
)

def get_db_connection():
    if db_pool:
        return db_pool.getconn()

def release_db_connection(conn):
    if db_pool:
        db_pool.putconn(conn)
