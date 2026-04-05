#!/bin/bash

CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
EXPIRY_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"
LOG_FILE="${XRAY_CLEANUP_LOG:-/var/log/xray/cleanup-expired.log}"

if [ ! -f "$EXPIRY_FILE" ]; then
    exit 0
fi

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

today=$(date +"%Y-%m-%d")

# Read all expired users, including users expiring today
expired=$(awk -v d="$today" '$2 <= d {print $1}' "$EXPIRY_FILE")

if [ -n "$expired" ]; then
    echo "Using config file: $CONFIG"
    echo "Using expiry file: $EXPIRY_FILE"
    echo "$(date) Using config file: $CONFIG" >> "$LOG_FILE"
    echo "$(date) Using expiry file: $EXPIRY_FILE" >> "$LOG_FILE"
fi

for user in $expired; do
    echo "Removing expired user: $user"
    echo "$(date) Removing expired user: $user" >> "$LOG_FILE"

    # Remove from expiry file
    awk -v user="$user" '$1 != user' "$EXPIRY_FILE" > /tmp/xray-expiry.tmp
    mv /tmp/xray-expiry.tmp "$EXPIRY_FILE"

    # Remove user from all protocols
    tmpfile=$(mktemp)
    jq --arg user "$user" '
      (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |= 
        map(select((.name // .email // "") != $user))
    ' "$CONFIG" > "$tmpfile" && mv "$tmpfile" "$CONFIG"
    chown root:root "$CONFIG"
    chmod 0644 "$CONFIG"
done

# Restart XRAY if any user was removed
if [ -n "$expired" ]; then
    systemctl restart xray
    echo "$(date) Restarted xray after removing expired users" >> "$LOG_FILE"
fi
