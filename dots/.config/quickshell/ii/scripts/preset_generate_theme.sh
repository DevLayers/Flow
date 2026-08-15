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
WPE_TEMP_SOURCE="/tmp/ii-preset-wpe-${request_id}.png"
VIDEO_TEMP_SOURCE="/tmp/ii-preset-video-${request_id}.jpg"

cleanup() {
    rm -f -- "$WPE_TEMP_SOURCE" "$VIDEO_TEMP_SOURCE"
}
trap cleanup EXIT

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

extract_first_frame() {
    local input="$1"
    local output="$2"
    command -v ffmpeg >/dev/null 2>&1 || return 1
    ffmpeg -loglevel error -y -i "$input" -frames:v 1 "$output" >/dev/null 2>&1
}

resolve_wpe_preview() {
    local wpe_id="$1"
    local assets="$2"
    local candidate workshop
    local -a workshops=()

    if [[ -n "$assets" ]]; then
        workshop="${assets/common\/wallpaper_engine\/assets/workshop\/content\/431960}"
        workshops+=("$workshop")
        workshop="${assets/common\/wallpaper_engine/workshop\/content\/431960}"
        workshops+=("$workshop")
    fi
    workshops+=(
        "$HOME/.local/share/Steam/steamapps/workshop/content/431960"
        "$HOME/.steam/steam/steamapps/workshop/content/431960"
        "$HOME/.steam/root/steamapps/workshop/content/431960"
    )

    for workshop in "${workshops[@]}"; do
        [[ -d "$workshop/$wpe_id" ]] || continue
        candidate="$workshop/$wpe_id/preview.jpg"
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
        candidate="$workshop/$wpe_id/preview.png"
        if [[ -f "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
        candidate="$workshop/$wpe_id/preview.gif"
        if [[ -f "$candidate" ]] && extract_first_frame "$candidate" "$WPE_TEMP_SOURCE"; then
            printf '%s' "$WPE_TEMP_SOURCE"
            return 0
        fi
    done
    return 1
}

resolve_color_source() {
    local wallpaper="$1"
    local use_wpe="$2"
    local thumbnail source wpe_id wpe_assets

    if [[ "$use_wpe" == "true" ]]; then
        wpe_id=$(jq -r '.background.wallpaperEngineId // ""' "$CONFIG_FILE" 2>/dev/null)
        wpe_assets=$(jq -r '.background.wallpaperEngineAssetsPath // ""' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$wpe_id" ]] && source=$(resolve_wpe_preview "$wpe_id" "$wpe_assets"); then
            printf '%s' "$source"
            return 0
        fi
        return 1
    fi

    case "${wallpaper,,}" in
        *.mp4|*.mkv|*.webm|*.avi|*.mov|*.m4v|*.ogv)
            thumbnail=$(jq -r '.background.thumbnailPath // ""' "$CONFIG_FILE" 2>/dev/null)
            if [[ -f "$thumbnail" ]]; then
                printf '%s' "$thumbnail"
                return 0
            fi
            [[ -f "$wallpaper" ]] || return 1
            extract_first_frame "$wallpaper" "$VIDEO_TEMP_SOURCE" || return 1
            printf '%s' "$VIDEO_TEMP_SOURCE"
            return 0
            ;;
        *)
            [[ -f "$wallpaper" ]] || return 1
            printf '%s' "$wallpaper"
            return 0
            ;;
    esac
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
use_wpe=$(jq -r '.background.useWallpaperEngine // false' "$CONFIG_FILE" 2>/dev/null)
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
color_source=""

if [[ "$accent" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
    matugen_args+=(color hex "$accent")
    generate_args+=(--color "$accent")
else
    # WPE/video presets need an image preview. Never feed a video or unrelated
    # stale wallpaperPath directly into Matugen: if a safe source cannot be
    # resolved, preserve the current palette and simply leave this preset cold.
    color_source=$(resolve_color_source "$wallpaper" "$use_wpe") || exit 0
    matugen_args+=(image "$color_source")
    generate_args+=(--path "$color_source")
fi

allowed_scheme=0
case "$scheme" in
    scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot|scheme-vibrant|scheme-intense)
        allowed_scheme=1
        ;;
    auto|scheme-auto)
        if [[ -n "$color_source" && -f "$color_source" ]]; then
            venv="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$XDG_STATE_HOME/quickshell/.venv}"
            if [[ -x "$venv/bin/python" ]]; then
                detected=$("$venv/bin/python" "$COLOR_DIR/scheme_for_image.py" "$color_source" 2>/dev/null | tr -d '\n')
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
