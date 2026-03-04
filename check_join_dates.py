
import sys
import os

sys.path.append(os.path.abspath('ResortApp'))

from app.database import SessionLocal
from app.models.employee import Employee

def check_join_dates():
    db = SessionLocal()
    employees = db.query(Employee).all()
    for emp in employees:
        print(f"ID: {emp.id}, Name: {emp.name}, Join Date: {emp.join_date}")
    db.close()

if __name__ == "__main__":
    check_join_dates()
