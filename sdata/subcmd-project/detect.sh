#!/usr/bin/env bash
#
# flow project detect — read-only project intelligence
# Part of Flow Terminal Phase 2
#
# Schema notes (documented per spec §25's instruction not to expose
# experimental fields as if final):
#   - Top-level keys are lowercase snake_case, matching §25 exactly.
#   - Every capability (languages/frameworks/...) is DEDUPLICATED: if two
#     signals point at the same name (e.g. manage.py AND a pyproject.toml
#     "django" dependency), they merge into ONE entry. Confidence takes the
#     higher of the two; evidence becomes an array of every distinct signal
#     seen (§17: "several weak markers can combine to medium/high").
#   - environment_candidates is an ARRAY (per the §25 canonical schema), but
#     each element is a rich per-language object (per the §7 example), e.g.
#     {"language":"python","detected":true,"frameworks":[...],
#      "environments":[{"path":".venv","type":"venv","exists":true}],
#      "uv_lock":true}
#   - runtime_hints is an ARRAY of typed objects, e.g.
#     {"type":"node_version_file","file":".nvmrc"}
#   - "databases", "workspaces", and "hosting" are Flow-specific additions
#     beyond the base §25 schema (harmless additive keys, not a breaking
#     change). "hosting" is static file-marker evidence only (e.g. a
#     vercel.json or serverless.yml existing) — it never queries a cloud
#     provider, reads credentials, or checks an active profile. That's
#     Phase 7 (DevOps context providers) by the spec's own design, not
#     Phase 2's job.

set -Eeuo pipefail

SCRIPT_VERSION="3.0.0"
SCHEMA_VERSION=2

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
JSON_OUTPUT=false
VERBOSE=false

print_help() {
    cat <<'EOF'
flow project detect — read-only project intelligence

USAGE:
    detect.sh [OPTIONS]

OPTIONS:
    --json          Emit structured JSON instead of human-readable output
    -v, --verbose   Include confidence levels and evidence in human output
    -h, --help      Show this help text
    --version       Show script version

This tool is strictly read-only: it never activates an environment,
installs anything, creates a venv, or modifies project files.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUTPUT=true ;;
        -v|--verbose) VERBOSE=true ;;
        -h|--help) print_help; exit 0 ;;
        --version) printf 'detect.sh %s (schema %s)\n' "$SCRIPT_VERSION" "$SCHEMA_VERSION"; exit 0 ;;
        *)
            printf 'Unknown option: %s\n' "$arg" >&2
            print_help >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
    C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_CYAN='\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
print_human() { [[ "$JSON_OUTPUT" == false ]] && printf '%b\n' "$*"; }

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

get_git_root() { git rev-parse --show-toplevel 2>/dev/null || return 1; }

find_project_root() {
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
    return 1
}

get_project_name() {
    local root="$1" git_root="$2"

    if [[ -f "$root/package.json" ]]; then
        local n
        n=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$root/package.json" 2>/dev/null \
            | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/' | xargs)
        [[ -n "$n" ]] && { printf '%s\n' "$n"; return; }
    fi
    if [[ -f "$root/pyproject.toml" ]]; then
        local n
        n=$(grep -E '^name\s*=' "$root/pyproject.toml" 2>/dev/null | head -1 | sed -E 's/.*=\s*"?([^"]+)"?/\1/' | xargs)
        [[ -n "$n" ]] && { printf '%s\n' "$n"; return; }
    fi
    if [[ -f "$root/Cargo.toml" ]]; then
        local n
        n=$(grep -E '^name\s*=' "$root/Cargo.toml" 2>/dev/null | head -1 | sed -E 's/.*=\s*"([^"]+)".*/\1/' | xargs)
        [[ -n "$n" ]] && { printf '%s\n' "$n"; return; }
    fi
    if [[ -n "$git_root" && "$git_root" == "$root" ]]; then
        basename "$git_root"; return
    fi
    basename "$root"
}

pkgjson_has_dep() {
    local content="$1" dep="$2"
    [[ -z "$content" ]] && return 1
    [[ "$content" =~ \"${dep}\"[[:space:]]*:[[:space:]]*\" ]]
}

# ---------------------------------------------------------------------------
# Capability store — deduplicating, evidence-merging, confidence-upgrading.
#
#   CAP_CONF["category:name"]  -> "high" | "medium" | "low"
#   CAP_EVID["category:name"]  -> evidence strings joined by \x1f (unit sep)
#   CAP_ORDER                  -> ordered list of unique "category:name" keys
#
# No eval anywhere: associative-array keys are just strings, safely indexed.
# ---------------------------------------------------------------------------
declare -A CAP_CONF=()
declare -A CAP_EVID=()
declare -a CAP_ORDER=()

conf_rank() {
    case "$1" in
        high) printf 3 ;;
        medium) printf 2 ;;
        low) printf 1 ;;
        *) printf 0 ;;
    esac
}

