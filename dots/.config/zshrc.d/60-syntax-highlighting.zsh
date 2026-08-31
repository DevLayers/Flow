# 60-syntax-highlighting.zsh — Fast syntax highlighting (load LAST, 1.7k★)
# https://github.com/zdharma-continuum/fast-syntax-highlighting
# Replaces zsh-users/zsh-syntax-highlighting (23k★) — 2-10x faster, Chroma themes, git-aware

# Idempotency guard
(( $+functions[_fast_highlight] )) && return 0

# ── Flow Material token styles ──────────────────────────────────────────────
# Semantic mapping; ANSI color names resolve through the terminal palette
# remap (sequences.txt), so hues follow the wallpaper like Starship/Kitty.
_flow_apply_fsh_styles() {
  typeset -gA FAST_HIGHLIGHT_STYLES
  # primary (runnable things)
  FAST_HIGHLIGHT_STYLES[command]='fg=cyan,bold'
  FAST_HIGHLIGHT_STYLES[alias]='fg=cyan'
  FAST_HIGHLIGHT_STYLES[builtin]='fg=cyan'
  FAST_HIGHLIGHT_STYLES[function]='fg=cyan'
  FAST_HIGHLIGHT_STYLES[arg0]='fg=cyan,bold'
  # error / risk
  FAST_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
  # secondary (structure)
  FAST_HIGHLIGHT_STYLES[reserved-word]='fg=magenta,bold'
  FAST_HIGHLIGHT_STYLES[history-expansion]='fg=magenta,bold'
  # strings
  FAST_HIGHLIGHT_STYLES[single-quoted-argument]='fg=green'
  FAST_HIGHLIGHT_STYLES[double-quoted-argument]='fg=green'
  FAST_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=green'
  FAST_HIGHLIGHT_STYLES[backslash-escape]='fg=magenta'
  # paths & patterns
  FAST_HIGHLIGHT_STYLES[path]='underline'
  FAST_HIGHLIGHT_STYLES[globbing]='fg=yellow,bold'
  # options stay quiet
  FAST_HIGHLIGHT_STYLES[single-hyphen-option]='none'
  FAST_HIGHLIGHT_STYLES[double-hyphen-option]='none'
  FAST_HIGHLIGHT_STYLES[comment]='fg=8'
}

# Load via plugin-load (defined in 05-plugin-manager.zsh)
# Plugin repo: zdharma-continuum/fast-syntax-highlighting
# Styles applied after plugin loads
if (( $+functions[_fast_highlight] )); then
  _flow_apply_fsh_styles
fi