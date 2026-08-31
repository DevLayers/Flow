#!/usr/bin/env bash
#
# flow project activate — safe profile activation
# Part of Flow Terminal Phase 3C
#
# This script outputs shell commands that are eval'd by the parent shell.
# It does NOT modify the child process environment.
#
# Model:
#   1. Resolve profile from 3B.2 state
#   2. Deactivate previous Flow-managed state (shell-local)
#   3. Activate new state (shell-local)
#   4. Set FLOW_ENV_* variables for tracking
#
# Safety:
#   - Only activates existing environments (no provisioning)
#   - Shell-local state (no cross-shell contamination)
#   - Idempotent (no duplicate PATH entries)
#   - Rollback on failure
#

set -Eeuo pipefail

# Resolve script directory (follows symlinks)
_source="${BASH_SOURCE[0]}"
while [[ -L "$_source" ]]; do
    _dir="$(cd -P "$(dirname "$_source")" >/dev/null 2>&1 && pwd)"
    _source="$(readlink "$_source")"
    [[ "$_source" != /* ]] && _source="$_dir/$_source"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_source")" >/dev/null 2>&1 && pwd)"
unset _source _dir

# XDG paths
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PROJECT_STATE_DIR="$XDG_STATE_HOME/flow/projects"

# Colors (for error messages)
if [[ -t 2 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_CYAN='\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi

JSON_OUTPUT=false
DRY_RUN=false
VERBOSE=false

# Get project ID from root path (deterministic hash)
project_id_from_root() {
    local root="$1"
    printf '%s' "$root" | sha256sum | cut -c1-16
}

# Get project state file path
project_state_file() {
    local root="$1"
    local id
    id=$(project_id_from_root "$root")
    printf '%s/%s.json' "$PROJECT_STATE_DIR" "$id"
}

# Load project state
load_project_state() {
    local state_file="$1"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        printf '{}'
    fi
}

# Get project root using Phase 2 detector logic
get_project_root() {
    local git_root=""
    if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        printf '%s\n' "$git_root"
        return 0
    fi

    local dir="$PWD"
    local markers=(
        "pyproject.toml" "package.json" "go.mod" "Cargo.toml"
        "composer.json" "Gemfile" "pom.xml" "build.gradle" "build.gradle.kts"
        "mix.exs" "CMakeLists.txt" "Makefile" "Taskfile.yml" "Justfile"
        "Dockerfile" "Containerfile" "compose.yaml" "compose.yml"
        "docker-compose.yml" "docker-compose.yaml" "Chart.yaml"
        "kustomization.yaml" "ansible.cfg" "*.csproj" "*.sln"
        "pubspec.yaml" "Package.swift" "stack.yaml" "dune-project"
        ".github" "terraform"
    )

    while [[ "$dir" != "/" ]]; do
        for marker in "${markers[@]}"; do
            if [[ "$marker" == *'*'* ]]; then
                compgen -G "$dir/$marker" >/dev/null 2>&1 && { printf '%s\n' "$dir"; return 0; }
            elif [[ -e "$dir/$marker" ]]; then
                printf '%s\n' "$dir"; return 0
            fi
        done
        dir="$(dirname "$dir")"
    done
    printf '%s\n' "$PWD"
    return 1
}

# Get project name from root
get_project_name() {
    local root="$1"
    local git_root="$2"

    if [[ -n "$git_root" && "$git_root" == "$root" ]]; then
        basename "$git_root"
        return
    fi

    if [[ -f "$root/package.json" ]]; then
        grep -E '"name"\s*:' "$root/package.json" 2>/dev/null | head -1 | sed -E 's/.*:\s*"([^"]+)".*/\1/' | xargs
        return
    fi
    if [[ -f "$root/pyproject.toml" ]]; then
        grep -E '^name\s*=' "$root/pyproject.toml" 2>/dev/null | head -1 | sed -E 's/.*=\s*"?([^"]+)"?/\1/' | xargs
        return
    fi
    if [[ -f "$root/Cargo.toml" ]]; then
        grep -E '^name\s*=' "$root/Cargo.toml" 2>/dev/null | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/' | xargs
        return
    fi

    basename "$root"
}

# Resolve the primary language for a profile scope
# This is determined by actual scope contents, NOT profile type
resolve_language_for_scope() {
    local root="$1"
    local scope="$2"

    local search_dir="$root"
    if [[ "$scope" != "." ]]; then
        search_dir="$root/$scope"
    fi

    # Priority order: check most specific markers first
    # Python
    if [[ -f "$search_dir/manage.py" ]] || [[ -f "$search_dir/pyproject.toml" ]] || \
       [[ -f "$search_dir/requirements.txt" ]] || [[ -d "$search_dir/requirements" ]] || \
       [[ -f "$search_dir/Pipfile" ]] || [[ -f "$search_dir/poetry.lock" ]] || \
       [[ -f "$search_dir/setup.py" ]] || [[ -f "$search_dir/setup.cfg" ]] || \
       [[ -f "$search_dir/uv.lock" ]] || [[ -f "$search_dir/.python-version" ]] || \
       [[ -d "$search_dir/.venv" ]] || [[ -d "$search_dir/venv" ]] || [[ -d "$search_dir/env" ]]; then
        printf 'python'
        return 0
    fi

    # Node/JavaScript
    if [[ -f "$search_dir/package.json" ]]; then
        printf 'node'
        return 0
    fi

    # Go
    if [[ -f "$search_dir/go.mod" ]]; then
        printf 'go'
        return 0
    fi

    # Rust
    if [[ -f "$search_dir/Cargo.toml" ]]; then
        printf 'rust'
        return 0
    fi

    # Java
    if [[ -f "$search_dir/pom.xml" ]] || [[ -f "$search_dir/build.gradle" ]] || [[ -f "$search_dir/build.gradle.kts" ]]; then
        printf 'java'
        return 0
    fi

    # PHP
    if [[ -f "$search_dir/composer.json" ]]; then
        printf 'php'
        return 0
    fi

    # Ruby
    if [[ -f "$search_dir/Gemfile" ]]; then
        printf 'ruby'
        return 0
    fi

    # Terraform
    if compgen -G "$search_dir/*.tf" >/dev/null 2>&1 || compgen -G "$search_dir/*.tf.json" >/dev/null 2>&1; then
        printf 'terraform'
        return 0
    fi

    # Generic/unknown
    printf 'generic'
    return 0
}

# Discover runtime selectors for a scope
discover_runtime_selectors() {
    local root="$1"
    local scope="$2"

    local search_dir="$root"
    if [[ "$scope" != "." ]]; then
        search_dir="$root/$scope"
    fi

    local selectors=()

    # Python runtime selectors
    if [[ -f "$search_dir/.python-version" ]]; then
        local version
        version=$(cat "$search_dir/.python-version" 2>/dev/null | xargs)
        local rel_path
        if [[ "$scope" != "." ]]; then
            rel_path="$scope/.python-version"
        else
            rel_path=".python-version"
        fi
        selectors+=("mise|python|$rel_path|$version|$scope")
    fi

    # Node runtime selectors
    if [[ -f "$search_dir/.nvmrc" ]]; then
        local version
        version=$(cat "$search_dir/.nvmrc" 2>/dev/null | xargs)
        local rel_path
        if [[ "$scope" != "." ]]; then
            rel_path="$scope/.nvmrc"
        else
            rel_path=".nvmrc"
        fi
        selectors+=("nvm|node|$rel_path|$version|$scope")
    fi

    if [[ -f "$search_dir/.node-version" ]]; then
        local version
        version=$(cat "$search_dir/.node-version" 2>/dev/null | xargs)
        local rel_path
        if [[ "$scope" != "." ]]; then
            rel_path="$scope/.node-version"
        else
            rel_path=".node-version"
        fi
        selectors+=("mise|node|$rel_path|$version|$scope")
    fi

    # Mise/asdf
    if [[ -f "$search_dir/mise.toml" ]] || [[ -f "$search_dir/.tool-versions" ]]; then
        selectors+=("mise|multi|mise config|available|$scope")
    fi

    if [[ ${#selectors[@]} -gt 0 ]]; then
        printf '%s\n' "${selectors[@]}"
    fi
}

# Discover Python environments in project/profile scope
discover_python_envs() {
    local root="$1"
    local scope="$2"

    local search_dir="$root"
    if [[ "$scope" != "." ]]; then
        search_dir="$root/$scope"
    fi

    local candidates=()
    local env_dirs=(".venv" "venv" "env")

    for env_dir in "${env_dirs[@]}"; do
        local full_path="$search_dir/$env_dir"
        if [[ -d "$full_path" ]]; then
            local rel_path
            if [[ "$scope" != "." ]]; then
                rel_path="$scope/$env_dir"
            else
                rel_path="$env_dir"
            fi
            candidates+=("$rel_path")
        fi
    done

    if [[ ${#candidates[@]} -gt 0 ]]; then
        printf '%s\n' "${candidates[@]}"
    fi
}

# Validate existing environment based on resolved language
validate_existing_env() {
    local target="$1"
    local resolved_language="$2"
    local root="$3"

    local target_path="$root/$target"

    # Must exist
    [[ -d "$target_path" ]] || return 1

    # Language-aware validation based on RESOLVED language
    case "$resolved_language" in
        python)
            # Python: validate bin/python exists and is executable
            [[ -x "$target_path/bin/python" ]] || return 1
            # Verify it's actually Python
            local version
            version=$("$target_path/bin/python" --version 2>/dev/null | sed 's/Python //')
            [[ -n "$version" ]] || return 1
            return 0
            ;;
        node)
            # Node: validate bin/node exists and is executable
            [[ -x "$target_path/bin/node" ]] || return 1
            # Verify it's actually Node
            local version
            version=$("$target_path/bin/node" --version 2>/dev/null | sed 's/v//')
            [[ -n "$version" ]] || return 1
            return 0
            ;;
        go)
            # Go: validate bin/go exists
            [[ -x "$target_path/bin/go" ]] || return 1
            return 0
            ;;
        rust)
            # Rust: validate bin/cargo exists
            [[ -x "$target_path/bin/cargo" ]] || return 1
            return 0
            ;;
        ruby)
            # Ruby: validate bin/ruby exists
            [[ -x "$target_path/bin/ruby" ]] || return 1
            return 0
            ;;
        java)
            # Java: validate bin/java exists
            [[ -x "$target_path/bin/java" ]] || return 1
            return 0
            ;;
        php)
            # PHP: validate bin/php exists
            [[ -x "$target_path/bin/php" ]] || return 1
            return 0
            ;;
        *)
            # Generic/unknown: accept if it has any recognized runtime binary
            if [[ -x "$target_path/bin/python" ]] || \
               [[ -x "$target_path/bin/node" ]] || \
               [[ -x "$target_path/bin/go" ]] || \
               [[ -x "$target_path/bin/cargo" ]] || \
               [[ -x "$target_path/bin/ruby" ]] || \
               [[ -x "$target_path/bin/java" ]] || \
               [[ -x "$target_path/bin/php" ]]; then
                return 0
            fi
            return 1
            ;;
    esac
}

