import json
import sys
import urllib.request
import urllib.error

BASE_URL = "http://localhost:8011/api"
EMAIL = "admin@orchid.com"
PASSWORD = "admin123"

def get_token():
    url = f"{BASE_URL}/auth/login"
    data = json.dumps({"email": EMAIL, "password": PASSWORD}).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                body = response.read().decode('utf-8')
                return json.loads(body).get("access_token")
            else:
                print(f"Login failed: {response.status}")
                return None
    except urllib.error.HTTPError as e:
        print(f"Login HTTP Error: {e.code} {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error login: {e}")
        return None

def get_bill(token, room_number, mode="single"):
    url = f"{BASE_URL}/bill/{room_number}?checkout_mode={mode}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                body = response.read().decode('utf-8')
                return json.loads(body)
            else:
                print(f"Get bill failed: {response.status}")
                return None
    except urllib.error.HTTPError as e:
        print(f"Get Bill HTTP Error: {e.code} {e.read().decode('utf-8')}")
        if e.code == 500:
             # On 500, sometimes detail is in body
             print(f"Detail: {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error getting bill: {e}")
        return None

if __name__ == "__main__":
    print("Getting token...")
    token = get_token()
    if not token:
        sys.exit(1)
    
    print(f"Got token: {token[:20]}...")
    
    print("Getting bill for room 200...")
    bill = get_bill(token, "200", "single")
    if bill:
        charges = bill.get("charges", {})
        print("\n=== SERVICE ITEMS ===")
        print(json.dumps(charges.get("service_items", []), indent=2))
        
        print("\n=== FOOD ITEMS ===")
        print(json.dumps(charges.get("food_items", []), indent=2))
        
        print("\n=== CHARGES SUMMARY ===")
        print(f"Service Charges: {charges.get('service_charges')}")
        print(f"Food Charges: {charges.get('food_charges')}")
    else:
        print("Failed to get bill")
