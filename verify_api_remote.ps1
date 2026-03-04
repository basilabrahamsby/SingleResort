$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
# This will dump the first 10 requests and find the one for Room 101 (case insensitive) and check its food_order_gst
ssh -i $pem -o StrictHostKeyChecking=no $remote "curl -s http://localhost:8011/api/housekeeping/service-requests?limit=100 | python3 -c \"import sys, json; data=json.load(sys.stdin); [print(f'Room: {r.get(\\\"room_number\\\")} Amount: {r.get(\\\"food_order_amount\\\")} GST: {r.get(\\\"food_order_gst\\\")}') for r in data if '101' in str(r.get(\\\"room_number\\\"))]\""