# Generate shell commands to activate a Python virtual environment
activate_python_venv() {
    local venv_path="$1"
    local root="$2"

    local full_path="$root/$venv_path"

    # Validate the environment exists
    if [[ ! -d "$full_path" ]]; then
        printf 'echo "Flow: Python environment not found: %%s" "%s"\n' "$venv_path"
        printf '_flow_activate_failed=1\n'
        return 1
    fi

    # Check for bin/activate
    if [[ ! -f "$full_path/bin/activate" ]]; then
        printf 'echo "Flow: Python environment missing bin/activate: %%s" "%s"\n' "$venv_path"
        printf '_flow_activate_failed=1\n'
        return 1
    fi

    # Pre-validate: test activate script in subshell (catches exit 1, syntax errors)
    local test_output
    test_output=$(bash -c "$(printf 'source %q' "$full_path/bin/activate")" 2>&1)
    local test_rc=$?
    if [[ $test_rc -ne 0 ]]; then
        printf 'echo "Flow: activate script failed validation: %%s (rc=%%d)" "%s" %d\n' "$venv_path" "$test_rc"
        printf '_flow_activate_failed=1\n'
        return 1
    fi

    # Generate activation commands
    printf '_flow_activate_failed=0\n'
    printf '# Flow: Activate Python virtual environment\n'
    printf 'if [[ -n "${FLOW_ENV_VENV:-}" && "${FLOW_ENV_VENV}" == "%s" ]]; then\n' "$full_path"
    printf '  : # Already activated, no-op\n'
    printf 'else\n'
    printf '  # Deactivate previous Flow-managed venv if any\n'
    printf '  if [[ -n "${FLOW_ENV_VENV:-}" && -f "${FLOW_ENV_VENV}/bin/deactivate" ]]; then\n'
    printf '    _flow_prev_venv="${FLOW_ENV_VENV}"\n'
    printf '    source "${_flow_prev_venv}/bin/deactivate" 2>/dev/null || true\n'
    printf '    unset FLOW_ENV_VENV _flow_prev_venv\n'
    printf '  fi\n'
    printf '  # Activate new venv\n'
    printf '  export FLOW_ENV_VENV="%s"\n' "$full_path"
    printf '  source "%s/bin/activate"\n' "$full_path"
    printf 'fi\n'
}

