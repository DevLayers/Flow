#!/usr/bin/env bash

# Lightweight color-scheme application path used by the Settings color picker.
# Unlike switchwall(_vynx).sh, this path does not regenerate wallpaper preview
# caches or launch unrelated background post-processing for a scheme-only change.
# Keeping the operation synchronous also makes the QML coordinator's
# single-flight/latest-wins behavior real: when this process exits, its work is
# actually finished.

set -u

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
TERMINAL_SCHEME="$SCRIPT_DIR/terminal/scheme-base.json"

scheme="${1:-}"
if [[ -z "$scheme" ]]; then
    echo "Usage: $0 <scheme>" >&2
    exit 2
fi

mkdir -p "$STATE_DIR/user/generated"

# Serialize scheme-only applications even when called outside QML.
exec 9>"$STATE_DIR/user/generated/.scheme_apply.lock"
flock -x 9

config_get() {
    local query="$1"
    local fallback="${2:-}"
    if [[ -f "$SHELL_CONFIG_FILE" ]]; then
        local value
        value=$(jq -r "$query // empty" "$SHELL_CONFIG_FILE" 2>/dev/null || true)
        if [[ -n "$value" && "$value" != "null" ]]; then
            printf '%s' "$value"
            return
        fi
    fi
    printf '%s' "$fallback"
}

request_shell_theme_reload_once() {
    if ! command -v qs >/dev/null 2>&1; then
        echo "[apply_scheme_core] qs not found; skipping one-shot shell reload" >&2
        return 0
    fi

    if qs -c ii ipc call theme reapplyTheme >/dev/null 2>&1; then
        echo "[apply_scheme_core] Requested one-shot shell theme reload"
    else
        echo "[apply_scheme_core] One-shot shell theme reload failed; FileView watcher remains primary" >&2
    fi
}

mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)
if [[ "$mode" == "prefer-light" ]]; then
    mode="light"
else
    mode="dark"
fi

use_wpe=$(config_get '.background.useWallpaperEngine' 'false')
wallpaper=$(config_get '.background.wallpaperPath' '')
accent=$(config_get '.appearance.palette.accentColor' '')

source_image="$wallpaper"
if [[ "$use_wpe" == "true" && -f /tmp/wpe_screenshot.png ]]; then
    source_image="/tmp/wpe_screenshot.png"
fi

# Keep auto behavior compatible with switchwall when possible.
if [[ "$scheme" == "auto" || "$scheme" == "scheme-auto" ]]; then
    if [[ -n "$source_image" && -f "$source_image" ]]; then
        venv="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$STATE_DIR/.venv}"
        if [[ -f "$venv/bin/activate" ]]; then
            # shellcheck disable=SC1090
            source "$venv/bin/activate"
        fi
        detected=$(python3 "$SCRIPT_DIR/scheme_for_image.py" "$source_image" 2>/dev/null | tr -d '\n' || true)
        case "$detected" in
            scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant)
                scheme="$detected"
                ;;
            *)
                scheme="scheme-tonal-spot"
                ;;
        esac
        if declare -F deactivate >/dev/null 2>&1; then
            deactivate
        fi
    else
        scheme="scheme-tonal-spot"
    fi
fi

matugen_type="$scheme"
if [[ "$scheme" == "scheme-intense" ]]; then
    matugen_type="scheme-fidelity"
fi

matugen_args=()

