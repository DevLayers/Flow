#!/usr/bin/env bash
set -euo pipefail

# fetch-extras.sh — deploy this mpv config to ~/.config/mpv and fetch the
# external pieces mpv.conf/input.conf reference (Anime4K shaders, material-osc,
# thumbfast). Idempotent and safe to re-run: only missing extras are fetched.
#
# Usage: MPV_CFG=/path/to/mpv-folder ./fetch-extras.sh   (defaults to ~/.config/mpv)

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MPV_CFG="${MPV_CFG:-$HOME/.config/mpv}"
if [ -L "$MPV_CFG" ] && [ ! -e "$MPV_CFG" ]; then
    rm -f "$MPV_CFG"
fi
mkdir -p "$MPV_CFG/scripts" "$MPV_CFG/script-opts" "$MPV_CFG/shaders"

# 0. Deploy the config that lives in this folder (mpv.conf, input.conf,
#    script-opts/material-osc.conf). A re-run just refreshes them.
cp -f "$SRC_DIR/mpv.conf" "$SRC_DIR/input.conf" "$MPV_CFG/"
cp -f "$SRC_DIR/script-opts/material-osc.conf" "$MPV_CFG/script-opts/"
rm -f "$MPV_CFG/shaders/.keep"

# 1. Anime4K shaders (v4.0 release) — needed by input.conf Ctrl+1/2/0
if [ ! -f "$MPV_CFG/shaders/Anime4K_Upscale_CNN_x2_S.glsl" ]; then
    tmp="$(mktemp --suffix=.zip)"
    curl -Ls -o "$tmp" \
        https://github.com/bloc97/Anime4K/releases/download/v4.0.1/Anime4K_v4.0.zip
    unzip -oq "$tmp" -d "$MPV_CFG/shaders"
    rm -f "$tmp"
fi

# 2. material-osc UI (latest release) — replaces default OSC, used by mpv.conf.
#    Only the script and fonts are pulled in; script-opts/material-osc.conf is
#    this folder's own file and is never overwritten.
mo_version="$(curl -s https://api.github.com/repos/brahmkshatriya/material-osc/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4 || true)"
[ -n "$mo_version" ] || mo_version="0.0.13"
rm -rf "$MPV_CFG/scripts/material-osc" "$MPV_CFG/scripts/material-osc.lua"
tmp="$(mktemp --suffix=.zip)"
curl -Ls -o "$tmp" \
    "https://github.com/brahmkshatriya/material-osc/releases/download/$mo_version/material-osc.zip"
unzip -oq "$tmp" 'scripts/*' 'fonts/*' -d "$MPV_CFG"
rm -f "$tmp"

# 3. thumbfast.lua — thumbnail preview script
curl -Ls -o "$MPV_CFG/scripts/thumbfast.lua" \
    https://raw.githubusercontent.com/po5/thumbfast/refs/heads/master/thumbfast.lua

echo "mpv extras installed into $MPV_CFG"
