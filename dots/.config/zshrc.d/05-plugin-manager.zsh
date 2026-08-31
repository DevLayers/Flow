# 05-plugin-manager.zsh — zsh_unplugged: minimal plugin management (~30 lines)
# https://github.com/mattmc3/zsh_unplugged
# Replaces manual git-clone logic in 55-autosuggestions, 56-history-substring-search, 60-syntax-highlighting, etc.

: ${ZPLUGINDIR:=${ZDOTDIR:-$HOME/.config/zsh}/plugins}

# Clone a plugin, identify its init file, source it, and add to fpath
function plugin-load {
  local plugin repo commitsha plugdir initfile initfiles=()
  for plugin in $@; do
    repo="$plugin"
    clone_args=(-q --depth 1 --recursive --shallow-submodules)
    # Pin repo to a specific commit sha if provided (e.g., 'user/repo@abc123')
    if [[ "$plugin" == *'@'* ]]; then
      repo="${plugin%@*}"
      commitsha="${plugin#*@}"
      clone_args+=(--no-checkout)
    fi
    plugdir=$ZPLUGINDIR/${repo:t}
    initfile=$plugdir/${repo:t}.plugin.zsh
    # Re-clone if the directory is missing OR its checkout is broken. A clone
    # interrupted mid-flight leaves the folder behind with an empty .git,
    # which the -d check alone would otherwise accept and never repair.
    if [[ ! -d $plugdir ]] || ! git -C $plugdir rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      [[ -d $plugdir ]] && rm -rf $plugdir
      echo "Cloning $repo..."
      git clone "${clone_args[@]}" https://github.com/$repo $plugdir
      if [[ -n "$commitsha" ]]; then
        git -C $plugdir fetch -q origin "$commitsha"
        git -C $plugdir checkout -q "$commitsha"
      fi
    fi
    if [[ ! -e $initfile ]]; then
      initfiles=($plugdir/*.{plugin.zsh,zsh-theme,zsh,sh}(N))
      # Drop a stale init link that points at itself, which the symlink step
      # below could otherwise re-create into an infinite link loop.
      initfiles=(${initfiles:#$initfile})
      (( $#initfiles )) || { echo >&2 "No init file found '$repo'." && continue }
      ln -sf $initfiles[1] $initfile
    fi
    fpath+=$plugdir
    (( $+functions[zsh-defer] )) && zsh-defer . $initfile || . $initfile
  done
}

# Update all plugins: plugin-update
function plugin-update {
  for d in $ZPLUGINDIR/*/.git(/); do
    echo "Updating ${d:h:t}..."
    if git -C "${d:h}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      command git -C "${d:h}" pull --ff --recurse-submodules --depth 1 --rebase --autostash
    else
      echo "  corrupt checkout — will be re-cloned on the next shell" >&2
      rm -rf "${d:h}"
    fi
  done
}

# Compile all plugins for speed: plugin-compile
function plugin-compile {
  autoload -U zrecompile
  local f
  for f in $ZPLUGINDIR/**/*.zsh{,-theme}(N); do
    zrecompile -pq "$f"
  done
}