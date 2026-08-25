import re

with open("/opt/data/profiles/lewd/projects/comfyui-nginx-auth/repo/nginx/nginx.conf") as f:
    conf = f.read()

checks = {
    "worker_processes": "worker_processes auto;" in conf,
    "events block": "events {" in conf,
    "http block": "http {" in conf,
    "map for WebSocket": "map $http_upgrade $connection_upgrade" in conf,
    "ComfyUI server on 8188": "listen 8188" in conf,
    "FileBrowser server on 8080": "listen 8080" in conf,
    "ComfyUI proxy_pass to 8189": "proxy_pass http://127.0.0.1:8189" in conf,
    "FileBrowser proxy_pass to 8081": "proxy_pass http://127.0.0.1:8081" in conf,
    "auth_basic on ComfyUI": 'auth_basic' in conf and 'ComfyUI' in conf,
    "auth_basic on FileBrowser": 'auth_basic' in conf and 'FileBrowser' in conf,
    "htpasswd file": "/etc/nginx/.htpasswd" in conf,
    "WebSocket Upgrade header": "proxy_set_header Upgrade $http_upgrade" in conf,
    "WebSocket Connection header": "proxy_set_header Connection $connection_upgrade" in conf,
    "proxy_http_version 1.1": "proxy_http_version 1.1" in conf,
    "client_max_body_size 0": "client_max_body_size 0" in conf,
    "proxy_read_timeout for WS": "proxy_read_timeout 86400s" in conf,
}

all_pass = True
for name, ok in checks.items():
    status = "PASS" if ok else "FAIL"
    if not ok:
        all_pass = False
    print(f"  {status}: {name}")

print(f"\n{'All checks passed!' if all_pass else 'Some checks failed!'}")