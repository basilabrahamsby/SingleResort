import requests
import json
import sys

BASE_URL = "http://localhost:8011/api"
USERNAME = "admin"
PASSWORD = "admin123"

def get_token():
    url = f"{BASE_URL}/auth/login"
    try:
        response = requests.post(url, json={"username": USERNAME, "password": PASSWORD})
        if response.status_code == 200:
            return response.json().get("access_token")
        else:
            print(f"Login failed: {response.status_code} {response.text}")
            return None
    except Exception as e:
        print(f"Error connecting to login: {e}")
        return None

def get_bill(token, room_number, mode="single"):
    url = f"{BASE_URL}/bill/{room_number}?checkout_mode={mode}"
    headers = {"Authorization": f"Bearer {token}"}
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Get bill failed: {response.status_code} {response.text}")
            return None
    except Exception as e:
        print(f"Error getting bill: {e}")
        return None

if __name__ == "__main__":
    token = get_token()
    if not token:
        sys.exit(1)
    
    print(f"Got token: {token[:20]}...")
    
    bill = get_bill(token, "200", "single")
    if bill:
        charges = bill.get("charges", {})
        print("\n=== SERVICE ITEMS ===")
        service_items = charges.get("service_items", [])
        print(json.dumps(service_items, indent=2))
        
        print("\n=== FOOD ITEMS ===")
        food_items = charges.get("food_items", [])
        print(json.dumps(food_items, indent=2))
        
        print("\n=== CHARGES SUMMARY ===")
        print(f"Service Charges: {charges.get('service_charges')}")
        print(f"Food Charges: {charges.get('food_charges')}")
    else:
        print("Failed to get bill")