if [[ "$accent" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
    matugen_args=(color hex "$accent")
elif [[ -n "$source_image" && -f "$source_image" ]]; then
    matugen_args=(image "$source_image")

    # Matugen 4 introduced interactive source-color selection for images.
    # Matugen 3 automatically uses its ranked source color and does not accept
    # --source-color-index, so only add the flag when the installed CLI exposes it.
    if matugen image --help 2>&1 | grep -qF -- '--source-color-index'; then
        matugen_args+=(--source-color-index 0)
    fi
else
    echo "[apply_scheme_core] No valid wallpaper/accent source available" >&2
    exit 1
fi

matugen_args+=(--mode "$mode" --type "$matugen_type")

# This is the same core operation that makes colors.json and Matugen-managed
# application templates update. FileView remains the primary shell update path;
# a single best-effort IPC reload is sent after the final colors.json is ready
# to cover a missed file-watch event without restoring the old repeated reloads.
if ! matugen "${matugen_args[@]}"; then
    echo "[apply_scheme_core] Matugen failed; preserving current theme" >&2
    exit 1
fi

if [[ "$scheme" == "scheme-intense" ]]; then
    python3 "$SCRIPT_DIR/boost_surface_chroma.py" \
        "$STATE_DIR/user/generated/colors.json" --mode "$mode"
fi

request_shell_theme_reload_once

# Terminal generation is optional and, critically, does NOT regenerate the
# all-schemes wallpaper preview cache. That cache depends on the wallpaper, not
# on which scheme button is currently selected.
enable_terminal=$(config_get '.appearance.wallpaperTheming.enableTerminal' 'true')
if [[ "$enable_terminal" == "true" && -n "$source_image" && -f "$source_image" ]]; then
    generator_args=(
        --path "$source_image"
        --scheme "$scheme"
        --termscheme "$TERMINAL_SCHEME"
        --blend_bg_fg
        --cache "$STATE_DIR/user/generated/color.txt"
        --mode "$mode"
    )

    harmony=$(config_get '.appearance.wallpaperTheming.terminalGenerationProps.harmony' '')
    harmonize_threshold=$(config_get '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold' '')
    term_fg_boost=$(config_get '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost' '')
    force_dark=$(config_get '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode' 'false')

    [[ -n "$harmony" ]] && generator_args+=(--harmony "$harmony")
    [[ -n "$harmonize_threshold" ]] && generator_args+=(--harmonize_threshold "$harmonize_threshold")
    [[ -n "$term_fg_boost" ]] && generator_args+=(--term_fg_boost "$term_fg_boost")
    if [[ "$force_dark" == "true" ]]; then
        # Replace the mode argument added above.
        generator_args[${#generator_args[@]}-1]="dark"
    fi

    venv="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$STATE_DIR/.venv}"
    if [[ -f "$venv/bin/activate" ]]; then
        # shellcheck disable=SC1090
        source "$venv/bin/activate"
    fi
    if python3 "$SCRIPT_DIR/generate_colors_material_vynx.py" "${generator_args[@]}" \
        > "$STATE_DIR/user/generated/material_colors.scss.tmp"; then
        mv "$STATE_DIR/user/generated/material_colors.scss.tmp" \
            "$STATE_DIR/user/generated/material_colors.scss"
        "$SCRIPT_DIR/applycolor_vynx.sh"
    else
        rm -f "$STATE_DIR/user/generated/material_colors.scss.tmp"
        echo "[apply_scheme_core] Terminal palette generation failed; preserving previous palette" >&2
    fi
    if declare -F deactivate >/dev/null 2>&1; then
        deactivate
    fi
fi

# Dynamic icon generation is expensive and changes the system icon theme. Do
# not even start it unless the experimental themed-icons feature is enabled.
enable_themed_icons=$(config_get '.appearance.icons.enableThemed' 'false')
if [[ "$enable_themed_icons" == "true" ]]; then
    python3 "$SCRIPT_DIR/recolor_icons.py"
fi

# KDE/Qt integration is optional. Keep it synchronous so repeated color-picker
# clicks cannot accumulate detached post-processing jobs after the parent exits.
enable_qt_apps=$(config_get '.appearance.wallpaperTheming.enableQtApps' 'true')
if [[ "$enable_qt_apps" == "true" ]]; then
    kde_scheme="$scheme"
    case "$kde_scheme" in
        scheme-intense) kde_scheme="scheme-fidelity" ;;
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant) ;;
        *) kde_scheme="scheme-tonal-spot" ;;
    esac
    "$XDG_CONFIG_HOME/matugen/templates/kde/kde-material-you-colors-wrapper.sh" \
        --scheme-variant "$kde_scheme" || true
fi
