import os

def fix_nginx():
    file_path = "/etc/nginx/sites-available/teqmates"
    with open(file_path, "r") as f:
        content = f.read()

    # Old block for orchidadmin
    old_target = "location /orchidadmin {"
    # Improved block - making it the longest match and fixing trailing slash
    new_target = """location /orchidadmin {
        alias /var/www/html/orchidadmin/;
        index index.html;
        try_files $uri $uri/ /orchidadmin/index.html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";"""
    
    if old_target in content:
        content = content.replace(old_target, new_target, 1) # Only first
        # ensure there is no recursive location or duplicate alias for it
    
    with open("/tmp/teqmates_fixed", "w") as f:
        f.write(content)
        
    print("Fixed Nginx file written to /tmp/teqmates_fixed")

if __name__ == "__main__":
    fix_nginx()
