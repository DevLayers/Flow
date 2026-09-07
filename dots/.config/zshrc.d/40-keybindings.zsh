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
    source "$fzf_shell/key-bindings.zsh"
  else
    print -P "%F{yellow}fzf key-bindings.zsh not found in any known location — arrow-down history widget will not work%f" 2>/dev/null
  fi
  unset fzf_shell
fi

# ── Final arrow-key assignment (last write wins) ─────────────────────────────
# zsh-autocomplete (loaded via plugin-load) owns both arrows. We intentionally
# do NOT bind ^[[A/^[[B here — letting autocomplete's smart widgets stand:
#   ↑ → .autocomplete__up-line-or-search__zle-widget (history search when typed,
#                                                cursor-up when empty)
#   ↓ → .autocomplete__down-line-or-select__zle-widget (live completion panel
#                                                      when typed, cursor-down
#                                                      when empty)
# Atuin's --disable-up-arrow keeps it from racing for ↑.
# Ctrl-T and Alt-C remain on fzf file/cd widgets (set up by fzf's
# key-bindings.zsh above).