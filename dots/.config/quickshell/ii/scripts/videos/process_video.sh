#!/usr/bin/env bash

# Compatibility entrypoint for older callers. The Quickshell editor now uses
# compress_video.py directly through its JSON-line protocol, but keeping this
# wrapper prevents scripts outside the editor from silently using the old,
# fixed-CRF implementation.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/compress_video.py" "$@"
