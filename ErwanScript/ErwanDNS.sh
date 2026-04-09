#!/bin/bash

set -euo pipefail

DOMAIN_FILE="${DOMAIN_FILE:-/etc/ErwanScript/domain}"
NS_FILE="${NS_FILE:-/etc/ErwanScript/nameserver}"
SERVER_KEY="${SERVER_KEY:-/etc/ErwanScript/server.key}"
SERVER_PUB="${SERVER_PUB:-/etc/ErwanScript/server.pub}"
STATUS_LOG="${STATUS_LOG:-/etc/ErwanScript/status.log}"
DNSTT_BIN="${DNSTT_BIN:-/etc/ErwanScript/dnstt-server}"
DNS_UNIT="${DNS_UNIT:-/lib/systemd/system/ErwanDNS.service}"
DNSTT_UNIT="${DNSTT_UNIT:-/lib/systemd/system/ErwanDNSTT.service}"
DEFAULT_SERVER_KEY="${DEFAULT_SERVER_KEY:-7f56d5366a659d30198b6fb29e8e010317c26b30bcf42c952eb3bbe366fe62e8}"
DEFAULT_SERVER_PUB="${DEFAULT_SERVER_PUB:-b7c0d9a1ca1f1e41f02a3dcc3318d969661037315d46cba3ba2e0e0215d4092e}"

ensure_dns_forwarding() {
    local iptables_bin="/usr/sbin/iptables"

    [ -x "$iptables_bin" ] || iptables_bin="$(command -v iptables 2>/dev/null || true)"
    [ -n "$iptables_bin" ] || return 0

    "$iptables_bin" -C INPUT -p udp --dport 5300 -j ACCEPT >/dev/null 2>&1 || \
        "$iptables_bin" -I INPUT -p udp --dport 5300 -j ACCEPT
    "$iptables_bin" -C INPUT -p udp --dport 53 -j ACCEPT >/dev/null 2>&1 || \
        "$iptables_bin" -I INPUT -p udp --dport 53 -j ACCEPT
    "$iptables_bin" -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 >/dev/null 2>&1 || \
        "$iptables_bin" -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
}

write_dns_units() {
    cat > "$DNS_UNIT" <<'EOF'
[Unit]
Description=ErwanDNS
After=network.target

[Service]
User=root
ExecStart=/etc/ErwanScript/ErwanDNS
Restart=always
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    cat > "$DNSTT_UNIT" <<EOF
[Unit]
Description=DNSTT Server
After=network-online.target
Wants=network-online.target
Requires=ErwanDNS.service
After=ErwanDNS.service

[Service]
User=root
Type=simple
WorkingDirectory=/etc/ErwanScript
ExecStart=${DNSTT_BIN} -mtu 512 -udp :5300 -privkey-file $(basename "$SERVER_KEY") $(cat "$NS_FILE") 127.0.0.1:443
Restart=on-failure
RestartSec=5s
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
StandardOutput=file:${STATUS_LOG}

[Install]
WantedBy=multi-user.target
EOF
}

install_mode() {
    mkdir -p /etc/ErwanScript
    [ -f "$DOMAIN_FILE" ] || echo "example.com" > "$DOMAIN_FILE"
    [ -f "$NS_FILE" ] || echo "ns.example.com" > "$NS_FILE"
    [ -f "$SERVER_KEY" ] || echo "$DEFAULT_SERVER_KEY" > "$SERVER_KEY"
    [ -f "$SERVER_PUB" ] || echo "$DEFAULT_SERVER_PUB" > "$SERVER_PUB"
    touch "$STATUS_LOG"
    ensure_dns_forwarding
    write_dns_units
    systemctl daemon-reload
    systemctl enable ErwanDNS >/dev/null 2>&1 || true
    systemctl enable ErwanDNSTT >/dev/null 2>&1 || true
    echo "ErwanDNS and DNSTT units installed."
}

watch_mode() {
    mkdir -p /etc/ErwanScript
    touch "$STATUS_LOG"
    while true; do
        {
            echo "[$(date '+%F %T')] Domain: $(cat "$DOMAIN_FILE" 2>/dev/null || echo 'unset')"
            echo "[$(date '+%F %T')] Nameserver: $(cat "$NS_FILE" 2>/dev/null || echo 'unset')"
        } >> "$STATUS_LOG"
        sleep 300
    done
}

case "${1:-watch}" in
    --install) install_mode ;;
    --watch|watch) watch_mode ;;
    *) echo "Usage: $0 [--install|--watch]"; exit 1 ;;
esac
