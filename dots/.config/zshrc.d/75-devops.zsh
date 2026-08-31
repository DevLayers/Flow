# 75-devops.zsh — DevOps tool integration and helpers
# Additional devops utilities beyond aliases/abbreviations

# ── krew (kubectl plugin manager) ────────────────────────────────────────────
if command -v kubectl >/dev/null 2>&1 && [[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ]]; then
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
fi

# ── kubecolor (colorized kubectl output) ────────────────────────────────────
if command -v kubecolor >/dev/null 2>&1; then
  alias kubectl='kubecolor'
  # Make completion work with kubecolor
  compdef kubecolor=kubectl
fi

# ── kube-ps1 (k8s context in prompt) — not needed with Starship ─────────────
# Starship already shows k8s context. If you want kube-ps1 instead:
# if command -v kube-ps1 >/dev/null 2>&1; then
#   PROMPT='$(kube_ps1)'$PROMPT
# fi

# ── stern (multi-pod log tailing) ───────────────────────────────────────────
# Already aliased in 50-tools.zsh with --all-namespaces

# ── kubectl-aliases (ahmetb/kubectl-aliases) ────────────────────────────────
# If you want 500+ kubectl aliases, install kubectl-aliases and source:
# [[ -f ~/.kubectl_aliases ]] && source ~/.kubectl_aliases

# ── dive (docker image analyzer) ────────────────────────────────────────────
if command -v dive >/dev/null 2>&1; then
  alias dive='dive'
fi

# ── ctop (container top) ────────────────────────────────────────────────────
if command -v ctop >/dev/null 2>&1; then
  alias ctop='ctop'
fi

# ── lazydocker (docker TUI) ─────────────────────────────────────────────────
if command -v lazydocker >/dev/null 2>&1; then
  alias lzd='lazydocker'
fi

# ── hadolint (Dockerfile linter) ────────────────────────────────────────────
if command -v hadolint >/dev/null 2>&1; then
  alias hadolint='hadolint'
fi

# ── tfsec / checkov (terraform security) ────────────────────────────────────
if command -v tfsec >/dev/null 2>&1; then
  alias tfsec='tfsec'
fi
if command -v checkov >/dev/null 2>&1; then
  alias checkov='checkov'
fi

# ── kics (IaC security) ─────────────────────────────────────────────────────
if command -v kics >/dev/null 2>&1; then
  alias kics='kics scan'
fi

# ── trivy (vulnerability scanner) ───────────────────────────────────────────
if command -v trivy >/dev/null 2>&1; then
  alias trivy='trivy'
fi

# ── helm-docs (helm chart docs generator) ───────────────────────────────────
if command -v helm-docs >/dev/null 2>&1; then
  alias hdocs='helm-docs'
fi

# ── kubeval / kubeconform (k8s manifest validation) ─────────────────────────
if command -v kubeval >/dev/null 2>&1; then
  alias kubeval='kubeval'
fi
if command -v kubeconform >/dev/null 2>&1; then
  alias kubeconform='kubeconform'
fi

# ── yq (YAML processor) ─────────────────────────────────────────────────────
if command -v yq >/dev/null 2>&1; then
  alias yq='yq'
fi

# ── jq (JSON processor) ─────────────────────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  alias jq='jq'
fi

# ── gron (JSON flattener) ───────────────────────────────────────────────────
if command -v gron >/dev/null 2>&1; then
  alias gron='gron'
fi

# ── fzf-kubectl (fzf integration for kubectl) ───────────────────────────────
# Use fzf-tab for completion instead
# If you want fzf-kubectl functions:
# fzf-kubectl() { ... }

# ── Environment switching helpers ───────────────────────────────────────────
# kctx/kns already aliased. For more advanced switching:
# kctxs() { kubectx $(kubectx | fzf) }
# knss() { kubens $(kubens | fzf) }

# ── Cloud provider auth helpers ─────────────────────────────────────────────
# aws-sso() { aws sso login --profile "$1" }
# gcp-auth() { gcloud auth application-default login }

# ── Talos Linux helpers ─────────────────────────────────────────────────────
# tc already aliased to talosctl
# tcgen() { talosctl gen config ... }
# tcapply() { talosctl apply-config ... }

# ── GitOps helpers ──────────────────────────────────────────────────────────
# flux/argocd already aliased
# flux-reconcile-all() { flux get kustomizations --all-namespaces -o name | xargs -I{} flux reconcile {} }

# ── Development container helpers ───────────────────────────────────────────
# devcontainer() { ... }
# distrobox() { ... }