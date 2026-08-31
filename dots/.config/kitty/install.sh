#!/usr/bin/env bash
set -euo pipefail

# install.sh — deploy this kitty config to ~/.config/kitty. Overlay: only the
# files the repo ships are written; anything else you have (current-theme.conf
# is managed by apply_kitty, so it is never touched) stays. Re-runnable.
#
# Usage: KITTY_CFG=/path/to/kitty-folder ./install.sh  (defaults to ~/.config/kitty)

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${KITTY_CFG:-$HOME/.config/kitty}"
mkdir -p "$DEST"

for f in kitty.conf scroll_mark.py search.py; do
    if [ -f "$SRC_DIR/$f" ]; then
        cp -f "$SRC_DIR/$f" "$DEST/$f"
    fi
done

echo "kitty config installed into $DEST"
