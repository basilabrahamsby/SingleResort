import os
import sys

# Add the current directory to sys.path to find the 'app' module
sys.path.append(os.getcwd())

from app.database import SessionLocal
from app.models.service_request import ServiceRequest

db = SessionLocal()
try:
    srs = db.query(ServiceRequest).all()
    print("Found Service Requests:")
    for s in srs:
        print(f"ID: {s.id}, Status: {s.status}, Type: {s.request_type}, Desc: {s.description}")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
