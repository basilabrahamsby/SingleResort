from sqlalchemy import text
from app.database import SessionLocal

def migrate_gst():
    db = SessionLocal()
    try:
        # Update food_orders where gst_amount is null
        res = db.execute(text("""
            UPDATE food_orders 
            SET gst_amount = amount * 0.05,
                total_with_gst = amount * 1.05
            WHERE (gst_amount IS NULL OR gst_amount = 0) AND amount > 0
            RETURNING id, amount, gst_amount
        """))
        updated = res.fetchall()
        print(f"Updated {len(updated)} food orders.")
        for r in updated:
            print(f"  - ID: {r[0]}, Amount: {r[1]}, GST: {r[2]}")
        
        db.commit()
    except Exception as e:
        print(f"Error during migration: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate_gst()
