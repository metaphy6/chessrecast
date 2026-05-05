#!/usr/bin/env bash
# scripts/agent/safe-run.sh
#
# Crash-safe command wrapper. Use this for any command whose failure would
# otherwise leave the agent stuck (terminal died, output lost, "Analyzing..."
# spinner forever). It guarantees that — even if the parent shell or chat
# session is killed mid-run — three artifacts survive on disk:
#
#   /tmp/agent-runs/<run-id>.cmd     # the exact command + cwd + env snippet
#   /tmp/agent-runs/<run-id>.log     # combined stdout + stderr (tee'd live)
#   /tmp/agent-runs/<run-id>.exit    # exit code (written ONLY after exit;
#                                    # absence means the command was killed)
#
# On non-zero exit it ALSO writes a short JSON record to
# agent/state/last_failure.json so the next session's bootstrap surfaces it
# immediately. The agent is then expected to:
#   1. read the .log to diagnose the failure,
#   2. fix the root cause (rebuild, install missing lib, file a queue entry,
#      etc. — see AGENTS.md §5a "Non-zero exit recovery protocol"),
#   3. resume the interrupted task from agent/state/checkpoint.json or by
#      re-running this command.
#
# The wrapper itself NEVER swallows the inner exit code: it always exits with
# the same code the wrapped command did, so calling gates still see failure.
#
# Usage:
#   scripts/agent/safe-run.sh <tag> -- <command> [args...]
#
# Example:
#   scripts/agent/safe-run.sh heir-batch -- flutter test test/manual_heir_audit_batch_test.dart
#
# <tag> is a short slug (a-z0-9_-) used in the run-id. Keep it descriptive
# (e.g. "heir-batch", "rebuild-native", "merc-probe-fen").

set -u

if [ $# -lt 3 ] || [ "$2" != "--" ]; then
  echo "usage: $0 <tag> -- <command> [args...]" >&2
  exit 64
fi

TAG="$1"
shift 2  # drop tag and the literal "--"

# Sanitize tag (defensive — agent should already pass a clean slug).
SAFE_TAG="$(echo "$TAG" | tr -c 'a-zA-Z0-9_-' '-' | cut -c1-40)"
if [ -z "$SAFE_TAG" ]; then SAFE_TAG="run"; fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUN_DIR="/tmp/agent-runs"
mkdir -p "$RUN_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="${SAFE_TAG}-${TS}-$$"
CMD_FILE="$RUN_DIR/${RUN_ID}.cmd"
LOG_FILE="$RUN_DIR/${RUN_ID}.log"
EXIT_FILE="$RUN_DIR/${RUN_ID}.exit"

# Capture invocation context up-front so it survives even if the command
# crashes the shell (segfault, OOM-kill).
{
  echo "run_id: $RUN_ID"
  echo "started_at: $(date -Iseconds)"
  echo "cwd: $PWD"
  echo "repo_root: $REPO_ROOT"
  echo "user: ${USER:-unknown}"
  echo "shell_pid: $$"
  echo "cmd:"
  printf '  %q' "$@"
  echo
  echo "env_subset:"
  for v in CHESSRECAST_NATIVE_ENGINE_LIB LD_LIBRARY_PATH PATH \
           HEIR_BATCH_LIVE_PROGRESS FRIENDLY_FIRE_BATCH_LIVE_PROGRESS \
           KB_BATCH_LIVE_PROGRESS MERC_BATCH_LIVE_PROGRESS \
           STQ_BATCH_LIVE_PROGRESS SUCCESSION_BATCH_LIVE_PROGRESS \
           TRUCE_BATCH_LIVE_PROGRESS; do
    val="${!v-}"
    if [ -n "$val" ]; then
      printf '  %s=%q\n' "$v" "$val"
    fi
  done
} > "$CMD_FILE"

echo "safe-run: tag=$SAFE_TAG run_id=$RUN_ID log=$LOG_FILE" >&2

# Run the command, tee'ing combined output to the log file. Use a subshell
# so we always capture the exit code even on signals.
set +e
( "$@" ) 2>&1 | tee "$LOG_FILE"
# PIPESTATUS[0] is the exit code of the wrapped command (left of the pipe).
RC="${PIPESTATUS[0]}"
set -e

echo "$RC" > "$EXIT_FILE"
echo "safe-run: exit=$RC run_id=$RUN_ID" >&2

if [ "$RC" -ne 0 ]; then
  # Persist a machine-readable failure marker for the next session.
  failure_json="$REPO_ROOT/agent/state/last_failure.json"
  mkdir -p "$(dirname "$failure_json")"
  # Build with simple printf to avoid jq/python dependency.
  esc_cmd="$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  esc_cwd="$(printf '%s' "$PWD" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  cat > "$failure_json" <<EOF
{
  "run_id": "$RUN_ID",
  "tag": "$SAFE_TAG",
  "exit_code": $RC,
  "failed_at": "$(date -Iseconds)",
  "cwd": "$esc_cwd",
  "cmd": "$esc_cmd",
  "log": "$LOG_FILE",
  "cmd_file": "$CMD_FILE",
  "resolved": false,
  "hint": "Diagnose via the log, fix the root cause, then mark resolved:true (or delete this file) and resume the interrupted task."
}
EOF
  echo "safe-run: wrote failure marker -> $failure_json" >&2
fi

exit "$RC"
