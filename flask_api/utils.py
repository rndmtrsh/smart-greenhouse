# flask_api/utils.py
def dictfetchall(cursor):
    """Convert all rows from a cursor to a list of dicts"""
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]
