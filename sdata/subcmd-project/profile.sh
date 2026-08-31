#!/usr/bin/env bash
#
# flow project profile — project profile management
# Part of Flow Terminal Phase 3A
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

SCRIPT_VERSION="1.0.0"
SCHEMA_VERSION=1

# Colors
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_CYAN='\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

# JSON output flag
JSON_OUTPUT=false
VERBOSE=false

# XDG paths
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PROJECT_STATE_DIR="$XDG_STATE_HOME/flow/projects"

# Profile types
PROFILE_TYPES=("backend" "frontend" "infrastructure" "devops" "full-stack" "python" "node" "go" "rust" "production" "custom")

# Lock file for atomic writes
LOCK_DIR="$PROJECT_STATE_DIR/.locks"

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

print_human() { [[ "$JSON_OUTPUT" == false ]] && printf '%b\n' "$*"; }
print_json() { [[ "$JSON_OUTPUT" == true ]] && printf '%s\n' "$*"; }

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

# Ensure state directory exists
ensure_state_dir() {
    mkdir -p "$PROJECT_STATE_DIR"
    mkdir -p "$LOCK_DIR"
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

# Load project state
load_project_state() {
    local state_file="$1"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        printf '{}'
    fi
}

# Save project state atomically
save_project_state() {
    local state_file="$1"
    local state_json="$2"
    local tmp_file
    tmp_file=$(mktemp "${state_file}.tmp.XXXXXX")
    printf '%s\n' "$state_json" > "$tmp_file"
    mv "$tmp_file" "$state_file"
}

# Acquire lock for project state
acquire_lock() {
    local state_file="$1"
    local lock_file="$LOCK_DIR/$(basename "$state_file" .json).lock"
    mkdir -p "$LOCK_DIR"
    exec 200>"$lock_file"
    flock -x 200
}

release_lock() {
    flock -u 200 2>/dev/null || true
    exec 200>&-
}

# Create default project state
create_project_state() {
    local root="$1"
    local name="$2"
    local id
    id=$(project_id_from_root "$root")

    cat <<EOF
{
  "schema_version": $SCHEMA_VERSION,
  "project": {
    "id": "$id",
    "root": "$(json_escape "$root")",
    "name": "$(json_escape "$name")"
  },
  "profiles": {},
  "default_profile": null,
  "activation": {
    "implemented": false
  }
}
EOF
}

# Validate profile name
validate_profile_name() {
    local name="$1"
    [[ -n "$name" ]] || return 1
    [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || return 1
    return 0
}

# Validate profile type
validate_profile_type() {
    local type="$1"
    for t in "${PROFILE_TYPES[@]}"; do
        [[ "$t" == "$type" ]] && return 0
    done
    # Allow custom types too
    [[ "$type" =~ ^[a-zA-Z0-9._-]+$ ]] && return 0
    return 1
}

# Normalize scope
normalize_scope() {
    local scope="$1"
    local root="$2"

    scope="${scope#./}"
    scope="${scope#/}"

    if [[ "$scope" == "." ]] || [[ -z "$scope" ]]; then
        printf '.\n'
        return
    fi

    # Prevent directory traversal
    local abs_scope
    abs_scope=$(realpath -m "$root/$scope" 2>/dev/null || printf '%s' "$root/$scope")
    local abs_root
    abs_root=$(realpath "$root" 2>/dev/null || printf '%s' "$root")

    if [[ "$abs_scope" != "$abs_root"* ]]; then
        printf '.\n'
        return
    fi

    local rel_scope
    rel_scope="${abs_scope#$abs_root/}"
    printf '%s\n' "$rel_scope"
}

# Get project root from Phase 2 detector
get_project_context() {
    local root name git_root
    root=$(get_project_root)
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    name=$(get_project_name "$root" "$git_root")
    printf '%s|%s|%s\n' "$root" "$name" "$git_root"
}

# List profiles for current project
cmd_list() {
    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    release_lock

    if [[ "$JSON_OUTPUT" == true ]]; then
        printf '%s\n' "$state_json"
        return
    fi

    local profiles_count
    profiles_count=$(printf '%s' "$state_json" | jq -r '.profiles | length // 0')

    if [[ "$profiles_count" -eq 0 ]]; then
        print_human "${C_YELLOW}No Flow profiles configured for $name.${C_RESET}"
        return
    fi

    print_human "${C_BOLD}${C_CYAN}Profiles for $name${C_RESET}"
    print_human ""

    local default_profile
    default_profile=$(printf '%s' "$state_json" | jq -r '.default_profile // ""')

    local profile_name profile_type profile_scope
    while IFS= read -r profile_name; do
        profile_type=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].type // \"\"")
        profile_scope=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].scope // \".\"")

        if [[ "$profile_name" == "$default_profile" ]]; then
            print_human "  ${C_GREEN}●${C_RESET} $profile_name ${C_DIM}($profile_type)${C_RESET} ${C_BLUE}[default]${C_RESET}"
        else
            print_human "  $profile_name ${C_DIM}($profile_type)${C_RESET}"
        fi
        print_human "    scope: $profile_scope"
        print_human ""
    done < <(printf '%s' "$state_json" | jq -r '.profiles | keys[]')
}

