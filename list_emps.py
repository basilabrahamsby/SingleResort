from app.database import SessionLocal
from app.models.employee import Employee

db = SessionLocal()
emps = db.query(Employee).all()
print(f"{'ID':<5} | {'Name'}")
print("-" * 20)
for e in emps:
    print(f"{e.id:<5} | {e.name}")
db.close()
