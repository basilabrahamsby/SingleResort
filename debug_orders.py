from app.database import SessionLocal
from app.models.foodorder import FoodOrder
from app.models.employee import Employee
from app.models.room import Room

db = SessionLocal()

orders = db.query(FoodOrder).order_by(FoodOrder.id.desc()).limit(10).all()

print(f"{'ID':<5} | {'Room':<6} | {'Status':<10} | {'Assigned':<10} | {'Prepared':<10} | {'Created At'}")
print("-" * 80)

for o in orders:
    room = db.query(Room).filter(Room.id == o.room_id).first()
    room_num = room.number if room else "N/A"
    assigned = str(o.assigned_employee_id) if o.assigned_employee_id else "None"
    prepared = str(o.prepared_by_id) if o.prepared_by_id else "None"
    print(f"{o.id:<5} | {room_num:<6} | {o.status:<10} | {assigned:<10} | {prepared:<10} | {o.created_at}")

# Also find the employee ID for 'kitch'
kitch = db.query(Employee).filter(Employee.name.like("%kitch%")).first()
if kitch:
    print(f"\nEmployee 'kitch': ID={kitch.id}, Name={kitch.name}")
else:
    print("\nEmployee 'kitch' not found")

db.close()
