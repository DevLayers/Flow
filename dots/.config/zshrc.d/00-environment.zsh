# Flow Zsh Environment
# Basic environment variables and early initialization

# Language and locale
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Editor
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"
export SUDO_EDITOR="${SUDO_EDITOR:-nvim}"

# Pager
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R -F -X}"

# Path additions (user-local bins)
typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$path[@]"
)
export PATH

# XDG Base Directory
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Flow-specific
export FLOW_CONFIG_ROOT="${FLOW_CONFIG_ROOT:-$XDG_CONFIG_HOME}"
export FLOW_STATE_DIR="${FLOW_STATE_DIR:-$XDG_STATE_HOME/quickshell/user/generated/terminal}"

# Auto-start Hyprland on tty1 (must run early)
if [[ -z "$DISPLAY" && "$XDG_VTNR" -eq 1 ]]; then
  mkdir -p "$HOME/.cache"
  exec start-hyprland > "$HOME/.cache/hyprland.log" 2>&1
fi

# ── _flow_cached_eval <id> <cmd…> ────────────────────────────────────────────
# Tool init scripts (atuin/mise/starship/direnv/zoxide) each cost ~8-12ms in
# subprocess forks on every startup. Cache their output; regenerate weekly or
# when the shell config changes. Identical behavior, fraction of the cost.
_flow_cached_eval() {
  local id="$1"; shift
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init"
  mkdir -p "$dir" 2>/dev/null
  local f="$dir/$id.zsh"
  local stale=0
  if [[ ! -s "$f" ]]; then stale=1
  else
    local age=0
    age=$(stat -Lc %Y "$f" 2>/dev/null || print 0)
    (( EPOCHSECONDS - age > 604800 )) && stale=1
    [[ "$f" -ot "${ZDOTDIR:-$HOME}/.zshrc" ]] && stale=1
  fi
  (( stale )) && { "$@" >| "$f.$$" 2>/dev/null && mv -f "$f.$$" "$f"; }
  [[ -s "$f" ]] && source "$f"
}
(( $+EPOCHSECONDS )) || zmodload zsh/datetime 2>/dev/null