# Generate shell commands to activate a Node runtime selector
activate_node_runtime() {
    local strategy="$1"
    local version="$2"

    case "$strategy" in
        nvm)
            # nvm activation
            printf '# Flow: Activate Node via nvm\n'
            printf 'if command -v nvm >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_NODE_VERSION:-}" == "%s" ]]; then\n' "$version"
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    nvm use "%s" 2>/dev/null || { echo "Flow: nvm use %s failed"; _flow_activate_failed=1; }\n' "$version" "$version"
            printf '    [[ "${_flow_activate_failed:-0}" == "0" ]] && export FLOW_ENV_NODE_VERSION="%s"\n' "$version"
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: nvm not found, cannot activate Node %s"\n' "$version"
            printf 'fi\n'
            ;;
        mise)
            # mise activation — use eval mise env (activate only, no install)
            printf '# Flow: Activate Node via mise\n'
            printf 'if command -v mise >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_MISE_NODE:-}" == "%s" ]]; then\n' "$version"
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    mise ls --installed 2>/dev/null | grep -q "node@%s" || {\n' "$version"
            printf '      echo "Flow: node@%%s not installed, run: mise install node@%%s" "%s" "%s"\n' "$version" "$version"
            printf '      _flow_activate_failed=1\n'
            printf '    }\n'
            printf '    if [[ "${_flow_activate_failed:-0}" == "0" ]]; then\n'
            printf '      _flow_mise_out=$(mise env "node@%s" 2>/dev/null)\n' "$version"
            printf '      if [[ $? -ne 0 ]]; then\n'
            printf '        echo "Flow: mise env node@%%s failed" "%s"\n' "$version"
            printf '        _flow_activate_failed=1\n'
            printf '      else\n'
            printf '        eval "$_flow_mise_out"\n'
            printf '        export FLOW_ENV_MISE_NODE="%s"\n' "$version"
            printf '      fi\n'
            printf '    fi\n'
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: mise not found, cannot activate Node %s"\n' "$version"
            printf 'fi\n'
            ;;
        node-version)
            # node-version activation
            printf '# Flow: Activate Node via node-version\n'
            printf 'if command -v node-version >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_NODE_VERSION:-}" == "%s" ]]; then\n' "$version"
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    export FLOW_ENV_NODE_VERSION="%s"\n' "$version"
            printf '    node-version "%s" 2>/dev/null || echo "Flow: node-version %s failed"\n' "$version" "$version"
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: node-version not found, cannot activate Node %s"\n' "$version"
            printf 'fi\n'
            ;;
        *)
            # system or none - no activation needed
            printf '# Flow: Node %s - no activation needed\n' "$strategy"
            ;;
    esac
}

