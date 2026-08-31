# flow_predictor.sh - shared engine for the Flow Predictive Command Intelligence.
# Pure, deterministic logic shared by the `flow suggest` CLI (bash) and any
# future consumer (zsh/IRIS). No side effects unless a function says so.
#
# Bash and zsh compatible. Do not use zsh-only syntax in this file
# (no ${=var}, no ${(s:x:)var}, no [[ ]] with zsh-isms, no arrays here).
#
# PERFORMANCE: every function in this file runs in-process (no command
# substitution / subprocess forks). The wall clock is cached; refresh it once
# per query run with flow_pred_clock_refresh. Results are written to globals:
#   FLOW_PRED_RESULT   - string result
#   FLOW_PRED_SCORE    - integer result
#   FLOW_PRED_MATCH    - 1 if a predicate matched, 0 otherwise
#   FLOW_PRED_EXPLAIN  - space-separated explanation tokens
#
# Record contract (schema=1)
# --------------------------
# A "command key" is the normalized command string (trimmed, single spaces,
# trailing ';' removed). It may contain spaces but never TAB or newline.
#
# Canonical aggregate line (TAB-separated, written by flow_pred_encode_cmd_record):
#   # flow-predictor schema=<n>
#   C\t<key>\t<count>\t<success>\t<fail>\t<last_ts>\t<first_ts>\t<dirs>\t<class>
#   T\t<prev\x1fnext>\t<count>\t<success>\t<last_ts>
#   W\t<c1\x1fc2\x1fc3>\t<count>\t<success>\t<last_ts>
#   R\t<failed\x1frecovery>\t<count>\t<success>\t<last_ts>
# DIRS is comma-separated "dir:count:last_ts" triples; DIRS and CLASS may be
# empty (trailing empty fields may be omitted by readers).
#
# LEGACY records (written by older producers) embedded the five stats as ONE
# space-joined field, sometimes space-padded ("12 12 0 ... <dirs>     "), and
# T/W/R keys leaked shell-quoting artifacts ($'\x1f', stray quotes). The reader
# normalizes all of this on load (see flow_pred_parse_cmd_record); writers must
# only ever emit canonical lines via flow_pred_encode_cmd_record.
#
# Versioning
# -----------
FLOW_PRED_SCHEMA_VERSION=1
FLOW_PRED_STATE_DIR="${FLOW_PRED_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/flow/predictor}"
FLOW_PRED_AGGREGATES="${FLOW_PRED_AGGREGATES:-$FLOW_PRED_STATE_DIR/aggregates.tsv}"

FLOW_PRED_RESULT=""
FLOW_PRED_SCORE=0
FLOW_PRED_MATCH=0
FLOW_PRED_EXPLAIN=""

# Load diagnostics (set by flow_pred_load_aggregates)
FLOW_PRED_LOAD_LINES=0
FLOW_PRED_LOAD_SKIPPED=0

# -- normalization ------------------------------------------------------------
# Normalize a raw command line into a command key. Result in FLOW_PRED_RESULT.
# (Ingest-time only; uses one tr fork - NOT on the keystroke hot path.)
flow_pred_normalize() {
  local s
  s="${1:-}"
  s="${s%;}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  s="$(printf '%s' "$s" | tr -s '[:space:]' ' ')"
  FLOW_PRED_RESULT="$s"
}

