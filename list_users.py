from app.database import SessionLocal
from app.models.user import User

db = SessionLocal()
users = db.query(User).all()
print(f"{'ID':<5} | {'Username':<15} | {'Emp ID'}")
print("-" * 35)
for u in users:
    print(f"{u.id:<5} | {u.username:<15} | {u.employee_id}")
db.close()
