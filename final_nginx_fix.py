import os

def final_fix():
    path = "/etc/nginx/sites-available/teqmates"
    with open(path, "r") as f:
        content = f.read()

    start_anchor = "location /orchidadmin/"
    end_anchor = "location /orchidapi/"
    
    start_idx = content.find(start_anchor)
    end_idx = content.find(end_anchor)

    if start_idx == -1 or end_idx == -1:
        print("Anchors not found!")
        return

    # Cleaned middle part
    middle = """location /orchidadmin/ {
        alias /var/www/html/orchidadmin/;
        index index.html;
        try_files $uri $uri/ /orchidadmin/index.html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
    }

    location = /orchidadmin {
        return 301 $scheme://$http_host/orchidadmin/;
    }

    # """

    new_content = content[:start_idx] + middle + content[end_idx:]
    
    with open("/tmp/teqmates_fixed_final", "w") as f:
        f.write(new_content)
    
    print("Fixed Nginx config written.")

if __name__ == "__main__":
    final_fix()
