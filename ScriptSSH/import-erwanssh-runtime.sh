#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_PATH="${1:-}"
TARGET_DIR="${TARGET_DIR:-$REPO_ROOT/ErwanSSH}"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ -z "$ARCHIVE_PATH" ]; then
    echo "Usage: $0 /path/to/ErwanSSH-built.tar.gz"
    exit 1
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "Archive not found: $ARCHIVE_PATH"
    exit 1
fi

tar -C "$TMP_DIR" -xzf "$ARCHIVE_PATH"

if [ ! -d "$TMP_DIR/ErwanSSH" ]; then
    echo "Archive does not contain ErwanSSH/ at its top level."
    exit 1
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -a "$TMP_DIR/ErwanSSH/." "$TARGET_DIR/"

find "$TARGET_DIR" -type d -exec chmod 0755 {} \;
find "$TARGET_DIR" -type f -exec chmod 0644 {} \;
find "$TARGET_DIR/bin" "$TARGET_DIR/sbin" "$TARGET_DIR/libexec" -type f -exec chmod 0755 {} \; 2>/dev/null || true
find "$TARGET_DIR/etc" -maxdepth 1 -type f -name 'ssh_host_*_key' -exec chmod 0600 {} \; 2>/dev/null || true
find "$TARGET_DIR/etc" -maxdepth 1 -type f -name 'ssh_host_*.pub' -exec chmod 0644 {} \; 2>/dev/null || true

echo "Imported rebuilt ErwanSSH bundle into $TARGET_DIR"
