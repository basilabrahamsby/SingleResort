import os
from sqlalchemy import text
from app.database import SessionLocal

def check_gst_data():
    db = SessionLocal()
    try:
        # Check active food orders for Room 101
        res = db.execute(text("""
            SELECT fo.id, fo.amount, fo.gst_amount, fo.total_with_gst, fo.status
            FROM food_orders fo
            JOIN rooms r ON fo.room_id = r.id
            WHERE r.number = '101' AND fo.is_deleted = false
            ORDER BY fo.created_at DESC LIMIT 5
        """)).fetchall()
        
        print("FOOD ORDERS FOR ROOM 101:")
        for r in res:
            print(f"ID: {r[0]} | Amount: {r[1]} | GST: {r[2]} | Total: {r[3]} | Status: {r[4]}")
            
        # Check service requests for Room 101
        res = db.execute(text("""
            SELECT sr.id, sr.food_order_id, sr.status, sr.request_type
            FROM service_requests sr
            JOIN rooms r ON sr.room_id = r.id
            WHERE r.number = '101'
            ORDER BY sr.created_at DESC LIMIT 5
        """)).fetchall()
        
        print("\nSERVICE REQUESTS FOR ROOM 101:")
        for r in res:
            print(f"ID: {r[0]} | FoodOrderID: {r[1]} | Status: {r[2]} | Type: {r[3]}")
    finally:
        db.close()

if __name__ == "__main__":
    check_gst_data()
