#!/bin/bash

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/etc/ErwanScript}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XRAY_MENU_DIR="$TARGET_DIR/XrayMenu"

extract_erwanssh_zip() {
    local zip_file="$1"
    local dest_dir="$2"
    local unzip_rc=0

    unzip -oq "$zip_file" -d "$dest_dir" || unzip_rc=$?
    if [ "$unzip_rc" -gt 1 ]; then
        echo "Failed to unpack $zip_file"
        return "$unzip_rc"
    fi
}

mkdir -p "$TARGET_DIR"
mkdir -p "$XRAY_MENU_DIR"

install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanMenu.sh" "$TARGET_DIR/ErwanMenu"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanNGINX.sh" "$TARGET_DIR/ErwanNGINX"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanXRAY.sh" "$TARGET_DIR/ErwanXRAY"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanWS.sh" "$TARGET_DIR/ErwanWS"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanTCP.sh" "$TARGET_DIR/ErwanTCP"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanTLS.sh" "$TARGET_DIR/ErwanTLS"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanDNS.sh" "$TARGET_DIR/ErwanDNS"
install -m 0755 "$SCRIPT_DIR/ErwanScript/ErwanUDP-auth.sh" "$TARGET_DIR/ErwanUDP-auth"
install -m 0755 "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR/uninstall.sh"
if [ -f "$SCRIPT_DIR/limit-useradd.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/limit-useradd.sh" "$TARGET_DIR/limit-useradd.sh"
fi
if [ -f "$SCRIPT_DIR/ErwanSSH.zip" ]; then
    rm -rf "$TARGET_DIR/ErwanSSH"
    mkdir -p "$TARGET_DIR/ErwanSSH"
    extract_erwanssh_zip "$SCRIPT_DIR/ErwanSSH.zip" "$TARGET_DIR/ErwanSSH"
    find "$TARGET_DIR/ErwanSSH" -type d -exec chmod 0755 {} \;
    find "$TARGET_DIR/ErwanSSH" -type f -exec chmod 0644 {} \;
    find "$TARGET_DIR/ErwanSSH/bin" "$TARGET_DIR/ErwanSSH/libexec" "$TARGET_DIR/ErwanSSH/sbin" -type f -exec chmod 0755 {} \; 2>/dev/null || true
    find "$TARGET_DIR/ErwanSSH/etc" -maxdepth 1 -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \; 2>/dev/null || true
    find "$TARGET_DIR/ErwanSSH/etc" -maxdepth 1 -type f -name 'ssh_host_*.pub' -exec chmod 0644 {} \; 2>/dev/null || true
else
    echo "WARNING: ErwanSSH.zip not found in $SCRIPT_DIR; skipping bundled ErwanSSH runtime install." >&2
fi

for helper in xray-menu.sh add-xray-user.sh remove-xray-user.sh list-xray-users.sh \
    show-xray-expiry.sh cleanup-expired.sh limit-xray.sh reset-xray-users.sh; do
    if [ -f "$SCRIPT_DIR/XrayMenu/$helper" ]; then
        install -m 0755 "$SCRIPT_DIR/XrayMenu/$helper" "$XRAY_MENU_DIR/$helper"
    elif [ -f "$SCRIPT_DIR/../xray-menu/$helper" ]; then
        install -m 0755 "$SCRIPT_DIR/../xray-menu/$helper" "$XRAY_MENU_DIR/$helper"
    fi
done

if [ -f "$SCRIPT_DIR/cloudflare.defaults" ]; then
    install -m 0600 "$SCRIPT_DIR/cloudflare.defaults" "$TARGET_DIR/cloudflare.defaults"
fi

if [ -f "$SCRIPT_DIR/cloudflare.env" ]; then
    install -m 0600 "$SCRIPT_DIR/cloudflare.env" "$TARGET_DIR/cloudflare.env"
fi

dos2unix "$TARGET_DIR"/* >/dev/null 2>&1 || true
ln -sf "$TARGET_DIR/ErwanMenu" /usr/bin/menu
if [ -f "$XRAY_MENU_DIR/xray-menu.sh" ]; then
    ln -sf "$XRAY_MENU_DIR/xray-menu.sh" /usr/bin/xray-menu
fi

TARGET_DIR="/etc/ErwanScript"
IP_HOST=$(wget -4qO- http://ipinfo.io/ip 2>/dev/null || echo "0.0.0.0")
DOMAIN=$(cat "$TARGET_DIR/domain" 2>/dev/null || echo "N/A")
NS=$(cat "$TARGET_DIR/nameserver" 2>/dev/null || echo "N/A")
PUB_KEY=$(cat "$TARGET_DIR/server.pub" 2>/dev/null | tr -d '\n')

TCP_PORT="1194,443"
UDP_PORT="110"
SSH_PORT="22,443"
SSL_PORT="443"
WS_PORT="80,443"
SDNS_PORT="5300"
XRAY_PORT="80,443"
SQUID_PORT="8000,8080"
HYSTERIA_PORT="36712"
HYSTERIA_OBFS="$(jq -r '.udp_hysteria_obfs // "erwanvpn"' "$TARGET_DIR/server-info.json" 2>/dev/null || echo "erwanvpn")"

SERVER_JSON=$(cat <<EOF
{
  "tcp_port": "$TCP_PORT",
  "udp_port": "$UDP_PORT",
  "ssh_port": "$SSH_PORT",
  "ssl_port": "$SSL_PORT",
  "ws_port": "$WS_PORT",
  "sdns_port": "$SDNS_PORT",
  "xray_port": "$XRAY_PORT",
  "squid_port": "$SQUID_PORT",
  "hysteria_port": "$HYSTERIA_PORT",
  "hysteria_obfs": "$HYSTERIA_OBFS",
  "ip_host": "$IP_HOST",
  "domain": "$DOMAIN",
  "name_server": "$NS",
  "public_key": "$PUB_KEY",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

FIREBASE_URL="https://viperpanel-cd232-default-rtdb.firebaseio.com/info.json?auth=QPVJxKzGoNO7GrgK9xZQMTuKLWudQV7s5mYJmQ84"
curl -X POST -H "Content-Type: application/json" -d "$SERVER_JSON" "$FIREBASE_URL"


echo "Installed open Erwan replacement into $TARGET_DIR"
echo "Main menu: /usr/bin/menu"
