# NewScript

`NewScript` is the open/plain replacement for the original locked `ErwanScript`
stack. It is rebuilt from:

- the original [installer.sh](../installer.sh)
- extracted strings from the compiled original binaries
- live testing against fresh and original VPS installs

The goal is not byte-for-byte recovery. The goal is a readable stack that
follows the same installed flow and service layout:

- `ErwanMenu` as the main operator menu
- built-in Xray management inside `ErwanMenu`
- `ErwanWS` as the multi-port payload-aware web listener
- `ErwanTCP` as the SSH/stunnel/multiplexer wiring layer
- `ErwanDNS` plus `ErwanDNSTT`
- `ErwanXRAY` plus the plain Xray helper scripts underneath
- `nginx`, `squid`, `udp`, `openvpn`, `badvpn-udpgw`, cron jobs, and profile
  banner setup via the new plain installer

## Main Files

- [installer.sh](./installer.sh)
  Plain installer that mirrors the original install flow with open scripts.
- [install-components.sh](./install-components.sh)
  Copies the plain components to `/etc/ErwanScript`.
- [ErwanScript/ErwanMenu.sh](./ErwanScript/ErwanMenu.sh)
  Main operator menu with built-in user and Xray management.
- [ErwanScript/ErwanWS.sh](./ErwanScript/ErwanWS.sh)
  Runs the recovered multi-port listener pattern on `700 8880 8888 8010 2052 2082 2086 2095`
  and handles payload-style tunneling for SSH and OpenVPN.
- [ErwanScript/ErwanTCP.sh](./ErwanScript/ErwanTCP.sh)
  Rebuilds the SSH/stunnel/runtime side, deploys the bundled `ErwanSSH/` runtime, and writes the `443` multiplexer unit.
- [ErwanScript/ErwanTLS.sh](./ErwanScript/ErwanTLS.sh)
  Runs the local TLS termination/helper path used by the `443` multiplexer.
- [ErwanTCP-FLOW.md](./ErwanTCP-FLOW.md)
  Notes the likely original `ErwanTCP` decision tree, the strongest extracted clues, and the suspicious behaviors intentionally removed from `NewScript`.
- [ErwanSSH](./ErwanSSH)
  Bundled SSH runtime used by fresh installs: client tools, `sshd`, helpers, configs, host keys, and manpages.
- [ErwanSSH.zip](./ErwanSSH.zip)
  Packaged SSH runtime archive used by the installer so fresh VPS installs can deploy the runtime without rebuilding it.
- [erwanssh-lock.go](./erwanssh-lock.go)
  Go-based locker/bootstrapper that embeds the bundled `ErwanSSH/` runtime and installs it to `/etc/ErwanSSH`.
- [ScriptSSH/verify-erwanssh-runtime.sh](./ScriptSSH/verify-erwanssh-runtime.sh)
  Checks whether a rebuilt runtime still contains any legacy `/etc/JuanSSH` references.
- [ScriptSSH/export-erwanssh-runtime.sh](./ScriptSSH/export-erwanssh-runtime.sh)
  Archives a rebuilt runtime so it can be copied back into this repo.
- [ScriptSSH/import-erwanssh-runtime.sh](./ScriptSSH/import-erwanssh-runtime.sh)
  Replaces the bundled repo copy of `ErwanSSH/` from an exported rebuild archive.
- [ErwanScript/ErwanDNS.sh](./ErwanScript/ErwanDNS.sh)
  Rebuilds the `ErwanDNS` and `ErwanDNSTT` service flow.
- [ErwanScript/ErwanXRAY.sh](./ErwanScript/ErwanXRAY.sh)
  Writes the live-style Xray config and service unit.

## Kept Close To Live Flow

- Nginx reverse proxy on `80` and `777`
- Xray inbounds on `10085`, `14016`, `14017`, `23456`, `23457`, `25432`, `25433`, `30300`
- `ErwanTCP` on `443` routing SSH and TLS/WebSocket traffic
- HTTP proxy mode through Squid on `8000` and `8080`
- HTTP payload mode on `700 8880 8888 8010 2052 2082 2086 2095`
- SSL payload mode through `443 -> ErwanTCP -> nginx -> ErwanWS`
- Stunnel on `111 -> 127.0.0.1:443`
- `erwanssh` compatibility listener on `22`
- stock admin SSH on `2222`
- Squid on `8000` and `8080`
- Hysteria config shape and `udp.service`
- OpenVPN TCP on direct `1194` and UDP `110`
- Generated download files at `/openvpn/tcp.ovpn`, `/openvpn/udp.ovpn`, and `/openvpn/ca.crt`
- DNSTT on `5300`
- `badvpn-udpgw` on `127.0.0.1:7300`
- Cron jobs for reboot, Xray expiry cleanup, and Xray IP limiting
- Shared multilogin limits through `/etc/ErwanScript/multilogin.txt` for SSH, OpenVPN, and Xray
- Xray helper scripts installed under `/etc/ErwanScript/XrayMenu`

