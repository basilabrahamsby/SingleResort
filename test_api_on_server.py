import os
import json
from app.database import SessionLocal
from app.api.service_request import get_service_requests
from app.models.user import User

def mock_get_current_user(db):
    return db.query(User).filter(User.email.like('%admin%')).first()

def test_api_logic():
    db = SessionLocal()
    try:
        user = mock_get_current_user(db)
        if not user:
            print("No admin user found to mock.")
            return
            
        # Calling the actual API function
        results = get_service_requests(limit=10, db=db, current_user=user)
        
        # Filtering for Room 101
        for res in results:
            if '101' in str(res.get('room_number', '')):
                print("API RESPONSE FOR ROOM 101:")
                print(json.dumps(res, indent=2))
                return
        print("Room 101 not found in latest 10 service requests.")
    finally:
        db.close()

if __name__ == "__main__":
    test_api_logic()