add_cap() {
    local cat="$1" name="$2" conf="$3" evid="$4"
    local key="${cat}:${name}"

    if [[ -z "${CAP_CONF[$key]+x}" ]]; then
        CAP_CONF["$key"]="$conf"
        CAP_EVID["$key"]="$evid"
        CAP_ORDER+=("$key")
        return 0
    fi

    # Upgrade confidence to the higher of the two.
    local cur_rank new_rank
    cur_rank=$(conf_rank "${CAP_CONF[$key]}")
    new_rank=$(conf_rank "$conf")
    ((new_rank > cur_rank)) && CAP_CONF["$key"]="$conf"

    # Merge evidence, deduplicated (exact-token match against \x1f-delimited list).
    local existing="${CAP_EVID[$key]}"
    case $'\x1f'"$existing"$'\x1f' in
        *$'\x1f'"$evid"$'\x1f'*) : ;;  # already present, skip
        *) CAP_EVID["$key"]="${existing}"$'\x1f'"${evid}" ;;
    esac
    return 0
}

add_evidence() { EVIDENCE+=("$1"); }

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
detect_capabilities() {
    local root="$1"

    EVIDENCE=(); RUNTIME_HINTS=(); WORKSPACES=()
    CAP_CONF=(); CAP_EVID=(); CAP_ORDER=()

    PY_DETECTED=false; PY_UV_LOCK=false
    declare -ga PY_ENVS=()          # "path|type"
    declare -ga PY_FRAMEWORK_NAMES=()

    NODE_DETECTED=false
    NODE_PKG_MANAGER=""
    NODE_VERSION_FILE=""

    # === Python ===
    local -a python_frameworks=()

    if [[ -f "$root/manage.py" ]]; then
        PY_DETECTED=true
        python_frameworks+=("django|high|manage.py")
        add_evidence "manage.py"
    fi
    if [[ -f "$root/pyproject.toml" ]]; then
        PY_DETECTED=true
        add_evidence "pyproject.toml"
        grep -q 'django'  "$root/pyproject.toml" 2>/dev/null && python_frameworks+=("django|medium|pyproject.toml dependency")
        grep -q 'fastapi' "$root/pyproject.toml" 2>/dev/null && python_frameworks+=("fastapi|medium|pyproject.toml dependency")
        grep -q 'flask'   "$root/pyproject.toml" 2>/dev/null && python_frameworks+=("flask|medium|pyproject.toml dependency")
        grep -q 'pytest'  "$root/pyproject.toml" 2>/dev/null && python_frameworks+=("pytest|low|pyproject.toml dependency")
        grep -q 'poetry'  "$root/pyproject.toml" 2>/dev/null && add_cap package_managers "poetry" "medium" "pyproject.toml"
    fi
    if [[ -f "$root/uv.lock" ]]; then
        PY_DETECTED=true; PY_UV_LOCK=true
        add_evidence "uv.lock"
        add_cap package_managers "uv" "high" "uv.lock"
    fi
    if [[ -f "$root/requirements.txt" ]] || [[ -d "$root/requirements" ]]; then
        PY_DETECTED=true
        add_evidence "requirements.txt"
        add_cap package_managers "pip" "medium" "requirements.txt"
    fi
    if [[ -f "$root/Pipfile" ]]; then
        PY_DETECTED=true
        add_evidence "Pipfile"
        add_cap package_managers "pipenv" "high" "Pipfile"
    fi
    if [[ -f "$root/poetry.lock" ]]; then
        PY_DETECTED=true
        add_evidence "poetry.lock"
        add_cap package_managers "poetry" "high" "poetry.lock"
    fi
    if [[ -f "$root/setup.py" ]] || [[ -f "$root/setup.cfg" ]]; then
        PY_DETECTED=true
        add_evidence "setup.py/setup.cfg"
    fi
    if [[ -f "$root/.python-version" ]]; then
        add_evidence ".python-version"
        RUNTIME_HINTS+=('{"type":"python_version_file","file":".python-version"}')
    fi
    for env in ".venv" "venv" "env"; do
        [[ -d "$root/$env" ]] && PY_ENVS+=("$env|venv")
    done
    if [[ "$PY_DETECTED" == true ]]; then
        add_cap languages "python" "high" "multiple indicators"
        for fw in "${python_frameworks[@]}"; do
            IFS='|' read -r fw_name fw_conf fw_ev <<< "$fw"
            add_cap frameworks "$fw_name" "$fw_conf" "$fw_ev"
            case $'\x1f'"${PY_FRAMEWORK_NAMES[*]-}"$'\x1f' in
                *$'\x1f'"$fw_name"$'\x1f'*) : ;;  # already recorded
                *) PY_FRAMEWORK_NAMES+=("$fw_name") ;;
            esac
        done
    fi

    # === Node / JavaScript / TypeScript ===
    if [[ -f "$root/package.json" ]]; then
        NODE_DETECTED=true
        add_evidence "package.json"
        add_cap languages "javascript" "high" "package.json"
        if [[ -f "$root/tsconfig.json" ]]; then
            add_cap languages "typescript" "high" "tsconfig.json"
            add_evidence "tsconfig.json"
        else
            add_cap languages "typescript" "medium" "package.json (likely)"
        fi

        local pkgjson_content=""
        pkgjson_content="$(<"$root/package.json")"

        pkgjson_has_dep "$pkgjson_content" "next"          && add_cap frameworks "next.js" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "nuxt"           && add_cap frameworks "nuxt" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "react"          && add_cap frameworks "react" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "vue"            && add_cap frameworks "vue" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "@angular/core"  && add_cap frameworks "angular" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "svelte"         && add_cap frameworks "svelte" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "@nestjs/core"   && add_cap frameworks "nest.js" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "express"        && add_cap frameworks "express" "medium" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "fastify"        && add_cap frameworks "fastify" "medium" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "astro"          && add_cap frameworks "astro" "high" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "remix"          && add_cap frameworks "remix" "medium" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "vite"           && add_cap frameworks "vite" "low" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "electron"       && add_cap frameworks "electron" "medium" "package.json dependency"
        pkgjson_has_dep "$pkgjson_content" "jest"           && add_cap frameworks "jest" "low" "package.json dependency (test)"
        pkgjson_has_dep "$pkgjson_content" "vitest"         && add_cap frameworks "vitest" "low" "package.json dependency (test)"

        if [[ -f "$root/pnpm-lock.yaml" ]]; then
            add_cap package_managers "pnpm" "high" "pnpm-lock.yaml"; add_evidence "pnpm-lock.yaml"
            NODE_PKG_MANAGER="pnpm"
        elif [[ -f "$root/yarn.lock" ]]; then
            add_cap package_managers "yarn" "high" "yarn.lock"; add_evidence "yarn.lock"
            NODE_PKG_MANAGER="yarn"
        elif [[ -f "$root/bun.lock" ]] || [[ -f "$root/bun.lockb" ]]; then
            add_cap package_managers "bun" "high" "bun.lock"; add_evidence "bun.lock"
            NODE_PKG_MANAGER="bun"
        elif [[ -f "$root/package-lock.json" ]]; then
            add_cap package_managers "npm" "high" "package-lock.json"; add_evidence "package-lock.json"
            NODE_PKG_MANAGER="npm"
        else
            add_cap package_managers "npm" "medium" "package.json (default)"
            NODE_PKG_MANAGER="npm"
        fi

        if [[ -f "$root/.nvmrc" ]]; then
            add_evidence ".nvmrc"; NODE_VERSION_FILE=".nvmrc"
            RUNTIME_HINTS+=('{"type":"node_version_file","file":".nvmrc"}')
        elif [[ -f "$root/.node-version" ]]; then
            add_evidence ".node-version"; NODE_VERSION_FILE=".node-version"
            RUNTIME_HINTS+=('{"type":"node_version_file","file":".node-version"}')
        fi

        if grep -q '"workspaces"' "$root/package.json" 2>/dev/null; then
            WORKSPACES+=('{"name":"npm/yarn workspaces","confidence":"medium","evidence":"package.json workspaces field"}')
        fi
        [[ -f "$root/pnpm-workspace.yaml" ]] && WORKSPACES+=('{"name":"pnpm workspaces","confidence":"high","evidence":"pnpm-workspace.yaml"}')
        [[ -f "$root/nx.json" ]]             && WORKSPACES+=('{"name":"nx","confidence":"high","evidence":"nx.json"}')
        [[ -f "$root/turbo.json" ]]          && WORKSPACES+=('{"name":"turborepo","confidence":"high","evidence":"turbo.json"}')
        [[ -f "$root/lerna.json" ]]          && WORKSPACES+=('{"name":"lerna","confidence":"high","evidence":"lerna.json"}')
    fi

    # === Go ===
    if [[ -f "$root/go.mod" ]]; then
        add_cap languages "go" "high" "go.mod"
        add_evidence "go.mod"
        [[ -f "$root/go.sum" ]] && add_evidence "go.sum"
        grep -q 'gin-gonic/gin' "$root/go.mod" 2>/dev/null && add_cap frameworks "gin" "medium" "go.mod dependency"
        grep -q 'labstack/echo' "$root/go.mod" 2>/dev/null && add_cap frameworks "echo" "medium" "go.mod dependency"
        grep -q 'gofiber/fiber' "$root/go.mod" 2>/dev/null && add_cap frameworks "fiber" "medium" "go.mod dependency"
    fi

    # === Rust ===
    if [[ -f "$root/Cargo.toml" ]]; then
        add_cap languages "rust" "high" "Cargo.toml"
        add_evidence "Cargo.toml"
        [[ -f "$root/Cargo.lock" ]] && add_evidence "Cargo.lock"
        grep -q 'actix-web' "$root/Cargo.toml" 2>/dev/null && add_cap frameworks "actix-web" "medium" "Cargo.toml dependency"
        grep -q '^axum'     "$root/Cargo.toml" 2>/dev/null && add_cap frameworks "axum" "medium" "Cargo.toml dependency"
        grep -q '\[workspace\]' "$root/Cargo.toml" 2>/dev/null && WORKSPACES+=('{"name":"cargo workspace","confidence":"high","evidence":"Cargo.toml [workspace]"}')
    fi

    # === Java / JVM (incl. Kotlin, Scala) ===
    if [[ -f "$root/pom.xml" ]]; then
        add_cap languages "java" "high" "pom.xml"
        add_cap package_managers "maven" "high" "pom.xml"
        add_evidence "pom.xml"
        grep -q 'spring-boot' "$root/pom.xml" 2>/dev/null && add_cap frameworks "spring-boot" "high" "pom.xml dependency"
    fi
    if [[ -f "$root/build.gradle" ]] || [[ -f "$root/build.gradle.kts" ]]; then
        add_cap languages "java" "high" "build.gradle"
        add_cap package_managers "gradle" "high" "build.gradle"
        add_evidence "build.gradle"
        [[ -f "$root/build.gradle.kts" ]] && add_cap languages "kotlin" "medium" "build.gradle.kts"
        grep -qE 'spring-boot' "$root"/build.gradle* 2>/dev/null && add_cap frameworks "spring-boot" "high" "build.gradle dependency"
    fi
    if compgen -G "$root/*.scala" >/dev/null 2>&1 || [[ -f "$root/build.sbt" ]]; then
        add_cap languages "scala" "high" "build.sbt / *.scala"
        [[ -f "$root/build.sbt" ]] && { add_cap package_managers "sbt" "high" "build.sbt"; add_evidence "build.sbt"; }
    fi

    # === PHP ===
    if [[ -f "$root/composer.json" ]]; then
        add_cap languages "php" "high" "composer.json"
        add_cap package_managers "composer" "high" "composer.json"
        add_evidence "composer.json"
        [[ -f "$root/composer.lock" ]] && add_evidence "composer.lock"
        grep -q 'laravel/framework' "$root/composer.json" 2>/dev/null && add_cap frameworks "laravel" "high" "composer.json dependency"
        grep -q 'symfony/'          "$root/composer.json" 2>/dev/null && add_cap frameworks "symfony" "medium" "composer.json dependency"
    fi

    # === Ruby ===
    if [[ -f "$root/Gemfile" ]]; then
        add_cap languages "ruby" "high" "Gemfile"
        add_cap package_managers "bundler" "high" "Gemfile"
        add_evidence "Gemfile"
        [[ -f "$root/Gemfile.lock" ]] && add_evidence "Gemfile.lock"
        grep -q "gem ['\"]rails" "$root/Gemfile" 2>/dev/null && add_cap frameworks "rails" "high" "Gemfile dependency"
    fi

    # === .NET / C# ===
    if compgen -G "$root/*.csproj" >/dev/null 2>&1 || compgen -G "$root/*.sln" >/dev/null 2>&1; then
        add_cap languages "csharp" "high" "*.csproj / *.sln"
        add_cap package_managers "nuget" "high" "*.csproj"
        add_evidence ".NET project file"
        grep -ql 'Microsoft.AspNetCore' "$root"/*.csproj 2>/dev/null && add_cap frameworks "asp.net-core" "medium" "*.csproj dependency"
    fi

    # === Swift ===
    if [[ -f "$root/Package.swift" ]]; then
        add_cap languages "swift" "high" "Package.swift"
        add_cap package_managers "spm" "high" "Package.swift"
        add_evidence "Package.swift"
    fi
    if compgen -G "$root/*.xcodeproj" >/dev/null 2>&1; then
        add_cap languages "swift" "medium" "*.xcodeproj"
        add_evidence "*.xcodeproj"
    fi

    # === Dart / Flutter ===
    if [[ -f "$root/pubspec.yaml" ]]; then
        add_cap languages "dart" "high" "pubspec.yaml"
        add_cap package_managers "pub" "high" "pubspec.yaml"
        add_evidence "pubspec.yaml"
        grep -q '^\s*flutter:' "$root/pubspec.yaml" 2>/dev/null && add_cap frameworks "flutter" "high" "pubspec.yaml"
    fi

    # === Elixir ===
    if [[ -f "$root/mix.exs" ]]; then
        add_cap languages "elixir" "high" "mix.exs"
        add_cap package_managers "mix" "high" "mix.exs"
        add_evidence "mix.exs"
        grep -q ':phoenix' "$root/mix.exs" 2>/dev/null && add_cap frameworks "phoenix" "high" "mix.exs dependency"
    fi

    # === Haskell / OCaml ===
    if [[ -f "$root/stack.yaml" ]] || compgen -G "$root/*.cabal" >/dev/null 2>&1; then
        add_cap languages "haskell" "high" "stack.yaml / *.cabal"
        add_evidence "haskell project file"
    fi
    if [[ -f "$root/dune-project" ]]; then
        add_cap languages "ocaml" "high" "dune-project"
        add_evidence "dune-project"
    fi

    # === Lua ===
    if compgen -G "$root/*.lua" >/dev/null 2>&1 || [[ -f "$root/rockspec" ]] || compgen -G "$root/*.rockspec" >/dev/null 2>&1; then
        add_cap languages "lua" "high" "*.lua / rockspec"
        add_evidence "Lua project file"
        [[ -f "$root/lua-lsp.toml" ]] && add_cap frameworks "lua-lsp" "medium" "lua-lsp.toml"
        grep -q 'luv' "$root"/*.rockspec 2>/dev/null && add_cap frameworks "luv" "medium" "rockspec dependency"
    fi

    # === QML / Qt Quick ===
    if compgen -G "$root/*.qml" >/dev/null 2>&1; then
        add_cap languages "qml" "high" "*.qml"
        add_evidence "QML file"
        grep -ql 'import QtQuick' "$root"/*.qml 2>/dev/null && add_cap frameworks "qt-quick" "high" "*.qml QtQuick import"
        grep -ql 'import QtQuick.Controls' "$root"/*.qml 2>/dev/null && add_cap frameworks "qt-quick-controls" "high" "*.qml QtQuick.Controls import"
        [[ -f "$root/CMakeLists.txt" ]] && grep -q 'qt_add_qml_module\|qt6_add_qml_module' "$root/CMakeLists.txt" 2>/dev/null && add_cap frameworks "qt6-qml-module" "high" "CMakeLists.txt qt_add_qml_module"
    fi

    # === C / C++ ===
    if [[ -f "$root/CMakeLists.txt" ]]; then
        add_cap languages "cpp" "medium" "CMakeLists.txt"
        add_evidence "CMakeLists.txt"
    fi

    # === Docker / Containers ===
    if [[ -f "$root/Dockerfile" ]] || [[ -f "$root/Containerfile" ]]; then
        add_cap containers "docker" "high" "Dockerfile"
        add_evidence "Dockerfile"
    fi
    if [[ -f "$root/compose.yaml" ]] || [[ -f "$root/compose.yml" ]] \
       || [[ -f "$root/docker-compose.yml" ]] || [[ -f "$root/docker-compose.yaml" ]]; then
        add_cap containers "compose" "high" "compose file"
        add_evidence "compose file"
        local cfile
        for cfile in "$root"/compose.yaml "$root"/compose.yml "$root"/docker-compose.yml "$root"/docker-compose.yaml; do
            [[ -f "$cfile" ]] || continue
            grep -qiE 'image:\s*.*postgres' "$cfile" 2>/dev/null && add_cap databases "postgresql" "medium" "$(basename "$cfile") image"
            grep -qiE 'image:\s*.*mysql'    "$cfile" 2>/dev/null && add_cap databases "mysql" "medium" "$(basename "$cfile") image"
            grep -qiE 'image:\s*.*mongo'    "$cfile" 2>/dev/null && add_cap databases "mongodb" "medium" "$(basename "$cfile") image"
            grep -qiE 'image:\s*.*redis'    "$cfile" 2>/dev/null && add_cap databases "redis" "medium" "$(basename "$cfile") image"
        done
    fi

    # === Terraform / OpenTofu ===
    # §22 explicitly allows a bounded look inside terraform/ (unlike arbitrary
    # subdirectories, which are deliberately NOT scanned for language markers).
    if compgen -G "$root/*.tf" >/dev/null 2>&1 || compgen -G "$root/*.tf.json" >/dev/null 2>&1; then
        add_cap infrastructure "terraform" "high" "*.tf files"
        add_evidence "terraform files"
    elif [[ -d "$root/terraform" ]] && compgen -G "$root/terraform/*.tf" >/dev/null 2>&1; then
        add_cap infrastructure "terraform" "high" "terraform/*.tf files"
        add_evidence "terraform/ directory"
    fi
    [[ -d "$root/.terraform" ]] && add_evidence ".terraform directory"
    { compgen -G "$root/*.tfvars" >/dev/null 2>&1 || [[ -f "$root/terraform.tfvars" ]]; } && add_evidence "tfvars files"
    { [[ -f "$root/pulumi.yaml" ]] || [[ -f "$root/Pulumi.yaml" ]]; } && { add_cap infrastructure "pulumi" "high" "Pulumi.yaml"; add_evidence "Pulumi.yaml"; }
    [[ -f "$root/ansible.cfg" ]] && { add_cap infrastructure "ansible" "high" "ansible.cfg"; add_evidence "ansible.cfg"; }

    # === Kubernetes / Helm ===
    for k8s_dir in "k8s" "kubernetes" "manifests"; do
        if [[ -d "$root/$k8s_dir" ]]; then
            add_cap kubernetes "kubernetes" "medium" "$k8s_dir/ directory"
            add_evidence "$k8s_dir/ directory"
            break
        fi
    done
    [[ -f "$root/kustomization.yaml" ]] && { add_cap kubernetes "kustomize" "high" "kustomization.yaml"; add_evidence "kustomization.yaml"; }
    if [[ -f "$root/Chart.yaml" ]]; then
        add_cap kubernetes "helm" "high" "Chart.yaml"
        add_cap containers "helm" "medium" "Chart.yaml"
        add_evidence "Chart.yaml"
    fi
    { [[ -d "$root/helm" ]] || [[ -d "$root/charts" ]]; } && {
        add_cap kubernetes "helm" "medium" "helm/ or charts/ directory"
        add_evidence "helm/ or charts/ directory"
    }
    # Cheap, bounded YAML content sniff — only inside known k8s dirs, only small files.
    for k8s_dir in "k8s" "kubernetes" "manifests"; do
        if [[ -d "$root/$k8s_dir" ]]; then
            while IFS= read -r -d '' file; do
                [[ ${#file} -gt 10000 ]] && continue
                if head -20 "$file" 2>/dev/null | grep -qE '^apiVersion:|^kind:|^metadata:'; then
                    add_cap kubernetes "kubernetes" "low" "YAML with k8s markers in $k8s_dir/"
                    break
                fi
            done < <(find "$root/$k8s_dir" -maxdepth 2 -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
            break
        fi
    done

    # === CI/CD ===
    [[ -d "$root/.github/workflows" ]] && { add_cap ci_cd "github-actions" "high" ".github/workflows/"; add_evidence ".github/workflows/"; }
    [[ -f "$root/.gitlab-ci.yml" ]]    && { add_cap ci_cd "gitlab-ci" "high" ".gitlab-ci.yml"; add_evidence ".gitlab-ci.yml"; }
    [[ -f "$root/Jenkinsfile" ]]       && { add_cap ci_cd "jenkins" "high" "Jenkinsfile"; add_evidence "Jenkinsfile"; }
    [[ -f "$root/.circleci/config.yml" ]] && { add_cap ci_cd "circleci" "high" ".circleci/config.yml"; add_evidence ".circleci/config.yml"; }
    [[ -f "$root/azure-pipelines.yml" ]]  && { add_cap ci_cd "azure-pipelines" "high" "azure-pipelines.yml"; add_evidence "azure-pipelines.yml"; }
    [[ -f "$root/.travis.yml" ]]          && { add_cap ci_cd "travis-ci" "high" ".travis.yml"; add_evidence ".travis.yml"; }

    # === Hosting / deployment targets ===
    # Static file-marker evidence only — this tells you what a repo is SET UP
    # to deploy to, never what's currently live. No cloud API calls, no
    # ~/.aws/credentials reads, no active-profile detection: that's Phase 7
    # (DevOps context providers) by design, not Phase 2.
    [[ -f "$root/vercel.json" ]] || [[ -d "$root/.vercel" ]]      && { add_cap hosting "vercel" "high" "vercel.json / .vercel/"; add_evidence "vercel.json"; }
    [[ -f "$root/netlify.toml" ]]                                 && { add_cap hosting "netlify" "high" "netlify.toml"; add_evidence "netlify.toml"; }
    [[ -f "$root/fly.toml" ]]                                     && { add_cap hosting "fly.io" "high" "fly.toml"; add_evidence "fly.toml"; }
    { [[ -f "$root/railway.json" ]] || [[ -f "$root/railway.toml" ]]; } && { add_cap hosting "railway" "high" "railway.json/toml"; add_evidence "railway.json/toml"; }
    [[ -f "$root/render.yaml" ]]                                  && { add_cap hosting "render" "high" "render.yaml"; add_evidence "render.yaml"; }
    [[ -f "$root/Procfile" ]]                                     && { add_cap hosting "heroku-style" "medium" "Procfile"; add_evidence "Procfile"; }
    [[ -f "$root/app.yaml" ]]                                     && { add_cap hosting "gcp-app-engine" "medium" "app.yaml"; add_evidence "app.yaml"; }
    [[ -f "$root/cdk.json" ]]                                     && { add_cap hosting "aws-cdk" "high" "cdk.json"; add_evidence "cdk.json"; }
    { [[ -f "$root/template.yaml" ]] && [[ -f "$root/samconfig.toml" ]]; } && { add_cap hosting "aws-sam" "high" "template.yaml + samconfig.toml"; add_evidence "AWS SAM files"; }
    { [[ -f "$root/serverless.yml" ]] || [[ -f "$root/serverless.ts" ]]; } && { add_cap hosting "serverless-framework" "high" "serverless.yml"; add_evidence "serverless.yml"; }
    [[ -f "$root/zappa_settings.json" ]]                          && { add_cap hosting "zappa" "high" "zappa_settings.json"; add_evidence "zappa_settings.json"; }
    [[ -f "$root/wrangler.toml" ]]                                && { add_cap hosting "cloudflare-workers" "high" "wrangler.toml"; add_evidence "wrangler.toml"; }
    [[ -f "$root/firebase.json" ]]                                && { add_cap hosting "firebase" "high" "firebase.json"; add_evidence "firebase.json"; }

    # Weak-signal SDK evidence — "this code talks to a cloud provider" is
    # weaker than "this repo is configured to deploy there," so these stay
    # medium/low even on a direct hit.
    if [[ -f "$root/package.json" ]]; then
        local hosting_pkg_content=""
        hosting_pkg_content="$(<"$root/package.json")"
        pkgjson_has_dep "$hosting_pkg_content" "aws-sdk"            && add_cap hosting "aws" "medium" "package.json aws-sdk dependency"
        pkgjson_has_dep "$hosting_pkg_content" "@aws-sdk/client-s3" && add_cap hosting "aws" "medium" "package.json @aws-sdk dependency"
        pkgjson_has_dep "$hosting_pkg_content" "@google-cloud/storage" && add_cap hosting "gcp" "medium" "package.json @google-cloud dependency"
        pkgjson_has_dep "$hosting_pkg_content" "@azure/storage-blob" && add_cap hosting "azure" "medium" "package.json @azure dependency"
    fi
    if [[ -f "$root/requirements.txt" ]]; then
        grep -qE '^boto3' "$root/requirements.txt" 2>/dev/null && add_cap hosting "aws" "medium" "requirements.txt boto3"
        grep -qE '^google-cloud' "$root/requirements.txt" 2>/dev/null && add_cap hosting "gcp" "medium" "requirements.txt google-cloud"
        grep -qE '^azure-' "$root/requirements.txt" 2>/dev/null && add_cap hosting "azure" "medium" "requirements.txt azure-*"
    fi
    if [[ -f "$root/pyproject.toml" ]]; then
        grep -q 'boto3' "$root/pyproject.toml" 2>/dev/null && add_cap hosting "aws" "medium" "pyproject.toml boto3"
    fi

    # === Task runners ===
    [[ -f "$root/Makefile" ]]  && { add_cap task_runners "make" "high" "Makefile"; add_evidence "Makefile"; }
    { [[ -f "$root/Taskfile.yml" ]] || [[ -f "$root/Taskfile.yaml" ]]; } && { add_cap task_runners "task" "high" "Taskfile"; add_evidence "Taskfile"; }
    [[ -f "$root/Justfile" ]]  && { add_cap task_runners "just" "high" "Justfile"; add_evidence "Justfile"; }

    # === Version/runtime managers ===
    [[ -f "$root/mise.toml" ]]  && { RUNTIME_HINTS+=('{"type":"mise_toml","present":true}'); add_evidence "mise.toml"; }
    [[ -f "$root/.mise.toml" ]] && { RUNTIME_HINTS+=('{"type":"mise_toml_local","present":true}'); add_evidence ".mise.toml"; }
    [[ -f "$root/.tool-versions" ]] && { RUNTIME_HINTS+=('{"type":"asdf_tool_versions","present":true}'); add_evidence ".tool-versions"; }

    return 0
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

# Emits a JSON array of {"name","confidence","evidence":[...]} objects for
# every deduplicated capability in the given category.
emit_cap_array() {
    local cat="$1" key name conf evid first=true chunk
    printf '['
    for key in "${CAP_ORDER[@]}"; do
        [[ "$key" == "${cat}:"* ]] || continue
        name="${key#*:}"
        conf="${CAP_CONF[$key]}"
        evid="${CAP_EVID[$key]}"
        [[ "$first" == true ]] && first=false || printf ', '
        printf '{"name":"%s","confidence":"%s","evidence":[' "$(json_escape "$name")" "$conf"
        local efirst=true
        local -a echunks=()
        IFS=$'\x1f' read -r -a echunks <<< "$evid"
        # A here-string always appends a trailing "\n"; since \x1f (not \n) is
        # the field separator, that newline sticks to the LAST element rather
        # than becoming a spurious extra one — strip it explicitly.
        if [[ ${#echunks[@]} -gt 0 ]]; then
            local last_idx=$((${#echunks[@]} - 1))
            echunks[last_idx]="${echunks[last_idx]%$'\n'}"
        fi
        for chunk in "${echunks[@]}"; do
            [[ -z "$chunk" ]] && continue
            [[ "$efirst" == true ]] && efirst=false || printf ', '
            printf '"%s"' "$(json_escape "$chunk")"
        done
        printf ']}'
    done
    printf ']'
}

emit_string_array() {
    local -n arr="$1"
    local first=true item
    printf '['
    for item in "${arr[@]-}"; do
        [[ -z "$item" ]] && continue
        [[ "$first" == true ]] && first=false || printf ', '
        printf '"%s"' "$(json_escape "$item")"
    done
    printf ']'
}

# Raw-object array: elements are already-formed JSON object strings.
emit_raw_array() {
    local -n arr="$1"
    local first=true item
    printf '['
    for item in "${arr[@]-}"; do
        [[ -z "$item" ]] && continue
        [[ "$first" == true ]] && first=false || printf ', '
        printf '%s' "$item"
    done
    printf ']'
}

cap_names_for() {
    local cat="$1" key
    for key in "${CAP_ORDER[@]}"; do
        [[ "$key" == "${cat}:"* ]] && printf '%s\n' "${key#*:}"
    done
}

cap_count_for() {
    local cat="$1" n=0 key
    for key in "${CAP_ORDER[@]}"; do
        [[ "$key" == "${cat}:"* ]] && ((n++))
    done
    printf '%s' "$n"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local git_root="" project_root="" project_name="" repo_type="none"

    if git_root=$(get_git_root); then
        project_root="$git_root"; repo_type="git"
    elif project_root=$(find_project_root); then
        repo_type="markers"
    else
        project_root="$PWD"; repo_type="none"
    fi

    project_name=$(get_project_name "$project_root" "$git_root")
    detect_capabilities "$project_root"

    if [[ "$JSON_OUTPUT" == true ]]; then
        printf '{\n'
        printf '  "schema_version": %s,\n' "$SCHEMA_VERSION"
        printf '  "tool_version": "%s",\n' "$SCRIPT_VERSION"
        printf '  "root": "%s",\n' "$(json_escape "$project_root")"
        printf '  "name": "%s",\n' "$(json_escape "$project_name")"
        printf '  "repository": {"type": "%s", "root": "%s"},\n' \
            "$(json_escape "$repo_type")" "$(json_escape "${git_root:-$project_root}")"

        printf '  "languages": %s,\n' "$(emit_cap_array languages)"
        printf '  "frameworks": %s,\n' "$(emit_cap_array frameworks)"
        printf '  "package_managers": %s,\n' "$(emit_cap_array package_managers)"
        printf '  "runtimes": %s,\n' "$(emit_cap_array runtimes)"
        printf '  "containers": %s,\n' "$(emit_cap_array containers)"
        printf '  "hosting": %s,\n' "$(emit_cap_array hosting)"
        printf '  "infrastructure": %s,\n' "$(emit_cap_array infrastructure)"
        printf '  "kubernetes": %s,\n' "$(emit_cap_array kubernetes)"
        printf '  "ci_cd": %s,\n' "$(emit_cap_array ci_cd)"
        printf '  "task_runners": %s,\n' "$(emit_cap_array task_runners)"
        printf '  "databases": %s,\n' "$(emit_cap_array databases)"

        # environment_candidates: array of per-language structured objects.
        printf '  "environment_candidates": ['
        local ec_first=true
        if [[ "$PY_DETECTED" == true ]]; then
            ec_first=false
            printf '{"language":"python","detected":true,"frameworks":%s,"environments":[' \
                "$(emit_string_array PY_FRAMEWORK_NAMES)"
            local pfirst=true e p t
            for e in "${PY_ENVS[@]-}"; do
                [[ -z "$e" ]] && continue
                IFS='|' read -r p t <<< "$e"
                [[ "$pfirst" == true ]] && pfirst=false || printf ', '
                printf '{"path":"%s","type":"%s","exists":true}' "$(json_escape "$p")" "$(json_escape "$t")"
            done
            printf '],"uv_lock":%s}' "$PY_UV_LOCK"
        fi
        if [[ "$NODE_DETECTED" == true ]]; then
            [[ "$ec_first" == false ]] && printf ', '
            ec_first=false
            printf '{"language":"node","detected":true,"package_manager":%s,"version_file":%s}' \
                "$([[ -n "$NODE_PKG_MANAGER" ]] && printf '"%s"' "$(json_escape "$NODE_PKG_MANAGER")" || printf 'null')" \
                "$([[ -n "$NODE_VERSION_FILE" ]] && printf '"%s"' "$(json_escape "$NODE_VERSION_FILE")" || printf 'null')"
        fi
        printf '],\n'

        printf '  "runtime_hints": %s,\n' "$(emit_raw_array RUNTIME_HINTS)"
        printf '  "evidence": %s,\n' "$(emit_string_array EVIDENCE)"
        printf '  "workspaces": %s,\n' "$(emit_raw_array WORKSPACES)"

        printf '  "note": "No environment was activated. No project files were modified."\n'
        printf '}\n'
    else
        print_human "${C_BOLD}${C_CYAN}Flow Project Context${C_RESET}"
        print_human "${C_DIM}────────────────────────────────────────${C_RESET}"
        print_human ""
        print_human "Root"
        print_human "  ${C_BOLD}$project_root${C_RESET}"
        print_human ""
        print_human "Project"
        print_human "  $project_name"
        print_human ""
        print_human "Repository"
        case "$repo_type" in
            git) print_human "  ${C_GREEN}Git${C_RESET}" ;;
            markers) print_human "  ${C_YELLOW}Markers only${C_RESET}" ;;
            *) print_human "  ${C_DIM}None detected${C_RESET}" ;;
        esac
        print_human ""

        print_cap_section() {
            local title="$1" cat="$2"
            local count; count=$(cap_count_for "$cat")
            ((count == 0)) && return
            print_human "$title"
            local name key
            while IFS= read -r name; do
                key="${cat}:${name}"
                if [[ "$VERBOSE" == true ]]; then
                    print_human "  ${C_GREEN}●${C_RESET} $name ${C_DIM}(${CAP_CONF[$key]})${C_RESET}"
                else
                    print_human "  $name"
                fi
            done < <(cap_names_for "$cat")
            print_human ""
        }

        print_cap_section "Languages" languages
        print_cap_section "Frameworks" frameworks
        print_cap_section "Package managers" package_managers

        if [[ ${#WORKSPACES[@]} -gt 0 ]]; then
            print_human "Monorepo / workspaces"
            local w
            for w in "${WORKSPACES[@]}"; do
                print_human "  $(sed -E 's/.*"name":"([^"]*)".*/\1/' <<< "$w")"
            done
            print_human ""
        fi

        if [[ "$PY_DETECTED" == true ]]; then
            print_human "Python"
            local e p t
            for e in "${PY_ENVS[@]-}"; do
                [[ -z "$e" ]] && continue
                IFS='|' read -r p t <<< "$e"
                print_human "  ${C_GREEN}●${C_RESET} $p"
            done
            [[ "$PY_UV_LOCK" == true ]] && print_human "  ${C_CYAN}uv.lock${C_RESET} present"
            print_human ""
        fi

        if [[ "$NODE_DETECTED" == true && -n "$NODE_VERSION_FILE" ]]; then
            print_human "Node version source"
            print_human "  ${C_GREEN}●${C_RESET} $NODE_VERSION_FILE"
            print_human ""
        fi

        print_cap_section "Containers" containers
        print_cap_section "Hosting / deploy targets" hosting
        print_cap_section "Databases" databases
        print_cap_section "Infrastructure" infrastructure
        print_cap_section "Kubernetes" kubernetes
        print_cap_section "CI/CD" ci_cd
        print_cap_section "Task runners" task_runners

        if [[ "$VERBOSE" == true && ${#EVIDENCE[@]} -gt 0 ]]; then
            print_human "Evidence"
            local e
            for e in "${EVIDENCE[@]}"; do
                print_human "  ${C_DIM}$e${C_RESET}"
            done
            print_human ""
        fi

        if [[ ${#CAP_ORDER[@]} -eq 0 ]]; then
            print_human "${C_YELLOW}No recognized project markers.${C_RESET}"
            print_human ""
        fi

        print_human "${C_DIM}No environment was activated.${C_RESET}"
        print_human "${C_DIM}No project files were modified.${C_RESET}"
    fi
}

main
