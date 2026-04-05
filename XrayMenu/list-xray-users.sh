#!/bin/bash

CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"

echo "==== XRAY USERS ===="

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed."
    exit 1
fi

jq -r '.inbounds[] | select(.settings.clients != null) | .settings.clients[] | (.name // .email // empty)' "$CONFIG" | sort -u
