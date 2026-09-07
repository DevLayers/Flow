# Flow Zsh History
# Persistent history with Atuin integration when available

# History file
local histdir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
[[ -d "$histdir" ]] || mkdir -p "$histdir"
export HISTFILE="$histdir/history"
export HISTSIZE=50000
export SAVEHIST=50000

# ── Critical history options ──────────────────────────────────────────────
# Write each command to $HISTFILE IMMEDIATELY after execution.
# Without this, commands only save on shell exit → the engine never sees
# them until you close the tab.
setopt INC_APPEND_HISTORY

# Share history across ALL open terminal windows in real time.
setopt SHARE_HISTORY

# Never record duplicates (keeps history clean for suggestions).
setopt HIST_IGNORE_ALL_DUPS

# Strip leading/trailing whitespace before saving.
setopt HIST_REDUCE_BLANKS

# Commands starting with a space are NOT recorded (for secrets/one-offs).
setopt HIST_IGNORE_SPACE

# Atuin integration (deferred; runs on first prompt, not at startup)
if command -v atuin >/dev/null 2>&1; then
  if (( $+functions[zsh-defer] )); then
    zsh-defer _flow_cached_eval atuin atuin init zsh --disable-up-arrow
  else
    _flow_cached_eval atuin atuin init zsh --disable-up-arrow
  fi
fi

# ── Arrow-key strategy ──────────────────────────────────────────────────────
# ↑   → atuin-up-search    (frecency-sorted inline match; re-press for next)
# ↓   → fzf-history-widget (multi-line fuzzy panel, --query=$LBUFFER)
# Both bindkeys use literal ^[A / ^[B so they work regardless of when
# zsh/terminfo was loaded. Atuin's --disable-up-arrow keeps it from trying
# to also bind ↑; fzf-history-widget is registered when its key-bindings.zsh
# is sourced in 40-keybindings.zsh (last fragment, last write wins).
#
# Atuin's `atuin-up-search` widget is registered by `atuin init zsh`, but
# that runs under zsh-defer — possibly AFTER this fragment. We bind anyway
# (bindkey to a non-existent widget is a silent no-op); 40-keybindings.zsh
# re-asserts both bindings at the very end so whichever init finished last
# wins.
bindkey '^[[A' atuin-up-search   # Up arrow
bindkey '^[[B' fzf-history-widget # Down arrow