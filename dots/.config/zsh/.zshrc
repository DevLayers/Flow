# Flow Zsh Bootstrap
# Loads modular fragments from $ZDOTDIR/../zshrc.d/*.zsh in deterministic order

# Only run for interactive shells
[[ -o interactive ]] || return

# Prevent double-loading within the same shell instance (do not export)
if (( ${+FLOW_ZSH_LOADED} )); then
  return
fi
typeset FLOW_ZSH_LOADED=1

# Determine Flow config root (directory containing this .zshrc)
export FLOW_CONFIG_ROOT="${${(%):-%x}:A:h:h}"

# Load fragments in lexical order
local fragment
for fragment in "$FLOW_CONFIG_ROOT/zshrc.d"/[0-9]*.zsh(.N); do
  [[ -r "$fragment" ]] && source "$fragment"
done
unset fragment

# Ensure Starship is initialized last (after all fragments)
if command -v starship >/dev/null 2>&1; then
  _flow_cached_eval starship starship init zsh
fi