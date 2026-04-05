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
if [ -f "$SCRIPT_DIR/ScriptSSH/build-erwanssh-runtime.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/ScriptSSH/build-erwanssh-runtime.sh" "$TARGET_DIR/build-erwanssh-runtime.sh"
fi
if [ -f "$SCRIPT_DIR/ScriptSSH/verify-erwanssh-runtime.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/ScriptSSH/verify-erwanssh-runtime.sh" "$TARGET_DIR/verify-erwanssh-runtime.sh"
fi
if [ -f "$SCRIPT_DIR/ScriptSSH/export-erwanssh-runtime.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/ScriptSSH/export-erwanssh-runtime.sh" "$TARGET_DIR/export-erwanssh-runtime.sh"
fi
if [ -f "$SCRIPT_DIR/ScriptSSH/import-erwanssh-runtime.sh" ]; then
    install -m 0755 "$SCRIPT_DIR/ScriptSSH/import-erwanssh-runtime.sh" "$TARGET_DIR/import-erwanssh-runtime.sh"
fi
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
elif [ -d "$SCRIPT_DIR/ErwanSSH" ]; then
    rm -rf "$TARGET_DIR/ErwanSSH"
    mkdir -p "$TARGET_DIR/ErwanSSH"
    cp -a "$SCRIPT_DIR/ErwanSSH/." "$TARGET_DIR/ErwanSSH/"
    find "$TARGET_DIR/ErwanSSH" -type d -exec chmod 0755 {} \;
    find "$TARGET_DIR/ErwanSSH" -type f -exec chmod 0644 {} \;
    find "$TARGET_DIR/ErwanSSH/bin" "$TARGET_DIR/ErwanSSH/libexec" "$TARGET_DIR/ErwanSSH/sbin" -type f -exec chmod 0755 {} \; 2>/dev/null || true
    find "$TARGET_DIR/ErwanSSH/etc" -maxdepth 1 -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \; 2>/dev/null || true
    find "$TARGET_DIR/ErwanSSH/etc" -maxdepth 1 -type f -name 'ssh_host_*.pub' -exec chmod 0644 {} \; 2>/dev/null || true
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

echo "Installed open Erwan replacement into $TARGET_DIR"
echo "Main menu: /usr/bin/menu"