# -- classification -----------------------------------------------------------
# Deterministic, lightweight command classification. Result in FLOW_PRED_RESULT.
flow_pred_classify() {
  local cmd="${1:-}"
  local first
  first="${cmd%% *}"
  case "$first" in
    git|git-*)                 FLOW_PRED_RESULT='version_control' ;;
    uv|python|python3|pip|pip3|poetry|pipenv|pdm|pyenv|python3.11|python3.12) FLOW_PRED_RESULT='python' ;;
    cargo|rustup|rustc)        FLOW_PRED_RESULT='rust' ;;
    node|npm|npx|yarn|pnpm|bun) FLOW_PRED_RESULT='javascript' ;;
    docker|podman|docker-compose) FLOW_PRED_RESULT='container' ;;
    kubectl|helm|k3s|minikube|kind) FLOW_PRED_RESULT='kubernetes' ;;
    terraform|tofu|terragrunt) FLOW_PRED_RESULT='infrastructure' ;;
    ssh|scp|rsync|curl|wget|ping|nc|nmap) FLOW_PRED_RESULT='network' ;;
    systemctl|journalctl|service|systemd-*) FLOW_PRED_RESULT='system' ;;
    ls|cd|cat|less|vim|nvim|nano|rm|cp|mv|mkdir|rmdir|touch|chmod|chown|find|grep|rg|sed|awk|bat) FLOW_PRED_RESULT='filesystem' ;;
    make|cmake|ninja|meson|bazel|just|task|mise) FLOW_PRED_RESULT='build' ;;
    sudo) FLOW_PRED_RESULT='privileged' ;;
    pacman|yay|paru|dnf|apt|apt-get|flatpak|snap) FLOW_PRED_RESULT='package' ;;
    *) FLOW_PRED_RESULT='other' ;;
  esac
}

# Risk class for presentation/ranking only (never blocks anything).
# Result in FLOW_PRED_RESULT.
flow_pred_risk_class() {
  local cmd="${1:-}"
  local first
  first="${cmd%% *}"
  case "$first" in
    rm|rmdir|dd|mkfs|format|shutdown|reboot|poweroff|kill|pkill|killall|systemctl|sudo) FLOW_PRED_RESULT='destructive' ;;
    git|mv|cp|chmod|chown) FLOW_PRED_RESULT='caution' ;;
    *) FLOW_PRED_RESULT='normal' ;;
  esac
}

# -- scoring weights ----------------------------------------------------------
# Weights are documented constants; tuning them changes ranking deterministically.
FLOW_PRED_W_PREFIX=40
FLOW_PRED_W_DIR=25
FLOW_PRED_W_DIR_PARENT=10
FLOW_PRED_W_PROFILE=15
FLOW_PRED_W_WORKSPACE=12
FLOW_PRED_W_PROJECT=10
FLOW_PRED_W_RUNTIME=8
FLOW_PRED_W_SESSION=12
FLOW_PRED_W_HOST=3
FLOW_PRED_W_TRANSITION=8
FLOW_PRED_W_TRANSITION_CAP=20
FLOW_PRED_W_WORKFLOW=10
FLOW_PRED_W_WORKFLOW_CAP=25
FLOW_PRED_W_RECOVERY=12
FLOW_PRED_W_SUCCESS=15
FLOW_PRED_W_FREQ=6
FLOW_PRED_W_FREQ_CAP=24
FLOW_PRED_W_RECENCY_H1=10
FLOW_PRED_W_RECENCY_D1=8
FLOW_PRED_W_RECENCY_D7=5
FLOW_PRED_W_RECENCY_D30=2
FLOW_PRED_N_FAIL_PENALTY=10
# Empty-query mode: candidates without any context anchor are penalized so the
# empty buffer does not degenerate into "globally most frequent commands".
FLOW_PRED_W_NO_ANCHOR_PENALTY=15

# -- confidence thresholds ----------------------------------------------------
#   >=80 very_high | >=60 high | >=40 medium | >=20 low | <20 very_low
FLOW_PRED_CONF_VHIGH=80
FLOW_PRED_CONF_HIGH=60
FLOW_PRED_CONF_MEDIUM=40
FLOW_PRED_CONF_LOW=20

# flow_pred_confidence <score> -> confidence label in FLOW_PRED_RESULT
flow_pred_confidence() {
  local s="${1:-0}"
  case "$s" in ''|*[!0-9]*) s=0 ;; esac
  if   [ "$s" -ge "$FLOW_PRED_CONF_VHIGH" ]; then FLOW_PRED_RESULT="very_high"
  elif [ "$s" -ge "$FLOW_PRED_CONF_HIGH" ];  then FLOW_PRED_RESULT="high"
  elif [ "$s" -ge "$FLOW_PRED_CONF_MEDIUM" ]; then FLOW_PRED_RESULT="medium"
  elif [ "$s" -ge "$FLOW_PRED_CONF_LOW" ];   then FLOW_PRED_RESULT="low"
  else FLOW_PRED_RESULT="very_low"
  fi
}

