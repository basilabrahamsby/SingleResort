import sys, os
sys.path.insert(0, '/var/www/inventory/ResortApp')
from app.database import SessionLocal
from app.models.user import User

db = SessionLocal()
users = db.query(User).all()
print("Available users:")
for u in users:
    print(f"id={u.id} email={u.email} role={u.role.name if u.role else 'None'}")
db.close()
