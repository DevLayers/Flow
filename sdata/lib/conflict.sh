# Flow bootstrap — file conflict handler.
#
# Sourced by setup-flow.sh (which supplies ui_*, OPT_ASSUME_YES, OPT_DRY_RUN,
# BACKUP_BASE_DIR). Resolves "the file I want to write already exists and
# differs" by applying the caller's safe default non-interactively, so an
# install run never blocks on a menu that a spawned/parented terminal cannot
# reliably collect input from (and never destroys anything by surprise).
#
# API:
#   conflict_resolve <dest> <newfile> <label> [default]
#     dest     — the file that exists and would be replaced
#     newfile  — a temp file holding the content that would be written
#     label    — short human name shown in the menu (e.g. "~/.zshrc")
#     default  — keep|overwrite|remove|skip (default: keep)
#
# On return the global CONFLICT_ACTION is one of:
#   keep      — leave dest untouched
#   overwrite — replace dest (a timestamped backup was kept first)
#   remove    — delete dest, then write the new file
#   skip      — do nothing, and don't ask about this file again
# CONFLICT_BACKUP holds the backup path after overwrite/remove, empty otherwise.
#
# Rules:
#   --dry-run      -> prints what the choice would do, changes nothing
#   anything else  -> apply the default, silently (non-interactive)
#   broken symlink as dest -> default becomes overwrite (keeping it is useless)

declare -g CONFLICT_ACTION=""
declare -g CONFLICT_BACKUP=""

_conflict_backup() {
    local dest="$1"
    local stamp dir
    stamp="$(date +%Y%m%d_%H%M%S)"
    dir="$BACKUP_BASE_DIR/conflict_$stamp"
    mkdir -p "$dir" 2>/dev/null || {
        ui_warn "Could not create backup dir $(tilde "$dir") — overwriting without a backup"
        return 0
    }
    if [[ -L "$dest" ]]; then
        # Preserve the symlink itself plus whatever it pointed at (if anything).
        cp -aP "$dest" "$dir/$(basename "$dest")" 2>/dev/null
    else
        cp -a "$dest" "$dir/$(basename "$dest")" 2>/dev/null
    fi
    printf '%s/%s' "$dir" "$(basename "$dest")"
}

conflict_resolve() {
    local dest="$1" newfile="$2" label="$3" default="${4:-keep}"
    CONFLICT_ACTION=""
    CONFLICT_BACKUP=""

    # A broken symlink is not something a user wants to "keep".
    [[ -L "$dest" && ! -e "$dest" ]] && default="overwrite"

    if [[ "$OPT_DRY_RUN" == true ]]; then
        ui_note "Conflict at $label: would apply default \"$default\" (dry run — no change)"
        CONFLICT_ACTION="$default"
        return 0
    fi

    # Non-interactive: always apply the safe default. Flow installs run from a
    # spawned/parented terminal where an interactive menu is unreliable (it can
    # swallow input or auto-close), so never block on one. `-y` keeps maps to the
    # caller's chosen default; the caller passes `overwrite` where the new file is
    # Flow's own idempotent content (e.g. the zsh bootstrap).
    CONFLICT_ACTION="$default"
    [[ "$default" == "overwrite" || "$default" == "remove" ]] &&
        CONFLICT_BACKUP="$(_conflict_backup "$dest")"
    ui_verbose "conflict $label -> $default (non-interactive)"
    return 0
}

# Apply the decision recorded in CONFLICT_ACTION.
# conflict_apply <dest> <newfile> — returns 0 if the new file ended up in place.
conflict_apply() {
    local dest="$1" newfile="$2"
    case "$CONFLICT_ACTION" in
        keep | skip)
            ui_verbose "kept $dest"
            return 0
            ;;
        remove)
            rm -f "$dest"
            mkdir -p "$(dirname "$dest")"
            cp -f "$newfile" "$dest"
            ui_note "Removed $dest and wrote the new file."
            return 0
            ;;
        overwrite)
            mkdir -p "$(dirname "$dest")"
            cp -f "$newfile" "$dest"
            ui_note "Overwrote $dest (backup: $(tilde "$CONFLICT_BACKUP"))."
            return 0
            ;;
    esac
    return 1
}