# -- clock --------------------------------------------------------------------
# Cached wall clock. flow_pred_clock_refresh re-reads it; scorers reuse the
# cache so every candidate in one query is ranked against the same instant.
if [ -n "${ZSH_VERSION:-}" ]; then
  flow_pred_clock_refresh() { _FLOW_PRED_CLOCK=$EPOCHSECONDS; }
else
  flow_pred_clock_refresh() { _FLOW_PRED_CLOCK="${EPOCHSECONDS:-$(date +%s)}"; }
fi
flow_pred_now() {
  if [ -z "${_FLOW_PRED_CLOCK:-}" ]; then flow_pred_clock_refresh; fi
  FLOW_PRED_SCORE=$_FLOW_PRED_CLOCK
}

# flow_pred_recency_bonus <last_ts> <now> -> integer in FLOW_PRED_SCORE
flow_pred_recency_bonus() {
  local age=$(( ${2:-0} - ${1:-0} ))
  if   [ "$age" -lt 3600 ]; then    FLOW_PRED_SCORE=$FLOW_PRED_W_RECENCY_H1
  elif [ "$age" -lt 86400 ]; then   FLOW_PRED_SCORE=$FLOW_PRED_W_RECENCY_D1
  elif [ "$age" -lt 604800 ]; then  FLOW_PRED_SCORE=$FLOW_PRED_W_RECENCY_D7
  elif [ "$age" -lt 2592000 ]; then FLOW_PRED_SCORE=$FLOW_PRED_W_RECENCY_D30
  else FLOW_PRED_SCORE=0
  fi
}

# -- context ------------------------------------------------------------------
# flow_pred_ctx_get <ctx> <name> -> value in FLOW_PRED_RESULT
# ctx is a '|'-separated list of key=value pairs.
flow_pred_ctx_get() {
  local ctx="$1" name="$2" kv k v
  local oldifs=$IFS
  IFS='|'
  for kv in $ctx; do
    k="${kv%%=*}" v="${kv#*=}"
    if [ "$k" = "$name" ]; then
      FLOW_PRED_RESULT="$v"
      IFS=$oldifs
      return 0
    fi
  done
  IFS=$oldifs
  FLOW_PRED_RESULT=""
  return 1
}

# flow_pred_ctx_prepare <ctx>
# Parses the context string ONCE into FLOW_PRED_C_* globals. The scorers
# auto-invoke this only when the ctx string changed since the last call, so
# scoring loops pay the parse cost exactly once per query.
flow_pred_ctx_prepare() {
  local kv k v
  local oldifs=$IFS
  IFS='|'
  for kv in $1; do
    k="${kv%%=*}" v="${kv#*=}"
    case "$k" in
      dir)       FLOW_PRED_C_DIR="$v" ;;
      profile)   FLOW_PRED_C_PROFILE="$v" ;;
      workspace) FLOW_PRED_C_WORKSPACE="$v" ;;
      project)   FLOW_PRED_C_PROJECT="$v" ;;
      runtime)   FLOW_PRED_C_RUNTIME="$v" ;;
      host)      FLOW_PRED_C_HOST="$v" ;;
      session)   FLOW_PRED_C_SESSION="$v" ;;
    esac
  done
  IFS=$oldifs
  _FLOW_PRED_CTX_SRC="${1:-}"
}

_flow_pred_split_tab() {
  local _rest="$1" _max="$2" _i=1 _field
  while [ "$_i" -le "$_max" ]; do
    if [ -z "$_rest" ]; then
      _field=""
    else
      case "$_rest" in
        *$'\t'*) _field="${_rest%%$'\t'*}"; _rest="${_rest#*$'\t'}" ;;
        *)       _field="$_rest"; _rest="" ;;
      esac
    fi
    case "$_i" in
      1) FLOW_PRED_F1="$_field" ;; 2) FLOW_PRED_F2="$_field" ;;
      3) FLOW_PRED_F3="$_field" ;; 4) FLOW_PRED_F4="$_field" ;;
      5) FLOW_PRED_F5="$_field" ;; 6) FLOW_PRED_F6="$_field" ;;
      7) FLOW_PRED_F7="$_field" ;; 8) FLOW_PRED_F8="$_field" ;;
    esac
    _i=$((_i+1))
  done
}

