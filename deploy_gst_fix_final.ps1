$ErrorActionPreference = "Stop"
$serverIP = "34.30.59.169"
$username = "basilabrahamaby"
$sshKey = "$env:USERPROFILE\.ssh\gcp_key"
$remoteBase = "/var/www/inventory/ResortApp"

$filesToDeploy = @(
    @{ local = "ResortApp\app\curd\foodorder.py"; remote = "app/curd/foodorder.py" },
    @{ local = "ResortApp\app\api\service_request.py"; remote = "app/api/service_request.py" },
    @{ local = "ResortApp\app\schemas\service_request.py"; remote = "app/schemas/service_request.py" }
)

foreach ($file in $filesToDeploy) {
    Write-Host "Uploading $($file.local)..."
    scp -i $sshKey -o StrictHostKeyChecking=no "$($file.local)" "${username}@${serverIP}:/tmp/$(Split-Path $file.local -Leaf)"
    
    Write-Host "Moving to production directory..."
    ssh -i $sshKey -o StrictHostKeyChecking=no "${username}@${serverIP}" "sudo cp /tmp/$(Split-Path $file.local -Leaf) $remoteBase/$($file.remote)"
}

Write-Host "Restarting backend service..."
ssh -i $sshKey -o StrictHostKeyChecking=no "${username}@${serverIP}" "sudo systemctl restart inventory-resort.service"

Write-Host "Deployment Complete!"
