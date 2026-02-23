
from sqlalchemy import create_engine, text
import requests

DATABASE_URL = "postgresql+psycopg2://postgres:qwerty123@localhost:5432/orchiddb"
engine = create_engine(DATABASE_URL)

def test_api():
    try:
        with engine.connect() as conn:
            user = conn.execute(text("SELECT id, name FROM users WHERE name ILIKE '%harry%'")).fetchone()
            if user:
                print(f"Testing for user: {user.name} (id: {user.id})")
                # Try to call the API locally if it's running
                # The .env says PORT=8011, but main.py says default 8012. 
                # Terminal logs show: cd ResortApp; .\venv\Scripts\python main.py
                # Let's check which port it's on.
                port = 8011
                try:
                    r = requests.get(f"http://localhost:{port}/api/reports/user-history?user_id={user.id}")
                    print(f"API Response on {port}: {r.status_code}")
                    if r.status_code != 200:
                        print(f"Error detail: {r.text}")
                except Exception as e:
                    print(f"Failed to connect to {port}: {e}")
                    
                port = 8012
                try:
                    r = requests.get(f"http://localhost:{port}/api/reports/user-history?user_id={user.id}")
                    print(f"API Response on {port}: {r.status_code}")
                    if r.status_code != 200:
                        print(f"Error detail: {r.text}")
                except Exception as e:
                    print(f"Failed to connect to {port}: {e}")
            else:
                print("User harry not found")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_api()
