$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "python3 -c \"
import sys
content = open('/var/www/inventory/ResortApp/app/api/service_request.py').read()
start = content.find('def get_service_requests(')
end = content.find('@router.', start + 1)
if end == -1: end = len(content)
print(content[start:end])
\""
