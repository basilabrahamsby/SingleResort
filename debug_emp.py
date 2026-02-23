
from sqlalchemy import create_engine, text

DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    res = conn.execute(text("SELECT id, name, user_id FROM employees WHERE user_id = 1")).fetchall()
    print(f"Employee records for user_id 1: {res}")
    
    res2 = conn.execute(text("SELECT id, name, user_id FROM employees WHERE id = 5")).fetchall()
    print(f"Employee record with id 5: {res2}")
