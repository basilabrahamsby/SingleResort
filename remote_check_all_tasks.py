import os
import sys
import json

# Add the current directory to sys.path to find the 'app' module
sys.path.append(os.getcwd())

from app.database import SessionLocal
from app.models.service_request import ServiceRequest
from app.models.service import AssignedService
from app.models.checkout import CheckoutRequest

db = SessionLocal()
try:
    print("--- Regular Service Requests ---")
    srs = db.query(ServiceRequest).all()
    for s in srs:
        print(f"SR ID: {s.id}, Status: {s.status}, Type: {s.request_type}, Room: {s.room_id}, Employee: {s.employee_id}")
    
    print("\n--- Assigned Services ---")
    asvcs = db.query(AssignedService).all()
    for s in asvcs:
        print(f"AS ID: {s.id + 2000000}, Status: {s.status}, Service: {s.service_id}, Room: {s.room_id}, Employee: {s.employee_id}")
        
    print("\n--- Checkout Requests ---")
    crs = db.query(CheckoutRequest).all()
    for s in crs:
        print(f"CR ID: {s.id + 1000000}, Status: {s.status}, Room: {s.room_number}, Employee: {s.employee_id}")

except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
