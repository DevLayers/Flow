#!/usr/bin/env bash
set -uo pipefail

preset_name="${1:-}"
request_id="${2:-}"
token_file="${3:-}"
cache_dir="${4:-}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/ii"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLOR_DIR="$SCRIPT_DIR/colors"
GENERATED_DIR="$XDG_STATE_HOME/quickshell/user/generated"
COLORS_FILE="$GENERATED_DIR/colors.json"
SCSS_FILE="$GENERATED_DIR/material_colors.scss"
TERMSCHEME="$COLOR_DIR/terminal/scheme-base.json"

is_current_request() {
    [[ -n "$request_id" && -n "$token_file" && -f "$token_file" ]] || return 1
    [[ "$(cat -- "$token_file" 2>/dev/null)" == "$request_id" ]]
}

atomic_copy() {
    local src="$1"
    local dst="$2"
    local tmp="${dst}.tmp.$$"
    [[ -f "$src" ]] || return 1
    mkdir -p "$(dirname -- "$dst")"
    cp -- "$src" "$tmp" || return 1
    mv -f -- "$tmp" "$dst"
}

is_current_request || exit 0
[[ -f "$CONFIG_FILE" ]] || exit 1
mkdir -p "$GENERATED_DIR" "$cache_dir"

# An uncached legacy/imported preset already committed its config. Give
# Quickshell/compositor one frame before starting CPU-heavy color generation so
# first-use fallback cannot steal time from the visible transition.
sleep 0.12
is_current_request || exit 0

enable_apps=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE" 2>/dev/null)
[[ "$enable_apps" == "true" ]] || exit 0

wallpaper=$(jq -r '.background.wallpaperPath // ""' "$CONFIG_FILE" 2>/dev/null)
accent=$(jq -r '.appearance.palette.accentColor // ""' "$CONFIG_FILE" 2>/dev/null)
scheme=$(jq -r '.appearance.palette.type // "auto"' "$CONFIG_FILE" 2>/dev/null)

current_dark=$(jq -r '.darkmode // empty' "$COLORS_FILE" 2>/dev/null)
if [[ "$current_dark" == "true" ]]; then
    mode="dark"
elif [[ "$current_dark" == "false" ]]; then
    mode="light"
else
    current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    if [[ "$current_mode" == "prefer-dark" ]]; then
        mode="dark"
    else
        mode="light"
    fi
fi

matugen_args=(--source-color-index 0)
generate_args=()

if [[ "$accent" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
    matugen_args+=(color hex "$accent")
    generate_args+=(--color "$accent")
else
    if [[ ! -f "$wallpaper" ]]; then
        exit 0
    fi
    matugen_args+=(image "$wallpaper")
    generate_args+=(--path "$wallpaper")
fi

allowed_scheme=0
case "$scheme" in
    scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant|scheme-intense)
        allowed_scheme=1
        ;;
    auto|scheme-auto)
        if [[ -f "$wallpaper" ]]; then
            venv="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$XDG_STATE_HOME/quickshell/.venv}"
            if [[ -x "$venv/bin/python" ]]; then
                detected=$("$venv/bin/python" "$COLOR_DIR/scheme_for_image.py" "$wallpaper" 2>/dev/null | tr -d '\n')
                case "$detected" in
                    scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant)
                        scheme="$detected"
                        ;;
                    *)
                        scheme="scheme-tonal-spot"
                        ;;
                esac
            else
                scheme="scheme-tonal-spot"
            fi
        else
            scheme="scheme-tonal-spot"
        fi
        allowed_scheme=1
        ;;
    *)
        ;;
esac

custom_theme=""
if [[ $allowed_scheme -eq 0 ]]; then
    if [[ -f "$XDG_CONFIG_HOME/illogical-impulse/themes/$scheme.json" ]]; then
        custom_theme="$XDG_CONFIG_HOME/illogical-impulse/themes/$scheme.json"
    elif [[ -f "$CONFIG_DIR/defaults/themes/$scheme.json" ]]; then
        custom_theme="$CONFIG_DIR/defaults/themes/$scheme.json"
    else
        scheme="scheme-tonal-spot"
    fi
fi

is_current_request || exit 0

if [[ -n "$custom_theme" ]]; then
    if [[ "$mode" == "light" && -f "${custom_theme%.json}_light.json" ]]; then
        custom_theme="${custom_theme%.json}_light.json"
    fi
    atomic_copy "$custom_theme" "$COLORS_FILE" || exit 1
else
    matugen_args+=(--mode "$mode" --type "$scheme")
    matugen "${matugen_args[@]}" >/dev/null 2>&1 || exit 1
    is_current_request || exit 0

    if [[ "$scheme" == "scheme-intense" && -f "$COLOR_DIR/boost_surface_chroma.py" ]]; then
        python3 "$COLOR_DIR/boost_surface_chroma.py" "$COLORS_FILE" --mode "$mode" >/dev/null 2>&1 || true
    fi
fi

is_current_request || exit 0

if [[ -z "$custom_theme" && -f "$TERMSCHEME" ]]; then
    force_dark=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode // false' "$CONFIG_FILE" 2>/dev/null)
    if [[ "$force_dark" == "true" ]]; then
        generate_args+=(--mode dark)
    else
        generate_args+=(--mode "$mode")
    fi
    generate_args+=(--scheme "$scheme" --termscheme "$TERMSCHEME" --blend_bg_fg --cache "$GENERATED_DIR/color.txt")

    harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony // empty' "$CONFIG_FILE" 2>/dev/null)
    threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold // empty' "$CONFIG_FILE" 2>/dev/null)
    fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost // empty' "$CONFIG_FILE" 2>/dev/null)
    [[ -n "$harmony" ]] && generate_args+=(--harmony "$harmony")
    [[ -n "$threshold" ]] && generate_args+=(--harmonize_threshold "$threshold")
    [[ -n "$fg_boost" ]] && generate_args+=(--term_fg_boost "$fg_boost")

    venv="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$XDG_STATE_HOME/quickshell/.venv}"
    python_bin="python3"
    [[ -x "$venv/bin/python" ]] && python_bin="$venv/bin/python"
    scss_tmp="${SCSS_FILE}.preset.$$"
    if "$python_bin" "$COLOR_DIR/generate_colors_material.py" "${generate_args[@]}" > "$scss_tmp"; then
        if is_current_request; then
            mv -f -- "$scss_tmp" "$SCSS_FILE"
        else
            rm -f -- "$scss_tmp"
            exit 0
        fi
    else
        rm -f -- "$scss_tmp"
    fi
fi

is_current_request || exit 0
atomic_copy "$COLORS_FILE" "$cache_dir/colors.json" || true
atomic_copy "$SCSS_FILE" "$cache_dir/material_colors.scss" || true
printf '%s\n' "$preset_name" > "$cache_dir/name"

bash "$SCRIPT_DIR/preset_post_apply.sh" "$request_id" "$token_file" >/dev/null 2>&1 &
