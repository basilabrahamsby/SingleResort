from sqlalchemy import create_engine, text

engine = create_engine("postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb")

with engine.connect() as conn:
    try:
        conn.execute(text("ALTER TABLE employees ADD COLUMN daily_tasks TEXT;"))
        conn.commit()
        print("Successfully added daily_tasks to employees")
    except Exception as e:
        print(f"Error migrating: {e}")
