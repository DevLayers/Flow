# 59-zsh-you-should-use.zsh — Reminds you of aliases you forgot (1.9k★)
# https://github.com/MichaelAquilina/zsh-you-should-use
# Shows hint when you type a command that has an alias defined.

# Load via plugin-load (defined in 05-plugin-manager.zsh)
# Plugin repo: MichaelAquilina/zsh-you-should-use

# Configuration (before plugin loads)
# Show message after command executes (default: before)
export YSU_MESSAGE_POSITION="after"

# Show only best match (default) or all matches
# export YSU_MODE="BESTMATCH"  # or "ALL"

# Custom message format (default: bold)
# export YSU_MESSAGE_FORMAT="$(tput setaf 1)Found %alias_type for %command: %alias$(tput sgr0)"

# Hardcore mode: refuse to execute if alias exists (enable if desired)
# export YSU_HARDCORE=1

# Hardcore mode for specific aliases only
# export YSU_HARDCORE_ALIASES=("gs" "ll" "gco")

# Ignore specific aliases
# export YSU_IGNORED_ALIASES=("g" "ll")
# export YSU_IGNORED_GLOBAL_ALIASES=("...")