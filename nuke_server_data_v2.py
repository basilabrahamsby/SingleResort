import os
import sys
from sqlalchemy import create_engine, text, inspect

# Try to load .env manually if dotenv is not available
def load_env_manual(path):
    if os.path.exists(path):
        with open(path, 'r') as f:
            for line in f:
                if '=' in line and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value
        return True
    return False

# Look in common locations
env_paths = [
    '.env',
    '/var/www/inventory/ResortApp/.env',
    os.path.join(os.getcwd(), '.env')
]

loaded = False
for p in env_paths:
    if load_env_manual(p):
        print(f"Loaded config from {p}")
        loaded = True
        break

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("DATABASE_URL not found in environment or .env files searched.")
    sys.exit(1)

engine = create_engine(DATABASE_URL)

def nuke_except_admin():
    with engine.connect() as conn:
        # Start a transaction
        # For multiple truncates, it's safer
        try:
            inspector = inspect(engine)
            tables = inspector.get_table_names()
            
            # Find admin user
            result = conn.execute(text("SELECT id, email FROM users WHERE email LIKE '%admin%' OR id = 1 ORDER BY id ASC LIMIT 1")).fetchone()
            if not result:
                print("Could not find admin user safely. Aborting.")
                return
            
            admin_id = result[0]
            admin_email = result[1]
            print(f"Preserving admin user: {admin_email} (ID: {admin_id})")
            
            # Tables to avoid truncating
            skip_tables = ['users', 'roles', 'alembic_version', 'settings']
            
            # Order tables to handle dependencies if CASCADE is not enough (though it should be)
            for table in tables:
                if table not in skip_tables:
                    try:
                        print(f"Truncating {table}...")
                        conn.execute(text(f"TRUNCATE TABLE \"{table}\" CASCADE"))
                    except Exception as e:
                        print(f"Failed to truncate {table}: {e}")
            
            # Clean up users table, keep ONLY the admin
            print("Cleaning up users table...")
            conn.execute(text(f"DELETE FROM users WHERE id != {admin_id}"))
            
            conn.execute(text("COMMIT"))
            print("\n✅ Success! All data cleared except Admin credentials.")
            
        except Exception as e:
            conn.execute(text("ROLLBACK"))
            print(f"Error during cleanup: {e}")
            raise

if __name__ == "__main__":
    nuke_except_admin()
