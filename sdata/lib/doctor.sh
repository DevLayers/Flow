# Flow bootstrap — read-only doctor report.
#
# Sourced by setup-flow.sh. Reports the workstation state from the dependency
# registry and the shell-integration status. Never modifies anything; repair is
# the installer's job (`flow install missing`).

font_nerd_detect() {
    have fc-list || return 1
    local fam
    fam="$(fc-list 2>/dev/null | grep -i 'nerd font' | head -n1)"
    [[ -n "$fam" ]] || return 1
    fam="${fam#*: }"
    printf '%s' "${fam%%:*}"
}

font_jetbrains_nerd() {
    have fc-list || return 1
    fc-list 2>/dev/null | grep -qiE 'jetbrains[ -]?mono.*nerd font'
}

# doctor_section <title> <tier> — one row per dependency.
doctor_section() {
    local title="$1" tier="$2" k v state bin
    ui_frame_open "$title"
    while IFS= read -r k; do
        [[ -z "$k" ]] && continue
        if deps_installed "$k"; then
            # Font and library entries have no executable to version — the
            # family match / package ownership is the whole report.
            bin="$(deps_bin "$k")"
            if [[ "$bin" == fc:* || "$bin" == pkg:* ]]; then
                v=""
            else
                v="$(tool_version "$bin" 2>/dev/null)"
            fi
            ui_kv "$k" "installed ${v:+· $v}"
        else
            ui_kv "$k" "missing"
        fi
    done < <(deps_by_tier "$tier")
    ui_frame_close
}

doctor_report() {
    ui_frame_open "Shell"
    if have zsh; then
        ui_kv "zsh" "installed · $(tool_version zsh 2>/dev/null)"
    else
        ui_kv "zsh" "missing"
    fi
    ui_kv "default shell" "$(shell_current 2>/dev/null || printf 'unknown')"
    ui_kv "flow integration" "$(zsh_bootstrap_status)"
    ui_frame_close

    doctor_section "Core" core
    doctor_section "UX (recommended)" ux
    doctor_section "Shell runtime" shell
    doctor_section "Fonts" fonts

    ui_frame_open "Terminal"
    if have kitty; then
        ui_kv "kitty" "installed"
    else
        ui_kv "kitty" "not installed"
    fi
    local nerd
    if nerd="$(font_nerd_detect)"; then
        ui_kv "nerd font" "$nerd"
        font_jetbrains_nerd && ui_kv "jetbrains mono" "present" || ui_kv "jetbrains mono" "missing"
    else
        ui_kv "nerd font" "missing"
        ui_kv "jetbrains mono" "missing"
    fi
    if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
        local fam
        fam="$(grep -E '^font_family' "$HOME/.config/kitty/kitty.conf" 2>/dev/null | head -n1 | sed 's/^font_family\s*//')"
        [[ -n "$fam" ]] && ui_kv "kitty font" "$fam"
        if [[ "$fam" == *"Nerd"* ]] && ! font_nerd_detect >/dev/null; then
            ui_kv "kitty font status" "configured font not installed"
        fi
    fi
    ui_frame_close

    ui_frame_open "Flow"
    ui_kv "cli" "$([[ -L "$BIN_DIR/$CLI_NAME" ]] && tilde "$BIN_DIR/$CLI_NAME" || printf 'not linked')"
    ui_kv "config" "$([[ -d "$TARGET_DIR" ]] && tilde "$TARGET_DIR" || printf 'missing')"
    ui_kv "starship config" "$([[ -f "$HOME/.config/starship.toml" ]] && tilde "$HOME/.config/starship.toml" || printf 'missing')"
    ui_kv "starship palette" "$([[ -f "$XDG_STATE_HOME/quickshell/user/generated/terminal/starship.toml" ]] && tilde "$XDG_STATE_HOME/quickshell/user/generated/terminal/starship.toml" || printf 'not generated')"
    ui_kv "bootstrap" "${FLOW_BOOTSTRAP_STATE:+$(bootstrap_state_get installed_tiers 2>/dev/null || printf 'never run')}"
    ui_frame_close

    doctor_section "DevOps" devops
}