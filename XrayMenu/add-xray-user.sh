#!/bin/bash

CONFIG="${XRAY_CONFIG:-/etc/xray/config.json}"
EXP_FILE="${XRAY_EXPIRY_FILE:-/etc/ErwanScript/xray-expiry.txt}"

if [ ! -f "$CONFIG" ]; then
    echo "Config file not found: $CONFIG"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required but not installed."
    exit 1
fi

read -p "Username: " user
read -p "Expiry days: " days

if [ -z "$user" ]; then
    echo "Username cannot be empty."
    exit 1
fi

if ! [[ "$user" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "Username may only contain letters, numbers, dot, underscore, and dash."
    exit 1
fi

if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo "Expiry days must be a number."
    exit 1
fi

# Check if username already exists
if grep -qw "$user" "$EXP_FILE" 2>/dev/null; then
    echo "ERROR: Username '$user' already exists!"
    exit 1
fi

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$days days" +"%Y-%m-%d")
tmpfile=$(mktemp)
host=$(cat /etc/ErwanScript/domain 2>/dev/null || echo "N/A")
public_host="$host"

if [ -z "$public_host" ] || [ "$public_host" = "N/A" ]; then
    public_host="your-domain"
fi

mkdir -p "$(dirname "$EXP_FILE")"

# Add user to config.json first, and only replace the file if jq succeeds.
if ! jq --arg user "$user" --arg uuid "$uuid" '
  (.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"name":$user,"email":$user,"id":$uuid}] |
  (.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"name":$user,"email":$user,"id":$uuid}] |
  (.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password":$uuid,"email":$user}] |
  (.inbounds[] | select(.protocol=="shadowsocks")) |= (
    .settings.clients += [{
      method: (.settings.method // "aes-128-gcm"),
      password: $uuid,
      email: $user
    }]
  )
' "$CONFIG" > "$tmpfile"; then
    rm -f "$tmpfile"
    echo "Failed to update config.json with jq."
    exit 1
fi

chown --reference="$CONFIG" "$tmpfile"
chmod --reference="$CONFIG" "$tmpfile"
mv "$tmpfile" "$CONFIG"
chown root:root "$CONFIG"
chmod 0644 "$CONFIG"

# Save expiry after config update succeeds.
echo "$user $exp" >> "$EXP_FILE"

systemctl restart xray

vless_direct_link="vless://${uuid}@${public_host}:8443?encryption=none&security=tls&sni=${public_host}&allowInsecure=1#VLESS-DIRECT-${user}"
vless_link="vless://${uuid}@${public_host}:443?encryption=none&type=ws&security=tls&host=${public_host}&path=%2Fvless&sni=${public_host}&allowInsecure=1#VLESS-${user}"
vless_ntls_link="vless://${uuid}@${public_host}:80?encryption=none&type=ws&security=none&host=${public_host}&path=%2Fvless#VLESS-NTLS-${user}"
vless_hu_link="vless://${uuid}@${public_host}:443?encryption=none&type=httpupgrade&security=tls&host=${public_host}&path=%2Fvless-hu&sni=${public_host}&allowInsecure=1#VLESS-HU-${user}"
vless_hu_ntls_link="vless://${uuid}@${public_host}:80?encryption=none&type=httpupgrade&security=none&host=${public_host}&path=%2Fvless-hu#VLESS-HU-NTLS-${user}"
vmess_json=$(jq -nc --arg user "$user" --arg uuid "$uuid" --arg host "$public_host" '{
  v: "2",
  ps: ("VMESS-" + $user),
  add: $host,
  port: "443",
  id: $uuid,
  aid: "0",
  scy: "auto",
  net: "ws",
  type: "none",
  host: $host,
  path: "/vmess",
  tls: "tls",
  sni: $host,
  verify_cert: false,
  allowInsecure: 1,
  insecure: true,
  skip_cert_verify: true
}')
vmess_link="vmess://$(printf '%s' "$vmess_json" | base64 | tr -d '\n')"
vmess_ntls_json=$(jq -nc --arg user "$user" --arg uuid "$uuid" --arg host "$public_host" '{
  v: "2",
  ps: ("VMESS-NTLS-" + $user),
  add: $host,
  port: "80",
  id: $uuid,
  aid: "0",
  scy: "auto",
  net: "ws",
  type: "none",
  host: $host,
  path: "/vmess",
  tls: "",
  sni: ""
}')
vmess_ntls_link="vmess://$(printf '%s' "$vmess_ntls_json" | base64 | tr -d '\n')"
vmess_hu_json=$(jq -nc --arg user "$user" --arg uuid "$uuid" --arg host "$public_host" '{
  v: "2",
  ps: ("VMESS-HU-" + $user),
  add: $host,
  port: "443",
  id: $uuid,
  aid: "0",
  scy: "auto",
  net: "httpupgrade",
  type: "none",
  host: $host,
  path: "/vmess-hu",
  tls: "tls",
  sni: $host,
  verify_cert: false,
  allowInsecure: 1,
  insecure: true,
  skip_cert_verify: true
}')
vmess_hu_link="vmess://$(printf '%s' "$vmess_hu_json" | base64 | tr -d '\n')"
vmess_hu_ntls_json=$(jq -nc --arg user "$user" --arg uuid "$uuid" --arg host "$public_host" '{
  v: "2",
  ps: ("VMESS-HU-NTLS-" + $user),
  add: $host,
  port: "80",
  id: $uuid,
  aid: "0",
  scy: "auto",
  net: "httpupgrade",
  type: "none",
  host: $host,
  path: "/vmess-hu",
  tls: "",
  sni: ""
}')
vmess_hu_ntls_link="vmess://$(printf '%s' "$vmess_hu_ntls_json" | base64 | tr -d '\n')"
trojan_link="trojan://${uuid}@${public_host}:443?type=ws&security=tls&sni=${public_host}&host=${public_host}&path=%2Ftrojan-ws&allowInsecure=1#TROJAN-${user}"
trojan_ntls_link="trojan://${uuid}@${public_host}:80?type=ws&security=none&host=${public_host}&path=%2Ftrojan-ws#TROJAN-NTLS-${user}"
trojan_hu_link="trojan://${uuid}@${public_host}:443?type=httpupgrade&security=tls&sni=${public_host}&host=${public_host}&path=%2Ftrojan-hu&allowInsecure=1#TROJAN-HU-${user}"
trojan_hu_ntls_link="trojan://${uuid}@${public_host}:80?type=httpupgrade&security=none&host=${public_host}&path=%2Ftrojan-hu#TROJAN-HU-NTLS-${user}"
ss_userinfo_b64=$(printf '%s' "aes-128-gcm:${uuid}" | base64 | tr -d '\n')
ss_plugin_opts="v2ray-plugin%3Bmode%3Dwebsocket%3Btls%3Bhost%3D${public_host}%3Bpath%3D%2Fss-ws%3BallowInsecure%3D1"
ss_link="ss://${ss_userinfo_b64}@${public_host}:443/?plugin=${ss_plugin_opts}#SS-${user}"
ss_compat_link="ss://$(printf '%s' "aes-128-gcm:${uuid}@${public_host}:443" | base64 | tr -d '\n')/?plugin=${ss_plugin_opts}#SS-COMPAT-${user}"

echo ""
echo "User Created Successfully"
echo "Config file : $CONFIG"
echo "Expiry file : $EXP_FILE"
echo "Username : $user"
echo "UUID : $uuid"
echo "Expiry : $exp"
if [ -n "$vless_link" ]; then
    echo ""
    echo "VLESS Direct TLS:"
    echo "$vless_direct_link"
    echo "VLESS Config:"
    echo "$vless_link"
    echo "VLESS Non-TLS:"
    echo "$vless_ntls_link"
    echo "VLESS HTTPUpgrade:"
    echo "$vless_hu_link"
    echo "VLESS HTTPUpgrade Non-TLS:"
    echo "$vless_hu_ntls_link"
fi
if [ -n "$vmess_link" ]; then
    echo ""
    echo "VMESS Config:"
    echo "$vmess_link"
    echo "VMESS Non-TLS:"
    echo "$vmess_ntls_link"
    echo "VMESS HTTPUpgrade:"
    echo "$vmess_hu_link"
    echo "VMESS HTTPUpgrade Non-TLS:"
    echo "$vmess_hu_ntls_link"
fi
if [ -n "$trojan_link" ]; then
    echo ""
    echo "TROJAN Config:"
    echo "$trojan_link"
    echo "TROJAN Non-TLS:"
    echo "$trojan_ntls_link"
    echo "TROJAN HTTPUpgrade:"
    echo "$trojan_hu_link"
    echo "TROJAN HTTPUpgrade Non-TLS:"
    echo "$trojan_hu_ntls_link"
    echo "TROJAN Manual:"
    echo "Server : $public_host"
    echo "Port : 443"
    echo "Password : $uuid"
    echo "Network : ws"
    echo "Path : /trojan-ws"
    echo "SNI : $public_host"
fi
if [ -n "$ss_link" ]; then
    echo ""
    echo "SHADOWSOCKS Config:"
    echo "$ss_link"
    echo "SHADOWSOCKS Compat Config:"
    echo "$ss_compat_link"
    echo "SHADOWSOCKS Manual:"
    echo "Server : $public_host"
    echo "Port : 443"
    echo "Method : aes-128-gcm"
    echo "Password : $uuid"
    echo "Plugin : v2ray-plugin"
    echo "Plugin opts : mode=websocket;tls;host=${public_host};path=/ss-ws;allowInsecure=1"
fi
