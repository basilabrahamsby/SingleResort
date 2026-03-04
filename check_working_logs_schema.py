
import sys
import os

# Add ResortApp to path
sys.path.append(os.path.abspath('ResortApp'))

from app.database import engine
from sqlalchemy import inspect

def check_table():
    inspector = inspect(engine)
    columns = inspector.get_columns('working_logs')
    print("Columns in working_logs table:")
    for col in columns:
        print(f" - {col['name']} ({col['type']})")

if __name__ == "__main__":
    check_table()
