#!/usr/bin/env bash
set -euo pipefail

# install.sh — deploy this zshrc.d to ~/.config/zshrc.d. Overlay: only the
# *.zsh files the repo ships are written; your own zshrc.d files are kept.
# Re-runnable.
#
# Usage: ZSHRC_D_DIR=/path/to/zshrc.d-folder ./install.sh  (defaults to ~/.config/zshrc.d)

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${ZSHRC_D_DIR:-$HOME/.config/zshrc.d}"
mkdir -p "$DEST"

for f in "$SRC_DIR"/*.zsh; do
    [ -f "$f" ] || continue
    cp -f "$f" "$DEST/$(basename "$f")"
done

echo "zshrc.d installed into $DEST"
