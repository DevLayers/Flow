# 55-autosuggestions.zsh — Fish-like autosuggestions config (loaded via plugin-load)
# https://github.com/zsh-users/zsh-autosuggestions

# Style
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Keybindings (after plugin loads via 06-plugins.zsh)
# → / End = accept suggestion
# Ctrl+Right = partial accept (forward-word)
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word