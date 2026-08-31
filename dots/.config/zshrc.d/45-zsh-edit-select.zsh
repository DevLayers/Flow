# 45-zsh-edit-select.zsh — Selection, clipboard, undo/redo via zsh-edit-select
# Replaces the custom 45-flow-editor.zsh with an externally maintained plugin.
# https://github.com/Michael-Matta1/zsh-edit-select
#
# Provides: Shift-select, Ctrl+A/C/X/V, Ctrl+Z/Ctrl+Shift+Z undo/redo,
# mouse-selection integration, OSC52 SSH clipboard support.
#
# One-time setup: run `edit-select config` to generate keybindings,
# then add the Kitty map lines from the plugin's README so Kitty
# forwards Ctrl+Shift sequences to zsh.

# Idempotency guard
(( $+functions[edit-select-init] )) && return 0

# Preferred install location
_es_install_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh-edit-select"

# 1. Try loading from known paths
local -a _es_dirs=(
  "$_es_install_dir"
  "$HOME/.zsh-plugins/zsh-edit-select"
  "/usr/share/zsh-edit-select"
)

local _es_dir=""
for _es_dir in "${_es_dirs[@]}"; do
  if [[ -f "$_es_dir/zsh-edit-select.plugin.zsh" ]]; then
    source "$_es_dir/zsh-edit-select.plugin.zsh"
    # Ensure native bracketed paste is preserved for terminal/application paste
    bindkey -M emacs '^[[200~' bracketed-paste 2>/dev/null || true
    bindkey '^[[200~' bracketed-paste 2>/dev/null || true
    return 0
  fi
done

# 2. Not found — auto-install to preferred path
if command -v git >/dev/null 2>&1; then
  print -P "%F{yellow}zsh-edit-select: not found, cloning...%f" 2>/dev/null
  if git clone --depth=1 https://github.com/Michael-Matta1/zsh-edit-select "$_es_install_dir" 2>/dev/null; then
    source "$_es_install_dir/zsh-edit-select.plugin.zsh"
    print -P "%F{green}zsh-edit-select: installed to $_es_install_dir%f" 2>/dev/null
    return 0
  fi
  print -P "%F{red}zsh-edit-select: clone failed%f" 2>/dev/null
fi

# 3. Git not available or clone failed — skip silently
