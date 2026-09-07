# 06-plugins.zsh — Load all plugins via zsh_unplugged (plugin-load)
# Must run AFTER 05-plugin-manager.zsh defines plugin-load

# Plugin load order matters:
# 1. zsh-autocomplete — live completion/history panels and arrow behavior
# 2. zsh-autosuggestions — inline suggestion source for autocomplete
# 3. zsh-autopair
# 4. zsh-you-should-use
# 5. fast-syntax-highlighting (MUST BE LAST)

# Load all plugins
plugin-load romkatv/zsh-defer
plugin-load --sync marlonrichert/zsh-autocomplete
plugin-load --sync zsh-users/zsh-autosuggestions
plugin-load \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use \
  zdharma-continuum/fast-syntax-highlighting

# zsh-autocomplete and zsh-autosuggestions must be initialized synchronously
# so that zsh-autocomplete's precmd can install widgets like `menu-search`
# and `recent-paths` before fast-syntax-highlighting's deferred init wraps
# them. Deferring the latter avoids "unhandled ZLE widget" warnings that
# appear when FSH iterates widgets before zsh-autocomplete's precmd fires.

# zsh-completions fpath is added in 20-completion.zsh before zsh-autocomplete
# runs its compinit.
# zsh-history-substring-search remains dropped; zsh-autocomplete provides the
# typed-history behavior and the completion panel.