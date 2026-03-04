$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "curl -s http://localhost:8011/api/housekeeping/service-requests?limit=200 | python3 /tmp/verify_api.py"
