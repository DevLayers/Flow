# Flow Zsh Completion
# Native Zsh completion with caching + zsh-completions + fzf-tab

# Completion directory
local zcompdir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$zcompdir" ]] || mkdir -p "$zcompdir"
local zcompdump="$zcompdir/zcompdump-${ZSH_VERSION}"

# ── zsh-completions: additional completion definitions (load BEFORE compinit) ──
# https://github.com/zsh-users/zsh-completions
fpath=("${ZPLUGINDIR:-${ZDOTDIR:-$HOME/.config/zsh}/plugins}/zsh-completions/src" $fpath)

# Load completion system — ONE call below (daily-rebuild block).
autoload -Uz compinit

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

# Rebuild completion cache once per day
if [[ ! -f "$zcompdump" ]] || [[ "$zcompdump" -ot "${ZDOTDIR:-$HOME}/.zshrc" ]]; then
  compinit -d "$zcompdump"
else
  compinit -C -d "$zcompdump"
fi

# ── fzf-tab: fuzzy completion picker (load AFTER compinit via plugin-load) ────
# https://github.com/Aloxaf/fzf-tab
# Configured via plugin-load in 05-plugin-manager.zsh
# Styles applied here after plugin loads
if (( $+functions[-ftb-complete] )); then
  zstyle ':completion:*' menu no
  zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
  zstyle ':fzf-tab:complete:ssh:*' fzf-preview 'echo {}'
  zstyle ':fzf-tab:complete:git-checkout:*' sort false
fi