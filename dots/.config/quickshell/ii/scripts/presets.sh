#!/usr/bin/env bash
set -uo pipefail

PRESETS_DIR="$HOME/.config/illogical-impulse/presets"
CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
GENERATED_DIR="$XDG_STATE_HOME/quickshell/user/generated"
CACHE_ROOT="$PRESETS_DIR/.cache"
TOKEN_FILE="$XDG_STATE_HOME/quickshell/user/preset_apply_request"
STATUS_FILE="$XDG_STATE_HOME/quickshell/user/preset_apply_status"
GENERATOR_PID_FILE="$XDG_STATE_HOME/quickshell/user/preset_theme_generator"

mkdir -p "$PRESETS_DIR" "$CACHE_ROOT" "$GENERATED_DIR" "$(dirname "$TOKEN_FILE")"

action="${1:-}"
name="${2:-}"
request_id="${3:-}"

notify_export() {
    local urgency="$1"
    local title="$2"
    local body="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "II Presets" -u "$urgency" "$title" "$body" >/dev/null 2>&1 &
    fi
}

fail_export() {
    local message="$1"
    printf '[presets.sh] Export failed: %s\n' "$message" >&2
    notify_export critical "Preset export failed" "$message"
    exit 1
}

valid_name() {
    [[ -n "$name" && "$name" != "." && "$name" != ".." ]] || return 1
    [[ "$name" != *"/"* && "$name" != *$'\n'* && "$name" != *$'\r'* && "$name" != *$'\t'* ]] || return 1
}

