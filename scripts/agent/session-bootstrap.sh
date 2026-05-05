#!/usr/bin/env bash
# scripts/agent/session-bootstrap.sh
#
# Run this at the start of every Copilot Chat / Claude / Cursor agent session.
# It prints the minimum context the agent needs to avoid disorientation after
# a killed terminal or a window reload:
#   - current working directory
#   - current branch and last commit
#   - tail of agent/state/log.jsonl
#   - status of agent/state/current.json (if any task is in_progress)
#   - whether agent/state/checkpoint.json is present
#   - whether the native engine library is present and up to date
#   - sanity-check that the per-mod baseline files exist and are < 7 days old
#
# It is read-only: it does not change state, install packages, or run tests.
# Safe to run from any cwd inside the repo.

set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
dim()  { printf '\033[2m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*"; }

bold "== chessrecast agent session bootstrap =="
echo "repo_root: $repo_root"
echo "pwd:       $PWD"
echo "date:      $(date -Iseconds)"
echo

bold "-- git --"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "branch:    $(git rev-parse --abbrev-ref HEAD)"
  echo "last:      $(git --no-pager log -1 --pretty='%h %s (%ar)')"
  dirty="$(git status --porcelain)"
  if [[ -n "$dirty" ]]; then
    warn "working tree dirty:"
    echo "$dirty" | head -20
  else
    echo "status:    clean"
  fi
else
  err "not a git repo"
fi
echo

bold "-- agent state --"
state_dir="$repo_root/agent/state"
current="$state_dir/current.json"
checkpoint="$state_dir/checkpoint.json"
logfile="$state_dir/log.jsonl"

if [[ -f "$current" ]]; then
  status_field="$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$current" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  task_id="$(grep -o '"task_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$current" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  if [[ "$status_field" == "in_progress" ]]; then
    warn "current.json shows IN-PROGRESS task: ${task_id:-<unknown>}"
    warn "  -> verify whether its commit landed (git log) before claiming a new task"
  else
    echo "current.json status: ${status_field:-<none>}"
  fi
else
  dim "current.json: absent"
fi

if [[ -f "$checkpoint" ]]; then
  warn "checkpoint.json present — a previous session was interrupted:"
  head -20 "$checkpoint" | sed 's/^/  /'
else
  dim "checkpoint.json: absent"
fi

last_failure="$state_dir/last_failure.json"
if [[ -f "$last_failure" ]]; then
  resolved="$(grep -o '"resolved"[[:space:]]*:[[:space:]]*\(true\|false\)' "$last_failure" | tail -1 | awk '{print $NF}')"
  if [[ "$resolved" != "true" ]]; then
    err "last_failure.json present and UNRESOLVED — a previous command exited non-zero:"
    sed 's/^/  /' "$last_failure"
    err "  -> per AGENTS.md §5a: read the .log, diagnose, fix, resume, then set resolved:true (or delete this file)."
  else
    dim "last_failure.json present but resolved"
  fi
fi

if [[ -f "$logfile" ]]; then
  echo "last 5 log entries:"
  tail -5 "$logfile" | sed 's/^/  /'
else
  dim "log.jsonl: absent"
fi
echo

bold "-- native engine --"
native_lib="$repo_root/frontend/build/native/linux/libchess_engine.so"
if [[ -f "$native_lib" ]]; then
  lib_mtime=$(stat -c '%Y' "$native_lib")
  newest_src=$(find "$repo_root/frontend/native/engine" -type f \( -name '*.c' -o -name '*.h' \) -printf '%T@\n' 2>/dev/null | sort -nr | head -1 | cut -d. -f1)
  if [[ -n "$newest_src" && "$newest_src" -gt "$lib_mtime" ]]; then
    warn "libchess_engine.so is OLDER than C sources — run 'Frontend: Rebuild Native Engine' or 'cmake --build frontend/build/native/linux'"
  else
    echo "libchess_engine.so: up to date ($(date -d "@$lib_mtime" '+%Y-%m-%d %H:%M'))"
  fi
else
  err "libchess_engine.so MISSING — rebuild before running flutter test"
fi
echo

bold "-- baselines --"
seven_days_ago=$(( $(date +%s) - 7*24*3600 ))
for mod in heir friendly_fire kings_battle mercenary save_the_queen succession truce; do
  bf="$repo_root/agent/baselines/$mod.json"
  if [[ -f "$bf" ]]; then
    mt=$(stat -c '%Y' "$bf")
    if (( mt < seven_days_ago )); then
      warn "  $mod: STALE ($(date -d "@$mt" '+%Y-%m-%d')) — refresh before triaging"
    else
      echo "  $mod: ok ($(date -d "@$mt" '+%Y-%m-%d'))"
    fi
  else
    warn "  $mod: MISSING — run a baseline batch via /improve-mod $mod"
  fi
done
echo

bold "-- queue --"
qf="$repo_root/agent/queue.yaml"
if [[ -f "$qf" ]]; then
  pending=$(grep -c '^  status: pending' "$qf" 2>/dev/null | head -1)
  in_progress=$(grep -c '^  status: in_progress' "$qf" 2>/dev/null | head -1)
  failed=$(grep -c '^  status: failed' "$qf" 2>/dev/null | head -1)
  echo "  pending=${pending:-0}  in_progress=${in_progress:-0}  failed=${failed:-0}"
fi
echo

bold "== ready =="
echo "Read AGENTS.md and .github/copilot-instructions.md before editing."
echo "If a slash command's gates pass: commit and push to main. No exceptions."
