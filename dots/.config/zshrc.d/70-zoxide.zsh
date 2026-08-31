# 70-zoxide.zsh — Smart cd with frecency (38k★)
# https://github.com/ajeetdsouza/zoxide

# zoxide is a binary, install via package manager:
#   pacman -S zoxide    # Arch
#   brew install zoxide # macOS
#   apt install zoxide  # Debian/Ubuntu
#   cargo install zoxide --locked

if command -v zoxide >/dev/null 2>&1; then
  # Explicit --cmd z: define only z / zi. Plain `cd` stays literal stock
# semantics; fuzzy frecency jumps are deliberate via `z <fragment>`.
_flow_cached_eval zoxide zoxide init zsh --cmd z

# Flow z: exact-name beats frecency.
#   z <name>        1) an existing path as typed      -> stock cd
#                   2) ~/<name> or ~/Projects/<name>  -> exact dir
#                   3) otherwise                      -> zoxide fuzzy
#   zi <query>      interactive zoxide picker (unchanged)
z() {
  local q="$*"
  [[ -n "$q" ]] || { builtin cd ~ && return 0; }
  if [[ -d "$q" ]]; then builtin cd "$q" && return 0; fi
  local root cand
  for root in "$HOME" "$HOME/Programming"; do
    cand="$root/$q"
    if [[ -d "$cand" ]]; then builtin cd "$cand" && return 0; fi
  done
  local dest
  dest="$(command zoxide query -- "$q" 2>/dev/null)" || return 1
  [[ -n "$dest" ]] && builtin cd "$dest"
}
  # Import from atuin: zoxide import atuin
else
  # Silently skip if not installed
  # To install: run your package manager command above
fi