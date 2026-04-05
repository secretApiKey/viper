#!/bin/bash

CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
EXPIRY_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

# List current users
echo "==== XRAY USERS ===="
jq -r '.inbounds[] | select(.settings.clients != null) | .settings.clients[] | (.name // .email // empty)' "$CONFIG" | sort -u
echo "==================="
echo "Using config file: $CONFIG"
echo "Using expiry file: $EXPIRY_FILE"

echo "Options:"
echo "1. Remove a single user"
echo "2. Remove ALL users"
read -p "Select an option: " choice

if [ "$choice" == "1" ]; then
    read -p "Enter the username to remove: " user
    if [ -z "$user" ]; then
        echo "No username entered."
        exit 1
    fi

    # Remove from expiry file
    if [ -f "$EXPIRY_FILE" ]; then
        awk -v user="$user" '$1 != user' "$EXPIRY_FILE" > /tmp/xray-expiry.tmp
        mv /tmp/xray-expiry.tmp "$EXPIRY_FILE"
    fi

    # Remove user from all protocols
    tmpfile=$(mktemp)
    jq --arg user "$user" '
      (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |= 
        map(select((.name // .email // "") != $user))
    ' "$CONFIG" > "$tmpfile" && mv "$tmpfile" "$CONFIG"
    chown root:root "$CONFIG"
    chmod 0644 "$CONFIG"

    echo "User '$user' removed successfully."

elif [ "$choice" == "2" ]; then
    read -p "Are you sure you want to remove ALL users? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Aborted."
        exit 1
    fi

    # Clear expiry file
    > "$EXPIRY_FILE"

    # Remove all clients from all protocols
    tmpfile=$(mktemp)
    jq '
      (.inbounds[] | select(.protocol=="vless" or .protocol=="vmess" or .protocol=="trojan" or .protocol=="shadowsocks") | .settings.clients) |= []
    ' "$CONFIG" > "$tmpfile" && mv "$tmpfile" "$CONFIG"
    chown root:root "$CONFIG"
    chmod 0644 "$CONFIG"

    echo "All XRAY users removed successfully."

else
    echo "Invalid option."
    exit 1
fi

# Restart XRAY
systemctl restart xray
