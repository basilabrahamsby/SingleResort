from app.database import SessionLocal
from sqlalchemy import text

def inspect_emps():
    db = SessionLocal()
    try:
        res = db.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'employees';"))
        cols = [row[0] for row in res.fetchall()]
        print(f"Employees columns: {cols}")
        
        # Also check users
        res = db.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users';"))
        cols = [row[0] for row in res.fetchall()]
        print(f"Users columns: {cols}")
    finally:
        db.close()

if __name__ == "__main__":
    inspect_emps()
