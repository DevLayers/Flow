#!/bin/bash
# flow suggest - Predictive Command Intelligence debug/query CLI.
# Usage: flow suggest [prefix] [--json] [--debug] [--limit N]
#
# Deterministic, local, offline. Reads only the persisted derived aggregates
# (${XDG_STATE_HOME}/flow/predictor/aggregates.tsv) plus the live environment
# context. Never reads raw command history, clipboard or secrets.
#
# Candidate sources:
#   history     - normalized command keys from aggregates.tsv
#   filesystem  - executable files / scripts discovered in $PWD when the query
#                 starts with "./" (stat-only discovery; nothing is executed,
#                 no recursion, hard entry cap)
#
# Optional live-session context (set by a future ZLE/IRIS integration):
#   FLOW_PRED_PREV_CMD     last executed command (normalized)
#   FLOW_PRED_SESSION_SEQ  \x1f-separated recent commands, oldest -> newest

set -euo pipefail

# locate the shared engine — the script's own tree wins over any installed copy
_engine=""
for _cand in \
  "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)/flow_predictor.sh" \
  "$(dirname "${BASH_SOURCE[0]}")/../../lib/flow_predictor.sh" \
  "${FLOW_BASE_DIR:-}/sdata/lib/flow_predictor.sh" \
  "${HOME}/.local/share/flow/sdata/lib/flow_predictor.sh"; do
  if [ -f "$_cand" ]; then _engine="$_cand"; break; fi
done
if [ -z "$_engine" ]; then
  echo "flow-suggest: engine not found" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$_engine"

PREFIX=""
JSON=0
DEBUG=0
LIMIT=10
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --debug) DEBUG=1; shift ;;
    --limit) LIMIT="${2:-10}"; shift 2 ;;
    -h|--help)
      echo "usage: flow suggest [prefix] [--json] [--debug] [--limit N]"
      exit 0
      ;;
    -*) echo "flow-suggest: unknown option $1" >&2; exit 2 ;;
    *) PREFIX="$1"; shift ;;
  esac
done

t_all_start=$(date +%s%N 2>/dev/null || echo 0)

# ---- load aggregates (streaming, query-aware prefilter) --------------------
FLOW_PRED_STATE_DIR="${FLOW_PRED_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/flow/predictor}"
FLOW_PRED_AGGREGATES="${FLOW_PRED_AGGREGATES:-$FLOW_PRED_STATE_DIR/aggregates.tsv}"
[ -f "$FLOW_PRED_AGGREGATES" ] || {
  echo "flow-suggest: no aggregates yet (run a few commands first)" >&2
  exit 1
}

declare -A cmd_stats key_dirs key_class trans wf_prefix recovery workflow_stats hist_seen anchor_next class_cache
MAX_ROWS=${FLOW_SUGGEST_MAX_ROWS:-400}   # bound worst-case parse work
POOL_N=0                                  # stored candidate count (set -u safe)

# ---- context (needed before load for the empty-query tier gate) -------------
DIR="${PWD:-$PWD}"
PARENT_DIR="${DIR%/*}"
PROFILE="${FLOW_ENV_PROFILE:-${FLOW_STARSHIP_PROFILE:-}}"
WORKSPACE="${FLOW_ENV_ROOT:-${FLOW_STARSHIP_ROOT:-}}"
PROJECT=""
[ -n "$WORKSPACE" ] && PROJECT="${WORKSPACE##*/}"
RUNTIME=""
[ -n "${VIRTUAL_ENV:-}" ] && RUNTIME="${VIRTUAL_ENV##*/}"
HOST="${HOSTNAME:-$(hostname 2>/dev/null || echo "")}"
PREV_CMD="${FLOW_PRED_PREV_CMD:-}"
SEQ="${FLOW_PRED_SESSION_SEQ:-}"
SESSION=""
if [ -n "$SEQ" ]; then SESSION="${SEQ##*$'\x1f'}"; else SESSION="$PREV_CMD"; fi
CTX="dir=$DIR|profile=$PROFILE|workspace=$WORKSPACE|project=$PROJECT|runtime=$RUNTIME|host=$HOST|session=${SESSION}"

