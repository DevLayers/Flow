#!/usr/bin/env bash
# flow project trust — per-project trust registry (security model §18, v0)
#
# Trust gates FUTURE automatic behaviors (env activation, auto-exec). Nothing
# reads it today by design: this ships the lock before the door exists.
#
# Store: ~/.local/state/flow/trust.json
#   { "projects": { "<sha256-16>": {
#       "root": "...", "trusted": bool, "auto_env": bool, "since": epoch } } }
#
# Usage: trust.sh <status|on|off|auto|list> [--json] [<root>]
set -Eeuo pipefail

TRUST_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/flow/trust.json"
JSON=false

hash_root() { printf '%s' "$1" | sha256sum | cut -c1-16; }

ensure_store() {
    mkdir -p "$(dirname "$TRUST_FILE")" 2>/dev/null || true
    if [[ ! -s "$TRUST_FILE" ]]; then
        printf '{"projects":{}}\n' > "$TRUST_FILE"
        chmod 0600 "$TRUST_FILE"
    fi
}

save_store() {
    local tmp="$TRUST_FILE.tmp"
    printf '%s\n' "$1" > "$tmp" && chmod 0600 "$tmp" && mv -f "$tmp" "$TRUST_FILE"
}

load_store() { ensure_store; cat "$TRUST_FILE"; }

entry_for() { # <root>
    local h; h=$(hash_root "$1")
    jq -c --arg h "$h" '.projects[$h] // empty' "$TRUST_FILE" 2>/dev/null
}

is_trusted() { # <root> -> exit 0 when trusted
    local e; e=$(entry_for "$1")
    [[ -n "$e" ]] && [[ "$(printf '%s' "$e" | jq -r '.trusted // false')" == "true" ]]
}

cmd_status() {
    local root="${1:-$PWD}" e
    e=$(entry_for "$root")
    if $JSON; then
        if [[ -n "$e" ]]; then printf '%s\n' "$e"
        else printf '{"root":"%s","trusted":false,"auto_env":false}\n' "$root"; fi
        return 0
    fi
    if [[ -z "$e" ]]; then
        printf 'unknown (default-deny)\n'
    else
        local t a
        t=$(jq -r '.trusted // false' <<<"$e"); a=$(jq -r '.auto_env // false' <<<"$e")
        printf 'trusted:%s auto_env:%s\n' "$t" "$a"
    fi
}

cmd_set_trusted() { # <bool> <root>
    local val="$1" root="${2:-$PWD}"
    ensure_store
    local h; h=$(hash_root "$root")
    local nj
    nj=$(jq --arg h "$h" --arg root "$root" --argjson v "$val" --argjson now "$(date +%s)" '
        .projects[$h] = ((.projects[$h] // {}) + {root:$root, trusted:$v, since:(.projects[$h].since // $now)})' \
        "$TRUST_FILE")
    save_store "$nj"
    printf '%s: trusted=%s\n' "${root##*/}" "$val"
}

cmd_auto_env() { # <on|off> <root>
    local val="$1" root="${2:-$PWD}"
    ensure_store
    local h; h=$(hash_root "$root")
    local nj
    nj=$(jq --arg h "$h" --argjson v "$val" '
        .projects[$h].auto_env = $v' "$TRUST_FILE")
    save_store "$nj"
    printf '%s: auto_env=%s\n' "${root##*/}" "$val"
}

cmd_list() {
    jq -r '.projects | to_entries[] |
        [.value.root // .key, .value.trusted, .value.auto_env] |
        @tsv' "$TRUST_FILE" 2>/dev/null \
      | awk -F'\t' '{printf "%-8s %-9s %s\n", ($2=="true"?"trusted":"deny"), ($3=="true"?"auto":"manual"), $1}'
    return 0
}

print_help() {
    cat <<'EOF'
flow project trust — per-project trust registry

Usage:
  flow project trust status [root]   show trust state (default deny)
  flow project trust on   [root]     mark trusted
  flow project trust off  [root]     mark untrusted
  flow project trust auto on|off [root]  toggle future auto-env permission
  flow project trust list            all entries
Flags: --json (status only)
EOF
}

main() {
    local cmd="${1:-status}"; shift || true
    [[ "${1:-}" == "--json" ]] && { JSON=true; shift; }

    case "$cmd" in
        status)  cmd_status "${1:-$PWD}" ;;
        on)      cmd_set_trusted true  "${1:-$PWD}" ;;
        off)     cmd_set_trusted false "${1:-$PWD}" ;;
        auto)    local v="${1:?on|off}"; shift; cmd_auto_env "$v" "${1:-$PWD}" ;;
        list)    cmd_list ;;
        -h|--help|help) print_help ;;
        *) print_help; exit 1 ;;
    esac
}

main "$@"
