#!/bin/bash

set -euo pipefail

DOMAIN_FILE="${DOMAIN_FILE:-/etc/ErwanScript/domain}"
ISSUE_NET="${ISSUE_NET:-/etc/issue.net}"
SYSTEM_SSH_CONFIG="${SYSTEM_SSH_CONFIG:-/etc/ssh/sshd_config}"
ERWANSSH_DIR="${ERWANSSH_DIR:-/etc/ErwanSSH}"
ERWANSSH_CONFIG="${ERWANSSH_CONFIG:-${ERWANSSH_DIR}/etc/sshd_config}"
ERWANSSH_BUNDLE_DIR="${ERWANSSH_BUNDLE_DIR:-/etc/ErwanScript/ErwanSSH}"
STUNNEL_CONF="${STUNNEL_CONF:-/etc/stunnel/stunnel.conf}"
STUNNEL_CERT="${STUNNEL_CERT:-/etc/stunnel/stunnel.crt}"
STUNNEL_KEY="${STUNNEL_KEY:-/etc/stunnel/stunnel.key}"
STUNNEL_UNIT="${STUNNEL_UNIT:-/etc/systemd/system/stunnel4.service}"
TCP_UNIT="${TCP_UNIT:-/lib/systemd/system/ErwanTCP.service}"
TLS_UNIT="${TLS_UNIT:-/lib/systemd/system/ErwanTLS.service}"
ERWANSSH_UNIT="${ERWANSSH_UNIT:-/etc/systemd/system/erwanssh.service}"
SYSTEM_SSH_OVERRIDE_DIR="${SYSTEM_SSH_OVERRIDE_DIR:-/etc/systemd/system/ssh.service.d}"
SYSTEM_SSH_OVERRIDE_FILE="${SYSTEM_SSH_OVERRIDE_FILE:-${SYSTEM_SSH_OVERRIDE_DIR}/override.conf}"
SSH_PORT="${SSH_PORT:-2222}"
ERWANSSH_PORT="${ERWANSSH_PORT:-22}"
SSH_VERSION_ADDENDUM="${SSH_VERSION_ADDENDUM:-none}"
MUX_PORT="${MUX_PORT:-443}"
MUX_TLS_PORT="${MUX_TLS_PORT:-777}"
OPENVPN_TCP_PORT="${OPENVPN_TCP_PORT:-1194}"
INTERNAL_PLAIN_MUX_PORT="${INTERNAL_PLAIN_MUX_PORT:-4443}"
INTERNAL_TLS_SSL_PORT="${INTERNAL_TLS_SSL_PORT:-4454}"

