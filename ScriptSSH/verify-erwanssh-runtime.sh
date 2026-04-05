#!/bin/bash

set -euo pipefail

RUNTIME_DIR="${RUNTIME_DIR:-/etc/ErwanSSH}"
SSHD_BIN="${SSHD_BIN:-$RUNTIME_DIR/sbin/sshd}"

if [ ! -x "$SSHD_BIN" ]; then
    echo "Missing sshd binary: $SSHD_BIN"
    exit 1
fi

echo "Checking compiled runtime paths in $SSHD_BIN"
echo

echo "[+] Expecting native /etc/ErwanSSH references:"
strings "$SSHD_BIN" | grep "/etc/ErwanSSH" || true

echo
echo "[+] Looking for legacy /etc/JuanSSH references:"
if strings "$SSHD_BIN" | grep -q "/etc/JuanSSH"; then
    strings "$SSHD_BIN" | grep "/etc/JuanSSH" || true
    echo
    echo "Legacy /etc/JuanSSH references are still present."
    exit 2
fi

echo "No legacy /etc/JuanSSH references found."
echo "Runtime looks ready to bundle."