# session-derived boost lookups
S_PREV="$PREV_CMD"
S_WFPRE=""
if [ -n "$SEQ" ]; then
  s_last="${SEQ##*$'\x1f'}"
  s_rest="${SEQ%"$s_last"}"; s_rest="${s_rest%$'\x1f'}"
  [ -n "$s_rest" ] && S_WFPRE="${s_rest##*$'\x1f'}"$'\x1f'"$s_last"
fi

flow_pred_clock_refresh   # one ranking instant for the whole run
NOW_TS=$FLOW_PRED_SCORE

store_cmd() { # consumes FLOW_PRED_R_* set by flow_pred_parse_cmd_record
  local k="$FLOW_PRED_R_KEY"
  [ -n "$k" ] || return 0
  [ -z "${hist_seen[$k]:-}" ] || return 0
  hist_seen[$k]=1
  POOL_N=$((POOL_N+1))
  cmd_stats["$k"]="$FLOW_PRED_R_COUNT $FLOW_PRED_R_SUCCESS $FLOW_PRED_R_FAIL $FLOW_PRED_R_LAST $FLOW_PRED_R_FIRST"
  if [ -n "$FLOW_PRED_R_DIRS" ]; then key_dirs["$k"]="$FLOW_PRED_R_DIRS"; fi
  local cls="$FLOW_PRED_R_CLASS"
  if [ -z "$cls" ]; then
    local fw="${k%% }"
    cls="${class_cache[$fw]:-}"
    if [ -z "$cls" ]; then flow_pred_classify "$k"; cls="$FLOW_PRED_RESULT"; class_cache["$fw"]="$cls"; fi
  fi
  key_class["$k"]="$cls"
}

# load_stream <file> <admit_all:0|1>
# Pure-shell fallback loader. C lines: prefix-filtered when PREFIX is set;
# otherwise tier-gated to contextually plausible rows. T/W/R lines are tiny;
# loaded only when a live session context exists.
load_stream() {
  local src="$1" admit="$2" line kind rest key pair cnt suc lts c1 rem c2 pkey prev nx third rows=0
  local IFS=$'\t'
  while IFS= read -r line; do
    case "$line" in '#'*|'') continue ;; esac
    kind="${line%%$'\t'*}"
    rest="${line#*$'\t'}"
    [ "$rest" != "$line" ] || continue
    case "$kind" in
      C)
        key="${rest%%$'\t'*}"
        [ -n "$key" ] || continue
        if [ -n "$PREFIX" ]; then
          case "$key" in "$PREFIX"*) ;; *) continue ;; esac
        elif [ "$admit" -eq 0 ]; then
          case "$rest" in
            *"$DIR:"*|*"$PARENT_DIR/"*) ;;
            *) [ -z "${anchor_next[$key]:-}" ] && continue ;;
          esac
        fi
        [ "$rows" -ge "$MAX_ROWS" ] && { rows=$((rows+1)); continue; }
        flow_pred_parse_cmd_record "$rest" || continue
        rows=$((rows+1))
        store_cmd
        ;;
      T)
        { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
        _flow_pred_split_tab "$rest" 4
        pair="$FLOW_PRED_F1"
        cnt=${FLOW_PRED_F2%%[!0-9]*}; cnt=${cnt:-0}
        suc=${FLOW_PRED_F3%%[!0-9]*}; suc=${suc:-0}
        trans["$pair"]="$cnt $suc"
        nx="${pair#*$'\x1f'}"
        if [ "$nx" != "$pair" ]; then anchor_next["$nx"]=1; fi
        ;;
      W)
        { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
        _flow_pred_split_tab "$rest" 4
        pair="$FLOW_PRED_F1"
        cnt=${FLOW_PRED_F2%%[!0-9]*}; cnt=${cnt:-0}
        suc=${FLOW_PRED_F3%%[!0-9]*}; suc=${suc:-0}
        lts=${FLOW_PRED_F4%%[!0-9]*}; lts=${lts:-0}
        workflow_stats["$pair"]="$cnt $suc $lts"
        c1="${pair%%$'\x1f'*}"
        rem="${pair#"$c1"$'\x1f'}"
        [ "$rem" != "$pair" ] || continue
        c2="${rem%%$'\x1f'*}"
        pkey="$c1"$'\x1f'"$c2"
        prev="${wf_prefix[$pkey]:-0}"
        wf_prefix["$pkey"]=$(( prev + cnt ))
        case "$rem" in *$'\x1f'*)
          third="${rem#"$c2"$'\x1f'}"; third="${third%%$'\x1f'*}"
          if [ -n "$third" ]; then anchor_next["$third"]=1; fi
        ;; esac
        ;;
      R)
        { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
        _flow_pred_split_tab "$rest" 4
        pair="$FLOW_PRED_F1"
        cnt=${FLOW_PRED_F2%%[!0-9]*}; cnt=${cnt:-0}
        recovery["$pair"]="$cnt"
        nx="${pair#*$'\x1f'}"
        if [ "$nx" != "$pair" ]; then anchor_next["$nx"]=1; fi
        ;;
      *) continue ;;
    esac
  done < "$src"
}

