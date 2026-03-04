import requests

def test_login():
    url = "http://localhost:8011/api/auth/login"
    data = {"email": "a@h.com", "password": "admin123"}
    try:
        r = requests.post(url, json=data)
        print(f"Status: {r.status_code}")
        print(f"Response: {r.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_login()
