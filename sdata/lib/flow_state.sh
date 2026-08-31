#!/bin/bash
# Flow Terminal — Starship State Generator
# Generates environment variables for Starship to consume
# Called from 80-flow.zsh after activation
# Compatible with both Bash and Zsh

# Source icon abstraction (Zsh-compatible path resolution)
_flow_state_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  _flow_state_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${(%):-%N}" ]; then
  # Zsh: %N gives the sourced file path
  _flow_state_dir="$(cd "$(dirname "${(%):-%N}")" && pwd)"
else
  # Fallback: try known locations
  for _flow_candidate in \
    "${FLOW_BASE_DIR:-}/sdata/lib" \
    "${HOME}/.local/share/flow/sdata/lib"; do
    if [ -f "${_flow_candidate}/starship-icons.sh" ]; then
      _flow_state_dir="$_flow_candidate"
      break
    fi
  done
fi

if [ -n "$_flow_state_dir" ] && [ -f "${_flow_state_dir}/starship-icons.sh" ]; then
  source "${_flow_state_dir}/starship-icons.sh"
fi
unset _flow_state_dir

# ─── Export Flow Environment State ─────────────────────────────
export FLOW_STARSHIP_PROFILE="${FLOW_ENV_PROFILE:-}"
export FLOW_STARSHIP_LANGUAGE="${FLOW_ENV_LANGUAGE:-}"
export FLOW_STARSHIP_STRATEGY="${FLOW_ENV_STRATEGY:-}"
export FLOW_STARSHIP_TARGET="${FLOW_ENV_TARGET:-}"
export FLOW_STARSHIP_ROOT="${FLOW_ENV_ROOT:-}"
export FLOW_STARSHIP_ACTIVATED="${FLOW_ENV_ACTIVATED:-}"

# ─── Export Runtime Information ────────────────────────────────
export FLOW_STARSHIP_VENV="${FLOW_ENV_VENV:-}"
export FLOW_STARSHIP_NODE_VERSION="${FLOW_ENV_NODE_VERSION:-}"
export FLOW_STARSHIP_MISE_NODE="${FLOW_ENV_MISE_NODE:-}"
export FLOW_STARSHIP_MISE_PYTHON="${FLOW_ENV_MISE_PYTHON:-}"
export FLOW_STARSHIP_MISE_GO="${FLOW_ENV_MISE_GO:-}"
export FLOW_STARSHIP_MISE_RUST="${FLOW_ENV_MISE_RUST:-}"

# ─── Export Verified Icon Codepoints ───────────────────────────
# All use $'\uXXXX' escapes for font portability
# Fallbacks match starship-icons.sh defaults

# Languages
export FLOW_ICON_PYTHON="${FLOW_ICON_PYTHON:-$'\uE73C'}"
export FLOW_ICON_NODEJS="${FLOW_ICON_NODEJS:-$'\uED0D'}"
export FLOW_ICON_GO="${FLOW_ICON_GO:-$'\uE65E'}"
export FLOW_ICON_RUST="${FLOW_ICON_RUST:-$'\uE7A8'}"
export FLOW_ICON_JAVA="${FLOW_ICON_JAVA:-$'\uE738'}"
export FLOW_ICON_KOTLIN="${FLOW_ICON_KOTLIN:-$'\uE81B'}"
export FLOW_ICON_SWIFT="${FLOW_ICON_SWIFT:-$'\uE755'}"
export FLOW_ICON_PHP="${FLOW_ICON_PHP:-$'\uE73D'}"
export FLOW_ICON_RUBY="${FLOW_ICON_RUBY:-$'\uE739'}"
export FLOW_ICON_TYPESCRIPT="${FLOW_ICON_TYPESCRIPT:-$'\uE628'}"
export FLOW_ICON_JAVASCRIPT="${FLOW_ICON_JAVASCRIPT:-$'\uE74E'}"
export FLOW_ICON_C="${FLOW_ICON_C:-$'\uE61E'}"
export FLOW_ICON_CPP="${FLOW_ICON_CPP:-$'\uE61D'}"
export FLOW_ICON_CSHARP="${FLOW_ICON_CSHARP:-$'\uE74F'}"

