for both owner and $pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "sed -n '50,150p' /var/www/inventory/ResortApp/app/api/service_request.py"