# Generate shell commands to activate a Python runtime selector
activate_python_runtime() {
    local strategy="$1"
    local version="$2"

    case "$strategy" in
        mise)
            # mise activation — use eval mise env (activate only, no install)
            printf '# Flow: Activate Python via mise\n'
            printf 'if command -v mise >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_MISE_PYTHON:-}" == "%s" ]]; then\n' "$version"
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    mise ls --installed 2>/dev/null | grep -q "python@%s" || {\n' "$version"
            printf '      echo "Flow: python@%%s not installed, run: mise install python@%%s" "%s" "%s"\n' "$version" "$version"
            printf '      _flow_activate_failed=1\n'
            printf '    }\n'
            printf '    if [[ "${_flow_activate_failed:-0}" == "0" ]]; then\n'
            printf '      _flow_mise_out=$(mise env "python@%s" 2>/dev/null)\n' "$version"
            printf '      if [[ $? -ne 0 ]]; then\n'
            printf '        echo "Flow: mise env python@%%s failed" "%s"\n' "$version"
            printf '        _flow_activate_failed=1\n'
            printf '      else\n'
            printf '        eval "$_flow_mise_out"\n'
            printf '        export FLOW_ENV_MISE_PYTHON="%s"\n' "$version"
            printf '      fi\n'
            printf '    fi\n'
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: mise not found, cannot activate Python %s"\n' "$version"
            printf 'fi\n'
            ;;
        *)
            # system or none - no activation needed
            printf '# Flow: Python %s - no activation needed\n' "$strategy"
            ;;
    esac
}

# Generate shell commands to activate Go runtime
activate_go_runtime() {
    local strategy="$1"

    case "$strategy" in
        mise)
            # mise activation for Go — activate only, no install
            printf '# Flow: Activate Go via mise\n'
            printf 'if command -v mise >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_MISE_GO:-}" == "active" ]]; then\n'
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    mise ls --installed 2>/dev/null | grep -q "^go" || {\n'
            printf '      echo "Flow: go not installed, run: mise install go"\n'
            printf '      _flow_activate_failed=1\n'
            printf '    }\n'
            printf '    if [[ "${_flow_activate_failed:-0}" == "0" ]]; then\n'
            printf '      _flow_mise_out=$(mise env go 2>/dev/null)\n'
            printf '      if [[ $? -ne 0 ]]; then\n'
            printf '        echo "Flow: mise env go failed"\n'
            printf '        _flow_activate_failed=1\n'
            printf '      else\n'
            printf '        eval "$_flow_mise_out"\n'
            printf '        export FLOW_ENV_MISE_GO="active"\n'
            printf '      fi\n'
            printf '    fi\n'
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: mise not found, cannot activate Go"\n'
            printf 'fi\n'
            ;;
        *)
            # system - no activation needed
            printf '# Flow: Go %s - no activation needed\n' "$strategy"
            ;;
    esac
}

