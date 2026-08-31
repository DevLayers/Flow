# Flow Zsh Mise
# Runtime version manager

if command -v mise >/dev/null 2>&1; then
  # Activate mise for Zsh
  _flow_cached_eval mise mise activate zsh
  
  # Trust mise shims directory
  export MISE_TRUSTED_CONFIG_PATHS="${MISE_TRUSTED_CONFIG_PATHS:-$HOME/.config/mise}"
  
  # Useful aliases
  alias mi='mise install'
  alias mu='mise use'
  alias ml='mise list'
  alias mc='mise current'
  alias mr='mise run'
  alias mt='mise exec --'
fi