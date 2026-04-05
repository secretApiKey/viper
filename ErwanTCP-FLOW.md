# ErwanTCP Flow

This file maps the likely original `ErwanTCP` behavior from:

- [JuanTCP.readable.txt](../extracted-readable/JuanTCP.readable.txt)
- [installer.sh](../installer.sh)
- the live original VPS audit
- the current live `NewScript` tests

It is not exact recovered source. It is the clearest working model of the
original `443` logic.

## Strong Clues From The Extract

The most useful strings in the original extract are:

- `Detected OpenVPN`
- `Detected V2RAY TLS`
- `Fallback to OpenVPN`
- `127.0.0.1:1194`
- `127.0.0.1:777`
- `127.0.0.1:111`
- `PermitRootLogin`
- `/etc/ssh/sshd_config`

That combination strongly suggests that the original binary:

1. accepted traffic on `443`
2. inspected the first bytes of the stream
3. routed traffic to different local backends
4. used OpenVPN as a fallback when classification was uncertain

## Likely Original Branches

### Branch 1: SSH

- raw SSH on `443` appears to have been supported
- stunnel `111 -> 443` also fed back into the same decision tree
- the binary knew about SSH config and root-login settings

In `NewScript`, this is modeled as:

- raw `SSH-` prefix -> `erwanssh` on `22`
- stock admin SSH kept on `2222`
- stunnel `111 -> 443`

### Branch 2: V2Ray / Xray TLS

The extract contains:

- `Detected V2RAY TLS`
- `127.0.0.1:777`

That points to TLS traffic for the domain being forwarded to the nginx/Xray
side.

In `NewScript`, this is modeled as:

- TLS with matching SNI -> local nginx TLS backend
- nginx then proxies `/vless`, `/vmess`, `/trojan-ws`, and `/ss-ws`

### Branch 3: OpenVPN

The extract contains:

- `Detected OpenVPN`
- `127.0.0.1:1194`
- `Fallback to OpenVPN`

That points to OpenVPN TCP being a first-class local backend, and also the
default when `ErwanTCP` could not confidently classify traffic.

In `NewScript`, this is modeled as:

- direct public OpenVPN TCP on `1194`
- inner `443` fallback paths eventually resolving to local OpenVPN TCP

### Branch 4: SSL Direct / Payload Re-entry

The extract also contains `127.0.0.1:111`, which lines up with the original
stack:

- public `111` accepted TLS
- stunnel forwarded that into `443`
- `ErwanTCP` then continued routing after TLS termination

In `NewScript`, this is modeled as:

- `111 -> 443` for public SSL direct
- local stunnel fallback -> plain internal mux for non-SNI TLS traffic

## Current Open `NewScript` Model

Today the open replacement uses:

- public mux on `443`
- plain internal mux on `127.0.0.1:4443`
- stunnel fallback on `127.0.0.1:4454`

Decision model:

1. raw SSH prefix -> SSH backend
2. HTTP / payload headers -> `ErwanWS`
3. TLS with matching SNI -> nginx/Xray side
4. non-SNI TLS -> stunnel fallback, then internal plain mux
5. unknown / inner fallback -> OpenVPN TCP

That is the readable replacement for the compiled original.

## Suspicious Behaviors In The Original

These were present in the original extracts and were intentionally not carried
over:

- Telegram bot callback strings
- Telegram contact handles
- SSH root-login manipulation clues
- `/etc/passwd` and `/etc/shadow` references tied to suspicious payloads
- `_apt` credential and shell manipulation in other original binaries

## What Was Removed In `NewScript`

The open replacement keeps the flow idea but removes the suspicious behavior:

- system admin SSH keeps `PermitRootLogin yes` on the dedicated admin port so VPS recovery still works
- `erwanssh` on `22` keeps `PermitRootLogin no`
- no hardcoded admin backdoor user
- no `_apt` manipulation
- no Telegram callback logic
- no embedded GitHub / Cloudflare / Firebase secrets

## What To Test Next

The best remaining validation is still off-box client testing against the live
server for:

- SSH over `22`, `111`, and `443`
- OpenVPN TCP direct on `1194`
- OpenVPN UDP direct on `110`
- app-specific payload modes that depend on how the client formats traffic

The server-side model is now much closer to the original, but some app modes
still depend on the client sending the same handshake pattern the original
binary expected.
