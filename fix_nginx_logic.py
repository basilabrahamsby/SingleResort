import os

def fix_nginx():
    file_path = "/etc/nginx/sites-available/teqmates"
    with open(file_path, "r") as f:
        content = f.read()

    # Define the block to replace
    # NOTE: I'll search for the location /orchidadmin and find its matching closing brace
    start_str = "location /orchidadmin {"
    idx = content.find(start_str)
    if idx == -1:
        print("Block not found!")
        return

    # Find the matching closing brace for this specific block
    # It has a nested block, so we count braces
    brace_count = 0
    end_idx = -1
    for i in range(idx, len(content)):
        if content[i] == '{':
            brace_count += 1
        elif content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                end_idx = i + 1
                break
    
    if end_idx == -1:
        print("Matching brace not found!")
        return
        
    old_block = content[idx:end_idx]
    
    # New block
    new_block = """location /orchidadmin/ {
        alias /var/www/html/orchidadmin/;
        index index.html;
        try_files $uri $uri/ /orchidadmin/index.html;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0";
    }

    location = /orchidadmin {
        return 301 $scheme://$http_host/orchidadmin/;
    }"""

    new_content = content[:idx] + new_block + content[end_idx:]
    
    with open("/tmp/teqmates_new", "w") as f:
        f.write(new_content)
    
    print("New Nginx config generated successfully.")

if __name__ == "__main__":
    fix_nginx()