# Generate shell commands to activate Rust runtime
activate_rust_runtime() {
    local strategy="$1"

    case "$strategy" in
        mise)
            # mise activation for Rust — activate only, no install
            printf '# Flow: Activate Rust via mise\n'
            printf 'if command -v mise >/dev/null 2>&1; then\n'
            printf '  if [[ "${FLOW_ENV_MISE_RUST:-}" == "active" ]]; then\n'
            printf '    : # Already activated, no-op\n'
            printf '  else\n'
            printf '    mise ls --installed 2>/dev/null | grep -q "^rust" || {\n'
            printf '      echo "Flow: rust not installed, run: mise install rust"\n'
            printf '      _flow_activate_failed=1\n'
            printf '    }\n'
            printf '    if [[ "${_flow_activate_failed:-0}" == "0" ]]; then\n'
            printf '      _flow_mise_out=$(mise env rust 2>/dev/null)\n'
            printf '      if [[ $? -ne 0 ]]; then\n'
            printf '        echo "Flow: mise env rust failed"\n'
            printf '        _flow_activate_failed=1\n'
            printf '      else\n'
            printf '        eval "$_flow_mise_out"\n'
            printf '        export FLOW_ENV_MISE_RUST="active"\n'
            printf '      fi\n'
            printf '    fi\n'
            printf '  fi\n'
            printf 'else\n'
            printf '  echo "Flow: mise not found, cannot activate Rust"\n'
            printf 'fi\n'
            ;;
        *)
            # system - no activation needed
            printf '# Flow: Rust %s - no activation needed\n' "$strategy"
            ;;
    esac
}

# Generate shell commands to set Flow environment variables
set_flow_env_vars() {
    local profile_name="$1"
    local resolved_language="$2"
    local strategy="$3"
    local target="$4"
    local root="$5"

    printf '# Flow: Set environment variables\n'
    printf 'export FLOW_ENV_PROFILE="%s"\n' "$profile_name"
    printf 'export FLOW_ENV_LANGUAGE="%s"\n' "$resolved_language"
    printf 'export FLOW_ENV_STRATEGY="%s"\n' "$strategy"
    [[ -n "$target" ]] && printf 'export FLOW_ENV_TARGET="%s"\n' "$target"
    printf 'export FLOW_ENV_ROOT="%s"\n' "$root"
    printf 'export FLOW_ENV_ACTIVATED="%s"\n' "$(date -Iseconds)"
}

# Generate shell commands to deactivate previous Flow-managed state
deactivate_previous() {
    printf '# Flow: Deactivate previous Flow-managed state\n'
    printf 'if [[ -n "${FLOW_ENV_PROFILE:-}" ]]; then\n'
    printf '  # Deactivate previous venv if any\n'
    printf '  if [[ -n "${FLOW_ENV_VENV:-}" && -f "${FLOW_ENV_VENV}/bin/deactivate" ]]; then\n'
    printf '    source "${FLOW_ENV_VENV}/bin/deactivate" 2>/dev/null || true\n'
    printf '  fi\n'
    printf '  # Clear Flow environment variables\n'
    printf '  unset FLOW_ENV_PROFILE\n'
    printf '  unset FLOW_ENV_LANGUAGE\n'
    printf '  unset FLOW_ENV_STRATEGY\n'
    printf '  unset FLOW_ENV_TARGET\n'
    printf '  unset FLOW_ENV_ROOT\n'
    printf '  unset FLOW_ENV_ACTIVATED\n'
    printf '  unset FLOW_ENV_VENV\n'
    printf '  unset FLOW_ENV_NODE_VERSION\n'
    printf '  unset FLOW_ENV_MISE_NODE\n'
    printf '  unset FLOW_ENV_MISE_PYTHON\n'
    printf 'fi\n'
}

