import os
import sys

# Setup environment 
from app.database import SessionLocal
from app.models.service_request import ServiceRequest

db = SessionLocal()

# Print current active service requests with description and type
active_reqs = db.query(ServiceRequest).filter(ServiceRequest.status == 'pending').all()
print(f"Total pending ServiceRequests: {len(active_reqs)}")
for r in active_reqs:
    print(f"ID: {r.id}, Type: {r.request_type}, Desc: {r.description}, food_order: {r.food_order_id}")

from app.models.service import AssignedService
active_asvcs = db.query(AssignedService).filter(AssignedService.status == 'pending').all()
print(f"Total pending AssignedServices: {len(active_asvcs)}")
for a in active_asvcs:
    print(f"ID: {a.id}, Status: {a.status}, Desc: {a.service.name if a.service else 'none'}")

db.close()
