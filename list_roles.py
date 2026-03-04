from app.database import SessionLocal
from app.models.role import Role

def list_roles():
    db = SessionLocal()
    try:
        roles = db.query(Role).all()
        print("ROLES IN SYSTEM:")
        for r in roles:
            print(f"ID: {r.id} | Name: {r.name}")
    finally:
        db.close()

if __name__ == "__main__":
    list_roles()