# Main activation function
cmd_activate() {
    local NO_ENV=false
    local -a pos=()

    # Flags may appear in any order; first non-flag arg is the profile name.
    # This makes `activate --no-env <name>` and `activate <name> --no-env`
    # both valid — and `fa` (no args, --no-env appended by the wrapper) works.
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON_OUTPUT=true ;;
            --dry-run) DRY_RUN=true ;;
            --no-env) NO_ENV=true ;;
            -v|--verbose) VERBOSE=true ;;
            -h|--help) print_help; exit 0 ;;
            --version) printf 'activate.sh %s\n' "1.0.0"; exit 0 ;;
            *) pos+=("$1") ;;
        esac
        shift
    done
    local profile_name="${pos[0]:-}"

    # Get project context
    local root name git_root
    root=$(get_project_root)
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    name=$(get_project_name "$root" "$git_root")

    # Get state file
    local state_file
    state_file=$(project_state_file "$root")

    # Load state
    local state_json
    state_json=$(load_project_state "$state_file")

    # If no profile specified, use default or first available
    if [[ -z "$profile_name" ]]; then
        profile_name=$(printf '%s' "$state_json" | jq -r '.default_profile // ""')
        if [[ -z "$profile_name" ]]; then
            # Get first profile
            profile_name=$(printf '%s' "$state_json" | jq -r '.profiles | keys[0] // ""')
        fi
    fi

    [[ -n "$profile_name" ]] || {
        printf 'Flow: no profile to activate\n' >&2
        printf '  Use: flow project profile create <name> <type> <scope>\n' >&2
        return 1
    }

    # Get profile (safe jq with --arg)
    local profile_json
    profile_json=$(printf '%s' "$state_json" | jq -r --arg name "$profile_name" '.profiles[$name] // empty')
    [[ -n "$profile_json" ]] || {
        printf 'Flow: profile "%s" does not exist\n' "$profile_name" >&2
        return 1
    }

    local profile_type profile_scope saved_strategy saved_target
    profile_type=$(printf '%s' "$profile_json" | jq -r '.type // "custom"')
    profile_scope=$(printf '%s' "$profile_json" | jq -r '.scope // "."')
    saved_strategy=$(printf '%s' "$profile_json" | jq -r '.environment.strategy // "unconfigured"')
    saved_target=$(printf '%s' "$profile_json" | jq -r '.environment.target // ""')

    # Resolve language from scope contents
    local resolved_language
    resolved_language=$(resolve_language_for_scope "$root" "$profile_scope")

    # Generate activation commands
    local activation_commands=""

    # 1. Deactivate previous state
    activation_commands+=$(deactivate_previous)
    activation_commands+=$'\n'

    # 2. Activate based on strategy
    case "$saved_strategy" in
        existing)
            # Activate existing environment
            case "$resolved_language" in
                python)
                    activation_commands+=$(activate_python_venv "$saved_target" "$root")
                    ;;
                node)
                    # For Node existing environments, we don't have venv-style activation
                    # Just set the environment variables
                    activation_commands+='# Flow: Node existing environment - no venv-style activation\n'
                    ;;
                *)
                    activation_commands+="# Flow: $resolved_language existing environment - no activation needed\n"
                    ;;
            esac
            ;;
        uv)
            # uv-managed environment
            case "$resolved_language" in
                python)
                    # Check if there's a .venv to activate
                    local search_dir="$root"
                    if [[ "$profile_scope" != "." ]]; then
                        search_dir="$root/$profile_scope"
                    fi
                    if [[ -d "$search_dir/.venv" ]]; then
                        local venv_path
                        if [[ "$profile_scope" != "." ]]; then
                            venv_path="$profile_scope/.venv"
                        else
                            venv_path=".venv"
                        fi
                        activation_commands+=$(activate_python_venv "$venv_path" "$root")
                    else
                        activation_commands+='# Flow: uv project but no .venv found\n'
                        activation_commands+='# Run "uv sync" to create the environment\n'
                    fi
                    ;;
                *)
                    activation_commands+="# Flow: uv $resolved_language - no activation needed\n"
                    ;;
            esac
            ;;
        mise)
            # mise-managed runtime
            case "$resolved_language" in
                python)
                    local runtime_selectors=()
                    mapfile -t runtime_selectors < <(discover_runtime_selectors "$root" "$profile_scope")
                    for selector in "${runtime_selectors[@]}"; do
                        IFS='|' read -r strategy lang rel_path version cand_scope <<< "$selector"
                        if [[ "$lang" == "python" ]]; then
                            activation_commands+=$(activate_python_runtime "$strategy" "$version")
                            break
                        fi
                    done
                    ;;
                node)
                    local runtime_selectors=()
                    mapfile -t runtime_selectors < <(discover_runtime_selectors "$root" "$profile_scope")
                    for selector in "${runtime_selectors[@]}"; do
                        IFS='|' read -r strategy lang rel_path version cand_scope <<< "$selector"
                        if [[ "$lang" == "node" ]]; then
                            activation_commands+=$(activate_node_runtime "$strategy" "$version")
                            break
                        fi
                    done
                    ;;
                go)
                    activation_commands+=$(activate_go_runtime "mise")
                    ;;
                rust)
                    activation_commands+=$(activate_rust_runtime "mise")
                    ;;
                *)
                    activation_commands+="# Flow: mise $resolved_language - no activation needed\n"
                    ;;
            esac
            ;;
        venv)
            # python -m venv
            case "$resolved_language" in
                python)
                    local search_dir="$root"
                    if [[ "$profile_scope" != "." ]]; then
                        search_dir="$root/$profile_scope"
                    fi
                    if [[ -d "$search_dir/.venv" ]]; then
                        local venv_path
                        if [[ "$profile_scope" != "." ]]; then
                            venv_path="$profile_scope/.venv"
                        else
                            venv_path=".venv"
                        fi
                        activation_commands+=$(activate_python_venv "$venv_path" "$root")
                    else
                        activation_commands+='# Flow: venv strategy but no .venv found\n'
                        activation_commands+='# Run "python -m venv .venv" to create the environment\n'
                    fi
                    ;;
                *)
                    activation_commands+="# Flow: venv $resolved_language - no activation needed\n"
                    ;;
            esac
            ;;
        nvm)
            # nvm runtime selection
            case "$resolved_language" in
                node)
                    local runtime_selectors=()
                    mapfile -t runtime_selectors < <(discover_runtime_selectors "$root" "$profile_scope")
                    for selector in "${runtime_selectors[@]}"; do
                        IFS='|' read -r strategy lang rel_path version cand_scope <<< "$selector"
                        if [[ "$lang" == "node" && "$strategy" == "nvm" ]]; then
                            activation_commands+=$(activate_node_runtime "nvm" "$version")
                            break
                        fi
                    done
                    ;;
                *)
                    activation_commands+="# Flow: nvm $resolved_language - no activation needed\n"
                    ;;
            esac
            ;;
        node-version)
            # node-version runtime selection
            case "$resolved_language" in
                node)
                    local runtime_selectors=()
                    mapfile -t runtime_selectors < <(discover_runtime_selectors "$root" "$profile_scope")
                    for selector in "${runtime_selectors[@]}"; do
                        IFS='|' read -r strategy lang rel_path version cand_scope <<< "$selector"
                        if [[ "$lang" == "node" && "$strategy" == "node-version" ]]; then
                            activation_commands+=$(activate_node_runtime "node-version" "$version")
                            break
                        fi
                    done
                    ;;
                *)
                    activation_commands+="# Flow: node-version $resolved_language - no activation needed\n"
                    ;;
            esac
            ;;
        system)
            # System runtime - no activation needed
            activation_commands+="# Flow: system runtime - no activation needed\n"
            ;;
        none)
            # No activation
            activation_commands+="# Flow: none - no activation"$'\n'
            ;;
        unconfigured)
            activation_commands+="# Flow: environment not configured"$'\n'
            activation_commands+=$'\\nRun "flow project env set <profile> --strategy <strategy>" to configure'
            ;;
        *)
            activation_commands+="# Flow: unknown strategy '$saved_strategy' - no activation\n"
            ;;
    esac

    # 3. Set Flow environment variables (unless --no-env for shell integration)
    if [[ "$NO_ENV" == false ]]; then
        activation_commands+=$'\n'
        activation_commands+=$(set_flow_env_vars "$profile_name" "$resolved_language" "$saved_strategy" "$saved_target" "$root")
    fi

    # Output activation commands
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$JSON_OUTPUT" == true ]]; then
            jq -n \
                --arg profile "$profile_name" \
                --arg language "$resolved_language" \
                --arg strategy "$saved_strategy" \
                --arg target "$saved_target" \
                --arg root "$root" \
                --arg commands "$activation_commands" \
                '{
                    dry_run: true,
                    profile: $profile,
                    resolved_language: $language,
                    strategy: $strategy,
                    target: $target,
                    root: $root,
                    commands: $commands
                }'
        else
            printf 'Flow: dry run for profile "%s"\n' "$profile_name"
            printf '  language: %s\n' "$resolved_language"
            printf '  strategy: %s\n' "$saved_strategy"
            [[ -n "$saved_target" ]] && printf '  target: %s\n' "$saved_target"
            printf '  root: %s\n' "$root"
            printf '\n'
            printf 'Commands that would be executed:\n'
            printf '%s\n' "$activation_commands"
        fi
        return 0
    fi

    # Execute activation (output for eval)
    printf '%s\n' "$activation_commands"

    # Print status message to stderr (not stdout, which is for eval)
    if [[ "$VERBOSE" == true ]]; then
        printf 'Flow: activated profile "%s"\n' "$profile_name" >&2
        printf '  language: %s\n' "$resolved_language" >&2
        printf '  strategy: %s\n' "$saved_strategy" >&2
        [[ -n "$saved_target" ]] && printf '  target: %s\n' "$saved_target" >&2
    fi
}