# ---- fast selection: awk normalizes legacy->canonical, applies the query
# gate (prefix match / empty-query contextual tier), computes a cheap prescore
# and emits only the top-K C rows pre-ranked. Falls back to pure-shell when
# awk is unavailable.
_norm=""
if command -v awk >/dev/null 2>&1 && [ -s "$FLOW_PRED_AGGREGATES" ]; then
  _norm="$(mktemp "${TMPDIR:-/tmp}/flow-norm.XXXXXX" 2>/dev/null)" || _norm=""

  awk_normalize() { # $1 = admit_all(0|1); emits canonical records, C rows
    # pre-ranked (best prescore first) and capped at max(48, LIMIT).
    awk -v pfx="$PREFIX" -v dir="$DIR:" -v pd="$PARENT_DIR/" -v now="$NOW_TS" \
        -v admit="$1" -v lim="$LIMIT" \
        -v wpfx="$FLOW_PRED_W_PREFIX" -v wdir="$FLOW_PRED_W_DIR" \
        -v wdirp="$FLOW_PRED_W_DIR_PARENT" -v wsuc="$FLOW_PRED_W_SUCCESS" \
        -v wfreq="$FLOW_PRED_W_FREQ" -v wfcap="$FLOW_PRED_W_FREQ_CAP" \
        -v wd1="$FLOW_PRED_W_RECENCY_D1" -v kh="$FLOW_PRED_W_RECENCY_H1" '
      function tonum(x) { x = x + 0; if (x < 0) x = 0; return x }
      BEGIN { FS = "\t"; OFS = "\t"; K = (lim > 48 ? lim : 48) }
      /^#/ || /^[[:space:]]*$/ { next }
      {
        kind = substr($0, 1, 1)
        rest = substr($0, index($0, "\t") + 1)
        n = split(rest, f, "\t")
        if (kind == "C") {
          key = f[1]
          if (key == "") next
          if (seen[key] > 0) next   # dedupe: first occurrence wins
          if (n >= 6) {
            c = tonum(f[2]); sc = tonum(f[3]); fl = tonum(f[4])
            lt = tonum(f[5]); ft = tonum(f[6]); d = (n >= 7 ? f[7] : ""); cl = (n >= 8 ? f[8] : "")
          } else {
            c=0; sc=0; fl=0; lt=0; ft=0; d=""; nums=0
            m = split(f[2], t, /[ \t]+/)
            for (i = 1; i <= m; i++) {
              tk = t[i]
              if (tk == "") continue
              if (substr(tk, 1, 1) == "/") { d = (d == "" ? tk : d "," tk); continue }
              if (nums < 5) {
                v = tk + 0; if (v < 0) v = 0
                if      (nums == 0) c  = v
                else if (nums == 1) sc = v
                else if (nums == 2) fl = v
                else if (nums == 3) lt = v
                else                ft = v
                nums++
              }
            }
          }
          ps = 0
          kl = length(key)
          if (pfx != "") {
            if (substr(key, 1, length(pfx)) != pfx) next
            ps += wpfx + int(int(length(pfx) * 100 / kl) / 4)
          } else {
            ok = 0
            if (d != "" && index(d, dir) > 0)       { ps += wdir;  ok = 1 }
            if (!ok && d != "" && index(d, pd) > 0) { ps += wdirp; ok = 1 }
            age = now - lt
            if (!ok && lt > 0 && age >= 0 && age < 86400) { ps += wd1; ok = 1 }
            if (!ok && admit != 1) next
          }
          fq = 0; cc2 = c
          while (cc2 > 1) { cc2 = int(cc2 / 2); fq++ }
          fb = fq * wfreq; if (fb > wfcap) fb = wfcap
          ps += fb
          tt = sc + fl
          if (tt > 0) ps += int(sc * wsuc / tt)
          if (lt > 0) {
            age = now - lt
            if      (age >= 0 && age < 3600)  ps += kh
            else if (age >= 0 && age < 86400) ps += wd1
          }
          seen[key] = 1
          nk++; pk[nk] = key; pp[nk] = ps
          rec[nk] = "C\t" key "\t" c "\t" sc "\t" fl "\t" lt "\t" ft "\t" d "\t" cl
        } else if (kind == "T" || kind == "W" || kind == "R") {
          if (n >= 2) print kind, f[1], tonum(f[2]), tonum(f[3]), (n >= 4 ? tonum(f[4]) : 0), "", "", ""
        }
      }
      END {
        taken = 0
        while (taken < K && taken < nk) {
          bi = -1; bv = -1
          for (i = 1; i <= nk; i++) {
            if (!done[i] && pp[i] > bv) { bv = pp[i]; bi = i }
          }
          done[bi] = 1
          print rec[bi]
          taken++
        }
      }
    ' "$FLOW_PRED_AGGREGATES"
  }

  load_norm() { # reads canonical records produced by awk_normalize
    local src="$1" kind kx n1 n2 n3 n4 n5 n6 n7 cls fw nx third c1 rem c2 pkey prev
    local IFS=$'\t'
    while IFS=$'\t' read -r kind kx n1 n2 n3 n4 n5 n6 n7; do
      case "$kind" in
        C)
          [ -n "$kx" ] || continue
          [ -z "${hist_seen[$kx]:-}" ] || continue
          hist_seen[$kx]=1
          POOL_N=$((POOL_N+1))
          cmd_stats["$kx"]="$n1 $n2 $n3 $n4 $n5"
          [ -n "$n6" ] && key_dirs["$kx"]="$n6"
          cls="$n7"
          if [ -z "$cls" ]; then
            fw="${kx%% *}"
            cls="${class_cache[$fw]:-}"
            if [ -z "$cls" ]; then flow_pred_classify "$kx"; cls="$FLOW_PRED_RESULT"; class_cache["$fw"]="$cls"; fi
          fi
          key_class["$kx"]="$cls"
          ;;
        T)
          { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
          trans["$kx"]="$n1 $n2"
          nx="${kx#*$'\x1f'}"
          [ "$nx" != "$kx" ] && anchor_next["$nx"]=1
          ;;
        W)
          { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
          workflow_stats["$kx"]="$n1 $n2 $n3"
          c1="${kx%%$'\x1f'*}"
          rem="${kx#"$c1"$'\x1f'}"
          [ "$rem" != "$kx" ] || continue
          c2="${rem%%$'\x1f'*}"
          pkey="$c1"$'\x1f'"$c2"
          prev="${wf_prefix[$pkey]:-0}"
          wf_prefix["$pkey"]=$(( prev + n1 ))
          case "$rem" in *$'\x1f'*)
            third="${rem#"$c2"$'\x1f'}"; third="${third%%$'\x1f'*}"
            [ -n "$third" ] && anchor_next["$third"]=1
          ;; esac
          ;;
        R)
          { [ -n "$S_PREV" ] || [ -n "$S_WFPRE" ]; } || continue
          recovery["$kx"]="$n1"
          nx="${kx#*$'\x1f'}"
          [ "$nx" != "$kx" ] && anchor_next["$nx"]=1
          ;;
      esac
    done < "$src"
  }

  awk_normalize 0 > "$_norm"
  load_norm "$_norm"
  if [ -z "$PREFIX" ] && [ "$POOL_N" -lt "$LIMIT" ]; then
    cmd_stats=(); key_dirs=(); key_class=(); hist_seen=(); class_cache=(); POOL_N=0
    awk_normalize 1 > "$_norm"
    load_norm "$_norm"
  fi
  rm -f "$_norm"
