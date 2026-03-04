from app.database import SessionLocal
from sqlalchemy import text

def check_live_data():
    db = SessionLocal()
    try:
        results = {}
        
        # 1. Total Packages
        res = db.execute(text("SELECT count(*) FROM packages;")).fetchone()
        results['Total Packages'] = res[0]
        
        # 2. Rooms
        res = db.execute(text("SELECT count(*) FROM rooms;")).fetchone()
        results['Total Rooms'] = res[0]
        res = db.execute(text("SELECT count(*) FROM rooms WHERE status = 'occupied';")).fetchone()
        results['Occupied Rooms'] = res[0]
        res = db.execute(text("SELECT count(*) FROM rooms WHERE status = 'available';")).fetchone()
        results['Available Rooms'] = res[0]
        
        # 3. Food Items
        res = db.execute(text("SELECT count(*) FROM food_items;")).fetchone()
        results['Food Items'] = res[0]
        
        # 4. Employees
        res = db.execute(text("SELECT count(*) FROM employees;")).fetchone()
        results['Employees'] = res[0]
        res = db.execute(text("SELECT count(*) FROM users WHERE is_active = true;")).fetchone()
        results['Active Users'] = res[0]
        
        # 5. Sellable Items/Inventory Value (Approx)
        # Sellable Items: 0 (but shows ₹760). Let's check food item prices
        res = db.execute(text("SELECT sum(price) FROM food_items;")).fetchone()
        results['Food Total Value'] = res[0] if res[0] else 0
        
        print("DATABASE COUNTS:")
        for key, val in results.items():
            print(f"{key}: {val}")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_live_data()
