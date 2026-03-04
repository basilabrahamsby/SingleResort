from app.database import SessionLocal
from sqlalchemy import text

def list_tables():
    db = SessionLocal()
    try:
        res = db.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';"))
        tables = [row[0] for row in res.fetchall()]
        with open("/tmp/tables_list.txt", "w") as f:
            for t in tables:
                f.write(t + "\n")
    finally:
        db.close()

if __name__ == "__main__":
    list_tables()
