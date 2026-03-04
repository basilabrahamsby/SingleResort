import os
import sys

# Add the current directory to sys.path to find the 'app' module
sys.path.append(os.getcwd())

from app.database import SessionLocal
from app.models.service_request import ServiceRequest

db = SessionLocal()
try:
    srs = db.query(ServiceRequest).filter(ServiceRequest.refill_data != None).all()
    print("Found Service Requests with Refill Data:")
    for s in srs:
        print(f"ID: {s.id}, Type: {s.request_type}, Refill Data: {s.refill_data}")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
