import requests
import json

base_url = "http://localhost:8011/api"

def get_token():
    # We'll try to get a valid token if possible, or just test without it to see the 401 vs 422
    # But since we can't easily get it here, let's assume one of the open endpoints might fail with 422
    pass

def test(path):
    print(f"\nTesting {path}...")
    try:
        # Some endpoints require auth. For now let's just see if we get a 422 for validation even without auth if the params are wrong.
        # But aggregate/status/today/holidays take no params other than auth.
        r = requests.get(f"{base_url}{path}")
        print(f"Status: {r.status_code}")
        if r.status_code == 422:
            print(f"422 Detail: {json.dumps(r.json(), indent=2)}")
        else:
            print(f"Response: {r.text[:200]}...")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Test endpoints called on overview load
    test("/attendance/utilization/aggregate")
    test("/attendance/holidays")
    test("/attendance/status/today")
    test("/employees")
