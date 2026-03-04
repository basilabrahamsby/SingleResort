import os
from sqlalchemy import create_engine, text, inspect
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("DATABASE_URL not found in .env")
    exit(1)

engine = create_engine(DATABASE_URL)

def nuke_except_admin():
    with engine.connect() as conn:
        trans = conn.begin()
        try:
            inspector = inspect(engine)
            tables = inspector.get_table_names()
            
            print(f"Found tables: {', '.join(tables)}")
            
            # Find admin user
            result = conn.execute(text("SELECT id, email FROM users WHERE email LIKE '%admin%' OR id = 1 LIMIT 1")).fetchone()
            if not result:
                print("Could not find admin user safely. Aborting.")
                return
            
            admin_id = result[0]
            admin_email = result[1]
            print(f"Preserving admin user: {admin_email} (ID: {admin_id})")
            
            # 1. Truncate all transactional and master data tables
            # We skip 'users' and 'roles' to be safe, we will handle users manually
            skip_tables = ['users', 'roles', 'alembic_version']
            
            for table in tables:
                if table not in skip_tables:
                    try:
                        print(f"Truncating {table}...")
                        conn.execute(text(f"TRUNCATE TABLE {table} CASCADE"))
                    except Exception as e:
                        print(f"Failed to truncate {table}: {e}")
            
            # 2. Clean up users table, keep ONLY the admin
            print("Cleaning up users table...")
            conn.execute(text(f"DELETE FROM users WHERE id != {admin_id}"))
            
            trans.commit()
            print("\n✅ Success! All data cleared except Admin credentials.")
            
        except Exception as e:
            trans.rollback()
            print(f"Error during cleanup: {e}")
            raise

if __name__ == "__main__":
    nuke_except_admin()
