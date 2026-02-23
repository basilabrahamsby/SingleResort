
import os
from sqlalchemy import create_engine, inspect

DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"

try:
    engine = create_engine(DATABASE_URL)
    inspector = inspect(engine)

    table_name = "service_requests"
    with open("schema_inspect.txt", "w") as f:
        if table_name in inspector.get_table_names():
            f.write(f"Columns in '{table_name}':\n")
            columns = inspector.get_columns(table_name)
            for column in columns:
                f.write(f" - {column['name']} ({column['type']})\n")
        else:
            f.write(f"Table '{table_name}' does not exist.\n")
except Exception as e:
    with open("schema_inspect.txt", "w") as f:
        f.write(f"Error: {str(e)}\n")
