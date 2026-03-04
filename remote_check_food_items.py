import os
import sys

# Add the current directory to sys.path to find the 'app' module
sys.path.append(os.getcwd())

from app.database import SessionLocal
from app.models.foodorder import FoodOrder, FoodOrderItem
from app.models.food_item import FoodItem

db = SessionLocal()
try:
    orders = db.query(FoodOrder).all()
    print("Food Orders and Items:")
    for o in orders:
        items = db.query(FoodOrderItem).filter(FoodOrderItem.order_id == o.id).all()
        item_details = []
        for i in items:
            fi = db.query(FoodItem).filter(FoodItem.id == i.food_item_id).first()
            item_details.append(f"{fi.name} x {i.quantity}" if fi else f"Item {i.food_item_id} x {i.quantity}")
        print(f"Order #{o.id}, Status: {o.status}, Items: {', '.join(item_details)}")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()
