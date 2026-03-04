from app.database import SessionLocal
from sqlalchemy import text

def list_things():
    db = SessionLocal()
    try:
        # Roles
        res = db.execute(text("SELECT id, name FROM roles;")).fetchall()
        print("ROLES:")
        for r in res:
            print(f"ID: {r[0]} | Name: {r[1]}")
            
        # Users
        res = db.execute(text("SELECT id, email, role_id, is_active FROM users;")).fetchall()
        print("\nUSERS:")
        for u in res:
            print(f"ID: {u[0]} | Email: {u[1]} | RoleID: {u[2]} | Active: {u[3]}")
    finally:
        db.close()

if __name__ == "__main__":
    list_things()
