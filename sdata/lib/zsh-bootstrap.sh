# Flow bootstrap — Zsh shell integration.
#
# Sourced by setup-flow.sh. Makes a fresh or existing machine load the Flow
# shell runtime (~/.config/zsh/.zshrc + ~/.config/zshrc.d/*) without ever
# overwriting a user's own ~/.zshrc, and provides an explicit opt-in for
# switching the login shell to Zsh.
#
# Mechanism:
#   ~/.zshenv             untouched (no ZDOTDIR games — hiding a user's ~/.zshrc
#                         behind a ZDOTDIR switch would lose their config)
#   ~/.zshrc              user file preserved; a single Flow-managed block is
#                         appended that sources ~/.config/zsh/.zshrc
#   ~/.config/zsh/.zshrc  Flow bootstrap (deployed via extras): loads zshrc.d in
#                         order, then `starship init zsh`
#   ~/.config/zshrc.d/    the modular shell fragments (deployed via extras)
#
# The managed block is the only thing between the markers, so it can be updated
# in place and never duplicates. If the user later sets ZDOTDIR themselves, Zsh
# reads their own rc files instead and the block simply never runs — Flow does
# not fight an explicit choice.

FLOW_ZSH_BLOCK_BEGIN="# >>> Flow managed block >>>"
FLOW_ZSH_BLOCK_END="# <<< Flow managed block <<<"

FLOW_ZSH_BOOTSTRAP="$HOME/.config/zsh/.zshrc"
FLOW_BOOTSTRAP_STATE="$SETUP_STATE_DIR/bootstrap.state"

zsh_managed_block() {
    printf '%s\n' \
        "$FLOW_ZSH_BLOCK_BEGIN" \
        "# Managed by Flow bootstrap. Do not edit between the markers." \
        '[[ -o interactive ]] && [[ -r "$HOME/.config/zsh/.zshrc" ]] && source "$HOME/.config/zsh/.zshrc"' \
        "$FLOW_ZSH_BLOCK_END"
}

# zsh_has_managed_block <file>
zsh_has_managed_block() {
    local file="$1"
    [[ -r "$file" ]] || return 1
    grep -qF "$FLOW_ZSH_BLOCK_BEGIN" "$file" 2>/dev/null && \
        grep -qF "$FLOW_ZSH_BLOCK_END" "$file" 2>/dev/null
}

# zsh_upsert_block <file> <block> — replaces any existing block region, then
# appends the new block. Idempotent: a re-run with identical content converges.
zsh_upsert_block() {
    local file="$1" block="$2" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/flow-zshrc-XXXXXX")"
    awk -v b="$FLOW_ZSH_BLOCK_BEGIN" -v e="$FLOW_ZSH_BLOCK_END" \
        'BEGIN{skip=0} $0==b{skip=1; next} $0==e{skip=0; next} !skip{print}' \
        "$file" >"$tmp"
    printf '\n%s\n' "$block" >>"$tmp"
    mv "$tmp" "$file"
}

