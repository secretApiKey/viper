#!/bin/bash

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/etc/ErwanScript}"
XRAY_DIR="${XRAY_DIR:-/etc/xray}"
UDP_DIR="${UDP_DIR:-/etc/udp}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx/conf.d}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

domain=""
if [ -f "${TARGET_DIR}/domain" ]; then
    domain="$(cat "${TARGET_DIR}/domain" 2>/dev/null || true)"
fi

echo "This will remove the installed NewScript stack from this VPS."
read -r -p "Type YES to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Cancelled."
    exit 0
fi

for service in xray ErwanDNSTT ErwanDNS ErwanWS ErwanTCP ErwanTLS udp badvpn-udpgw ddos stunnel4 squid nginx openvpn-server@tcp openvpn-server@udp; do
    systemctl stop "$service" >/dev/null 2>&1 || true
    systemctl disable "$service" >/dev/null 2>&1 || true
done

rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/udp.service
rm -f /etc/systemd/system/ddos.service
rm -f /lib/systemd/system/ErwanDNS.service
rm -f /lib/systemd/system/ErwanDNSTT.service
rm -f /lib/systemd/system/ErwanTCP.service
rm -f /lib/systemd/system/ErwanTLS.service
rm -f /lib/systemd/system/ErwanWS.service
rm -f /lib/systemd/system/badvpn-udpgw.service

rm -f /etc/cron.d/reboot_at_midnight_utc
rm -f /etc/cron.d/xray-expiry
rm -f /etc/cron.d/xray-limit
rm -f /etc/cron.d/useradd-limit
rm -f /etc/profile.d/juan.sh
rm -f /etc/profile.d/erwan.sh
rm -f /usr/bin/menu
rm -f /usr/bin/xray-menu

rm -rf "$XRAY_DIR"
rm -rf "$UDP_DIR"
rm -rf "$TARGET_DIR"

if [ -n "$domain" ]; then
    rm -f "${NGINX_CONF_DIR}/${domain}.conf"
    rm -rf "/etc/letsencrypt/live/${domain}"
fi

rm -f /etc/stunnel/stunnel.conf
rm -f /etc/stunnel/stunnel.crt
rm -f /etc/stunnel/stunnel.key
rm -f /var/log/stunnel-users.log

rm -f /etc/openvpn/server/tcp.conf
rm -f /etc/openvpn/server/udp.conf
rm -f /etc/openvpn/configs/tcp.ovpn
rm -f /etc/openvpn/configs/udp.ovpn
rm -f /etc/openvpn/tcp.log
rm -f /etc/openvpn/udp.log
rm -f /etc/openvpn/tcp_stats.log
rm -f /etc/openvpn/udp_stats.log

cat > /etc/ssh/sshd_config <<'EOF'
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

Include /etc/ssh/sshd_config.d/*.conf

Port 22
ListenAddress 0.0.0.0
ListenAddress ::
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_* COLORTERM NO_COLOR
Subsystem sftp /usr/lib/openssh/sftp-server
ChallengeResponseAuthentication no
PermitRootLogin yes
PasswordAuthentication yes
EOF

systemctl daemon-reload
systemctl restart ssh >/dev/null 2>&1 || true
systemctl restart nginx >/dev/null 2>&1 || true

echo "NewScript has been removed."
echo "Packages were left installed to avoid damaging the VPS base system."
