# Flow Zsh Tools
# Initialize installed CLI tools

# zoxide - smarter cd: plain `cd` stays literal (stock builtin); fuzzy
# frecency jumps are deliberate via z / zi (70-zoxide.zsh, --cmd z).

# fzf - fuzzy finder (keybindings loaded in 40-keybindings.zsh)
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#d0d0d0,bg:#1e1e2e,hl:#f38ba8,fg+:#d0d0d0,bg+:#313244,hl+:#f38ba8,info:#cba6f7,prompt:#f38ba8,pointer:#f5e0dc,marker:#f5e0dc,spinner:#f5e0dc,header:#cba6f7'
fi

# eza - modern ls
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --group-directories-first --git'
  alias la='eza -la --icons --group-directories-first --git'
  alias lt='eza --tree --icons --group-directories-first --git-ignore'
  alias lta='eza --tree --icons --group-directories-first -a --git-ignore'
fi

# bat - syntax highlighting cat
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  alias catp='bat'
  export BAT_THEME="${BAT_THEME:-Catppuccin Mocha}"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ripgrep - fast grep
if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
  export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc"
fi

# fd - fast find
if command -v fd >/dev/null 2>&1; then
  alias find='fd'
fi

# lazygit
if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi

# ── DevOps aliases & functions ──────────────────────────────────────────────
# Kubernetes
if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  alias kg='kubectl get'
  alias kgp='kubectl get pods'
  alias kgs='kubectl get svc'
  alias kgd='kubectl get deploy'
  alias kgn='kubectl get nodes'
  alias kd='kubectl describe'
  alias kdp='kubectl describe pod'
  alias kds='kubectl describe svc'
  alias kdd='kubectl describe deploy'
  alias kl='kubectl logs'
  alias klf='kubectl logs -f'
  alias kex='kubectl exec -it'
  alias kctx='kubectx'
  alias kns='kubens'
fi

if command -v k9s >/dev/null 2>&1; then
  alias k9='k9s'
fi

if command -v stern >/dev/null 2>&1; then
  alias stern='stern --all-namespaces'
fi

# Terraform
if command -v terraform >/dev/null 2>&1; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfd='terraform destroy'
  alias tfv='terraform validate'
  alias tff='terraform fmt'
  alias tfo='terraform output'
  alias tfw='terraform workspace'
fi

if command -v terragrunt >/dev/null 2>&1; then
  alias tg='terragrunt'
fi

# Helm
if command -v helm >/dev/null 2>&1; then
  alias h='helm'
  alias hi='helm install'
  alias hu='helm upgrade'
  alias hul='helm upgrade --install'
  alias hd='helm delete'
  alias hl='helm list'
  alias hs='helm search repo'
  alias hr='helm repo'
  alias hru='helm repo update'
  alias ht='helm template'
fi

if command -v helmfile >/dev/null 2>&1; then
  alias hf='helmfile'
  alias hfa='helmfile apply'
  alias hfs='helmfile sync'
  alias hfd='helmfile destroy'
fi

# Docker
if command -v docker >/dev/null 2>&1; then
  alias d='docker'
  alias dc='docker-compose'
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias di='docker images'
  alias dib='docker image build'
  alias drm='docker rm'
  alias drmi='docker rmi'
  alias dlogs='docker logs'
  alias dlogsf='docker logs -f'
  alias dex='docker exec -it'
  alias dprune='docker system prune -af'
fi

# Flux / ArgoCD
if command -v flux >/dev/null 2>&1; then
  alias fl='flux'
  alias flg='flux get'
  alias flr='flux reconcile'
fi

if command -v argocd >/dev/null 2>&1; then
  alias ac='argocd'
  alias acl='argocd app list'
  alias acg='argocd app get'
  alias acs='argocd app sync'
  alias ach='argocd app history'
fi

# Kustomize
if command -v kustomize >/dev/null 2>&1; then
  alias kz='kustomize'
  alias kzb='kustomize build'
fi

# Cloud CLIs
if command -v aws >/dev/null 2>&1; then
  alias awsprofile='export AWS_PROFILE=$(aws configure list-profiles | fzf)'
fi

if command -v gcloud >/dev/null 2>&1; then
  alias gcp='gcloud config configurations activate'
fi

# Talos
if command -v talosctl >/dev/null 2>&1; then
  alias tc='talosctl'
  alias tcg='talosctl get'
  alias tcc='talosctl config'
fi

# Useful functions
# klogs - tail logs from multiple pods matching pattern
klogs() {
  local pattern="${1:-.}"
  local namespace="${2:-$(kubectl config view --minify -o jsonpath='{..namespace}')}"
  kubectl logs -l "$pattern" -n "$namespace" --tail=100 -f --all-containers=true
}

# kshell - get shell in a pod
kshell() {
  local pod="${1}"
  local namespace="${2:-$(kubectl config view --minify -o jsonpath='{..namespace}')}"
  if [[ -z "$pod" ]]; then
    pod=$(kubectl get pods -n "$namespace" --no-headers | fzf --prompt="Pod: " | awk '{print $1}')
  fi
  [[ -n "$pod" ]] && kubectl exec -it "$pod" -n "$namespace" -- /bin/sh
}

# kport - port forward a service
kport() {
  local svc="${1}"
  local namespace="${2:-$(kubectl config view --minify -o jsonpath='{..namespace}')}"
  local port="${3:-8080}"
  if [[ -z "$svc" ]]; then
    svc=$(kubectl get svc -n "$namespace" --no-headers | fzf --prompt="Service: " | awk '{print $1}')
  fi
  [[ -n "$svc" ]] && kubectl port-forward -n "$namespace" "svc/$svc" "$port:$port"
}

# tfswitch - switch terraform version (if tfswitch installed)
if command -v tfswitch >/dev/null 2>&1; then
  alias tfswitch='tfswitch'
fi

# Common aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# Typos (from Fish config)
alias celar='clear'
alias claer='clear'
alias pamcan='pacman'

# Clear screen (kitty-compatible)
alias clear="printf '\033[2J\033[3J\033[1;1H'"

# Flow CLI shortcut
alias q='qs -c flow'