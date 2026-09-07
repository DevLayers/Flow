# Flow Zsh Completion
# Native Zsh completion with caching + zsh-completions + zsh-autocomplete

# Completion directory
local zcompdir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$zcompdir" ]] || mkdir -p "$zcompdir"
local zcompdump="$zcompdir/zcompdump-${ZSH_VERSION}"

# ── zsh-completions: additional completion definitions (load BEFORE compinit) ──
# https://github.com/zsh-users/zsh-completions
fpath=("${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}/zsh-completions/src" $fpath)

# zsh-autocomplete owns completion initialization — it patches compinit and
# runs it from its own precmd hook so that completion definitions registered
# after this fragment are still captured. Calling compinit here would be a
# no-op (the patch makes it a stub). Don't autoload it.

# Completion styles
zstyle ':completion:*' cache-path "$zcompdir"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' rehash true
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format '%F{blue}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'
zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'

# Kill completion
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*:processes' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# SSH/SCP/RSYNC completion
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(ssh|scp|rsync):*' group-order users hosts-host hosts-domain hosts-ipaddr

# Git completion (uses git's own completion if available)
if command -v git >/dev/null 2>&1; then
  zstyle ':completion:*:*:git:*' script ~/.local/share/zsh/git-completion.bash 2>/dev/null || true
fi

# Docker completion
if command -v docker >/dev/null 2>&1; then
  fpath=("${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions" $fpath)
fi

# Cache generated completion scripts to avoid subshell execution on every startup
_flow_source_cached_completion() {
  local cmd="$1" cache_file="$2"
  shift 2
  if command -v "$cmd" >/dev/null 2>&1; then
    local bin_path
    bin_path="$(command -v "$cmd")"
    if [[ ! -f "$cache_file" || "$cache_file" -ot "$bin_path" ]]; then
      "$@" > "$cache_file" 2>/dev/null || rm -f "$cache_file"
    fi
    [[ -f "$cache_file" ]] && source "$cache_file" 2>/dev/null || true
  fi
}

_flow_comp_cache_dir="${zcompdir}/completions"
[[ -d "$_flow_comp_cache_dir" ]] || mkdir -p "$_flow_comp_cache_dir"

# ── Defer all completion caches (first-prompt, not startup) ──────────────────
# Each of the calls below runs `command` to check the binary exists, then
# sources the generated zsh script. Forking 20 subshells synchronously adds
# ~80–150 ms of cold-start cost. With zsh-defer, the entire block runs once
# Zsh is idle, after the first prompt is drawn. Completions work for normal
# commands on first tab-press; the deferred tool-specific completions appear
# shortly after. This is the single biggest startup-time win available.
_flow_defer_completion_caches() {
  setopt local_options no_glob no_ksh_arrays 2>/dev/null
  _flow_source_cached_completion kubectl "$_flow_comp_cache_dir/kubectl.zsh" kubectl completion zsh
  _flow_source_cached_completion helm "$_flow_comp_cache_dir/helm.zsh" helm completion zsh
  _flow_source_cached_completion gh "$_flow_comp_cache_dir/gh.zsh" gh completion -s zsh
  _flow_source_cached_completion mise "$_flow_comp_cache_dir/mise.zsh" mise completion zsh
  _flow_source_cached_completion docker "$_flow_comp_cache_dir/docker.zsh" docker completion zsh
  _flow_source_cached_completion docker-compose "$_flow_comp_cache_dir/docker-compose.zsh" docker-compose completion zsh
  _flow_source_cached_completion terraform "$_flow_comp_cache_dir/terraform.zsh" terraform -install-autocomplete 2>/dev/null || terraform completion zsh 2>/dev/null
  _flow_source_cached_completion kubectx "$_flow_comp_cache_dir/kubectx.zsh" kubectx completion zsh 2>/dev/null
  _flow_source_cached_completion kubens "$_flow_comp_cache_dir/kubens.zsh" kubens completion zsh 2>/dev/null
  _flow_source_cached_completion k9s "$_flow_comp_cache_dir/k9s.zsh" k9s completion zsh 2>/dev/null
  _flow_source_cached_completion stern "$_flow_comp_cache_dir/stern.zsh" stern completion zsh 2>/dev/null
  _flow_source_cached_completion flux "$_flow_comp_cache_dir/flux.zsh" flux completion zsh 2>/dev/null
  _flow_source_cached_completion argocd "$_flow_comp_cache_dir/argocd.zsh" argocd completion zsh 2>/dev/null
  _flow_source_cached_completion kustomize "$_flow_comp_cache_dir/kustomize.zsh" kustomize completion zsh 2>/dev/null
  _flow_source_cached_completion helmfile "$_flow_comp_cache_dir/helmfile.zsh" helmfile completion zsh 2>/dev/null
  _flow_source_cached_completion aws "$_flow_comp_cache_dir/aws.zsh" aws_completer 2>/dev/null
  _flow_source_cached_completion gcloud "$_flow_comp_cache_dir/gcloud.zsh" gcloud completion zsh 2>/dev/null
  _flow_source_cached_completion az "$_flow_comp_cache_dir/az.zsh" az completion zsh 2>/dev/null
  _flow_source_cached_completion talosctl "$_flow_comp_cache_dir/talosctl.zsh" talosctl completion zsh 2>/dev/null
}
if (( $+functions[zsh-defer] )); then
  zsh-defer _flow_defer_completion_caches
else
  # zsh-defer not loaded yet (fragment order raced); call immediately
  _flow_defer_completion_caches
fi
unfunction _flow_defer_completion_caches

# Rebuild completion cache only if the zshrc has changed since the last dump.
# ZDOTDIR is exported early in 00-environment.zsh so this resolves correctly.
# (zsh-autocomplete runs compinit itself in its precmd hook.)

# ── zsh-autocomplete: live completion + history panels ─────────────────────
# https://github.com/marlonrichert/zsh-autocomplete
# Loaded via plugin-load in 06-plugins.zsh before the first prompt. The plugin
# installs its widgets in its precmd hook and owns:
#   Tab  → cycle top completion (no panel; inserts on single match, otherwise
#          opens the live panel)
#   ↓    → .autocomplete__down-line-or-select__zle-widget
#          (live multi-row completion panel beneath the prompt, refined on
#           every keystroke, sourced from compctl + Atuin history)
#   ↑    → .autocomplete__up-line-or-search__zle-widget
#          (typed: substring/multi-word history search against Atuin-backed
#           $HISTFILE; empty: cursor up / walk history)
#   Alt-↓ / Alt-↑  → force-enter the menus regardless of state
#   Ctrl-X, /      → recent-path completion
# fzf-tab is no longer in the plugin stack; zsh-autocomplete subsumes the
# picker role. fzf's own widgets (Ctrl-T, Alt-C, Ctrl-R history) are still
# loaded by 40-keybindings.zsh.
