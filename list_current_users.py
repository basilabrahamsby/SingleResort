from app.database import SessionLocal
from app.models.user import User

def list_users():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print("CURRENT USERS:")
        for u in users:
            role_name = u.role.name if u.role else "None"
            print(f"Email: {u.email} | Role: {role_name} | Active: {u.is_active}")
    finally:
        db.close()

if __name__ == "__main__":
    list_users()
