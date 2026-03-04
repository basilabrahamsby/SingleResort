import sys
import os
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.user import User
from app.models.employee import Employee
from app.api.service_request import get_service_requests
from app.models.service_request import ServiceRequest

db = SessionLocal()

# Find Arun
arun = db.query(Employee).filter(Employee.name.ilike('%Arun%')).first()
if not arun:
    print("Arun not found")
    sys.exit(0)

print(f"Arun found: ID={arun.id}")
user = db.query(User).filter(User.id == arun.user_id).first()
if not user:
    print("User not found for Arun")
    sys.exit(0)

print(f"Running get_service_requests(limit=10, db, current_user={user.email})")

try:
    results_all = get_service_requests(skip=0, limit=10, status=None, room_id=None, include_checkout_requests=True, db=db, current_user=user)
    print(f"Results without status: {len(results_all)}")
    for r in results_all:
        print(f" - {r.get('id')} / {r.get('type')} / {r.get('status')} / {r.get('employee_name')}")
except Exception as e:
    print(f"Error: {e}")

try:
    results_completed = get_service_requests(skip=0, limit=10, status='completed', room_id=None, include_checkout_requests=True, db=db, current_user=user)
    print(f"Results WITH status='completed': {len(results_completed)}")
    for r in results_completed:
        print(f" - {r.get('id')} / {r.get('type')} / {r.get('status')} / {r.get('employee_name')}")
except Exception as e:
    print(f"Error: {e}")

db.close()
