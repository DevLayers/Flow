# Flow Terminal Integration
# Phase 5: Starship Prompt Integration
# Load generated terminal sequences from Flow/Matugen pipeline

# Generated color sequences (from Matugen via QuickShell)
local sequences_file="${FLOW_STATE_DIR:-$HOME/.local/state/quickshell/user/generated/terminal}/sequences.txt"
if [[ -f "$sequences_file" && -r "$sequences_file" ]]; then
  command cat "$sequences_file"
fi

# Kitty theme (if using Kitty)
if [[ "$TERM" == "xterm-kitty" ]] || [[ -n "$KITTY_WINDOW_ID" ]]; then
  local kitty_theme="${FLOW_STATE_DIR:-$HOME/.local/state/quickshell/user/generated/terminal}/kitty-theme.conf"
  if [[ -f "$kitty_theme" && -r "$kitty_theme" ]]; then
    # Kitty loads this via include in kitty.conf, but we can also source for immediate effect
    # Note: kitty.conf includes this file, so terminal colors are applied on startup
    # This fragment ensures sequences are output for non-Kitty terminals too
    :
  fi
fi

# Load Flow state for Starship prompt integration
# Uses Zsh-compatible path resolution (no BASH_SOURCE)
_flow_state_file=""
for _flow_candidate in \
  "${FLOW_BASE_DIR:-}/sdata/lib/flow_state.sh" \
  "${HOME}/.local/share/flow/sdata/lib/flow_state.sh" \
  "${0:A:h}/../../sdata/lib/flow_state.sh"; do
  if [[ -f "$_flow_candidate" ]]; then
    _flow_state_file="$_flow_candidate"
    break
  fi
done

if [[ -n "$_flow_state_file" ]]; then
  source "$_flow_state_file"
fi

# Flow Project Activation (Phase 3C)
# Shell functions that wrap the activation command
# This ensures activation affects the parent shell via eval

# Refresh Flow state for Starship (called after activation/deactivation)
_flow_refresh_starship_state() {
  if [[ -n "$_flow_state_file" ]]; then
    source "$_flow_state_file"
  fi
}

# Resolve activate.sh location (once, at source time)
_flow_activate_script=""
if [[ -n "${FLOW_BASE_DIR:-}" && -f "${FLOW_BASE_DIR}/sdata/subcmd-project/activate.sh" ]]; then
  _flow_activate_script="${FLOW_BASE_DIR}/sdata/subcmd-project/activate.sh"
elif [[ -f "${HOME}/.local/share/flow/sdata/subcmd-project/activate.sh" ]]; then
  _flow_activate_script="${HOME}/.local/share/flow/sdata/subcmd-project/activate.sh"
fi

