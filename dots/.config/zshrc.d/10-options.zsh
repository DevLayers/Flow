# Flow Zsh Options
# Sensible Zsh option defaults

# Changing directories
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # pushd on cd
setopt PUSHD_IGNORE_DUPS    # no duplicate entries in dir stack
setopt PUSHD_SILENT         # don't print dir stack on pushd/popd
setopt PUSHD_TO_HOME        # pushd with no args goes home

# Completion
setopt ALWAYS_TO_END        # move cursor to end on completion
setopt AUTO_LIST            # list choices on ambiguous completion
setopt AUTO_MENU            # show menu on successive tab
setopt AUTO_PARAM_SLASH     # add slash for completed directories
setopt COMPLETE_IN_WORD     # complete from both ends of word
setopt LIST_PACKED          # compact completion lists
setopt LIST_TYPES           # show file types in completion

# Expansion and globbing
setopt EXTENDED_GLOB        # extended glob patterns
setopt GLOB_DOTS            # include dotfiles in glob
setopt NO_NOMATCH           # don't error on unmatched globs (pass through)

# History
setopt EXTENDED_HISTORY     # save timestamps
setopt HIST_EXPIRE_DUPS_FIRST  # expire dups first when trimming
setopt HIST_FIND_NO_DUPS    # don't show dups in history search
setopt HIST_IGNORE_ALL_DUPS # remove old duplicate entries
setopt HIST_IGNORE_DUPS     # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE    # don't record commands starting with space
setopt HIST_REDUCE_BLANKS   # remove superfluous blanks
setopt HIST_SAVE_NO_DUPS    # don't save duplicates
setopt HIST_VERIFY          # show history expansion before executing
setopt INC_APPEND_HISTORY   # append history incrementally
setopt SHARE_HISTORY        # share history across sessions

# Input/Output
setopt CORRECT              # command spelling correction
setopt INTERACTIVE_COMMENTS # allow comments in interactive shell
setopt NO_CLOBBER           # don't overwrite files with > (use >|)
setopt NO_FLOW_CONTROL      # disable ^S/^Q flow control
setopt RC_QUOTES            # allow '' to escape single quote

# Job control
setopt AUTO_CONTINUE        # auto-continue stopped jobs on disown
setopt LONG_LIST_JOBS       # list jobs in long format
setopt NOTIFY               # report job status immediately

# Prompt
setopt PROMPT_SUBST         # allow substitution in prompt
setopt TRANSIENT_RPROMPT    # remove rprompt on accepted lines