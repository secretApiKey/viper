#!/bin/bash

set -euo pipefail

RUNTIME_PARENT="${RUNTIME_PARENT:-/etc/ErwanScript}"
RUNTIME_NAME="${RUNTIME_NAME:-ErwanSSH}"
RUNTIME_DIR="${RUNTIME_DIR:-$RUNTIME_PARENT/$RUNTIME_NAME}"
OUTPUT_TAR="${OUTPUT_TAR:-/root/ErwanSSH-built.tar.gz}"

if [ ! -d "$RUNTIME_DIR" ]; then
    echo "Missing runtime directory: $RUNTIME_DIR"
    exit 1
fi

tar -C "$RUNTIME_PARENT" -czf "$OUTPUT_TAR" "$RUNTIME_NAME"
echo "Exported runtime archive: $OUTPUT_TAR"
