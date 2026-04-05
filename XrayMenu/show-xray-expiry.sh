#!/bin/bash

EXPIRY_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"

echo "==== XRAY EXPIRY ===="

if [ ! -f "$EXPIRY_FILE" ]; then
    echo "Expiry file not found: $EXPIRY_FILE"
    exit 0
fi

if [ ! -s "$EXPIRY_FILE" ]; then
    echo "No XRAY users with expiry found."
    exit 0
fi

printf "%-24s %-12s\n" "USERNAME" "EXPIRY"
printf "%-24s %-12s\n" "--------" "------"
awk '{printf "%-24s %-12s\n", $1, $2}' "$EXPIRY_FILE"
