import os
with open('deploy_remote.sh', 'rb') as f:
    data = f.read().replace(b'\r', b'')
with open('deploy_remote_lf.sh', 'wb') as f:
    f.write(data)
print("Converted deploy_remote.sh to LF and saved as deploy_remote_lf.sh")
