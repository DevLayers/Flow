# 55-autosuggestions.zsh — Fish-like autosuggestions config (loaded via plugin-load)
# https://github.com/zsh-users/zsh-autosuggestions

# Style
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# zsh-autocomplete is the source of the live completion panel. Keep these
# ghost-text widgets for a single suggestion between completions.

# ── Accept-key bindings (fish-model) ────────────────────────────────────────
# Autosuggestions show ghost text after the cursor. Accept it with:
#   →             accept the entire suggestion
#   End           accept the entire suggestion (fallback for terminals where
#                 → is consumed for forward-char or sticky-keys)
#   Shift-→       accept the next word of the suggestion
#   Ctrl-→        accept the next word (alt for the same)
#   Ctrl-F        accept the entire suggestion (readline muscle memory)
#
# Word-skip on Ctrl-← is kept as `backward-word` (NOT auto-suggest-related —
# we want plain word-jump when no suggestion is showing).
bindkey '^[[C'           autosuggest-accept         # bare →
bindkey '^[[1;2C'        autosuggest-accept-word    # Shift-→
bindkey '^[[1;5C'        autosuggest-accept-word    # Ctrl-→  (was forward-word — this was the ghost-text bug)
bindkey '^F'             autosuggest-accept         # Ctrl-F muscle memory
bindkey '^[[1;5D'        backward-word              # Ctrl-← unchanged