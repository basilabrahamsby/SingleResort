$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "grep -C 10 'gst_amount = amount \* 0.05' /var/www/inventory/ResortApp/app/curd/foodorder.py"