## Current Xray Flow

- Clients use `443` for VLESS, VMESS, Trojan WS, HTTPUpgrade, and SSH-side SSL tunneling
- `ErwanTCP` listens on `443`
- `erwanssh` compatibility listener stays on local `22`
- stock sshd stays on local `2222`
- OpenVPN TCP listens directly on public `1194`
- TLS/WebSocket traffic is sent to local nginx on `777`
- nginx proxies `/vless`, `/vless-hu`, `/vmess`, `/vmess-hu`, `/trojan-ws`, `/trojan-hu`, and `/ss-ws` to Xray

## Practical Split

- SSH keeps the advanced tunnel flow on `22`, SSL `111`, `443`, and admin `2222`
- OpenVPN is kept on the direct ports for stability: TCP `1194`, UDP `110`
- This avoids OpenVPN payload/proxy resets without changing the working SSH behavior

## Verification Notes

- The repo now keeps the restored `ErwanTCP` detection logic that previously fixed the working snapshot:
  - explicit `Detected V2RAY TLS`
  - explicit `Detected Non V2RAY TLS`
  - explicit `Detected OpenVPN`
  - `3s timeout, forwarding to SSH`
- Fresh VPS installs should be verified live after install because SSH, OVPN, and Xray all depend on the shared `443` multiplexer behavior.
- OpenVPN direct TCP still uses `1194` as the clean direct endpoint.
- SSH remains the primary `443` multiplexer identity.
- SSH runtime now uses the bundled `ErwanSSH` runtime; the old `JCMSSH.zip` fallback is no longer used.
- The installed SSH runtime now lives natively under `/etc/ErwanSSH`.
- Fresh installs use the bundled `ErwanSSH` runtime by default, so `build-erwanssh-runtime.sh` is not run on every VPS.
- Fresh installs prefer `ErwanSSH.zip`; the unpacked `ErwanSSH/` folder is kept as a repo-side source/fallback.
- If you want to force a fresh OpenSSH rebuild during install, set `BUILD_ERWANSSH_RUNTIME=1`.
- The rebuild path now compiles SSH binaries for `/etc/ErwanSSH` as their native runtime root.

## Rebuild The SSH Bundle Once

On a Linux VPS:

```bash
cd /etc/ErwanScript
BUILD_ERWANSSH_RUNTIME=1 bash ./installer.sh
bash ./verify-erwanssh-runtime.sh
bash ./export-erwanssh-runtime.sh
```

Expected archive output:

```bash
/root/ErwanSSH-built.tar.gz
```

Bring that archive back to your local machine and replace the repo bundle in:

- [ErwanSSH](./ErwanSSH)

Local import command:

```bash
bash ./import-erwanssh-runtime.sh /path/to/ErwanSSH-built.tar.gz
```

- If you want a Go-packaged installer for the SSH runtime, build [erwanssh-lock.go](./erwanssh-lock.go) and run it on the VPS as root.

## Deliberately Not Carried Over

These suspicious behaviors were not restored:

- `_apt` password/shell/sudo manipulation
- hardcoded `admin` backdoor account
- embedded Telegram bot callbacks
- embedded GitHub, Cloudflare, or Firebase secrets
- stock admin SSH keeps the original split on `2222`

## Notes

- `ErwanTCP`, `ErwanWS`, and `ErwanDNS` now follow the live runtime layout more
  closely, but they are still open reimplementations, not recovered original
  source.
- The original locked `ErwanMenu` appears to have built-in Xray actions, so
  `NewScript` now exposes Xray management from the main menu too.
- `installer.sh` mirrors the service/config flow, but it intentionally avoids
  destructive actions from the original installer like `rm -rf *`.
- `installer.sh` now refuses to continue with `example.com`; provide a real domain
  or enable generated Cloudflare records before installing.

## Generated Domain Mode

`NewScript` still supports the original pattern of creating a fresh subdomain per
VPS install. The difference is that the Cloudflare values are now provided
externally instead of being embedded in the repo.

Use it like this:

1. Create `cloudflare.env`
2. Fill in:
   - `BASE_DOMAIN`
   - `CF_AUTH_EMAIL`
   - `CF_AUTH_KEY`
   - `CF_ZONE_ID`
3. Run the installer normally

When `GENERATE_CLOUDFLARE_RECORDS=1`, the installer will:

- generate a random 5-letter subdomain
- create the `A` and `NS` records
- write `/etc/ErwanScript/domain` and `/etc/ErwanScript/nameserver`
- continue with nginx and Let's Encrypt for that generated hostname

If `cloudflare.env` is missing, `NewScript` will also try to reuse the original
Cloudflare defaults from the repo-root [installer.sh](../installer.sh), so it can
behave more like the original installer without retyping those values.
- [XrayMenu](./XrayMenu)
  Dedicated folder for Xray helper/menu scripts that are installed under `/etc/ErwanScript/XrayMenu`.