# Tools
export FLOW_ICON_DOCKER="${FLOW_ICON_DOCKER:-$'\uE7B0'}"
export FLOW_ICON_KUBERNETES="${FLOW_ICON_KUBERNETES:-$'\uE81D'}"
export FLOW_ICON_HELM="${FLOW_ICON_HELM:-$'\uE7FB'}"
export FLOW_ICON_TERRAFORM="${FLOW_ICON_TERRAFORM:-$'\uE8BD'}"
export FLOW_ICON_ANSIBLE="${FLOW_ICON_ANSIBLE:-$'\uE723'}"
export FLOW_ICON_JENKINS="${FLOW_ICON_JENKINS:-$'\uE767'}"
export FLOW_ICON_GITHUB_ACTIONS="${FLOW_ICON_GITHUB_ACTIONS:-$'\uE7E9'}"
export FLOW_ICON_NGINX="${FLOW_ICON_NGINX:-$'\uE776'}"
export FLOW_ICON_APACHE="${FLOW_ICON_APACHE:-$'\uE72B'}"

# Cloud
export FLOW_ICON_AWS="${FLOW_ICON_AWS:-$'\uE7AD'}"
export FLOW_ICON_GCP="${FLOW_ICON_GCP:-$'\uE7F1'}"
export FLOW_ICON_AZURE="${FLOW_ICON_AZURE:-$'\uE754'}"

# Databases
export FLOW_ICON_POSTGRESQL="${FLOW_ICON_POSTGRESQL:-$'\uE76E'}"
export FLOW_ICON_MYSQL="${FLOW_ICON_MYSQL:-$'\uE704'}"
export FLOW_ICON_REDIS="${FLOW_ICON_REDIS:-$'\uE76D'}"
export FLOW_ICON_MONGODB="${FLOW_ICON_MONGODB:-$'\uE7A4'}"

# Monitoring
export FLOW_ICON_PROMETHEUS="${FLOW_ICON_PROMETHEUS:-$'\uE870'}"
export FLOW_ICON_GRAFANA="${FLOW_ICON_GRAFANA:-$'\uE7F3'}"
export FLOW_ICON_ELASTICSEARCH="${FLOW_ICON_ELASTICSEARCH:-$'\uE7CA'}"
export FLOW_ICON_DATADOG="${FLOW_ICON_DATADOG:-$'\uE902'}"
export FLOW_ICON_SENTRY="${FLOW_ICON_SENTRY:-$'\uE89F'}"

# Version Control
export FLOW_ICON_GIT="${FLOW_ICON_GIT:-$'\uE725'}"
export FLOW_ICON_GITHUB="${FLOW_ICON_GITHUB:-$'\uE709'}"
export FLOW_ICON_GITLAB="${FLOW_ICON_GITLAB:-$'\uE7EB'}"
export FLOW_ICON_SSH="${FLOW_ICON_SSH:-$'\uE8B1'}"

# Status
export FLOW_ICON_WARNING="${FLOW_ICON_WARNING:-$'\u26A0'}"
export FLOW_ICON_SEPARATOR="${FLOW_ICON_SEPARATOR:-·}"

# ─── Detect Remote Shell ───────────────────────────────────────
export FLOW_STARSHIP_REMOTE=""
if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
  export FLOW_STARSHIP_REMOTE="1"
fi

# ─── Detect Production Context ─────────────────────────────────
export FLOW_STARSHIP_PROD=""
if [[ "${FLOW_ENV_TARGET:-}" == "production" ]] || [[ "${FLOW_ENV_PROFILE:-}" =~ prod ]]; then
  export FLOW_STARSHIP_PROD="1"
fi

# ─── Point Starship at the Generated Material Palette ──────────
# Phase 6: applycolor regenerates this file from Material tokens on every
# theme change. When present, Starship reads the generated config (static
# structure + live [palettes.flow]); otherwise it falls back to the static
# ~/.config/starship.toml with its offline fallback palette. Only export
# when the file exists — a missing STARSHIP_CONFIG target would blank the
# prompt, not fall back.
_flow_starship_generated="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/terminal/starship.toml"
if [ -z "${STARSHIP_CONFIG:-}" ] && [ -f "$_flow_starship_generated" ]; then
  export STARSHIP_CONFIG="$_flow_starship_generated"
fi
unset _flow_starship_generated