# _flow_pred_sanitize_int <value> -> leading-digit-run integer in FLOW_PRED_NUM
# "12 13 x" -> 12 ; "" / "abc" / "-5" -> 0. Kills legacy padding/junk safely.
_flow_pred_sanitize_int() {
  local n="${1:-}"
  n="${n%%[!0-9]*}"
  FLOW_PRED_NUM="${n:-0}"
}

# -- canonical record encoding (single source of truth for producers) ----------
# flow_pred_encode_cmd_record <key> <count> <success> <fail> <last> <first> <dirs> <class>
# Prints one canonical C line to stdout. Producers MUST use this (or
# flow_pred_save_aggregates); hand-rolled printf is what corrupted history.
flow_pred_encode_cmd_record() {
  printf 'C\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${1:-}" "${2:-0}" "${3:-0}" "${4:-0}" "${5:-0}" "${6:-0}" "${7:-}" "${8:-}"
}

# flow_pred_parse_cmd_record <raw-line-without-leading-"C<TAB>">
# Tolerant parser: accepts canonical records AND legacy records whose stats
# were space-joined/padded into a single field (optionally carrying dirs).
# Results in globals FLOW_PRED_R_{KEY,COUNT,SUCCESS,FAIL,LAST,FIRST,DIRS,CLASS}
# and FLOW_PRED_R_FMT = canonical | positional | legacy | degraded | invalid.
flow_pred_parse_cmd_record() {
  local line="${1:-}"
  local key count success fail last first dirs cls fmt tok nums blob r f
  key=""; count=0; success=0; fail=0; last=0; first=0; dirs=""; cls=""
  fmt="invalid"

  # layout probe: >=5 tabs anywhere -> positional/canonical fields; else legacy
  case "$line" in
    *$'\t'*$'\t'*$'\t'*$'\t'*$'\t'*)
      # unrolled extraction: no helper calls on this hot path
      key="${line%%$'\t'*}"
      r="${line#*$'\t'}"
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      count=${f%%[!0-9]*}; count=${count:-0}
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      success=${f%%[!0-9]*}; success=${success:-0}
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      fail=${f%%[!0-9]*}; fail=${fail:-0}
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      last=${f%%[!0-9]*}; last=${last:-0}
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      first=${f%%[!0-9]*}; first=${first:-0}
      case "$r" in *$'\t'*) f="${r%%$'\t'*}"; r="${r#*$'\t'}" ;; *) f="$r"; r="" ;; esac
      dirs="$f"
      cls="$r"
      fmt="positional"
      ;;
    *)
      key="${line%%$'\t'*}"
      if [ "$key" != "$line" ]; then
        blob="${line#*$'\t'}"
        fmt="legacy"
        nums=0
        while [ -n "$blob" ]; do
          blob="${blob#"${blob%%[![:space:]]*}"}"
          [ -n "$blob" ] || break
          tok="${blob%%[[:space:]]*}"
          case "$tok" in
            /[![:space:]]*)
              dirs="${dirs:+$dirs,}$tok"
              ;;
              *)
                if [ "$nums" -lt 5 ]; then
                  tok="${tok%%[!0-9]*}"
                  case "$nums" in
                    0) count=${tok:-0} ;;
                    1) success=${tok:-0} ;;
                    2) fail=${tok:-0} ;;
                    3) last=${tok:-0} ;;
                    4) first=${tok:-0} ;;
                  esac
                  nums=$((nums+1))
                fi
                ;;
          esac
          blob="${blob#"$tok"}"
        done
        [ "$nums" -gt 0 ] || fmt="degraded"
      else
        # key with no stats: preserve the record, zero-fill the numbers
        fmt="degraded"
      fi
      ;;
  esac

  FLOW_PRED_R_KEY="$key"
  FLOW_PRED_R_COUNT="$count"
  FLOW_PRED_R_SUCCESS="$success"
  FLOW_PRED_R_FAIL="$fail"
  FLOW_PRED_R_LAST="$last"
  FLOW_PRED_R_FIRST="$first"
  FLOW_PRED_R_DIRS="$dirs"
  FLOW_PRED_R_CLASS="$cls"
  FLOW_PRED_R_FMT="$fmt"
  [ -n "$key" ] && [ "$fmt" != "invalid" ] && return 0 || return 1
}

