# 58-zsh-autopair.zsh — Auto-close/delete matching delimiters (628★)
# https://github.com/hlissner/zsh-autopair
# Auto-pairs: (), [], {}, "", '', `` and spaces in brackets

# Load via plugin-load (defined in 05-plugin-manager.zsh)
# Plugin repo: hlissner/zsh-autopair

# Configuration (before plugin loads)
# Disable space-pair expansion if it interferes (e.g., in Midnight Commander)
# unset 'AUTOPAIR_PAIRS[ ]'

# Works well with fast-syntax-highlighting's brackets highlighter
# (fast-syntax-highlighting must be loaded AFTER zsh-autopair)