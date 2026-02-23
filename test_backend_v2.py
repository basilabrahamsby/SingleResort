import requests
import json

base_url = "http://localhost:8011/api"

def test_endpoint(path):
    print(f"\n--- Testing {path} ---")
    try:
        response = requests.get(f"{base_url}{path}")
        print(f"Status: {response.status_code}")
        try:
            print(f"Body: {json.dumps(response.json(), indent=2)}")
        except:
            print(f"Body: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Test without auth to see if we get 401 or 422
    test_endpoint("/attendance/utilization/aggregate")
    test_endpoint("/attendance/holidays")
    test_endpoint("/attendance/status/today")