# Deploy the Flow bootstrap rc file from the checkout/mirror if the extras
# install has not already put it in place. <repo_root> may be empty. Also
# overlays the zshrc.d fragments when they are missing, so a bare
# `install missing` still ends with a working shell.
zsh_ensure_bootstrap_rc() {
    local repo_root="${1:-}"
    local candidates=("$MIRROR_DIR/dots/.config/zsh/.zshrc" "$SCRIPT_DIR/dots/.config/zsh/.zshrc")
    [[ -n "$repo_root" ]] && candidates+=("$repo_root/dots/.config/zsh/.zshrc")
    local c zshrc_candidate=""
    for c in "${candidates[@]}"; do
        if [[ -f "$c" ]]; then
            zshrc_candidate="$c"
            break
        fi
    done

    # Deploy Flow bootstrap rc (~/.config/zsh/.zshrc). Use conflict resolution
    # if the destination exists (it may be a user's existing config like Oh My Zsh).
    if [[ -n "$zshrc_candidate" ]]; then
        if [[ ! -f "$FLOW_ZSH_BOOTSTRAP" ]]; then
            mkdir -p "$(dirname "$FLOW_ZSH_BOOTSTRAP")"
            cp -f "$zshrc_candidate" "$FLOW_ZSH_BOOTSTRAP"
            ui_verbose "deployed $FLOW_ZSH_BOOTSTRAP"
        else
            # Destination exists — use conflict resolution to avoid silently
            # overwriting a user's existing config (e.g., Oh My Zsh).
            local newfile
            newfile="$(mktemp "${TMPDIR:-/tmp}/flow-zsh-XXXXXX")"
            cp -f "$zshrc_candidate" "$newfile"
            conflict_resolve "$FLOW_ZSH_BOOTSTRAP" "$newfile" "$(tilde "$FLOW_ZSH_BOOTSTRAP")" overwrite
            local action="$CONFLICT_ACTION"
            if [[ "$action" == "remove" ]]; then
                cp -f "$zshrc_candidate" "$newfile"
            fi
            if [[ "$action" == "keep" || "$action" == "skip" ]]; then
                ui_note "Left $(tilde "$FLOW_ZSH_BOOTSTRAP") alone — Flow bootstrap not deployed."
                rm -f "$newfile"
                return 1
            fi
            conflict_apply "$FLOW_ZSH_BOOTSTRAP" "$newfile"
            rm -f "$newfile"
            ui_verbose "deployed $FLOW_ZSH_BOOTSTRAP"
        fi
    fi

    # zshrc.d fragments: overlay only the Flow *.zsh files, never removing or
    # replacing anything a user already keeps there. Deploy new fragments even
    # when zshrc.d is already initialised (the inner check is idempotent).
    local d
    for d in "$repo_root/dots/.config/zshrc.d" "$MIRROR_DIR/dots/.config/zshrc.d" "$SCRIPT_DIR/dots/.config/zshrc.d"; do
        if [[ -d "$d" ]]; then
            mkdir -p "$HOME/.config/zshrc.d"
            local frag
            for frag in "$d"/[0-9]*.zsh; do
                [[ -f "$frag" ]] || continue
                if [[ ! -f "$HOME/.config/zshrc.d/$(basename "$frag")" ]]; then
                    cp -f "$frag" "$HOME/.config/zshrc.d/"
                    ui_verbose "deployed zshrc.d/$(basename "$frag")"
                fi
            done
            break
        fi
    done

    if [[ ! -f "$FLOW_ZSH_BOOTSTRAP" ]]; then
        ui_warn "Flow zsh bootstrap ($(tilde "$FLOW_ZSH_BOOTSTRAP")) not found in the source."
        return 1
    fi
    return 0
}

# zsh_install_managed_block [repo_root] — idempotent ~/.zshrc integration.
# Returns 0 when the Flow block is in place.
zsh_install_managed_block() {
    local repo_root="${1:-}"
    zsh_ensure_bootstrap_rc "$repo_root" || return 1

    local target="$HOME/.zshrc" block
    block="$(zsh_managed_block)"

    # Fresh machine: no rc file at all.
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$HOME"
        printf '%s\n' "$block" >"$target"
        ui_ok "Zsh config" "created $(tilde "$target")"
        return 0
    fi

    # Broken symlink: detect, report, and replace safely.
    if [[ -L "$target" && ! -e "$target" ]]; then
        local broken_target
        broken_target="$(readlink "$target")"
        ui_warn "Found broken symlink $(tilde "$target") -> $broken_target"
        ui_note "Replacing with Flow managed block (backup kept)."
        rm -f "$target"
        mkdir -p "$HOME"
        printf '%s\n' "$block" >"$target"
        ui_ok "Zsh config" "replaced broken symlink with Flow block in $(tilde "$target")"
        return 0
    fi

    # Already integrated: keep it, replace a stale block in place.
    if zsh_has_managed_block "$target"; then
        zsh_upsert_block "$target" "$block"
        ui_verbose "zsh managed block up to date"
        return 0
    fi

    # A real user rc file. Default is to preserve it and append the block;
    # the conflict handler offers keep/remove/skip as explicit alternatives.
    local newfile
    newfile="$(mktemp "${TMPDIR:-/tmp}/flow-zsh-XXXXXX")"
    cp -a "$target" "$newfile"
    printf '\n%s\n' "$block" >>"$newfile"
    conflict_resolve "$target" "$newfile" "$(tilde "$target")" overwrite
    local action="$CONFLICT_ACTION"
    if [[ "$action" == "remove" ]]; then
        printf '%s\n' "$block" >"$newfile"
    fi
    if [[ "$action" == "keep" || "$action" == "skip" ]]; then
        ui_note "Left $(tilde "$target") alone — Flow shell integration not added."
        rm -f "$newfile"
        return 0
    fi
    conflict_apply "$target" "$newfile"
    rm -f "$newfile"
    ui_ok "Zsh config" "Flow block ${action} in $(tilde "$target")"
    return 0
}

