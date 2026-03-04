from app.database import SessionLocal
from app.models.user import User
from app.utils.auth import get_password_hash
from sqlalchemy import text

def recreate_user():
    db = SessionLocal()
    try:
        # Check if user already exists
        existing = db.query(User).filter(User.email == "a@h.com").first()
        if existing:
            print("User a@h.com already exists. Updating status and password.")
            existing.hashed_password = get_password_hash("admin123")
            existing.is_active = True
            db.commit()
            print("Updated.")
            return

        # Create new admin user
        # Get admin role id
        res = db.execute(text("SELECT id FROM roles WHERE LOWER(name) = 'admin';")).fetchone()
        role_id = res[0] if res else 1
        
        new_user = User(
            email="a@h.com",
            hashed_password=get_password_hash("admin123"),
            role_id=role_id,
            is_active=True,
            name="Test User"
        )
        db.add(new_user)
        db.commit()
        print("User a@h.com created with role admin and password admin123")
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    recreate_user()
