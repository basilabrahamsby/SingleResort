
from sqlalchemy import create_engine, inspect

DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"
engine = create_engine(DATABASE_URL)
inspector = inspect(engine)

def check_table(table_name):
    if table_name in inspector.get_table_names():
        print(f"Columns in '{table_name}':")
        columns = inspector.get_columns(table_name)
        for column in columns:
            print(f" - {column['name']}")
    else:
        print(f"Table '{table_name}' does not exist.")

if __name__ == "__main__":
    check_table("employees")
    check_table("working_logs")
    check_table("attendances")
    check_table("leaves")
