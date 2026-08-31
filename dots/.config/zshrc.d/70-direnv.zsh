# Flow Zsh Direnv
# Environment switcher for project-local env

if command -v direnv >/dev/null 2>&1; then
  # Load direnv hook for Zsh
  _flow_cached_eval direnv direnv hook zsh
  
  # Direnv configuration
  export DIRENV_WARN_TIMEOUT=5s
  
  # Useful aliases
  alias de='direnv edit'
  alias da='direnv allow'
  alias dr='direnv revoke'
  alias ds='direnv status'
  alias dt='direnv dump'
  
  # Auto-allow for known safe directories (opt-in via config)
  # direnv allow is still required per-project by default for safety
fi