# -- scoring core ---------------------------------------------------------------
# _flow_pred_score_core <key> <count> <success> <fail> <last> <first> <dirs>
#                       <prefix> <ctx> [<trans_cnt> <wf_cnt> <rec_cnt>]
# Single scoring implementation shared by every entry point. Sets
# FLOW_PRED_SCORE, FLOW_PRED_MATCH, FLOW_PRED_EXPLAIN. Returns 1 when a
# non-empty prefix does not match the key (hot-path short circuit).
#
# Empty-prefix mode: prefix="" skips prefix matching entirely. MATCH then
# requires a *context anchor* (directory match, parent-dir match, session
# repeat, workflow step, transition, recovery) OR usage within the last 24h -
# so an empty buffer yields contextual top candidates instead of the globally
# most frequent commands. Anchor-less stale rows are penalized into oblivion.
_flow_pred_score_core() {
  local key="$1" count="$2" success="$3" fail="$4" last="$5" first="$6" dirs="$7"
  local prefix="$8" ctx="$9" tcnt="${10:-0}" wcnt="${11:-0}" rcnt="${12:-0}"

  FLOW_PRED_MATCH=0
  FLOW_PRED_EXPLAIN=""
  local score=0 keylen=${#key} prefixlen=${#prefix}
  local anchored=0

  if [ "$keylen" -le 0 ]; then FLOW_PRED_SCORE=0; return 0; fi

  if [ "$prefixlen" -gt 0 ]; then
    case "$key" in
      "$prefix"*)
        score=$(( score + FLOW_PRED_W_PREFIX + (prefixlen * 100 / keylen) / 4 ))
        FLOW_PRED_EXPLAIN="prefix_match"
        anchored=1
        ;;
      *)
        FLOW_PRED_SCORE=0
        return 1
        ;;
    esac
  fi

  # context (parsed once per distinct ctx string)
  if [ "${_FLOW_PRED_CTX_SRC:-}" != "$ctx" ]; then flow_pred_ctx_prepare "$ctx"; fi
  local dir profile workspace project runtime host session
  dir="$FLOW_PRED_C_DIR"; profile="$FLOW_PRED_C_PROFILE"; workspace="$FLOW_PRED_C_WORKSPACE"
  project="$FLOW_PRED_C_PROJECT"; runtime="$FLOW_PRED_C_RUNTIME"
  host="$FLOW_PRED_C_HOST"; session="$FLOW_PRED_C_SESSION"

  # directory context (exact dir wins once; parent bonus at most once)
  if [ -n "$dir" ] && [ -n "$dirs" ]; then
    local d dpath dcount fb dd_hit=0 dp_hit=0 dcap=0 oldifs=$IFS
    IFS=','
    for d in $dirs; do
      dcap=$((dcap+1))
      [ "$dd_hit" -eq 1 ] && [ "$dp_hit" -eq 1 ] && break
      [ "$dcap" -le 16 ] || break
      dpath="${d%%:*}"
      if [ "$dd_hit" -eq 0 ] && [ "$dpath" = "$dir" ]; then
        dd_hit=1
        score=$(( score + FLOW_PRED_W_DIR ))
        FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN dir_match"
        anchored=1
        dcount="${d#*:}"; dcount="${dcount%%:*}"; dcount="${dcount%%[!0-9]*}"; dcount="${dcount:-1}"
        fb=$(( dcount * FLOW_PRED_W_FREQ ))
        [ "$fb" -gt "$FLOW_PRED_W_FREQ_CAP" ] && fb=$FLOW_PRED_W_FREQ_CAP
        score=$(( score + fb ))
      elif [ "$dp_hit" -eq 0 ]; then
        case "$dir/" in
          "$dpath"/*)
            dp_hit=1
            score=$(( score + FLOW_PRED_W_DIR_PARENT ))
            FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN parent_dir_match"
            anchored=1
            ;;
        esac
      fi
    done
    IFS=$oldifs
  fi

  if [ -n "$profile" ]; then
    case "$key" in "$profile"*)
      score=$(( score + FLOW_PRED_W_PROFILE ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN profile_match"
    ;; esac
  fi
  if [ -n "$workspace" ]; then
    case "$key" in "$workspace"*)
      score=$(( score + FLOW_PRED_W_WORKSPACE ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN workspace_match"
    ;; esac
  fi
  if [ -n "$project" ]; then
    case "$key" in "$project"*)
      score=$(( score + FLOW_PRED_W_PROJECT ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN project_match"
    ;; esac
  fi
  if [ -n "$runtime" ]; then
    case "$key" in "$runtime"*)
      score=$(( score + FLOW_PRED_W_RUNTIME ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN runtime_match"
    ;; esac
  fi
  if [ -n "$session" ] && [ "$session" = "$key" ]; then
    score=$(( score + FLOW_PRED_W_SESSION ))
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN session_match"
    anchored=1
  fi
  if [ -n "$host" ] && [ "$host" = "$key" ]; then
    score=$(( score + FLOW_PRED_W_HOST ))
  fi

  # transition boost (prev -> candidate), log2-proportional, capped
  case "$tcnt" in ''|*[!0-9]*) tcnt=0 ;; esac
  if [ "$tcnt" -gt 0 ]; then
    local tb=0 tb2=$tcnt
    while [ "$tb2" -gt 1 ]; do tb=$((tb+1)); tb2=$((tb2 >> 1)); done
    tb=$(( tb * FLOW_PRED_W_TRANSITION ))
    [ "$tb" -gt "$FLOW_PRED_W_TRANSITION_CAP" ] && tb=$FLOW_PRED_W_TRANSITION_CAP
    score=$(( score + tb ))
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN follows_prev"
    anchored=1
  fi

  # workflow boost, log2-proportional, capped
  case "$wcnt" in ''|*[!0-9]*) wcnt=0 ;; esac
  if [ "$wcnt" -gt 0 ]; then
    local wb=0 wb2=$wcnt
    while [ "$wb2" -gt 1 ]; do wb=$((wb+1)); wb2=$((wb2 >> 1)); done
    wb=$(( wb * FLOW_PRED_W_WORKFLOW ))
    [ "$wb" -gt "$FLOW_PRED_W_WORKFLOW_CAP" ] && wb=$FLOW_PRED_W_WORKFLOW_CAP
    score=$(( score + wb ))
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN workflow_step"
    anchored=1
  fi

  # recovery boost (candidate historically followed this failing command)
  case "$rcnt" in ''|*[!0-9]*) rcnt=0 ;; esac
  if [ "$rcnt" -gt 0 ]; then
    local rb=$(( rcnt * FLOW_PRED_W_RECOVERY ))
    [ "$rb" -gt 20 ] && rb=20
    score=$(( score + rb ))
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN recovery_candidate"
    anchored=1
  fi

  # success rate
  case "$success" in ''|*[!0-9]*) success=0 ;; esac
  case "$fail" in ''|*[!0-9]*) fail=0 ;; esac
  local total=$(( success + fail ))
  if [ "$total" -gt 0 ]; then
    score=$(( score + (success * FLOW_PRED_W_SUCCESS / total) ))
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN ${success}ok_${fail}fail"
    if [ "$total" -ge 3 ] && [ "$fail" -gt 0 ] && [ $(( fail * 100 / total )) -ge 50 ]; then
      score=$(( score - FLOW_PRED_N_FAIL_PENALTY ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN high_failure_rate"
    fi
  fi

  # global frequency (log2), capped
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  local freq=0 c=$count now age
  while [ "$c" -gt 1 ]; do c=$(( c >> 1 )); freq=$((freq+1)); done
  local fb2=$(( freq * FLOW_PRED_W_FREQ ))
  [ "$fb2" -gt "$FLOW_PRED_W_FREQ_CAP" ] && fb2=$FLOW_PRED_W_FREQ_CAP
  score=$(( score + fb2 ))

  # recency (cached clock: consistent ranking within one query run)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  if [ -n "${_FLOW_PRED_CLOCK:-}" ]; then now=$_FLOW_PRED_CLOCK
  else flow_pred_clock_refresh; now=$_FLOW_PRED_CLOCK; fi
  age=$(( now - last ))
  if   [ "$age" -lt 3600 ]; then    score=$(( score + FLOW_PRED_W_RECENCY_H1 ))
  elif [ "$age" -lt 86400 ]; then   score=$(( score + FLOW_PRED_W_RECENCY_D1 ))
  elif [ "$age" -lt 604800 ]; then  score=$(( score + FLOW_PRED_W_RECENCY_D7 ))
  elif [ "$age" -lt 2592000 ]; then score=$(( score + FLOW_PRED_W_RECENCY_D30 ))
  fi
  if [ "$prefixlen" -eq 0 ] && [ "$last" -gt 0 ] && [ "$age" -lt 86400 ]; then
    anchored=1
    FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN recently_used"
  fi

  # empty-query gate: drop context-less, stale candidates entirely
  if [ "$prefixlen" -eq 0 ]; then
    if [ "$anchored" -eq 1 ]; then
      FLOW_PRED_MATCH=1
    else
      score=$(( score - FLOW_PRED_W_NO_ANCHOR_PENALTY ))
      FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN no_context_anchor"
      FLOW_PRED_MATCH=0
    fi
  else
    FLOW_PRED_MATCH=1   # reached only via the prefix branch above
  fi

  [ "$count" -gt 0 ] && FLOW_PRED_EXPLAIN="$FLOW_PRED_EXPLAIN ${count}x_used"

  FLOW_PRED_SCORE=$score
  return 0
}

# flow_pred_score_fields <key> <count> <success> <fail> <last> <first> <dirs>
#   <class> <prefix> <ctx> [<trans_cnt> <wf_cnt> <rec_cnt>]
# Parse-free entry point for callers that already hold parsed fields (the CLI
# loader, future ZLE/IRIS consumers). Same results as flow_pred_score_record.
flow_pred_score_fields() {
  _flow_pred_score_core "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$9" "${10:-}" "${11:-0}" "${12:-0}" "${13:-0}"
}

# flow_pred_score_record <rec> <prefix> <ctx> [<trans_cnt> <wf_cnt> <rec_cnt>]
# Full scorer used by the HUD and generic consumers. rec is a TAB-separated
# candidate record (canonical or legacy; parsed tolerantly).
flow_pred_score_record() {
  local rec="$1" prefix="$2" ctx="$3" tcnt="${4:-0}" wcnt="${5:-0}" rcnt="${6:-0}"
  flow_pred_parse_cmd_record "$rec" || { FLOW_PRED_SCORE=0; FLOW_PRED_MATCH=0; FLOW_PRED_EXPLAIN=""; return 0; }
  _flow_pred_score_core "$FLOW_PRED_R_KEY" "$FLOW_PRED_R_COUNT" "$FLOW_PRED_R_SUCCESS" \
    "$FLOW_PRED_R_FAIL" "$FLOW_PRED_R_LAST" "$FLOW_PRED_R_FIRST" "$FLOW_PRED_R_DIRS" \
    "$prefix" "$ctx" "$tcnt" "$wcnt" "$rcnt"
  return 0
}

# flow_pred_score_fast <key> <count> <success> <fail> <last> <first> <dirs>
#   <class> <prefix> <ctx> [<trans_cnt> <wf_cnt> <rec_cnt>]
# Fast heuristic scorer for the keystroke hot path. Returns 1 on prefix
# non-match (short-circuit), 0 otherwise.
flow_pred_score_fast() {
  _flow_pred_score_core "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$9" "${10:-}" "${11:-0}" "${12:-0}" "${13:-0}"
}

# -- persistence --------------------------------------------------------------
# Aggregate file at $FLOW_PRED_AGGREGATES (versioned). Derived statistics only -
# never full command history, clipboard or secrets.

flow_pred_agg_header() { printf '# flow-predictor schema=%s\n' "$FLOW_PRED_SCHEMA_VERSION"; }

# flow_pred_save_aggregates < pre-encoded lines >  writes the file atomically.
# Callers should produce C/T/W/R lines from the encode helpers or verbatim
# canonical lines; the file gets a fresh schema header.
flow_pred_save_aggregates() {
  mkdir -p "$FLOW_PRED_STATE_DIR" 2>/dev/null || return 1
  local tmp="$FLOW_PRED_STATE_DIR/.aggregates.$$.tmp"
  {
    flow_pred_agg_header
    cat
  } > "$tmp" || return 1
  mv -f "$tmp" "$FLOW_PRED_AGGREGATES" || { rm -f "$tmp"; return 1; }
}

# flow_pred_load_aggregates <cb_cmd> <cb_trans> <cb_workflow> <cb_recovery> [<file>]
# Streams the aggregate file through tolerant parsing and invokes callbacks:
#   cb_cmd       key count success fail last first dirs class   (always 8 args)
#   cb_trans     pair count success last                        (always 4 args;
#                pair is "prev<US>next", US = \x1f)
#   cb_workflow  triple count success last                      (always 4 args)
#   cb_recovery  pair count success last                        (always 4 args)
# Malformed lines are counted in FLOW_PRED_LOAD_SKIPPED, never fatal.
flow_pred_load_aggregates() {
  local cb_cmd="$1" cb_trans="$2" cb_workflow="$3" cb_recovery="$4"
  local file="${5-}"
  if [ -z "$file" ]; then file="$FLOW_PRED_AGGREGATES"; fi
  [ -f "$file" ] || return 1
  FLOW_PRED_LOAD_LINES=0
  FLOW_PRED_LOAD_SKIPPED=0
  local line kind rest pair cnt suc last_ts
  local IFS=$'\t'
  while IFS= read -r line; do
    case "$line" in '#'*|'') continue ;; esac
    kind="${line%%$'\t'*}"
    rest="${line#*$'\t'}"
    [ "$rest" != "$line" ] || { FLOW_PRED_LOAD_SKIPPED=$((FLOW_PRED_LOAD_SKIPPED+1)); continue; }
    case "$kind" in
      [CTWR]) ;;
      *) FLOW_PRED_LOAD_SKIPPED=$((FLOW_PRED_LOAD_SKIPPED+1)); continue ;;
    esac
    FLOW_PRED_LOAD_LINES=$((FLOW_PRED_LOAD_LINES+1))

    if [ "$kind" = "C" ]; then
      flow_pred_parse_cmd_record "$rest"
      if [ "$FLOW_PRED_R_FMT" = "invalid" ]; then
        FLOW_PRED_LOAD_SKIPPED=$((FLOW_PRED_LOAD_SKIPPED+1))
        continue
      fi
      "$cb_cmd" "$FLOW_PRED_R_KEY" "$FLOW_PRED_R_COUNT" "$FLOW_PRED_R_SUCCESS" \
        "$FLOW_PRED_R_FAIL" "$FLOW_PRED_R_LAST" "$FLOW_PRED_R_FIRST" \
        "$FLOW_PRED_R_DIRS" "$FLOW_PRED_R_CLASS"
      continue
    fi

    # T/W/R: pair/triple in ONE tab field (\x1f inside) + up to 3 stat fields.
    _flow_pred_split_tab "$rest" 4
    pair="$FLOW_PRED_F1"
    _flow_pred_sanitize_int "$FLOW_PRED_F2"; cnt=$FLOW_PRED_NUM
    _flow_pred_sanitize_int "$FLOW_PRED_F3"; suc=$FLOW_PRED_NUM
    _flow_pred_sanitize_int "$FLOW_PRED_F4"; last_ts=$FLOW_PRED_NUM
    case "$kind" in
      T) "$cb_trans" "$pair" "$cnt" "$suc" "$last_ts" ;;
      W) "$cb_workflow" "$pair" "$cnt" "$suc" "$last_ts" ;;
      R) "$cb_recovery" "$pair" "$cnt" "$suc" "$last_ts" ;;
    esac
  done < "$file"
  return 0
}
