#!/usr/bin/env bash
set -u

request_id="${1:-}"
token_file="${2:-}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$XDG_STATE_HOME/quickshell/user/generated"
COLORS_FILE="$GENERATED_DIR/colors.json"

is_current_request() {
    [[ -z "$request_id" || -z "$token_file" ]] && return 0
    [[ -f "$token_file" ]] || return 1
    [[ "$(cat -- "$token_file" 2>/dev/null)" == "$request_id" ]]
}

is_current_request || exit 0

# Yield the first render frame to Quickshell. Everything below is integration
# work that does not need to block the shell's visual preset transition.
sleep 0.12
is_current_request || exit 0

if [[ -f "$COLORS_FILE" ]]; then
    darkmode=$(jq -r '.darkmode // empty' "$COLORS_FILE" 2>/dev/null)
    if [[ "$darkmode" == "true" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 &
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' >/dev/null 2>&1 &
    elif [[ "$darkmode" == "false" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' >/dev/null 2>&1 &
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' >/dev/null 2>&1 &
    fi
fi

# Terminal/OpenRGB application uses the already cached SCSS and is intentionally
# detached from the visual transition. Keep parity with the preset's selected
# color engine instead of always using the default applycolor backend.
color_engine=$(jq -r '.appearance.colorEngine // "vynx"' "$CONFIG_FILE" 2>/dev/null)
applycolor_script="$SCRIPT_DIR/colors/applycolor.sh"
if [[ "$color_engine" == "fork" ]]; then
    applycolor_script="$SCRIPT_DIR/colors/applycolor_vynx.sh"
fi
if [[ -f "$GENERATED_DIR/material_colors.scss" && -f "$applycolor_script" ]]; then
    bash "$applycolor_script" >/dev/null 2>&1 &
fi

is_current_request || exit 0

enable_apps=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE" 2>/dev/null)
if [[ "$enable_apps" != "true" ]]; then
    exit 0
fi

# Lower-priority consumers are fan-out work. Run them concurrently only after
# the shell has had time to paint the new preset.
sleep 0.18
is_current_request || exit 0

if [[ -x "$SCRIPT_DIR/colors/code/material-code-set-color.sh" ]]; then
    "$SCRIPT_DIR/colors/code/material-code-set-color.sh" >/dev/null 2>&1 &
fi
if [[ -x "$SCRIPT_DIR/ytmusic/generate-ytmusic-theme.sh" ]]; then
    "$SCRIPT_DIR/ytmusic/generate-ytmusic-theme.sh" >/dev/null 2>&1 &
fi
if [[ -f "$SCRIPT_DIR/colors/recolor_icons.py" ]]; then
    python3 "$SCRIPT_DIR/colors/recolor_icons.py" >/dev/null 2>&1 &
fi

enable_qt=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$CONFIG_FILE" 2>/dev/null)
if [[ "$enable_qt" == "true" ]]; then
    scheme=$(jq -r '.appearance.palette.type // "scheme-tonal-spot"' "$CONFIG_FILE" 2>/dev/null)
    case "$scheme" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant)
            ;;
        scheme-intense)
            scheme="scheme-fidelity"
            ;;
        *)
            scheme="scheme-tonal-spot"
            ;;
    esac
    kde_wrapper="$XDG_CONFIG_HOME/matugen/templates/kde/kde-material-you-colors-wrapper.sh"
    if [[ -x "$kde_wrapper" ]]; then
        "$kde_wrapper" --scheme-variant "$scheme" >/dev/null 2>&1 &
    fi
fi
