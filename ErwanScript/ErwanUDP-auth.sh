#!/bin/bash

set -euo pipefail

username="${1:-${USERNAME:-}}"
password="${2:-${PASSWORD:-}}"

if [ -z "$username" ]; then
    read -r username || username=""
fi

if [ -z "$password" ]; then
    read -r password || password=""
fi

if [ -z "$username" ] || [ -z "$password" ]; then
    echo "missing credentials" >&2
    exit 1
fi

if ! id "$username" >/dev/null 2>&1; then
    echo "authentication failed" >&2
    exit 1
fi

python3 - "$username" "$password" <<'PY'
import sys

username = sys.argv[1]
password = sys.argv[2]

try:
    import pam  # type: ignore
except Exception:
    sys.exit(1)

auth = pam.pam()
ok = auth.authenticate(username, password, service="login")
sys.exit(0 if ok else 1)
PY
