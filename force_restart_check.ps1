$pem = "$env:USERPROFILE\.ssh\gcp_key"
$remote = "basilabrahamaby@34.30.59.169"

Write-Host "Service PID before restart:"
ssh -i $pem -o StrictHostKeyChecking=no $remote "pgrep -f uvicorn"

ssh -i $pem -o StrictHostKeyChecking=no $remote "sudo systemctl restart inventory-resort.service"
Start-Sleep -Seconds 5

Write-Host "Service PID after restart:"
ssh -i $pem -o StrictHostKeyChecking=no $remote "pgrep -f uvicorn"
