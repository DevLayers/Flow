# 75-flow-project.zsh — Project Context wiring (Phase: skeleton)
#
# Connects the pieces that already exist: on every project-root CHANGE, run
# the read-only detector once (cached, bounded), and — until a profile is
# selected for that root — print ONE quiet hint line. Never runs on plain
# prompt redraws, never blocks longer than the timeout, never auto-activates
# anything (activation stays an explicit `flow project profile use`).

autoload -Uz add-zsh-hook
(( $+commands[sha256sum] )) || return 0

typeset -g FLOW_PROJ_LAST_ROOT=""
typeset -gA FLOW_PROJ_HINTED
zmodload zsh/datetime 2>/dev/null

# --- resolve helpers (mirror dir wins, repo checkout as fallback) ----------
typeset _fp_detect=""
for _d in "${FLOW_BASE_DIR:-}" "$HOME/.local/share/flow" "$HOME/Programming/ArchTide"; do
  [[ -n "$_d" && -f "$_d/sdata/subcmd-project/detect.sh" ]] && {
    _fp_detect="$_d/sdata/subcmd-project/detect.sh"; break; }
done
unset _d

# A project is a git repository. Non-git dirs (including $HOME and any
# directory init scripts transiently cd through) are never projects.
_flow_proj_root() {
  command git rev-parse --show-toplevel 2>/dev/null || true
}

_flow_proj_hash() { printf '%s' "$1" | sha256sum | cut -c1-16; }

_flow_proj_cache_file() {
  local d="${XDG_STATE_HOME:-$HOME/.local/state}/flow/project-cache"
  mkdir -p "$d" 2>/dev/null
  print -r -- "$d/$(_flow_proj_hash "$1").json"
}

_flow_proj_on_root_change() {
  local root
  root="$(_flow_proj_root)"
  [[ "$root" == "$FLOW_PROJ_LAST_ROOT" ]] && return 0
  # $HOME itself and Flow's own plumbing dirs are never "projects"
  case "$root" in
    "$HOME"|"$HOME"/.local/share/flow/*|"$HOME"/.local/state/flow/*|"$HOME"/.cache/flow/*)
      FLOW_PROJ_LAST_ROOT="$root"; return 0 ;;
  esac
  FLOW_PROJ_LAST_ROOT="$root"

  [[ -n "$_fp_detect" ]] || return 0

  local cache
  cache="$(_flow_proj_cache_file "$root")"

  # refresh cache at most every 6h per root
  local mtime=0
  (( $+commands[stat] )) && mtime=$(stat -Lc %Y "$cache" 2>/dev/null || print 0)
  if (( ! $+EPOCHSECONDS )) || (( mtime < EPOCHSECONDS - 21600 )); then
    command timeout 3 bash "$_fp_detect" --json >| "$cache" 2>/dev/null \
      || { rm -f "$cache"; return 0; }
  fi
  [[ -s "$cache" ]] || return 0

  # one-time hint until a profile exists for this root
  (( ${+FLOW_PROJ_HINTED[$root]} )) && return 0
  FLOW_PROJ_HINTED[$root]=1

  local state_file
  state_file="${XDG_STATE_HOME:-$HOME/.local/state}/flow/projects/$(_flow_proj_hash "$root").json"
  [[ -s "$state_file" ]] && return 0   # profile already chosen: stay quiet

  local hinted="${cache:r}.hinted"
  [[ -e "$hinted" ]] && return 0       # already nagged once, ever
  : >| "$hinted"

  local caps name
  caps="$(command jq -r '
    [ (select(.repository.type == "git") | "git"),
      (.languages[]?   | .name),
      (.frameworks[]?  | .name),
      (.containers[]?  | .name),
      (.infrastructure[]? | .name),
      (.ci_cd[]?       | .name) ] | unique | join(" ")
  ' "$cache" 2>/dev/null)"
  name="$(command jq -r '.name // "project"' "$cache" 2>/dev/null)"
  # Styled to match the Starship grammar: bold identity, muted detail,
  # '·' separators, tool icon — colors resolve through the terminal palette.
  local R=$'\e[0m' B=$'\e[1m' D=$'\e[2m' M=$'\e[90m' ID=$'\e[97m'
  print -u2 -- "  ${M}󰣀${R} ${B}${ID}${name}${R} ${M}·${R} ${caps:-no markers} ${M}· no profile yet —${R} ${D}flow project profile create${R}"
}
add-zsh-hook chpwd _flow_proj_on_root_change

# first detection rides the first prompt instead of shell startup
_flow_proj_boot() {
  add-zsh-hook -d precmd _flow_proj_boot
  _flow_proj_on_root_change
}
add-zsh-hook precmd _flow_proj_boot
