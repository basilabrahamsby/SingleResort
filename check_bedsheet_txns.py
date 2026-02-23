import sys, os, json
sys.path.insert(0, '/var/www/inventory/ResortApp')
from app.database import SessionLocal
from app.models.service import AssignedService, Service
from app.models.foodorder import FoodOrder, FoodOrderItem
from app.models.room import Room
from app.models.booking import Booking
from sqlalchemy.orm import joinedload
from datetime import datetime

db = SessionLocal()

# Get room and booking
room = db.query(Room).filter(Room.number == "200").first()
print(f"Room 200: id={room.id}")

# Find active booking for this room
booking = db.query(Booking).filter(Booking.status == "checked-in").order_by(Booking.id.desc()).first()
if booking:
    print(f"Active Booking: #{booking.id} guest={booking.guest_name} check_in={booking.check_in}")
    
    # Check if booking has rooms
    rooms = getattr(booking, 'rooms', None)
    room_ids = [r.id for r in rooms] if rooms else [room.id]
    print(f"Room IDs in booking: {room_ids}")
    
    check_in = booking.check_in
    print(f"Check-in date: {check_in} (type={type(check_in)})")
    
    # Check assigned services
    print("\n=== ASSIGNED SERVICES ===")
    all_svc = db.query(AssignedService).options(
        joinedload(AssignedService.service)
    ).filter(
        AssignedService.room_id.in_(room_ids)
    ).all()
    print(f"Total services for room IDs {room_ids}: {len(all_svc)}")
    
    for a in all_svc:
        print(f"  #{a.id} svc={a.service.name if a.service else '?'}")
        print(f"    room_id={a.room_id} booking_id={a.booking_id}")
        print(f"    billing_status={a.billing_status}")
        print(f"    assigned_at={a.assigned_at}")
        
        # Check if it passes the filter
        if booking:
            if a.booking_id == booking.id:
                print(f"    MATCH: booking_id matches")
            elif a.booking_id is None and a.assigned_at:
                check_in_dt = datetime.combine(check_in, datetime.min.time()) if hasattr(check_in, 'date') == False else check_in
                print(f"    check_in_dt={check_in_dt} assigned_at={a.assigned_at}")
                if a.assigned_at >= check_in_dt:
                    print(f"    MATCH: no booking_id, assigned after check-in")
                else:
                    print(f"    NO MATCH: assigned before check-in")
            else:
                print(f"    NO MATCH: booking_id={a.booking_id} != {booking.id}")

    # Check food orders
    print("\n=== FOOD ORDERS ===")
    food_orders = db.query(FoodOrder).filter(
        FoodOrder.room_id.in_(room_ids)
    ).all()
    print(f"Total food orders for room IDs {room_ids}: {len(food_orders)}")
    for fo in food_orders:
        print(f"  #{fo.id} amount={fo.amount} status={fo.status}")
        print(f"    billing_status={fo.billing_status}")
        print(f"    created_at={fo.created_at}")

db.close()
