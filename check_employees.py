
import sys
import os

sys.path.append(os.path.abspath('ResortApp'))

from app.database import SessionLocal
from app.models.employee import Employee

def check_employees():
    db = SessionLocal()
    employees = db.query(Employee).all()
    print(f"Total employees: {len(employees)}")
    for emp in employees:
        print(f" - ID: {emp.id}, Name: {emp.name}, Role: {emp.role}")
    db.close()

if __name__ == "__main__":
    check_employees()
