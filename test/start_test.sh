#!/bin/bash
set -e

# ---- Replicate the auth setup from start.sh ----
setup_auth() {
    echo "Setting up nginx Basic Auth..."

    if [ -z "$WEB_PASSWORD" ]; then
        echo "ERROR: WEB_PASSWORD environment variable is required."
        echo "       Aborting startup."
        exit 1
    fi

    WEB_USERNAME="${WEB_USERNAME:-admin}"
    htpasswd -bc /etc/nginx/.htpasswd "$WEB_USERNAME" "$WEB_PASSWORD"
    chmod 644 /etc/nginx/.htpasswd
    echo "Basic Auth configured for user: $WEB_USERNAME"
}

setup_auth

# ---- Start mock backends ----
echo "Starting mock ComfyUI backend on 127.0.0.1:8189..."
python3 /mock_backend.py --port 8189 --name ComfyUI &

echo "Starting mock FileBrowser backend on 127.0.0.1:8081..."
python3 /mock_backend.py --port 8081 --name FileBrowser &

sleep 1

# ---- Start nginx ----
echo "Starting nginx..."
nginx -t
nginx

sleep 1

# ---- Run tests ----
echo ""
echo "=============================================="
echo "  Running authentication tests"
echo "=============================================="

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $desc (got $actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# Test 1: Unauthenticated ComfyUI → 401
STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/)
check "Unauthenticated ComfyUI returns 401" "401" "$STATUS"

# Test 2: Unauthenticated FileBrowser → 401
STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/)
check "Unauthenticated FileBrowser returns 401" "401" "$STATUS"

# Test 3: Authenticated ComfyUI → 200
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -u "admin:${WEB_PASSWORD}" http://127.0.0.1:8188/)
check "Authenticated ComfyUI returns 200" "200" "$STATUS"

# Test 4: Authenticated FileBrowser → 200
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -u "admin:${WEB_PASSWORD}" http://127.0.0.1:8080/)
check "Authenticated FileBrowser returns 200" "200" "$STATUS"

# Test 5: Wrong password → 401
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -u "admin:wrongpass" http://127.0.0.1:8188/)
check "Wrong password returns 401" "401" "$STATUS"

# Test 6: Custom username works
if [ -n "$TEST_CUSTOM_USER" ]; then
    STATUS=$(curl -s -o /dev/null -w '%{http_code}' -u "myuser:${WEB_PASSWORD}" http://127.0.0.1:8188/)
    check "Custom username auth returns 200" "200" "$STATUS"
fi

# Test 7: Backend port not accessible from outside (localhost only)
# Since we can't test from outside the container, verify the backend is on localhost
STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8189/)
check "Backend ComfyUI reachable on localhost:8189" "200" "$STATUS"

STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8081/)
check "Backend FileBrowser reachable on localhost:8081" "200" "$STATUS"

# Test 8: WebSocket upgrade headers pass through
WS_RESULT=$(curl -s -o /dev/null -w '%{http_code}' \
    -u "admin:${WEB_PASSWORD}" \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    http://127.0.0.1:8188/ws)
# Mock backend returns 200 for WS upgrade attempt; real ComfyUI would complete the handshake
check "WebSocket upgrade request passes through nginx" "200" "$WS_RESULT"

# Test 9: Content is from the correct backend
BODY=$(curl -s -u "admin:${WEB_PASSWORD}" http://127.0.0.1:8188/ | grep -o 'ComfyUI' | head -1)
check "ComfyUI proxy returns ComfyUI content" "ComfyUI" "$BODY"

BODY=$(curl -s -u "admin:${WEB_PASSWORD}" http://127.0.0.1:8080/ | grep -o 'FileBrowser' | head -1)
check "FileBrowser proxy returns FileBrowser content" "FileBrowser" "$BODY"

echo ""
echo "=============================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=============================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0