import requests
import json

base_url = "http://localhost:8011/api"

# Payload similar to what frontend sends
payload = [
    {"date": "DEC 25", "name": "Christmas"},
    {"date": "JAN 01", "name": "New Year"},
    {"date": "JAN 26", "name": "Republic Day"},
    {"date": "FEB 21", "name": "leave"}
]

print("Testing POST /attendance/holidays...")
# Note: This might return 401 if we don't have a token, but let's see if it hits 422 first
r = requests.post(f"{base_url}/attendance/holidays", json=payload)
print(f"Status: {r.status_code}")
if r.status_code == 422:
    print(f"422 Detail: {json.dumps(r.json(), indent=2)}")
else:
    print(f"Response: {r.text}")
