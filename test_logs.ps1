$pem = "$env:USERPROFILE\.ssh\gcp_key"
ssh -o StrictHostKeyChecking=no -i $pem basilabrahamaby@136.113.93.47 "pm2 logs ResortApp --lines 100 --nostream"
