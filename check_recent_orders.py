from app.database import SessionLocal
from app.models.foodorder import FoodOrder
from app.models.room import Room

db = SessionLocal()

# Get the most recent 5 orders
orders = db.query(FoodOrder).order_by(FoodOrder.id.desc()).limit(10).all()

print(f"{'ID':<5} | {'Room':<6} | {'Status':<12} | {'Amount':<8} | {'Created At'}")
print("-" * 60)

for o in orders:
    room = db.query(Room).filter(Room.id == o.room_id).first()
    room_num = room.number if room else "N/A"
    print(f"{o.id:<5} | {room_num:<6} | {o.status:<12} | {o.amount:<8} | {o.created_at}")

db.close()
