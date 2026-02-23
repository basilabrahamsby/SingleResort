
from sqlalchemy import create_engine, text
DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"
engine = create_engine(DATABASE_URL)
with engine.connect() as conn:
    print("Settings table keys:")
    try:
        res = conn.execute(text("SELECT key FROM settings")).fetchall()
        print(res)
    except Exception as e:
        print(f"Error reading settings: {e}")

    print("\nSystem Settings table keys:")
    try:
        res = conn.execute(text("SELECT key FROM system_settings")).fetchall()
        print(res)
    except Exception as e:
        print(f"Error reading system_settings: {e}")