write_system_ssh_config() {
    mkdir -p "$(dirname "$SYSTEM_SSH_CONFIG")"
    cat > "$SYSTEM_SSH_CONFIG" <<EOF
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

Include /etc/ssh/sshd_config.d/*.conf

Port ${SSH_PORT}
ListenAddress 0.0.0.0
ListenAddress ::
Protocol 2
SyslogFacility AUTH
LogLevel INFO
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PrintLastLog yes
PermitTunnel yes
TCPKeepAlive yes
UseDNS no
PubkeyAuthentication no
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
AcceptEnv LANG LC_*
KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1
Ciphers aes128-ctr,aes192-ctr,aes256-ctr
MACs hmac-sha2-256,hmac-sha2-512,hmac-sha1
LoginGraceTime 0
MaxStartups 100:5:1000
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 120
PermitRootLogin yes
PasswordAuthentication yes
VersionAddendum ${SSH_VERSION_ADDENDUM}
Banner /etc/issue.net
EOF
}

write_erwanssh_config() {
    mkdir -p "${ERWANSSH_DIR}/etc" "${ERWANSSH_DIR}/libexec" "${ERWANSSH_DIR}/sbin" "${ERWANSSH_DIR}/var/empty"
    for key_type in rsa ecdsa ed25519; do
        local hostkey="${ERWANSSH_DIR}/etc/ssh_host_${key_type}_key"
        if [ ! -f "$hostkey" ]; then
            ssh-keygen -q -N "" -t "$key_type" -f "$hostkey"
        fi
    done
    if [ ! -x "${ERWANSSH_DIR}/libexec/sftp-server" ]; then
        ln -sf /usr/lib/openssh/sftp-server "${ERWANSSH_DIR}/libexec/sftp-server"
    fi
    cat > "$ERWANSSH_CONFIG" <<EOF
Port ${ERWANSSH_PORT}
ListenAddress ::
ListenAddress 0.0.0.0
Protocol 2
HostKey ${ERWANSSH_DIR}/etc/ssh_host_rsa_key
HostKey ${ERWANSSH_DIR}/etc/ssh_host_ecdsa_key
HostKey ${ERWANSSH_DIR}/etc/ssh_host_ed25519_key
SyslogFacility AUTH
LogLevel INFO
PermitRootLogin no
StrictModes yes
PubkeyAuthentication no
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
PrintMotd no
PermitTunnel yes
PrintLastLog yes
AcceptEnv LANG LC_*
Subsystem sftp ${ERWANSSH_DIR}/libexec/sftp-server
UsePAM yes
Banner /etc/banner
TCPKeepAlive yes
UseDNS no
VersionAddendum ${SSH_VERSION_ADDENDUM}
KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1
Ciphers aes128-ctr,aes192-ctr,aes256-ctr
MACs hmac-sha2-256,hmac-sha2-512,hmac-sha1
LoginGraceTime 0
MaxStartups 100:5:1000
EOF
}

prepare_erwanssh_bundle() {
    if [ -d "$ERWANSSH_BUNDLE_DIR" ]; then
        mkdir -p "$ERWANSSH_DIR"
        cp -a "${ERWANSSH_BUNDLE_DIR}/." "$ERWANSSH_DIR/"
    fi
    mkdir -p "${ERWANSSH_DIR}/etc" "${ERWANSSH_DIR}/libexec" "${ERWANSSH_DIR}/sbin" "${ERWANSSH_DIR}/var/empty"
    rm -f "${ERWANSSH_DIR}/etc"/ssh_host_*_key "${ERWANSSH_DIR}/etc"/ssh_host_*.pub 2>/dev/null || true
    chmod 0755 "${ERWANSSH_DIR}/bin" "${ERWANSSH_DIR}/libexec" "${ERWANSSH_DIR}/sbin" "${ERWANSSH_DIR}/var" "${ERWANSSH_DIR}/var/empty" 2>/dev/null || true
    chmod 0755 "${ERWANSSH_DIR}/bin/"* "${ERWANSSH_DIR}/libexec/"* "${ERWANSSH_DIR}/sbin/"* 2>/dev/null || true
    chmod 0644 "${ERWANSSH_DIR}/etc/"* 2>/dev/null || true
    chmod 0600 "${ERWANSSH_DIR}/etc/ssh_host_"*_key 2>/dev/null || true
    chmod 0644 "${ERWANSSH_DIR}/etc/ssh_host_"*.pub 2>/dev/null || true
    if [ ! -x "${ERWANSSH_DIR}/sbin/sshd" ]; then
        ln -sf /usr/sbin/sshd "${ERWANSSH_DIR}/sbin/sshd"
    fi
    if [ ! -x "${ERWANSSH_DIR}/libexec/sftp-server" ]; then
        ln -sf /usr/lib/openssh/sftp-server "${ERWANSSH_DIR}/libexec/sftp-server"
    fi
    if [ -x "${ERWANSSH_DIR}/libexec/sshd-auth" ]; then
        ln -sf "${ERWANSSH_DIR}/libexec/sshd-auth" /usr/libexec/sshd-auth
    fi
    rm -f /etc/JuanSSH 2>/dev/null || true
}

write_erwanssh_unit() {
    cat > "$ERWANSSH_UNIT" <<EOF
[Unit]
Description=ErwanSSH Server
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target auditd.service

[Service]
Environment="PATH=${ERWANSSH_DIR}/libexec:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EnvironmentFile=-${ERWANSSH_DIR}/sbin/sshd
ExecStartPre=${ERWANSSH_DIR}/sbin/sshd -t -f ${ERWANSSH_CONFIG}
ExecStart=${ERWANSSH_DIR}/sbin/sshd -D -f ${ERWANSSH_CONFIG} \$SSHD_OPTS
ExecReload=${ERWANSSH_DIR}/sbin/sshd -t -f ${ERWANSSH_CONFIG}
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=notify
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
Alias=erwansshd.service
EOF
}

write_system_ssh_override() {
    mkdir -p "$SYSTEM_SSH_OVERRIDE_DIR"
    cat > "$SYSTEM_SSH_OVERRIDE_FILE" <<EOF
[Service]
Environment="PATH=${ERWANSSH_DIR}/libexec:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStartPre=
ExecStart=
ExecReload=
ExecStartPre=${ERWANSSH_DIR}/sbin/sshd -t -f ${SYSTEM_SSH_CONFIG}
ExecStart=${ERWANSSH_DIR}/sbin/sshd -D -f ${SYSTEM_SSH_CONFIG}
ExecReload=${ERWANSSH_DIR}/sbin/sshd -t -f ${SYSTEM_SSH_CONFIG}
ExecReload=/bin/kill -HUP \$MAINPID
EOF
}

write_stunnel() {
    mkdir -p /etc/stunnel
    touch /var/log/stunnel-users.log
    cat > "$STUNNEL_CONF" <<EOF
foreground = yes
pid = /etc/stunnel/stunnel.pid
cert = $STUNNEL_CERT
key  = $STUNNEL_KEY
client = no
socket = a:SO_REUSEADDR=0
TIMEOUTclose = 0
output = /var/log/stunnel-users.log
debug = 7
[ssl-direct]
accept = 0.0.0.0:111
connect = 127.0.0.1:${MUX_PORT}
EOF
}

write_stunnel_unit() {
    cat > "$STUNNEL_UNIT" <<EOF
[Unit]
Description=Stunnel TLS tunnel service
After=network.target ssh.service
Wants=ssh.service

[Service]
Type=simple
ExecStart=/usr/bin/stunnel4 ${STUNNEL_CONF}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

write_units() {
    cat > "$TCP_UNIT" <<'EOF'
[Unit]
Description=ErwanTCP
After=network.target

[Service]
User=root
ExecStart=/etc/ErwanScript/ErwanTCP
Restart=always
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    cat > "$TLS_UNIT" <<'EOF'
[Unit]
Description=ErwanTLS
After=network.target

[Service]
User=root
ExecStart=/etc/ErwanScript/ErwanTLS
Restart=always
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
}

install_mode() {
    local domain
    domain="$(cat "$DOMAIN_FILE" 2>/dev/null || echo "example.com")"
    write_system_ssh_config
    prepare_erwanssh_bundle
    write_erwanssh_config
    write_erwanssh_unit
    write_system_ssh_override
    write_stunnel
    write_stunnel_unit
    write_units
    cat > /etc/banner <<EOF
Connected to ${domain} [$(hostname)]
EOF
    systemctl daemon-reload
    systemctl enable ssh >/dev/null 2>&1 || true
    systemctl enable erwanssh >/dev/null 2>&1 || true
    systemctl enable stunnel4 >/dev/null 2>&1 || true
    systemctl enable ErwanTCP >/dev/null 2>&1 || true
    systemctl enable ErwanTLS >/dev/null 2>&1 || true
    systemctl disable --now juanmux >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/juanmux.service
    echo "ErwanTCP, SSH, and 443 multiplexer installed."
    echo "ErwanSSH compatibility listener uses ${ERWANSSH_PORT}; stock admin SSH stays on ${SSH_PORT}."
}

serve_tcp() {
    python3 - "$DOMAIN_FILE" "$MUX_PORT" "$MUX_TLS_PORT" "$SSH_PORT" "$ERWANSSH_PORT" "$OPENVPN_TCP_PORT" "$INTERNAL_PLAIN_MUX_PORT" "$INTERNAL_TLS_SSL_PORT" <<'PY'
import asyncio
import struct
import sys
from contextlib import suppress

domain_file = sys.argv[1]
public_mux_port = int(sys.argv[2])
tls_backend_port = int(sys.argv[3])
ssh_port = int(sys.argv[4])
erwanssh_port = int(sys.argv[5])
openvpn_port = int(sys.argv[6])
plain_mux_port = int(sys.argv[7])
tls_ssl_port = int(sys.argv[8])

try:
    with open(domain_file, "r", encoding="utf-8") as fh:
        domain_name = fh.read().strip().lower()
except OSError:
    domain_name = ""

HTTP_METHODS = (b"GET ", b"POST ", b"HEAD ", b"PUT ", b"PATCH ", b"OPTIONS ", b"DELETE ", b"CONNECT ")
SSH_PREFIX = b"SSH-"
FALLBACK_TIMEOUT = 3.0
XRAY_HTTP_PATH_PORTS = {
    "/vless": 14016,
    "/vless-hu": 14017,
    "/vmess": 23456,
    "/vmess-hu": 23457,
    "/trojan-ws": 25432,
    "/trojan-hu": 25433,
    "/ss-ws": 30300,
}
HTTP_HEADER_PREFIXES = (
    b"host:",
    b"upgrade:",
    b"connection:",
    b"x-real-host:",
    b"x-online-host:",
    b"x-forward-host:",
    b"x-host:",
    b"x-port:",
    b"x-pass:",
    b"x-target-protocol:",
)

def is_tls_client_hello(data: bytes) -> bool:
    return len(data) >= 6 and data[0] == 0x16 and data[1] == 0x03 and data[5] == 0x01

def is_openvpn_tcp(data: bytes) -> bool:
    sample = data.lstrip(b"\r\n")
    if len(sample) < 3:
        return False
    frame_len = struct.unpack("!H", sample[:2])[0]
    if frame_len < 1 or frame_len > 8192:
        return False
    if len(sample) >= frame_len + 2:
        opcode = sample[2] >> 3
        return opcode in {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    opcode = sample[2] >> 3
    return opcode in {7, 8, 10}

def log_detected(message: str):
    print(message, flush=True)

def extract_http_path(data: bytes) -> str:
    try:
        line = data.split(b"\r\n", 1)[0].decode("ascii", "ignore")
        parts = line.split()
        if len(parts) >= 2:
            return parts[1]
    except Exception:
        return ""
    return ""

def lookup_xray_http_backend(path: str):
    if not path:
        return None
    if path in XRAY_HTTP_PATH_PORTS:
        return XRAY_HTTP_PATH_PORTS[path]
    for prefix, port in XRAY_HTTP_PATH_PORTS.items():
        if path.startswith(prefix + "/"):
            return port
    return None

def extract_sni(data: bytes) -> str:
    try:
        if not is_tls_client_hello(data):
            return ""
        record_len = struct.unpack("!H", data[3:5])[0]
        if len(data) < 5 + record_len:
            return ""
        body = memoryview(data)[5:5 + record_len]
        if body[0] != 0x01:
            return ""
        hs_len = int.from_bytes(body[1:4], "big")
        hello = body[4:4 + hs_len]
        idx = 2 + 32
        session_len = hello[idx]
        idx += 1 + session_len
        cipher_len = struct.unpack("!H", hello[idx:idx + 2])[0]
        idx += 2 + cipher_len
        comp_len = hello[idx]
        idx += 1 + comp_len
        ext_len = struct.unpack("!H", hello[idx:idx + 2])[0]
        idx += 2
        end = idx + ext_len
        while idx + 4 <= end:
            ext_type = struct.unpack("!H", hello[idx:idx + 2])[0]
            ext_size = struct.unpack("!H", hello[idx + 2:idx + 4])[0]
            idx += 4
            ext = hello[idx:idx + ext_size]
            idx += ext_size
            if ext_type != 0x0000 or len(ext) < 5:
                continue
            list_len = struct.unpack("!H", ext[0:2])[0]
            pos = 2
            while pos + 3 <= 2 + list_len:
                name_type = ext[pos]
                name_len = struct.unpack("!H", ext[pos + 1:pos + 3])[0]
                pos += 3
                if name_type == 0 and pos + name_len <= len(ext):
                    return bytes(ext[pos:pos + name_len]).decode("idna", "ignore").lower()
                pos += name_len
    except Exception:
        return ""
    return ""

async def pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        with suppress(Exception):
            if writer.can_write_eof():
                writer.write_eof()
                await writer.drain()

async def proxy_stream(client_reader, client_writer, host, port, initial=b""):
    try:
        server_reader, server_writer = await asyncio.open_connection(host, port)
    except Exception:
        client_writer.close()
        with suppress(Exception):
            await client_writer.wait_closed()
        return
    if port == openvpn_port and initial:
        initial = initial.lstrip(b"\r\n")
    if initial:
        server_writer.write(initial)
        await server_writer.drain()
    upstream = asyncio.create_task(pipe(client_reader, server_writer))
    downstream = asyncio.create_task(pipe(server_reader, client_writer))
    await asyncio.gather(upstream, downstream, return_exceptions=True)
    with suppress(Exception):
        server_writer.close()
        await server_writer.wait_closed()
    with suppress(Exception):
        client_writer.close()
        await client_writer.wait_closed()

def choose_plain_backend(initial: bytes):
    stripped = initial.lstrip()
    lowered = stripped.lower()
    if stripped.startswith(SSH_PREFIX):
        return "127.0.0.1", erwanssh_port
    if stripped.startswith(HTTP_METHODS) or lowered.startswith(HTTP_HEADER_PREFIXES):
        path = extract_http_path(stripped)
        backend_port = lookup_xray_http_backend(path)
        if backend_port is not None:
            log_detected(f"Detected Xray HTTP path on plain mux ({path})")
            return "127.0.0.1", backend_port
        return "127.0.0.1", 700
    if is_openvpn_tcp(stripped):
        log_detected(f"Detected OpenVPN (len={len(stripped)})")
        return "127.0.0.1", openvpn_port
    if is_tls_client_hello(stripped):
        log_detected("Detected Non V2RAY TLS")
        return "127.0.0.1", openvpn_port
    return "127.0.0.1", openvpn_port

def choose_public_backend(initial: bytes):
    stripped = initial.lstrip()
    lowered = stripped.lower()
    if stripped.startswith(SSH_PREFIX):
        return "127.0.0.1", erwanssh_port
    if stripped.startswith(HTTP_METHODS) or lowered.startswith(HTTP_HEADER_PREFIXES):
        return "127.0.0.1", 700
    if is_openvpn_tcp(stripped):
        log_detected(f"Detected OpenVPN (len={len(stripped)})")
        return "127.0.0.1", openvpn_port
    if is_tls_client_hello(stripped):
        sni = extract_sni(stripped)
        if sni and sni == domain_name:
            log_detected("Detected V2RAY TLS")
            return "127.0.0.1", tls_backend_port
        if sni:
            log_detected(f"Detected Non V2RAY TLS with custom SNI ({sni})")
            return "127.0.0.1", tls_backend_port
        log_detected("Detected Non V2RAY TLS")
        return "127.0.0.1", tls_ssl_port
    return "127.0.0.1", openvpn_port

async def read_initial(reader: asyncio.StreamReader):
    try:
        data = await asyncio.wait_for(reader.read(4096), timeout=FALLBACK_TIMEOUT)
        if len(data) >= 5 and data[0] == 0x16 and data[1] == 0x03:
            record_len = struct.unpack("!H", data[3:5])[0]
            target_len = min(5 + record_len, 16384)
            while len(data) < target_len:
                chunk = await asyncio.wait_for(reader.read(target_len - len(data)), timeout=0.5)
                if not chunk:
                    break
                data += chunk
        return data
    except asyncio.TimeoutError:
        return b""

async def handle_public(reader, writer):
    initial = await read_initial(reader)
    if not initial:
        log_detected("3s timeout, forwarding to SSH")
        await proxy_stream(reader, writer, "127.0.0.1", erwanssh_port)
        return
    host, port = choose_public_backend(initial)
    await proxy_stream(reader, writer, host, port, initial)

async def handle_plain(reader, writer):
    initial = await read_initial(reader)
    if not initial:
        log_detected("3s timeout, forwarding to SSH")
        await proxy_stream(reader, writer, "127.0.0.1", erwanssh_port)
        return
    host, port = choose_plain_backend(initial)
    await proxy_stream(reader, writer, host, port, initial)

async def main():
    public_server = await asyncio.start_server(handle_public, host="0.0.0.0", port=public_mux_port, reuse_address=True)
    plain_server = await asyncio.start_server(handle_plain, host="127.0.0.1", port=plain_mux_port, reuse_address=True)
    await asyncio.gather(public_server.serve_forever(), plain_server.serve_forever())

asyncio.run(main())
PY
}

case "${1:-serve}" in
    --install) install_mode ;;
    --serve|serve) serve_tcp ;;
    *) echo "Usage: $0 [--install|--serve]"; exit 1 ;;
esac