# Deactivation command
cmd_deactivate() {
    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON_OUTPUT=true ;;
            -h|--help) print_help; exit 0 ;;
            --version) printf 'activate.sh %s\n' "1.0.0"; exit 0 ;;
            *) printf 'Unknown option: %s\n' "$1" >&2; return 1 ;;
        esac
        shift
    done

    # Generate deactivation commands
    deactivate_previous
}

# Status command
cmd_status() {
    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON_OUTPUT=true ;;
            -h|--help) print_help; exit 0 ;;
            --version) printf 'activate.sh %s\n' "1.0.0"; exit 0 ;;
            *) printf 'Unknown option: %s\n' "$1" >&2; return 1 ;;
        esac
        shift
    done

    # Output current Flow environment state
    if [[ "$JSON_OUTPUT" == true ]]; then
        jq -n \
            --arg profile "${FLOW_ENV_PROFILE:-}" \
            --arg language "${FLOW_ENV_LANGUAGE:-}" \
            --arg strategy "${FLOW_ENV_STRATEGY:-}" \
            --arg target "${FLOW_ENV_TARGET:-}" \
            --arg root "${FLOW_ENV_ROOT:-}" \
            --arg activated "${FLOW_ENV_ACTIVATED:-}" \
            --arg venv "${FLOW_ENV_VENV:-}" \
            '{
                active: (($profile | length) > 0),
                profile: $profile,
                language: $language,
                strategy: $strategy,
                target: $target,
                root: $root,
                activated: $activated,
                venv: $venv
            }'
    else
        if [[ -n "${FLOW_ENV_PROFILE:-}" ]]; then
            printf 'Flow Environment Status\n'
            printf '────────────────────────────────────────\n'
            printf '\n'
            printf 'Profile:\n'
            printf '  %s\n' "$FLOW_ENV_PROFILE"
            printf '\n'
            printf 'Environment:\n'
            printf '  language: %s\n' "${FLOW_ENV_LANGUAGE:-}"
            printf '  strategy: %s\n' "${FLOW_ENV_STRATEGY:-}"
            [[ -n "${FLOW_ENV_TARGET:-}" ]] && printf '  target: %s\n' "$FLOW_ENV_TARGET"
            printf '  root: %s\n' "${FLOW_ENV_ROOT:-}"
            printf '  activated: %s\n' "${FLOW_ENV_ACTIVATED:-}"
            [[ -n "${FLOW_ENV_VENV:-}" ]] && printf '  venv: %s\n' "$FLOW_ENV_VENV"
        else
            printf 'Flow Environment Status\n'
            printf '────────────────────────────────────────\n'
            printf '\n'
            printf 'No Flow environment active.\n'
            printf '\n'
            printf 'Run "flow project activate" to activate a profile.\n'
        fi
    fi
}

