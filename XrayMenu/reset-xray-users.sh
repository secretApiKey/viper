#!/bin/bash

CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
EXPIRY_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed."
    exit 1
fi

tmpfile=$(mktemp)

if ! jq '
  (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |= []
' "$CONFIG" > "$tmpfile"; then
    rm -f "$tmpfile"
    echo "Failed to update config.json with jq."
    exit 1
fi

if ! mv "$tmpfile" "$CONFIG"; then
    rm -f "$tmpfile"
    echo "Failed to replace config file: $CONFIG"
    exit 1
fi

chown root:root "$CONFIG"
chmod 0644 "$CONFIG"

if [ -f "$EXPIRY_FILE" ]; then
    : > "$EXPIRY_FILE"
fi

echo "All XRAY users removed."
echo "Config file: $CONFIG"
echo "Expiry file: $EXPIRY_FILE"

if ! systemctl restart xray; then
    echo "Warning: failed to restart xray."
    exit 1
fi