flow_activate() {
  if [[ -z "$_flow_activate_script" ]]; then
    echo "Flow: activate.sh not found (set FLOW_BASE_DIR or install Flow)" >&2
    return 1
  fi

  # Save previous state for rollback
  local prev_profile="${FLOW_ENV_PROFILE:-}" prev_language="${FLOW_ENV_LANGUAGE:-}"
  local prev_strategy="${FLOW_ENV_STRATEGY:-}" prev_target="${FLOW_ENV_TARGET:-}"
  local prev_root="${FLOW_ENV_ROOT:-}" prev_activated="${FLOW_ENV_ACTIVATED:-}"
  local prev_venv="${FLOW_ENV_VENV:-}" prev_node_version="${FLOW_ENV_NODE_VERSION:-}"
  local prev_mise_node="${FLOW_ENV_MISE_NODE:-}" prev_mise_python="${FLOW_ENV_MISE_PYTHON:-}"
  local prev_path="$PATH" prev_virtual_env="${VIRTUAL_ENV:-}" prev_ps1="${PS1:-}"

  # Generate activation commands (without env vars)
  local commands
  commands=$(bash "$_flow_activate_script" activate --no-env "$@")
  local rc=$?

  if [[ $rc -ne 0 ]]; then
    return $rc
  fi

  # Eval the activation commands, tracking failure
  _flow_activate_failed=0
  eval "$commands"

  # If activation failed, rollback
  if [[ "${_flow_activate_failed:-0}" == "1" ]]; then
    export PATH="$prev_path"
    [[ -n "$prev_virtual_env" ]] && export VIRTUAL_ENV="$prev_virtual_env" || unset VIRTUAL_ENV
    [[ -n "${prev_ps1:-}" ]] && PS1="$prev_ps1"
    FLOW_ENV_PROFILE="$prev_profile" FLOW_ENV_LANGUAGE="$prev_language"
    FLOW_ENV_STRATEGY="$prev_strategy" FLOW_ENV_TARGET="$prev_target"
    FLOW_ENV_ROOT="$prev_root" FLOW_ENV_ACTIVATED="$prev_activated"
    FLOW_ENV_VENV="$prev_venv" FLOW_ENV_NODE_VERSION="$prev_node_version"
    FLOW_ENV_MISE_NODE="$prev_mise_node" FLOW_ENV_MISE_PYTHON="$prev_mise_python"
    [[ -z "$prev_profile" ]] && unset FLOW_ENV_PROFILE
    [[ -z "$prev_language" ]] && unset FLOW_ENV_LANGUAGE
    [[ -z "$prev_strategy" ]] && unset FLOW_ENV_STRATEGY
    [[ -z "$prev_target" ]] && unset FLOW_ENV_TARGET
    [[ -z "$prev_root" ]] && unset FLOW_ENV_ROOT
    [[ -z "$prev_activated" ]] && unset FLOW_ENV_ACTIVATED
    [[ -z "$prev_venv" ]] && unset FLOW_ENV_VENV
    [[ -z "$prev_node_version" ]] && unset FLOW_ENV_NODE_VERSION
    [[ -z "$prev_mise_node" ]] && unset FLOW_ENV_MISE_NODE
    [[ -z "$prev_mise_python" ]] && unset FLOW_ENV_MISE_PYTHON
    unset _flow_activate_failed
    
    # Refresh Starship state after rollback
    _flow_refresh_starship_state
    
    echo "Flow: activation failed, rolled back" >&2
    return 1
  fi

  # Activation succeeded — set env vars now (only on success)
  unset _flow_activate_failed
  local profile_name="${1:-}"
  local root git_root
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local xdg_state="${XDG_STATE_HOME:-$HOME/.local/state}"
  local state_file="$xdg_state/flow/projects/$(printf '%s' "$root" | sha256sum | cut -c1-16).json"

  if [[ -f "$state_file" ]]; then
    local p_json
    # If no profile name given, use default or first available
    if [[ -z "$profile_name" ]]; then
      profile_name=$(jq -r '.default_profile // .profiles | keys[0] // ""' "$state_file" 2>/dev/null)
    fi
    if [[ -n "$profile_name" ]]; then
      p_json=$(jq -r --arg name "$profile_name" '.profiles[$name] // empty' "$state_file" 2>/dev/null)
    fi
    if [[ -n "${p_json:-}" ]]; then
      local p_scope p_strategy p_target p_lang
      p_scope=$(jq -r '.scope // "."' <<< "$p_json")
      p_strategy=$(jq -r '.environment.strategy // "unconfigured"' <<< "$p_json")
      p_target=$(jq -r '.environment.target // ""' <<< "$p_json")
      # Resolve language from scope (matches activate.sh markers)
      local search_dir="$root"
      [[ "$p_scope" != "." ]] && search_dir="$root/$p_scope"
      p_lang=""
      [[ -f "$search_dir/manage.py" || -f "$search_dir/requirements.txt" || -f "$search_dir/Pipfile" || -f "$search_dir/pyproject.toml" || -f "$search_dir/setup.py" || -f "$search_dir/setup.cfg" || -f "$search_dir/uv.lock" || -f "$search_dir/poetry.lock" || -f "$search_dir/.python-version" ]] && p_lang="python"
      [[ -z "$p_lang" ]] && { [[ -f "$search_dir/package.json" || -d "$search_dir/node_modules" ]] && p_lang="node"; }
      [[ -z "$p_lang" ]] && { [[ -f "$search_dir/go.mod" ]] && p_lang="go"; }
      [[ -z "$p_lang" ]] && { [[ -f "$search_dir/Cargo.toml" ]] && p_lang="rust"; }
      [[ -z "$p_lang" ]] && p_lang="unknown"

      export FLOW_ENV_PROFILE="$profile_name"
      export FLOW_ENV_LANGUAGE="$p_lang"
      export FLOW_ENV_STRATEGY="$p_strategy"
      export FLOW_ENV_TARGET="$p_target"
      export FLOW_ENV_ROOT="$root"
      export FLOW_ENV_ACTIVATED="$(date -Iseconds)"
      
      # Refresh Starship state
      _flow_refresh_starship_state
    fi
  fi
}

flow_deactivate() {
  if [[ -z "$_flow_activate_script" ]]; then
    echo "Flow: activate.sh not found (set FLOW_BASE_DIR or install Flow)" >&2
    return 1
  fi
  
  local commands
  commands=$(bash "$_flow_activate_script" deactivate "$@")
  if [[ $? -eq 0 ]]; then
    eval "$commands"
    # Refresh Starship state after deactivation
    _flow_refresh_starship_state
  else
    return $?
  fi
}

flow_status() {
  if [[ -z "$_flow_activate_script" ]]; then
    echo "Flow: activate.sh not found (set FLOW_BASE_DIR or install Flow)" >&2
    return 1
  fi
  
  bash "$_flow_activate_script" status "$@"
}

# Aliases
alias fa='flow_activate'
alias fd='flow_deactivate'
alias fs='flow_status'
# ── Flow Engine recorder ─────────────────────────────────────────────────────
# Feeds every executed command into the engine's aggregates store (canonical
# schema=1). Async, silent, never blocks the prompt. Skipped inside the
# engine's own child shells to avoid double-counting PTY echoes.
typeset -g _FLOW_REC_CMD=""
_flow_rec_preexec() {
  _FLOW_REC_CMD="$1"
}
_flow_rec_precmd() {
  local ec=$?
  local cmd="$_FLOW_REC_CMD"
  _FLOW_REC_CMD=""
  [[ -n "$cmd" ]] || return 0
  command -v iris >/dev/null 2>&1 || return 0
  # &! = background + disown: no [1] PID / [1] done job announcements
  iris record --cmd "$cmd" --dir "$PWD" --exit "$ec" >/dev/null 2>&1 &!
}
add-zsh-hook preexec _flow_rec_preexec
add-zsh-hook precmd _flow_rec_precmd
