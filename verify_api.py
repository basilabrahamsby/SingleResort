import json
import sys

def check_structure():
    try:
        data = json.load(sys.stdin)
        print(f"Type: {type(data)}")
        if isinstance(data, dict):
            print(f"Keys: {data.keys()}")
            # If it has 'requests' or 'results'
            items = data.get('requests') or data.get('results') or []
        elif isinstance(data, list):
            items = data
        else:
            print("Unknown structure")
            return

        for req in items:
            room = str(req.get('room_number', ''))
            if '101' in room:
                amount = req.get('food_order_amount')
                gst = req.get('food_order_gst')
                total = req.get('food_order_total')
                print(f"ROOM: {room} | Amount: {amount} | GST: {gst} | Total: {total}")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    check_structure()