zshrc_d_ready() {
    [[ -f "$HOME/.config/zshrc.d/00-environment.zsh" ]]
}

# Status for doctor: configured | not configured | partial
zsh_bootstrap_status() {
    local block=no rc=no frags=no
    zsh_has_managed_block "$HOME/.zshrc" && block=yes
    [[ -r "$FLOW_ZSH_BOOTSTRAP" ]] && rc=yes
    zshrc_d_ready && frags=yes
    if [[ "$rc" == "yes" && "$frags" == "yes" ]]; then
        if [[ "$block" == "yes" ]]; then
            printf 'configured'
        else
            printf 'partial'
        fi
    else
        printf 'not configured'
    fi
}

shell_current() {
    printf '%s' "${SHELL:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)}"
}

shell_is_zsh() {
    case "$(shell_current)" in
        */zsh | zsh) return 0 ;;
        *) return 1 ;;
    esac
}

# shell_default_zsh — explicit opt-in to make Zsh the login shell.
# Never called automatically; only `flow shell default zsh` reaches here.
shell_default_zsh() {
    local zsh_path=""
    have zsh && zsh_path="$(command -v zsh)"
    [[ -n "$zsh_path" ]] || zsh_path="/usr/bin/zsh"
    if [[ ! -x "$zsh_path" ]]; then
        ui_fail "Zsh not installed" "install it first, then re-run this command"
        return 1
    fi

    if shell_is_zsh; then
        ui_ok "Default shell" "already Zsh ($zsh_path)"
        return 0
    fi

    ui_frame_open "Change login shell"
    ui_kv "current" "$(shell_current)"
    ui_kv "wanted" "$zsh_path"
    ui_frame_close

    if ! grep -Fxq "$zsh_path" /etc/shells 2>/dev/null; then
        ui_warn "$zsh_path is not listed in /etc/shells — chsh will refuse it."
        if ui_confirm "Append $zsh_path to /etc/shells (needs sudo)?"; then
            run_logged sudo sh -c "printf '%s\\n' '$zsh_path' >> /etc/shells" || {
                ui_fail "Could not update /etc/shells"
                return 1
            }
            ui_ok "Shells" "added $zsh_path"
        else
            ui_note "Aborted — login shell unchanged."
            return 1
        fi
    fi

    ui_confirm "Set your login shell to Zsh? (chsh -s $zsh_path)" yes || {
        ui_note "Aborted — login shell unchanged."
        return 1
    }

    ui_info "Running chsh — enter your password if prompted."
    if run_logged chsh -s "$zsh_path"; then
        ui_ok "Default shell" "set to Zsh ($zsh_path)"
        ui_note "Log out and back in for it to take effect."
    else
        ui_fail "chsh failed" "login shell unchanged"
        return 1
    fi
    return 0
}

# ── Bootstrap state ───────────────────────────────────────────────────────────
# Minimal metadata only — never secrets, tokens or credentials.
bootstrap_state_write() {
    local tiers="$1" zsh="$2"
    mkdir -p "$SETUP_STATE_DIR"
    {
        printf 'bootstrap_version=1\n'
        printf 'installed_tiers=%s\n' "$tiers"
        printf 'zsh_integration=%s\n' "$zsh"
        printf 'timestamp=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    } >"$FLOW_BOOTSTRAP_STATE"
}

bootstrap_state_get() {
    local key="$1"
    [[ -f "$FLOW_BOOTSTRAP_STATE" ]] || return 1
    grep "^$key=" "$FLOW_BOOTSTRAP_STATE" 2>/dev/null | cut -d= -f2- || true
}