else
  # pure-shell fallback path
  _sel=""
  if command -v grep >/dev/null 2>&1 && [ -s "$FLOW_PRED_AGGREGATES" ]; then
    _sel="$(mktemp "${TMPDIR:-/tmp}/flow-sel.XXXXXX" 2>/dev/null)" || _sel=""
    if [ -n "$_sel" ]; then
      if [ -n "$PREFIX" ]; then
        _esc="$(printf '%s' "$PREFIX" | sed -e 's/[][\.*$^]/\\&/g')"
        { grep -E -- "^C"$'\t'"$_esc" "$FLOW_PRED_AGGREGATES" 2>/dev/null || true; } > "$_sel"
      else
        { grep -E -- "^[TWR]"$'\t' "$FLOW_PRED_AGGREGATES" 2>/dev/null || true
          grep -F -e "$DIR:" -e "$PARENT_DIR/" "$FLOW_PRED_AGGREGATES" 2>/dev/null \
            | grep -E -- "^C"$'\t' 2>/dev/null || true
        } > "$_sel"
      fi
    fi
  fi

  if [ -n "$_sel" ]; then
    load_stream "$_sel" 1
    rm -f "$_sel"
  else
    load_stream "$FLOW_PRED_AGGREGATES" 0
  fi
  if [ -z "$PREFIX" ] && [ "$POOL_N" -lt "$LIMIT" ]; then
    cmd_stats=(); key_dirs=(); key_class=(); hist_seen=(); POOL_N=0
    load_stream "$FLOW_PRED_AGGREGATES" 1
  fi
