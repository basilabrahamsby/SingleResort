import requests

base_url = "http://localhost:8011/api" # Most common port in previous turns

def test_endpoint(path):
    print(f"Testing {path}...")
    try:
        # We need a token. Let's try to get one or skip auth if possible.
        # But our new endpoints require auth.
        # Let's see if we can at least see the 422/500 detail without auth if it's a validation error.
        response = requests.get(f"{base_url}{path}")
        print(f"Status Output: {response.status_code}")
        print(f"Response Body: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_endpoint("/attendance/utilization/aggregate")
    test_endpoint("/attendance/holidays")
    test_endpoint("/attendance/status/today")