print_help() {
    cat <<'EOF'
flow project activate — safe profile activation

USAGE:
    flow project activate [profile] [options]
    flow project deactivate [options]
    flow project status [options]

SUBCOMMANDS:
    activate [profile]   Activate a profile (default: current directory)
    deactivate           Deactivate current Flow environment
    status               Show current Flow environment status

OPTIONS:
    --json               Emit JSON output
    --dry-run            Show intended changes without executing
    -v, --verbose        Verbose output
    -h, --help           Show this help
    --version            Show version

EXAMPLES:
    flow project activate                  # Activate default profile
    flow project activate backend          # Activate specific profile
    flow project activate --dry-run        # Show what would happen
    flow project deactivate                # Deactivate current environment
    flow project status                    # Show current status

ACTIVATION MODEL:
    Phase 3C activates the RESOLVED state from Phase 3B.2.

    For Python:
      existing .venv → source .venv/bin/activate
      uv-managed → activate existing .venv (never auto-sync)
      venv → source .venv/bin/activate
      system → no activation

    For Node:
      nvm → nvm use <version>
      mise → mise use node@<version>
      node-version → node-version <version>
      system → no activation

    For Go/Rust/etc:
      mise → mise use go/rust
      system → no activation

SAFETY:
    - Only activates existing environments (no provisioning)
    - Shell-local state (no cross-shell contamination)
    - Idempotent (no duplicate PATH entries)
    - Rollback on failure
EOF
}

main() {
    local subcmd="${1:-activate}"
    (($# > 0)) && shift

    case "$subcmd" in
        activate)
            cmd_activate "$@"
            ;;
        deactivate)
            cmd_deactivate "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        *)
            print_help
            exit 1
            ;;
    esac
}

main "$@"
