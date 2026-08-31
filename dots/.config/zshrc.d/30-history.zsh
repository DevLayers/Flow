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

# Atuin integration (if installed)
if command -v atuin >/dev/null 2>&1; then
  # Initialize Atuin for Zsh
  # --disable-up-arrow: we bind atuin to Down arrow instead of Ctrl+R
  _flow_cached_eval atuin atuin init zsh --disable-up-arrow
  # Bind atuin search to Down arrow (replaces Ctrl+R)
  # Note: This overrides history-substring-search-down on Down arrow
  bindkey "$terminfo[kcud1]" atuin-search
fi