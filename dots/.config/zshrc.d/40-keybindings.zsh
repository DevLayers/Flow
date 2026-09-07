# Flow Zsh Keybindings
# Line editing and history navigation

# Use emacs keybindings (standard)
bindkey -e

# History search (Ctrl+R/S for incremental, Up/Down handled by zsh-history-substring-search)
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Beginning/end of line
# Ctrl+A: select-all (handled by zsh-edit-select)
bindkey '^E' end-of-line

# Word movement
# NOTE: Ctrl+→ (^[[1;5C) and Ctrl+← (^[[1;5D) are bound to autosuggest-accept-word
# and backward-word in 55-autosuggestions.zsh. They run after this fragment, so
# their bindings win. We do NOT re-bind them here.
bindkey '^[[H' beginning-of-line    # Home
bindkey '^[[F' end-of-line          # End
bindkey '^[b' backward-word         # Alt+Left / Esc+b
bindkey '^[f' forward-word          # Alt+Right / Esc+f

# Delete word
bindkey '^W' backward-kill-word     # Ctrl+W
bindkey '^[[3;5~' kill-word         # Ctrl+Delete
bindkey '^H' backward-kill-word     # Ctrl+Backspace (from existing shortcuts.zsh)
bindkey '^[[3~' delete-char         # Delete

# Undo — handled by zsh-edit-select (Ctrl+Z / Ctrl+Shift+Z)

# Clear screen
bindkey '^L' clear-screen

# Edit command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line    # Ctrl+X Ctrl+E

# FZF integration (if available)
if command -v fzf >/dev/null 2>&1; then
  # Load fzf keybindings. Sourced LAST so fzf-history-widget is registered
  # before we re-assert the arrow-key bindings below. We do NOT source
  # fzf's completion.zsh — fzf-tab is our completion picker.
  #
  # Search order matches where fzf is typically installed:
  #   1. $XDG_DATA_HOME/fzf    (Arch: pacman + fzf ships here, or user install)
  #   2. /usr/share/fzf        (Debian/Ubuntu: apt install fzf)
  #   3. /opt/homebrew/opt/fzf/share/fzf  (macOS Homebrew)
  #   4. $(brew --prefix)/share/fzf       (Linux Homebrew, optional)
  local fzf_shell=""
  for fzf_shell in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/fzf" \
    "/usr/share/fzf" \
    "/opt/homebrew/opt/fzf/share/fzf" \
    "/usr/local/share/fzf" \
    "/usr/local/opt/fzf/shell"; do
    [[ -f "$fzf_shell/key-bindings.zsh" ]] && break || fzf_shell=""
  done
  if [[ -n "$fzf_shell" ]]; then
    # fzf's key-bindings.zsh saves and restores shell options around its
    # widget definitions. Newer zsh refuses `setopt zle` and fzf's
    # restore uses `eval $__fzf_key_bindings_options` whose value is
    # `options=( ... zle on ... )`. We stub `eval` so that an
    # `options=(...)` array assignment rebuilds `$options` and then
    # suppresses just the `zle` token before zsh parses it.
    eval() {
      local cmd="$*"
      if [[ "$cmd" == 'options=('* ]]; then
        # Drop `zle on` / `zle off` token pairs from the captured options
        # string. `zle` is implicit in interactive shells.
        cmd=${cmd// zle on / }
        cmd=${cmd// zle off / }
      fi
      builtin eval "$cmd"
    }
    source "$fzf_shell/key-bindings.zsh"
    unfunction eval
  else
    print -P "%F{yellow}fzf key-bindings.zsh not found in any known location — arrow-down history widget will not work%f" 2>/dev/null
  fi
  unset fzf_shell
fi

# ── Final arrow-key assignment (after zsh-autocomplete's precmd) ───────────────
# zsh-autocomplete creates its arrow widgets from a precmd hook, after this
# fragment has already loaded. Rebind the first prompt once, after that hook
# has registered `up-line-or-search` and `down-line-or-select`.
_flow_rebind_autocomplete_arrows() {
  add-zsh-hook -d precmd _flow_rebind_autocomplete_arrows
  if (( ${+widgets[up-line-or-search]} &&
        ${+widgets[down-line-or-select]} )); then
    bindkey -M main   '^[[A' up-line-or-search
    bindkey -M main   '^[[B' down-line-or-select
    bindkey -M emacs  '^[[A' up-line-or-search
    bindkey -M emacs  '^[[B' down-line-or-select
    bindkey -M viins  '^[[A' up-line-or-search
    bindkey -M viins  '^[[B' down-line-or-select
  fi
}
add-zsh-hook precmd _flow_rebind_autocomplete_arrows

# Atuin's --disable-up-arrow keeps it from racing for ↑. Ctrl-T and Alt-C remain
# on fzf file/cd widgets set up by key-bindings.zsh above.