cache_dir_for() {
    local preset_name="$1"
    local key
    key=$(printf '%s' "$preset_name" | sha256sum | cut -d' ' -f1)
    printf '%s/%s' "$CACHE_ROOT" "$key"
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

cache_snapshot() {
    local preset_name="$1"
    local cache_dir
    cache_dir=$(cache_dir_for "$preset_name")
    mkdir -p "$cache_dir"
    atomic_copy "$GENERATED_DIR/colors.json" "$cache_dir/colors.json" || true
    atomic_copy "$GENERATED_DIR/material_colors.scss" "$cache_dir/material_colors.scss" || true
    printf '%s\n' "$preset_name" > "$cache_dir/name"
}

restore_cached_theme() {
    local preset_name="$1"
    local cache_dir
    cache_dir=$(cache_dir_for "$preset_name")
    [[ -f "$cache_dir/colors.json" ]] || return 1

    # Presets do not own the global light/dark mode. Reusing an exported cache
    # from the opposite mode would emit darkmodeChanged and can recursively
    # start another wallpaper pipeline. Warm a same-mode cache instead.
    local cached_dark current_dark
    cached_dark=$(jq -r '.darkmode // empty' "$cache_dir/colors.json" 2>/dev/null)
    current_dark=$(jq -r '.darkmode // empty' "$GENERATED_DIR/colors.json" 2>/dev/null)
    if [[ -n "$cached_dark" && -n "$current_dark" && "$cached_dark" != "$current_dark" ]]; then
        return 1
    fi

    atomic_copy "$cache_dir/colors.json" "$GENERATED_DIR/colors.json" || return 1
    if [[ -f "$cache_dir/material_colors.scss" ]]; then
        atomic_copy "$cache_dir/material_colors.scss" "$GENERATED_DIR/material_colors.scss" || true
    fi
    return 0
}

register_request() {
    [[ "$request_id" =~ ^[0-9]+$ ]] || request_id="$(date +%s%3N)"

    exec 201>"${TOKEN_FILE}.lock"
    flock -x 201
    local current=""
    [[ -f "$TOKEN_FILE" ]] && current=$(cat -- "$TOKEN_FILE" 2>/dev/null)
    if [[ "$current" =~ ^[0-9]+$ ]] && (( request_id <= current )); then
        flock -u 201
        exec 201>&-
        return 1
    fi
    printf '%s' "$request_id" > "${TOKEN_FILE}.tmp.$$"
    mv -f -- "${TOKEN_FILE}.tmp.$$" "$TOKEN_FILE"
    flock -u 201
    exec 201>&-
    return 0
}

is_current_request() {
    [[ -f "$TOKEN_FILE" ]] || return 1
    [[ "$(cat -- "$TOKEN_FILE" 2>/dev/null)" == "$request_id" ]]
}

write_status() {
    local state="$1"
    local mode="${2:-}"
    is_current_request || return 0
    local tmp="${STATUS_FILE}.tmp.$$"
    printf '%s\t%s\t%s\n' "$request_id" "$state" "$mode" > "$tmp"
    mv -f -- "$tmp" "$STATUS_FILE"
}

cancel_previous_generator() {
    [[ -f "$GENERATOR_PID_FILE" ]] || return 0
    local old_request old_pid
    IFS=$'\t' read -r old_request old_pid < "$GENERATOR_PID_FILE" || true
    if [[ "$old_pid" =~ ^[0-9]+$ && "$old_request" != "$request_id" ]]; then
        kill -- "-$old_pid" >/dev/null 2>&1 || true
        for _ in {1..10}; do
            kill -0 "$old_pid" >/dev/null 2>&1 || break
            sleep 0.01
        done
        kill -KILL -- "-$old_pid" >/dev/null 2>&1 || true
    fi
    rm -f -- "$GENERATOR_PID_FILE"
}

start_cache_warmup() {
    local preset_name="$1"
    local cache_dir
    cache_dir=$(cache_dir_for "$preset_name")

    setsid bash "$SCRIPTS_DIR/preset_generate_theme.sh" \
        "$preset_name" "$request_id" "$TOKEN_FILE" "$cache_dir" \
        > /tmp/presets_theme_warmup.log 2>&1 &
    local generator_pid=$!
    printf '%s\t%s\n' "$request_id" "$generator_pid" > "${GENERATOR_PID_FILE}.tmp.$$"
    mv -f -- "${GENERATOR_PID_FILE}.tmp.$$" "$GENERATOR_PID_FILE"
}

case "$action" in
    save)
        valid_name || exit 1
        cp -- "$CONFIG_FILE" "$PRESETS_DIR/$name.json" || exit 1

        wall_path=$(jq -r '.background.wallpaperPath // ""' "$CONFIG_FILE" 2>/dev/null)
        if [[ -f "$wall_path" ]]; then
            ext="${wall_path##*.}"
            cp -- "$wall_path" "$PRESETS_DIR/$name.$ext"
        fi
        cache_snapshot "$name"
        ;;

    update)
        valid_name || exit 1
        [[ -f "$PRESETS_DIR/$name.json" ]] || exit 1
        for file in "$PRESETS_DIR/$name".*; do
            if [[ -f "$file" && "${file##*.}" != "json" ]]; then
                rm -f -- "$file"
            fi
        done
        cp -- "$CONFIG_FILE" "$PRESETS_DIR/$name.json" || exit 1
        wall_path=$(jq -r '.background.wallpaperPath // ""' "$CONFIG_FILE" 2>/dev/null)
        if [[ -f "$wall_path" ]]; then
            ext="${wall_path##*.}"
            cp -- "$wall_path" "$PRESETS_DIR/$name.$ext"
        fi
        cache_snapshot "$name"
        ;;

    load)
        valid_name || exit 1
        [[ -f "$PRESETS_DIR/$name.json" ]] || exit 1
        register_request || exit 0
        cancel_previous_generator
        write_status "applying" ""

        apply_result=$(python3 "$SCRIPTS_DIR/presets_helper.py" apply \
            "$PRESETS_DIR/$name.json" "$CONFIG_FILE" "$PRESETS_DIR" "$name" \
            "$TOKEN_FILE" "$request_id" 2>/tmp/presets_apply_error.log) || {
                write_status "failed" "config"
                exit 1
            }

        is_current_request || exit 0
        if [[ "$apply_result" == *'"superseded": true'* || "$apply_result" == *'"superseded":true'* ]]; then
            exit 0
        fi

        theming_enabled=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$CONFIG_FILE" 2>/dev/null)
        if [[ "$theming_enabled" != "true" ]]; then
            write_status "success" "config-only"
            exit 0
        fi

        if restore_cached_theme "$name"; then
            write_status "success" "cached"
            bash "$SCRIPTS_DIR/preset_post_apply.sh" "$request_id" "$TOKEN_FILE" >/dev/null 2>&1 &
        else
            # Legacy/raw imports get their config immediately. Color generation is
            # isolated in a cancellable process group, never writes config, and
            # fills the cache for the next switch.
            start_cache_warmup "$name"
            write_status "success" "warming-cache"
        fi
        ;;

    delete)
        valid_name || exit 1
        rm -f -- "$PRESETS_DIR/$name.json"
        for file in "$PRESETS_DIR/$name".*; do
            if [[ -f "$file" && "${file##*.}" != "json" ]]; then
                rm -f -- "$file"
            fi
        done
        rm -rf -- "$(cache_dir_for "$name")"
        ;;

    list)
        python3 "$SCRIPTS_DIR/presets_helper.py" list "$PRESETS_DIR"
        ;;

    export)
        valid_name || fail_export "Invalid preset name."
        [[ -f "$PRESETS_DIR/$name.json" ]] || fail_export "Preset not found: $name"
        command -v zip >/dev/null 2>&1 || fail_export "The 'zip' utility is not installed."

        if command -v zenity >/dev/null 2>&1; then
            DEST_ZIP=$(zenity --file-selection --save --confirm-overwrite --filename="$HOME/${name}.zip" --file-filter="ZIP | *.zip" 2>/dev/null)
        else
            DEST_ZIP=$(kdialog --getsavefilename "$HOME/${name}.zip" "*.zip" 2>/dev/null)
        fi

        if [[ -n "$DEST_ZIP" ]]; then
            [[ "$DEST_ZIP" == *.zip ]] || DEST_ZIP="${DEST_ZIP}.zip"
            DEST_DIR=$(dirname -- "$DEST_ZIP")
            [[ -d "$DEST_DIR" ]] || fail_export "Destination directory does not exist: $DEST_DIR"
            [[ -w "$DEST_DIR" ]] || fail_export "Destination directory is not writable: $DEST_DIR"

            TMP_DIR=$(mktemp -d /tmp/preset_export_XXXXXX) || fail_export "Could not create a temporary export directory."
            trap 'rm -rf -- "${TMP_DIR:-}"' EXIT

            cp -- "$PRESETS_DIR/$name.json" "$TMP_DIR/config.json" || fail_export "Could not copy the preset configuration."
            python3 "$SCRIPTS_DIR/presets_helper.py" sanitize "$TMP_DIR/config.json" "$TMP_DIR/config.json" \
                || fail_export "Could not sanitize the preset configuration."

            for file in "$PRESETS_DIR/$name".*; do
                if [[ -f "$file" ]]; then
                    ext="${file##*.}"
                    if [[ "$ext" != "json" && "$ext" != "zip" ]]; then
                        cp -- "$file" "$TMP_DIR/wallpaper.$ext" || fail_export "Could not copy the preset wallpaper."
                        break
                    fi
                fi
            done

            cache_dir=$(cache_dir_for "$name")
            if [[ -f "$cache_dir/colors.json" ]]; then
                mkdir -p "$TMP_DIR/preset-cache"
                cp -- "$cache_dir/colors.json" "$TMP_DIR/preset-cache/colors.json"
                [[ ! -f "$cache_dir/material_colors.scss" ]] || cp -- "$cache_dir/material_colors.scss" "$TMP_DIR/preset-cache/material_colors.scss"
            fi

            (cd "$TMP_DIR" && zip -qr "$DEST_ZIP" .) || fail_export "Could not write the archive to: $DEST_ZIP"
            [[ -s "$DEST_ZIP" ]] || fail_export "The archive was not created: $DEST_ZIP"

            rm -rf -- "$TMP_DIR"
            trap - EXIT
            printf '[presets.sh] Exported preset to: %s\n' "$DEST_ZIP"
            notify_export normal "Preset exported" "Saved to: $DEST_ZIP"
        else
            printf '[presets.sh] Export cancelled.\n' >&2
            notify_export low "Preset export cancelled" "No destination was selected."
        fi
        ;;

    import)
        if command -v zenity >/dev/null 2>&1; then
            FILE=$(zenity --file-selection --file-filter="Presets (*.zip *.json) | *.zip *.json" 2>/dev/null)
        else
            FILE=$(kdialog --getopenfilename "$HOME" "*.zip *.json" 2>/dev/null)
        fi

        if [[ -n "$FILE" && -f "$FILE" ]]; then
            preset_name=$(basename "$FILE" | sed 's/\.[^.]*$//')
            name="$preset_name"
            valid_name || exit 1
            ext="${FILE##*.}"
            ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')

            if [[ "$ext" == "json" ]]; then
                python3 "$SCRIPTS_DIR/presets_helper.py" sanitize "$FILE" "$PRESETS_DIR/$preset_name.json" || exit 1
                echo 'success'
            elif [[ "$ext" == "zip" ]]; then
                TMP_DIR=$(mktemp -d /tmp/preset_import_XXXXXX) || exit 1
                trap 'rm -rf -- "${TMP_DIR:-}"' EXIT
                unzip -oq "$FILE" -d "$TMP_DIR" || exit 1

                config_json=""
                if [[ -f "$TMP_DIR/config.json" ]]; then
                    config_json="$TMP_DIR/config.json"
                else
                    for f in "$TMP_DIR"/*.json; do
                        if [[ -f "$f" ]]; then
                            config_json="$f"
                            break
                        fi
                    done
                fi

                if [[ -n "$config_json" ]]; then
                    python3 "$SCRIPTS_DIR/presets_helper.py" sanitize "$config_json" "$PRESETS_DIR/$preset_name.json" || exit 1

                    for f in "$TMP_DIR"/*; do
                        if [[ -f "$f" ]]; then
                            f_ext="${f##*.}"
                            f_ext=$(printf '%s' "$f_ext" | tr '[:upper:]' '[:lower:]')
                            if [[ "$f_ext" != "json" && "$f_ext" != "zip" ]]; then
                                cp -- "$f" "$PRESETS_DIR/$preset_name.$f_ext"
                                break
                            fi
                        fi
                    done

                    cache_dir=$(cache_dir_for "$preset_name")
                    if [[ -f "$TMP_DIR/preset-cache/colors.json" ]]; then
                        mkdir -p "$cache_dir"
                        atomic_copy "$TMP_DIR/preset-cache/colors.json" "$cache_dir/colors.json" || true
                        atomic_copy "$TMP_DIR/preset-cache/material_colors.scss" "$cache_dir/material_colors.scss" || true
                        printf '%s\n' "$preset_name" > "$cache_dir/name"
                    fi
                    echo 'success'
                fi
                rm -rf -- "$TMP_DIR"
                trap - EXIT
            fi
        fi
        ;;

    *)
        printf '[presets.sh] Unknown action: %s\n' "$action" >&2
        exit 1
        ;;
esac
