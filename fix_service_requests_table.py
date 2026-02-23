
from sqlalchemy import create_engine, text

DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"
engine = create_engine(DATABASE_URL)

def add_column_safely(table, column, type_def):
    try:
        with engine.connect() as conn:
            conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {type_def}"))
            conn.commit()
            print(f"Added column {column} to {table}")
    except Exception as e:
        if "already exists" in str(e).lower() or "duplicate column" in str(e).lower():
            print(f"Column {column} already exists in {table}")
        else:
            print(f"Error adding {column} to {table}: {e}")

if __name__ == "__main__":
    # Add pickup_location_id to service_requests
    add_column_safely("service_requests", "pickup_location_id", "INTEGER REFERENCES locations(id)")
    
    # Also check other potential missing columns in service_requests based on the model
    # refill_data TEXT, image_path VARCHAR
    add_column_safely("service_requests", "refill_data", "TEXT")
    add_column_safely("service_requests", "image_path", "VARCHAR(255)")
    add_column_safely("service_requests", "started_at", "TIMESTAMP")
    add_column_safely("service_requests", "completed_at", "TIMESTAMP")
    add_column_safely("service_requests", "billing_status", "VARCHAR(50)")
