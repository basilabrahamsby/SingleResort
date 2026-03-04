$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"
ssh -i $pem -o StrictHostKeyChecking=no $remote "grep -A 10 'location /orchidapi/' /etc/nginx/sites-available/default"
ssh -i $pem -o StrictHostKeyChecking=no $remote "grep -A 10 'location /orchidapi/' /etc/nginx/sites-available/teqmates"
