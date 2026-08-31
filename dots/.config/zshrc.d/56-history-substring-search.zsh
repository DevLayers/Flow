# 56-history-substring-search.zsh — Fish-like history search config (loaded via plugin-load)
# https://github.com/zsh-users/zsh-history-substring-search

# Config
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=white,bold,bg=magenta"
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=white,bold,bg=red"
export HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
export HISTORY_SUBSTRING_SEARCH_FUZZY=1

# Keybindings (after plugin loads via 06-plugins.zsh)
# Up arrow = history substring search (Atuin uses Down arrow)
bindkey "$terminfo[kcuu1]" history-substring-search-up   # Up
# Down arrow is bound to atuin-search in 30-history.zsh
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down