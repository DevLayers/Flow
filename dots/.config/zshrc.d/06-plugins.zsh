# 06-plugins.zsh — Load all plugins via zsh_unplugged (plugin-load)
# Must run AFTER 05-plugin-manager.zsh defines plugin-load

# Plugin load order matters:
# 1. zsh-completions (fpath) — loaded in 20-completion.zsh BEFORE compinit
# 2. zsh-autocomplete — live completion/history panels and arrow behavior
# 3. zsh-autosuggestions — inline suggestion source for autocomplete
# 4. zsh-autopair
# 5. zsh-you-should-use
# 6. fast-syntax-highlighting (MUST BE LAST)

# Load all plugins
plugin-load \
  romkatv/zsh-defer \
  marlonrichert/zsh-autocomplete \
  zsh-users/zsh-autosuggestions \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use \
  zdharma-continuum/fast-syntax-highlighting

# fzf-tab remains available for the explicit Ctrl-T/default keybindings; the
# live down-arrow completion panel is owned by zsh-autocomplete.
# zsh-completions fpath is added in 20-completion.zsh before compinit
# zsh-history-substring-search remains dropped; zsh-autocomplete provides the
# typed-history behavior and the completion panel.