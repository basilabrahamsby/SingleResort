#!/bin/bash
set -e

# Nginx Update
echo '[Server] Updating Nginx Config...'
chmod +x ~/orchid-repo/update_nginx.sh
sudo ~/orchid-repo/update_nginx.sh

# Backend deployment
echo '[Backend] Extracting and deploying...'
sudo rm -rf ~/orchid-repo/ResortApp
python3 ~/orchid-repo/extract_fixed.py ~/orchid-repo/backend_deploy.zip ~/orchid-repo/ResortApp
sudo cp -r ~/orchid-repo/ResortApp/* /var/www/inventory/ResortApp/
cd /var/www/inventory/ResortApp/ && sudo python3 ~/orchid-repo/fix_paths.py

# Data Fixes
echo '[Backend] Running Data Fixes...'
# We use || true here to prevent script from stopping if these specific files don't exist or fail
sudo ./venv/bin/python3 fix_rental_prices_by_id.py || echo 'Fix rental prices failed or already run'
sudo ./venv/bin/python3 fix_payable_status.py || echo 'Fix payable status failed or already run'
echo '[Backend] Running Database Migrations...'
sudo ./venv/bin/python3 migrate_database.py || echo 'Migration failed'
sudo ./venv/bin/python3 create_activity_log_table.py || echo 'Activity log table create failed'

# Userend deployment
echo '[Userend] Extracting and deploying...'
sudo rm -rf ~/orchid-repo/userend_build
mkdir -p ~/orchid-repo/userend_build
python3 ~/orchid-repo/extract_fixed.py ~/orchid-repo/userend_deploy.zip ~/orchid-repo/userend_build
sudo mkdir -p /var/www/html/inventory/
sudo cp -r ~/orchid-repo/userend_build/* /var/www/html/inventory/

# Dashboard deployment
echo '[Dashboard] Extracting and deploying...'
sudo rm -rf ~/orchid-repo/dashboard_build
mkdir -p ~/orchid-repo/dashboard_build
python3 ~/orchid-repo/extract_fixed.py ~/orchid-repo/dashboard_deploy.zip ~/orchid-repo/dashboard_build
sudo mkdir -p /var/www/resort/Resort_first/dasboard/build/
sudo rm -rf /var/www/resort/Resort_first/dasboard/build/*
sudo cp -r ~/orchid-repo/dashboard_build/* /var/www/resort/Resort_first/dasboard/build/

# Legacy Dashboard path
sudo mkdir -p /var/www/html/orchidadmin/
sudo rm -rf /var/www/html/orchidadmin/*
sudo cp -r ~/orchid-repo/dashboard_build/* /var/www/html/orchidadmin/

# Restart backend service
echo '[Service] Restarting backend...'
sudo systemctl restart inventory-resort.service

echo 'Deployment complete!'
