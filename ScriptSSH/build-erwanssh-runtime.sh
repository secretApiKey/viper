#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${TARGET_DIR:-/etc/ErwanScript}"
RUNTIME_DIR="${RUNTIME_DIR:-$TARGET_DIR/ErwanSSH}"
COMPILED_RUNTIME_ROOT="${COMPILED_RUNTIME_ROOT:-/etc/ErwanSSH}"
WORK_DIR="${WORK_DIR:-/usr/local/src/erwanssh-build}"
SRC_DIR="${SRC_DIR:-$WORK_DIR/openssh-portable}"
OPENSSH_GIT_URL="${OPENSSH_GIT_URL:-https://github.com/openssh/openssh-portable.git}"
OPENSSH_REF="${OPENSSH_REF:-}"
SSH_BRAND="${SSH_BRAND:-ViperScript}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1"
        exit 1
    }
}

need_cmd git
need_cmd make
need_cmd autoreconf
need_cmd gcc

mkdir -p "$WORK_DIR" "$TARGET_DIR"
mkdir -p "$(dirname "$COMPILED_RUNTIME_ROOT")"

if [ ! -d "$SRC_DIR/.git" ]; then
    rm -rf "$SRC_DIR"
    git clone "$OPENSSH_GIT_URL" "$SRC_DIR"
fi

cd "$SRC_DIR"

if [ -n "$OPENSSH_REF" ]; then
    git fetch --tags origin >/dev/null 2>&1 || true
    git checkout "$OPENSSH_REF"
fi

SSH_BRAND="$SSH_BRAND" perl -0pi -e 's/#define SSH_VERSION\s+"[^"]+"/#define SSH_VERSION\t"$ENV{SSH_BRAND}"/' version.h

autoreconf -fi

rm -rf "$RUNTIME_DIR" "$COMPILED_RUNTIME_ROOT"
mkdir -p "$COMPILED_RUNTIME_ROOT/var/run" "$COMPILED_RUNTIME_ROOT/var/empty"

./configure \
    --prefix="$RUNTIME_DIR" \
    --bindir="$COMPILED_RUNTIME_ROOT/bin" \
    --sbindir="$COMPILED_RUNTIME_ROOT/sbin" \
    --libexecdir="$COMPILED_RUNTIME_ROOT/libexec" \
    --sysconfdir="$COMPILED_RUNTIME_ROOT/etc" \
    --with-privsep-path="$COMPILED_RUNTIME_ROOT/var/empty" \
    --with-pid-dir="$COMPILED_RUNTIME_ROOT/var/run" \
    --with-default-path="/usr/bin:/bin:/usr/sbin:/sbin:$COMPILED_RUNTIME_ROOT/bin" \
    --with-pam

make -j"$JOBS"
make install-nokeys

if [ "$RUNTIME_DIR" != "$COMPILED_RUNTIME_ROOT" ]; then
    cp -a "$COMPILED_RUNTIME_ROOT" "$RUNTIME_DIR"
fi

for path in "$COMPILED_RUNTIME_ROOT" "$RUNTIME_DIR"; do
    [ -d "$path" ] || continue
    chmod 0755 "$path" "$path/bin" "$path/sbin" "$path/libexec" "$path/var" "$path/var/empty" "$path/var/run"
    find "$path/bin" "$path/sbin" "$path/libexec" -type f -exec chmod 0755 {} \;
    find "$path/etc" -maxdepth 1 -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \; 2>/dev/null || true
    find "$path/etc" -maxdepth 1 -type f -name 'ssh_host_*.pub' -exec chmod 0644 {} \; 2>/dev/null || true
done

echo "Built ErwanSSH runtime bundle into $RUNTIME_DIR"
echo "Compiled runtime paths target $COMPILED_RUNTIME_ROOT"
