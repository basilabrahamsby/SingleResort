from app.database import SessionLocal
from sqlalchemy import text
import sys

def final_cleanup():
    db = SessionLocal()
    try:
        # 1. Get Admin Role IDs
        res = db.execute(text("SELECT id FROM roles WHERE LOWER(name) IN ('admin', 'superadmin', 'owner', 'manager');"))
        admin_role_ids = [row[0] for row in res.fetchall()]
        role_ids_str = ",".join(map(str, admin_role_ids))
        
        # 2. Identify Users to KEEP
        res = db.execute(text(f"SELECT id FROM users WHERE role_id IN ({role_ids_str});"))
        keep_user_ids = [row[0] for row in res.fetchall()]
        keep_user_ids_str = ",".join(map(str, keep_user_ids))
        
        print(f"Keeping User IDs: {keep_user_ids_str}")

        # 3. Clear Transactional Tables (One more pass to be sure)
        # We'll use a very long list this time
        tables = [
            "food_order_items", "food_orders", "service_requests", "assigned_services",
            "checkout_verifications", "checkout_requests", "checkouts", "checkout_payments",
            "booking_rooms", "bookings", "package_booking_rooms", "package_bookings",
            "working_logs", "attendances", "leaves", "notifications", "activity_logs",
            "stock_issue_details", "stock_issues", "stock_requisition_details", "stock_requisitions",
            "inventory_transactions", "waste_logs", "wastage_logs", "consumable_usage",
            "salary_payments", "journal_entry_lines", "journal_entries", "payments",
            "expenses", "vouchers", "damage_reports", "laundry_logs", "room_inventory_audits",
            "room_consumable_assignments", "audit_discrepancies", "eod_audits", "eod_audit_items"
        ]
        
        for t in tables:
            try:
                res = db.execute(text(f"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '{t}');"))
                if res.fetchone()[0]:
                    db.execute(text(f"DELETE FROM {t};"))
            except:
                db.rollback()

        # 4. Clear Employees EXCEPT those linked to kept users
        print("Clearing non-admin employees...")
        db.execute(text(f"DELETE FROM employees WHERE user_id NOT IN ({keep_user_ids_str}) OR user_id IS NULL;"))
        
        # 5. Clear Users EXCEPT those to keep
        print("Clearing non-admin users...")
        db.execute(text(f"DELETE FROM users WHERE id NOT IN ({keep_user_ids_str});"))
        
        # 6. Reset Room states
        print("Resetting rooms...")
        db.execute(text("UPDATE rooms SET status = 'available', housekeeping_status = 'clean' WHERE true;"))
        
        db.commit()
        print("--- FINAL CLEANUP COMPLETED ---")
        
    except Exception as e:
        print(f"ERROR: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    final_cleanup()
