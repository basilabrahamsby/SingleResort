from app.database import SessionLocal
from app.models.user import User
from app.models.employee import Employee

db = SessionLocal()
users = db.query(User).all()
print(f"{'User ID':<8} | {'User Name':<20} | {'Emp ID'}")
print("-" * 50)
for u in users:
    emp = db.query(Employee).filter(Employee.user_id == u.id).first()
    emp_id = emp.id if emp else "None"
    print(f"{u.id:<8} | {str(u.name):<20} | {emp_id}")
db.close()
