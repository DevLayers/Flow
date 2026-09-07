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
# Both ↑ and ↓ are owned by zsh-autocomplete (loaded via plugin-load in
# 06-plugins.zsh). Do NOT bind them here:
#   ↑   → .autocomplete__up-line-or-search__zle-widget
#         empty buffer: cursor up / start of history
#         typed buffer: history-search matching current $LBUFFER (substring,
#         multi-word, Atuin-backed since zsh-autocomplete reads $HISTFILE which
#         atuin's preexec hook writes to).
#   ↓   → .autocomplete__down-line-or-select__zle-widget
#         empty buffer: cursor down
#         typed buffer: opens the multi-row live completion panel beneath the
#         prompt, populated from Atuin history + compctl completions, refined
#         on every keystroke.
#
# Atuin's own widgets stay bound:
#   Ctrl-R → atuin-search (full-screen TUI history)
# Atuin's --disable-up-arrow (set above) keeps it from competing for ↑.