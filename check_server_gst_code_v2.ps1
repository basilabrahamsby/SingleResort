$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "cat /var/www/inventory/ResortApp/app/api/service_request.py" | Select-String -Context 2,10 "fo_gst"
