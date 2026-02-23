from app.database import SessionLocal
from app.models.employee import Employee, WorkingLog
from datetime import date, time, timedelta, datetime
import random

def seed_logs():
    db = SessionLocal()
    try:
        employees = db.query(Employee).all()
        if not employees:
            print("No employees found. Seed employees first.")
            return

        print(f"Seeding logs for {len(employees)} employees...")
        today = date.today()
        
        # Seed for last 6 months
        for i in range(180):
            log_date = today - timedelta(days=i)
            # Skip weekends maybe? Nah, just seed some.
            for emp in employees:
                if random.random() > 0.3: # 70% attendance
                    # 8 hours roughly
                    check_in = time(9, 0)
                    check_out = time(17, random.randint(0, 59))
                    
                    # Check if already exists
                    existing = db.query(WorkingLog).filter(
                        WorkingLog.employee_id == emp.id,
                        WorkingLog.date == log_date
                    ).first()
                    
                    if not existing:
                        log = WorkingLog(
                            employee_id=emp.id,
                            date=log_date,
                            check_in_time=check_in,
                            check_out_time=check_out,
                            location="Office"
                        )
                        db.add(log)
            
            if i % 30 == 0:
                print(f"Commiting logs for {log_date}...")
                db.commit()
        
        db.commit()
        print("Seeding completed successfully.")
    except Exception as e:
        db.rollback()
        print(f"Error seeding logs: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_logs()