fi

t_load_end=$(date +%s%N 2>/dev/null || echo 0)

# ---- result collection (bounded top-K, fork-free) --------------------------
top_score=(); top_key=(); top_expl=(); top_src=(); top_meta=()

add_result() { # <score> <key> <explain> <source> <meta>
  local score="$1" key="$2" expl="$3" src="$4" meta="$5"
  local n=${#top_score[@]}
  if [ "$n" -ge "$LIMIT" ]; then
    [ "$score" -gt "${top_score[$((LIMIT-1))]}" ] || return 0
  fi
  local pos=0
  while [ "$pos" -lt "$n" ] && [ "${top_score[$pos]}" -ge "$score" ]; do pos=$((pos+1)); done
  local i=$(( n < LIMIT ? n : LIMIT-1 ))
  while [ "$i" -gt "$pos" ]; do
    top_score[$i]="${top_score[$((i-1))]}"; top_key[$i]="${top_key[$((i-1))]}"
    top_expl[$i]="${top_expl[$((i-1))]}";   top_src[$i]="${top_src[$((i-1))]}"
    top_meta[$i]="${top_meta[$((i-1))]}"
    i=$((i-1))
  done
  if [ "$pos" -lt "$LIMIT" ]; then
    top_score[$pos]="$score"; top_key[$pos]="$key"
    top_expl[$pos]="$expl";   top_src[$pos]="$src"; top_meta[$pos]="$meta"
  fi
}

# ---- rank historical candidates --------------------------------------------
score_row() { # full engine scoring for one stored key
  local key="$1"
  set -- ${cmd_stats[$key]}
  count=$1 success=$2 fail=$3 last=$4 first=$5
  dirs="${key_dirs[$key]:-}"
  tcnt=0 rcnt=0 wcnt=0
  if [ -n "$S_PREV" ]; then
    pk="$S_PREV"$'\x1f'"$key"
    tvals="${trans["$pk"]:-0 0}"
    tcnt="${tvals%% *}"
    rcnt="${recovery["$pk"]:-0}"
  fi
  if [ -n "$S_WFPRE" ]; then wcnt="${wf_prefix[$S_WFPRE]:-0}"; fi
  flow_pred_score_fields "$key" "$count" "$success" "$fail" "$last" "$first" \
    "$dirs" "${key_class[$key]:-other}" "$PREFIX" "$CTX" "$tcnt" "$wcnt" "$rcnt"
}

collect_row() { # score + insert into bounded top-K
  local key="$1"
  score_row "$key"
  if [ "$FLOW_PRED_MATCH" -eq 1 ] && [ "$FLOW_PRED_SCORE" -gt 0 ]; then
    set -- ${cmd_stats[$key]}
    meta="$1 $2 $3 $4 ${key_class[$key]:-other}"
    add_result "$FLOW_PRED_SCORE" "$key" "${FLOW_PRED_EXPLAIN:-}" "history" "$meta"
  fi
}

if [ "$POOL_N" -gt 0 ]; then
  for key in "${!cmd_stats[@]}"; do collect_row "$key"; done
fi

# ---- "./" filesystem discovery ----------------------------------------------
FS_SCANNED=0
if [ "${PREFIX#./}" != "$PREFIX" ]; then
  fs_rest="${PREFIX#./}"
  # recency markers (4 forks total, once per run)
  _fs_tmp="$(mktemp -d 2>/dev/null || echo "/tmp/flow-fs.$$")"
  mkdir -p "$_fs_tmp"
  touch -d '1 hour ago'  "$_fs_tmp/m1h" 2>/dev/null
  touch -d '1 day ago'   "$_fs_tmp/m1d" 2>/dev/null
  touch -d '7 days ago'  "$_fs_tmp/m7d" 2>/dev/null
  shopt -s nullglob dotglob
  for fpath in *; do
    FS_SCANNED=$((FS_SCANNED+1))
    [ "$FS_SCANNED" -le 400 ] || break          # hard scan cap: cwd only, flat
    case "$fpath" in "$fs_rest"*) ;; *) continue ;; esac
    [ -f "$fpath" ] || continue                  # regular files only
    ftype=""
    if [ -x "$fpath" ]; then ftype="exec"; else
      case "$fpath" in
        *.sh|*.bash|*.zsh|*.py|*.pl|*.rb|*.fish) ftype="script" ;;
        *) continue ;;
      esac
    fi
    key="./$fpath"
    # skip if history already surfaced this exact key with real usage stats
    [ -z "${cmd_stats[$key]:-}" ] || continue
    prefixlen=${#PREFIX}; keylen=${#key}
    score=$(( FLOW_PRED_W_PREFIX + (prefixlen * 100 / keylen) / 4 ))
    expl="prefix_match"
    if [ "$ftype" = "exec" ]; then score=$((score+6)); expl="$expl fs_exec"; else expl="$expl fs_script"; fi
    mtime_bonus=0; recent=""
    if [ "$fpath" -nt "$_fs_tmp/m1h" ]; then mtime_bonus=8; recent="recently_modified"
    elif [ "$fpath" -nt "$_fs_tmp/m1d" ]; then mtime_bonus=6; recent="recently_modified"
    elif [ "$fpath" -nt "$_fs_tmp/m7d" ]; then mtime_bonus=3; recent="recently_modified"
    fi
    score=$((score+mtime_bonus))
    [ -n "$recent" ] && expl="$expl $recent"
    # blend prior success stats for this exact command key, if any twin exists
    if [ -n "${cmd_stats[$key]:-}" ]; then :; fi
    [ "$score" -gt 90 ] && score=90
    meta="1 1 0 0 script:$ftype"
    add_result "$score" "$key" "$expl" "filesystem" "$meta"
  done
  shopt -u nullglob dotglob
  rm -rf "$_fs_tmp" 2>/dev/null
fi

t_score_end=$(date +%s%N 2>/dev/null || echo 0)

elapsed_ms=0 elapsed_load_ms=0 elapsed_score_ms=0
if [ "$t_all_start" != "0" ] && [ "$t_score_end" != "0" ]; then
  elapsed_ms=$(( (t_score_end - t_all_start) / 1000000 ))
  elapsed_load_ms=$(( (t_load_end - t_all_start) / 1000000 ))
  elapsed_score_ms=$(( (t_score_end - t_load_end) / 1000000 ))
fi

count=${#top_score[@]}

# confidence for best result
best_score=0
[ "$count" -gt 0 ] && best_score="${top_score[0]}"
flow_pred_confidence "$best_score"
best_conf="$FLOW_PRED_RESULT"

_json_escape() {
  printf '%s' "$1" | jq -Rsa . 2>/dev/null || printf '"%s"' "$1"
}

tab=$'\t'
if [ "$JSON" -eq 1 ]; then
  printf '{'
  printf '"schema":%d,' "$FLOW_PRED_SCHEMA_VERSION"
  printf '"prefix":%s,' "$(_json_escape "$PREFIX")"
  printf '"count":%d,' "$count"
  printf '"latency_ms":%d,"latency_load_ms":%d,"latency_score_ms":%d,' "$elapsed_ms" "$elapsed_load_ms" "$elapsed_score_ms"
  printf '"keys_considered":%d,' "$POOL_N"
  printf '"confidence":%s,' "$(_json_escape "$best_conf")"
  printf '"context":{"dir":%s,"profile":%s,"workspace":%s,"project":%s,"runtime":%s,"host":%s},' \
    "$(_json_escape "$DIR")" "$(_json_escape "$PROFILE")" "$(_json_escape "$WORKSPACE")" \
    "$(_json_escape "$PROJECT")" "$(_json_escape "$RUNTIME")" "$(_json_escape "$HOST")"
  printf '"candidates":['
  for ((i=0; i<count; i++)); do
    [ $i -gt 0 ] && printf ','
    score="${top_score[$i]}"
    key="${top_key[$i]}"
    expl="${top_expl[$i]}"
    src="${top_src[$i]}"
    meta="${top_meta[$i]}"
    set -- $meta
    flow_pred_confidence "$score"; cand_conf="$FLOW_PRED_RESULT"
    reasons="["
    first_reason=1
    for token in $expl; do
      case "$token" in
        prefix_match)       r="prefix_match" ;;
        dir_match)          r="exact_directory" ;;
        parent_dir_match)   r="parent_directory" ;;
        profile_match)      r="profile_match" ;;
        workspace_match)    r="workspace_match" ;;
        project_match)      r="project_match" ;;
        runtime_match)      r="runtime_match" ;;
        session_match)      r="session_match" ;;
        follows_prev)       r="follows_previous_command" ;;
        workflow_step)      r="workflow_continuation" ;;
        recovery_candidate) r="recovery_after_failure" ;;
        high_failure_rate)  r="high_failure_rate" ;;
        recently_used)      r="recently_used" ;;
        recently_modified)  r="recently_modified" ;;
        fs_exec)            r="executable_file" ;;
        fs_script)          r="script_file" ;;
        *)                  r="$token" ;;
      esac
      [ $first_reason -eq 0 ] && reasons+=","
      reasons+="$(_json_escape "$r")"
      first_reason=0
    done
    reasons+="]"
    printf '{"score":%d,"confidence":%s,"command":%s,"source":%s,"count":%d,"success":%d,"fail":%d,"class":%s,"risk":%s,"reasons":%s}' \
      "$score" "$(_json_escape "$cand_conf")" "$(_json_escape "$key")" "$(_json_escape "$src")" \
      "$1" "$2" "$3" \
      "$(_json_escape "${5:-other}")" \
      "$(_json_escape "$(flow_pred_risk_class "$key"; printf '%s' "$FLOW_PRED_RESULT")")" \
      "$reasons"
  done
  printf ']}\n'
  exit 0
