
import sys
import os

# Add ResortApp to path
sys.path.append(os.path.abspath('ResortApp'))

from app.database import SessionLocal
from app.models.employee import Employee

db = SessionLocal()
try:
    employees = db.query(Employee).all()
    print("Found employees:")
    for emp in employees:
        print(f"ID: {emp.id}, Name: {emp.name}")
finally:
    db.close()
