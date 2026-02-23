
# ... (imports) ...
import sys
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from app.database import SQLALCHEMY_DATABASE_URL
    from app.models.user import User
except ImportError as e:
    print(f"Error importing app modules: {e}")
    sys.exit(1)

def clear_data():
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("Starting data cleanup...")
        
        # Get admin user
        admin = session.query(User).filter(User.email == "admin@orchid.com").first()
        if not admin:
             admin = session.query(User).filter(User.id == 1).first()
        
        if admin:
            print(f"Preserving Admin User: {admin.email} (ID: {admin.id})")
        else:
            print("WARNING: Admin user not found. Aborting safety check.")
            return

        # List of tables to clear (Order matters for FK)
        tables = [
            # Notifications
            "notifications",
            
            # Checkout / Billing
            "checkout_verifications",
            "checkout_requests",
            "checkout_payments",
            "checkout_items",
            "employee_inventory_assignments", # Added
            "checkouts",
            "billing_records",
            
            # Services & Food
            "assigned_services", 
            "food_order_items", # Detail before Master
            "food_orders",
            "service_requests",
            
            # Bookings
            "package_booking_rooms",
            "package_bookings",
            "booking_rooms",
            "bookings",
            
            # Inventory / Stock
            "waste_logs",
            "stock_issue_details",
            "stock_issues",
            "stock_requisition_details",
            "stock_requisitions",
            "inventory_transactions",
            "location_stocks",
            "purchase_details", # Detail before Master
            "purchase_masters",
            "laundry_logs",
            "consumption_logs",
            "asset_mappings", 
            
            # Financial
            "expenses",
            "payments",
            "journal_entries",
            
            # Misc
            "suggestions",
            "attendance_logs",
        ]

        print(f"Clearing {len(tables)} transactional tables...")
        
        for table in tables:
            try:
                exists = session.execute(text(f"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '{table}')")).scalar()
                if not exists:
                    print(f"Skipping {table} (not found)")
                    continue
                
                # Delete
                result = session.execute(text(f"DELETE FROM {table}"))
                session.commit()
                # Row count might be available
                print(f"✓ Cleared {table} ({result.rowcount} rows)")
            except Exception as e:
                session.rollback()
                print(f"❌ Error clearing {table}: {e}")

        # Clear Users and Employees (Except Admin)
        print("Clearing non-admin users and employees...")
        
        try:
            # Clear employees linked to non-admin users
            session.execute(text(f"DELETE FROM employees WHERE user_id != {admin.id} OR user_id IS NULL"))
            session.commit()
            print("✓ Cleared non-admin employees")
            
            # Clear non-admin users
            session.execute(text(f"DELETE FROM users WHERE id != {admin.id}"))
            session.commit()
            print("✓ Cleared non-admin users")
        except Exception as e:
            session.rollback()
            print(f"❌ Error clearing users/employees: {e}")

        # Reset Inventory Stock
        print("Resetting inventory stocks to 0...")
        try:
            session.execute(text("UPDATE inventory_items SET current_stock = 0"))
            session.commit()
            print("✓ Stocks reset")
        except Exception as e:
            session.rollback()
            print(f"❌ Error resetting stocks: {e}")

        # Reset Room Status
        print("Resetting room status...")
        try:
            session.execute(text("UPDATE rooms SET status = 'Available'"))
            session.commit()
            print("✓ Rooms reset to Available")
        except Exception as e:
            session.rollback()
            print(f"❌ Error resetting rooms: {e}")

        print("\n✅ Cleanup Complete!")

    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
    finally:
        session.close()

if __name__ == "__main__":
    clear_data()