# List all projects with profiles
cmd_list_all() {
    ensure_state_dir

    if [[ "$JSON_OUTPUT" == true ]]; then
        local all_projects=()
        local first=true
        for state_file in "$PROJECT_STATE_DIR"/*.json; do
            [[ -f "$state_file" ]] || continue
            local state_json
            state_json=$(cat "$state_file")
            [[ "$first" == true ]] && first=false || printf ', '
            printf '%s' "$state_json"
        done
        printf '[]\n'  # fallback if no files
        return
    fi

    local found=false
    for state_file in "$PROJECT_STATE_DIR"/*.json; do
        [[ -f "$state_file" ]] || continue
        found=true
        local state_json
        state_json=$(cat "$state_file")

        local proj_name proj_root default_prof
        proj_name=$(printf '%s' "$state_json" | jq -r '.project.name // "unknown"')
        proj_root=$(printf '%s' "$state_json" | jq -r '.project.root // "unknown"')
        default_prof=$(printf '%s' "$state_json" | jq -r '.default_profile // "none"')

        local missing=""
        [[ -d "$proj_root" ]] || missing=" ${C_RED}[missing]${C_RESET}"

        print_human "$proj_name$missing"
        print_human "  default: $default_prof"
        print_human "  root: $proj_root"
        print_human ""
    done

    [[ "$found" == false ]] && print_human "${C_YELLOW}No Flow projects with profiles found.${C_RESET}"
}

# Create a new profile
cmd_create() {
    local profile_name="${1:-}"
    local profile_type="${2:-}"
    local profile_scope="${3:-}"
    local interactive=false

    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    # Initialize state with project info if empty
    if [[ "$state_json" == "{}" ]]; then
        state_json=$(create_project_state "$root" "$name")
    fi

    # Interactive mode if name not provided
    if [[ -z "$profile_name" ]]; then
        interactive=true
        release_lock

        # Run detector to show capabilities
        local detect_output
        detect_output=$("$SCRIPT_DIR/detect.sh" 2>/dev/null || true)

        print_human "${C_BOLD}${C_CYAN}Flow Project Profile Creation${C_RESET}"
        print_human "${C_DIM}────────────────────────────────────────${C_RESET}"
        print_human ""
        print_human "Detected project:"
        print_human "  $name"
        print_human ""
        print_human "Detected capabilities:"
        local caps_line=""
        caps_line=$(bash "$SCRIPT_DIR/detect.sh" --json 2>/dev/null | jq -r '
          [ (select(.repository.type == "git") | "git"),
            (.languages[]?      | .name),
            (.frameworks[]?     | .name),
            (.containers[]?     | .name),
            (.infrastructure[]? | .name),
            (.ci_cd[]?          | .name) ] | unique | join(" · ")' 2>/dev/null)
        [[ -n "$caps_line" ]] && printf '  %s\n' "$caps_line"
        print_human ""

        # Get profile name
        while true; do
            read -rp "Profile name: " profile_name
            validate_profile_name "$profile_name" && break
            print_human "${C_RED}Invalid profile name. Use alphanumeric, dash, underscore, dot.${C_RESET}"
        done

        # Get profile type
        print_human ""
        print_human "Profile type (suggestions: ${PROFILE_TYPES[*]}):"
        read -rp "Profile type: " profile_type
        validate_profile_type "$profile_type" || profile_type="custom"

        # Get scope
        print_human ""
        print_human "Scope (relative to project root, '.' for whole project):"
        read -rp "Scope [.]: " profile_scope
        profile_scope="${profile_scope:-.}"

        # Confirm
        print_human ""
        print_human "Create profile?"
        print_human "  name: $profile_name"
        print_human "  type: $profile_type"
        print_human "  scope: $profile_scope"
        read -rp "[Y/n] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || [[ -z "$confirm" ]] || { print_human "Cancelled."; return 1; }

        acquire_lock "$state_file"
        state_json=$(load_project_state "$state_file")
    fi

    # Validate
    validate_profile_name "$profile_name" || { print_human "${C_RED}Invalid profile name.${C_RESET}"; release_lock; return 1; }
    validate_profile_type "$profile_type" || profile_type="custom"

    # Normalize scope
    profile_scope=$(normalize_scope "$profile_scope" "$root")

    # Check if profile already exists
    local exists
    exists=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"] // empty")
    [[ -n "$exists" ]] && { print_human "${C_RED}Profile '$profile_name' already exists.${C_RESET}"; release_lock; return 1; }

    # Add profile
    local profile_json
    profile_json=$(jq -n \
        --arg name "$profile_name" \
        --arg type "$profile_type" \
        --arg scope "$profile_scope" \
        '{name: $name, type: $type, scope: $scope, environment: {strategy: "unconfigured", target: null, auto_activate: false}}')

    state_json=$(printf '%s' "$state_json" | jq --arg name "$profile_name" --argjson profile "$profile_json" '.profiles[$name] = $profile')

    save_project_state "$state_file" "$state_json"
    release_lock

    print_human "${C_GREEN}Profile '$profile_name' created.${C_RESET}"
}

# Use/select a profile
cmd_use() {
    local profile_name="${1:-}"

    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    if [[ -z "$profile_name" ]]; then
        release_lock
        print_human "${C_RED}Profile name required.${C_RESET}"
        return 1
    fi

    local exists
    exists=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"] // empty")
    [[ -n "$exists" ]] || { print_human "${C_RED}Profile '$profile_name' does not exist.${C_RESET}"; release_lock; return 1; }

    # Selection persists default_profile; shell activation happens via fa
    if [[ "$JSON_OUTPUT" == true ]]; then
        local profile_type profile_scope
        profile_type=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].type")
        profile_scope=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].scope")
        jq -n \
            --arg name "$profile_name" \
            --arg type "$profile_type" \
            --arg scope "$profile_scope" \
            '{selected: true, profile: {name: $name, type: $type, scope: $scope}, activation: {implemented: false}}'
    else
        # Persist the selection as the project's default profile — this is
        # what `fa`/activate resolves on every future activation.
        state_json=$(printf '%s' "$state_json" | jq --arg n "$profile_name" '.default_profile = $n')
        save_project_state "$state_file" "$state_json"
        print_human "${C_GREEN}Selected profile: $profile_name (default)${C_RESET}"
        print_human "${C_DIM}Activate this shell with: fa${C_RESET}"
    fi

    release_lock
}

# Set default profile
cmd_set_default() {
    local profile_name="${1:-}"

    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    if [[ -z "$profile_name" ]]; then
        release_lock
        print_human "${C_RED}Profile name required.${C_RESET}"
        return 1
    fi

    local exists
    exists=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"] // empty")
    [[ -n "$exists" ]] || { print_human "${C_RED}Profile '$profile_name' does not exist.${C_RESET}"; release_lock; return 1; }

    state_json=$(printf '%s' "$state_json" | jq --arg name "$profile_name" '.default_profile = $name')
    save_project_state "$state_file" "$state_json"
    release_lock

    print_human "${C_GREEN}Default profile set to '$profile_name'.${C_RESET}"
}

# Show project status (detection + profiles)
cmd_status() {
    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    release_lock

    # Get detection output
    local detect_json
    detect_json=$("$SCRIPT_DIR/detect.sh" --json 2>/dev/null || printf '{}')

    if [[ "$JSON_OUTPUT" == true ]]; then
        local combined
        local project_json
        if [[ "$(printf '%s' "$state_json" | jq -r '.project // empty')" != "" ]]; then
            project_json=$(printf '%s' "$state_json" | jq '.project')
        else
            project_json=$(jq -n \
                --arg root "$root" \
                --arg name "$name" \
                --arg id "$(project_id_from_root "$root")" \
                '{id: $id, root: $root, name: $name}')
        fi
        combined=$(jq -n \
            --argjson project "$project_json" \
            --argjson state "$state_json" \
            --argjson detect "$detect_json" \
            '{project: $project, profiles: $state.profiles, default_profile: $state.default_profile, detection: $detect, activation: {implemented: false}}')
        printf '%s\n' "$combined"
        return
    fi

    print_human "${C_BOLD}${C_CYAN}Flow Project Status${C_RESET}"
    print_human "${C_DIM}────────────────────────────────────────${C_RESET}"
    print_human ""
    print_human "Root"
    print_human "  $root"
    print_human ""
    print_human "Project"
    print_human "  $name"
    print_human ""

    # Detected capabilities
    local detect_types=("languages" "frameworks" "package_managers" "containers" "databases" "infrastructure" "kubernetes" "ci_cd" "task_runners" "hosting")
    local detected_any=false
    for dt in "${detect_types[@]}"; do
        local count
        count=$(printf '%s' "$detect_json" | jq -r ".$dt | length // 0")
        if [[ "$count" -gt 0 ]]; then
            [[ "$detected_any" == false ]] && { print_human "Detected"; detected_any=true; }
            local names
            names=$(printf '%s' "$detect_json" | jq -r ".$dt[].name" | paste -sd ", " -)
            print_human "  $names"
        fi
    done
    [[ "$detected_any" == false ]] && print_human "  ${C_DIM}No capabilities detected${C_RESET}"
    print_human ""

    # Profiles
    local profiles_count
    profiles_count=$(printf '%s' "$state_json" | jq -r '.profiles | length // 0')

    if [[ "$profiles_count" -gt 0 ]]; then
        print_human "Profiles"
        local default_profile
        default_profile=$(printf '%s' "$state_json" | jq -r '.default_profile // ""')
        local profile_name profile_type profile_scope saved_strategy saved_target
        while IFS= read -r profile_name; do
            profile_type=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].type // \"\"")
            profile_scope=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].scope // \".\"")
            saved_strategy=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].environment.strategy // \"unconfigured\"")
            saved_target=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"].environment.target // \"\"")
            if [[ "$profile_name" == "$default_profile" ]]; then
                print_human "  ${C_GREEN}●${C_RESET} $profile_name ${C_DIM}($profile_type)${C_RESET} ${C_BLUE}[default]${C_RESET}"
            else
                print_human "  $profile_name ${C_DIM}($profile_type)${C_RESET}"
            fi
            print_human "    scope: $profile_scope"
            if [[ "$saved_strategy" != "unconfigured" && -n "$saved_target" && "$saved_target" != "null" ]]; then
                print_human "    env: $saved_strategy ($saved_target)"
            elif [[ "$saved_strategy" != "unconfigured" ]]; then
                print_human "    env: $saved_strategy"
            else
                print_human "    env: ${C_DIM}not configured${C_RESET}"
            fi
        done < <(printf '%s' "$state_json" | jq -r '.profiles | keys[]')
    else
        print_human "Profiles"
        print_human "  ${C_YELLOW}None configured${C_RESET}"
    fi
    print_human ""

    # Default
    local default_profile
    default_profile=$(printf '%s' "$state_json" | jq -r '.default_profile // "none"')
    print_human "Default"
    print_human "  $default_profile"
    print_human ""

    # Environment candidates from detector
    local py_envs node_pm node_vf
    py_envs=$(printf '%s' "$detect_json" | jq -r '.environment_candidates[]? | select(.language=="python") | .environments[]?.path' 2>/dev/null | paste -sd ", " -)
    node_pm=$(printf '%s' "$detect_json" | jq -r '.environment_candidates[]? | select(.language=="node") | .package_manager' 2>/dev/null)
    node_vf=$(printf '%s' "$detect_json" | jq -r '.environment_candidates[]? | select(.language=="node") | .version_file' 2>/dev/null)

    print_human "Environment"
    if [[ -n "$py_envs" && "$py_envs" != "null" ]]; then
        print_human "  Python environments: $py_envs"
    fi
    if [[ -n "$node_pm" && "$node_pm" != "null" ]]; then
        print_human "  Node package manager: $node_pm"
    fi
    if [[ -n "$node_vf" && "$node_vf" != "null" ]]; then
        print_human "  Node version file: $node_vf"
    fi
    if [[ -z "$py_envs" && -z "$node_pm" ]]; then
        print_human "  ${C_DIM}Not configured${C_RESET}"
    fi
    print_human ""

    print_human "Activation"
    print_human "  ${C_DIM}run: fa  (activates selected profile in this shell)${C_RESET}"
}

# Delete a profile
cmd_delete() {
    local profile_name="${1:-}"

    local project_context root name git_root
    project_context=$(get_project_context)
    IFS='|' read -r root name git_root <<< "$project_context"

    local state_file
    state_file=$(project_state_file "$root")

    ensure_state_dir
    acquire_lock "$state_file"

    local state_json
    state_json=$(load_project_state "$state_file")

    if [[ -z "$profile_name" ]]; then
        release_lock
        print_human "${C_RED}Profile name required.${C_RESET}"
        return 1
    fi

    local exists
    exists=$(printf '%s' "$state_json" | jq -r ".profiles[\"$profile_name\"] // empty")
    [[ -n "$exists" ]] || { print_human "${C_RED}Profile '$profile_name' does not exist.${C_RESET}"; release_lock; return 1; }

    # Check if it's the default
    local default_profile
    default_profile=$(printf '%s' "$state_json" | jq -r '.default_profile // ""')
    local new_default=""

    if [[ "$profile_name" == "$default_profile" ]]; then
        # Need to choose new default or clear
        local remaining
        remaining=$(printf '%s' "$state_json" | jq -r ".profiles | del(.[\"$profile_name\"]) | keys[]")
        if [[ -n "$remaining" ]]; then
            print_human "Profile '$profile_name' is the default. Choose new default:"
            print_human "$remaining" | sed 's/^/  /'
            read -rp "New default (or empty to clear): " new_default
            validate_profile_name "$new_default" || new_default=""
        fi
    fi

    # Delete profile
    state_json=$(printf '%s' "$state_json" | jq --arg name "$profile_name" 'del(.profiles[$name])')

    # Update default if needed
    if [[ "$profile_name" == "$default_profile" ]]; then
        if [[ -n "$new_default" ]]; then
            state_json=$(printf '%s' "$state_json" | jq --arg name "$new_default" '.default_profile = $name')
        else
            state_json=$(printf '%s' "$state_json" | jq '.default_profile = null')
        fi
    fi

    # If no profiles left, we could clean up but spec says keep identity
    save_project_state "$state_file" "$state_json"
    release_lock

    print_human "${C_GREEN}Profile '$profile_name' deleted.${C_RESET}"
}

# Print help
print_help() {
    cat <<'EOF'
flow project profile — project profile management

USAGE:
    flow project profile <subcommand> [options]

SUBCOMMANDS:
    list              List profiles for current project
    list-all          List all projects with profiles
    create [name]     Create a new profile (interactive if name omitted)
    use <name>        Select a profile for current session
    set-default <name> Set persistent default profile
    status            Show project status (detection + profiles)
    delete <name>     Delete a profile

OPTIONS:
    --json            Emit JSON output
    -v, --verbose     Verbose output
    -h, --help        Show this help
    --version         Show version

PROFILE TYPES (suggestions):
    backend, frontend, infrastructure, devops, full-stack,
    python, node, go, rust, production, custom

EXAMPLES:
    flow project profile create backend
    flow project profile use backend
    flow project profile set-default backend
    flow project profile status
    flow project profile delete old-profile
    flow project profile list-all
EOF
}

# Main
main() {
    local args=()
    local subcmd=""

    # Parse all args, separating flags from subcommand and its args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON_OUTPUT=true ;;
            -v|--verbose) VERBOSE=true ;;
            -h|--help) print_help; exit 0 ;;
            --version) printf 'profile.sh %s (schema %s)\n' "$SCRIPT_VERSION" "$SCHEMA_VERSION"; exit 0 ;;
            *)
                if [[ -z "$subcmd" ]]; then
                    subcmd="$1"
                else
                    args+=("$1")
                fi
                ;;
        esac
        shift
    done

    subcmd="${subcmd:-list}"

    case "$subcmd" in
        list)
            cmd_list
            ;;
        list-all)
            cmd_list_all
            ;;
        create)
            cmd_create "${args[@]}"
            ;;
        use)
            cmd_use "${args[@]}"
            ;;
        set-default)
            cmd_set_default "${args[@]}"
            ;;
        status)
            cmd_status
            ;;
        delete)
            cmd_delete "${args[@]}"
            ;;
        *)
            print_help
            exit 1
            ;;
    esac
}

main "$@"