fi

# ---- human-readable output --------------------------------------------------
echo "flow-suggest: ${count} candidate(s) for '${PREFIX}'"
echo "context: dir=${DIR} profile=${PROFILE} workspace=${WORKSPACE} project=${PROJECT} runtime=${RUNTIME} host=${HOST}"
echo "confidence: ${best_conf}  latency: ${elapsed_ms}ms (load ${elapsed_load_ms}ms + score ${elapsed_score_ms}ms)"
if [ "$DEBUG" -eq 1 ]; then
  echo "--- debug ---"
  echo "weights: prefix=$FLOW_PRED_W_PREFIX dir=$FLOW_PRED_W_DIR parent_dir=$FLOW_PRED_W_DIR_PARENT profile=$FLOW_PRED_W_PROFILE workspace=$FLOW_PRED_W_WORKSPACE project=$FLOW_PRED_W_PROJECT runtime=$FLOW_PRED_W_RUNTIME session=$FLOW_PRED_W_SESSION transition=$FLOW_PRED_W_TRANSITION workflow=$FLOW_PRED_W_WORKFLOW recovery=$FLOW_PRED_W_RECOVERY success=$FLOW_PRED_W_SUCCESS freq=$FLOW_PRED_W_FREQ"
  echo "confidence thresholds: very_high>=$FLOW_PRED_CONF_VHIGH high>=$FLOW_PRED_CONF_HIGH medium>=$FLOW_PRED_CONF_MEDIUM low>=$FLOW_PRED_CONF_LOW"
  n_tr=0; [ -n "${trans[@]+x}" ] && n_tr=${#trans[@]}
  n_wf=0; [ -n "${wf_prefix[@]+x}" ] && n_wf=${#wf_prefix[@]}
  n_rc=0; [ -n "${recovery[@]+x}" ] && n_rc=${#recovery[@]}
  echo "aggregates: keys=$POOL_N transitions=$n_tr workflows=$n_wf recoveries=$n_rc"
  [ "${PREFIX#./}" != "$PREFIX" ] && echo "fs-discovery: scanned=${FS_SCANNED} entries in $PWD"
  echo "empty-query mode: anchored=(dir|parent_dir|session|workflow|transition|recovery|recent<24h); unanchored excluded from pool"
fi
for ((i=0; i<count; i++)); do
  score="${top_score[$i]}"
  key="${top_key[$i]}"
  expl="${top_expl[$i]}"
  src="${top_src[$i]}"
  meta="${top_meta[$i]}"
  set -- $meta
  m_count=$1 m_success=$2 m_fail=$3 m_last=$4 m_class="${5:-other}"
  total=$(( m_success + m_fail ))
  pct=0
  [ "$total" -gt 0 ] && pct=$(( m_success * 100 / total ))
  ago=""
  if [ "$m_last" -gt 0 ]; then
    diff=$(( NOW_TS - m_last ))
    if [ "$diff" -lt 60 ]; then ago="just now"
    elif [ "$diff" -lt 3600 ]; then ago="$(( diff / 60 ))m ago"
    elif [ "$diff" -lt 86400 ]; then ago="$(( diff / 3600 ))h ago"
    else ago="$(( diff / 86400 ))d ago"
    fi
  else
    [ "$src" = "filesystem" ] && ago="on disk"
  fi
  flow_pred_confidence "$score"
  cand_conf="$FLOW_PRED_RESULT"
  line="  ${key}  score=${score} (${cand_conf})  src=${src}  reasons=[${expl}]"
  if [ "$src" = "history" ]; then
    line+="  ${m_count}x  ${pct}% success  ${ago}  class=${m_class}  risk=$(flow_pred_risk_class "$key"; printf '%s' "$FLOW_PRED_RESULT")"
  else
    line+="  ${ago}  class=script  risk=$(flow_pred_risk_class "$key"; printf '%s' "$FLOW_PRED_RESULT")"
  fi
  echo "$line"
done
