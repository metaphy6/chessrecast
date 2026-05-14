#!/usr/bin/env bash
# xops/agent/run-test-with-retry.sh
#
# Flake-quarantine wrapper: run a flutter test once. If it fails, retry once.
# - Both fail -> exit with the second exit code (real failure).
# - First fails, second passes -> log to agent/state/flakes.jsonl AND append
#   a `kind: kpi_regression / phase: tactics / severity: low` queue entry,
#   then exit 0 so the calling gate proceeds.
#
# Usage:
#   xops/agent/run-test-with-retry.sh <test-file> [-- <extra flutter test args...>]
#
# Run from the repo root or from frontend/. Standard env-var prefixes
# (CHESSRECAST_NATIVE_ENGINE_LIB, LD_LIBRARY_PATH, *_BATCH_*) must already be
# exported by the caller.

set -u

if [ $# -lt 1 ]; then
  echo "usage: $0 <test-file> [-- <flutter test args>]" >&2
  exit 64
fi

TEST_FILE="$1"
shift
EXTRA_ARGS=()
if [ "${1:-}" = "--" ]; then
  shift
  EXTRA_ARGS=("$@")
fi

# Locate repo root.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "run-test-with-retry: not in a git repo" >&2
  exit 2
fi

FRONTEND_DIR="$REPO_ROOT/frontend"
if [ ! -d "$FRONTEND_DIR" ]; then
  echo "run-test-with-retry: $FRONTEND_DIR missing" >&2
  exit 2
fi

cd "$FRONTEND_DIR"

run_once() {
  flutter test "$TEST_FILE" "${EXTRA_ARGS[@]}"
}

echo "run-test-with-retry: attempt 1/2 -- $TEST_FILE"
if run_once; then
  exit 0
fi
FIRST_RC=$?

echo "run-test-with-retry: attempt 1 failed (rc=$FIRST_RC); retrying once..."
if run_once; then
  echo "run-test-with-retry: FLAKE detected ($TEST_FILE) -- logging."
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  flake_path="$REPO_ROOT/agent/state/flakes.jsonl"
  mkdir -p "$REPO_ROOT/agent/state"
  printf '{"timestamp":"%s","test":"%s","first_rc":%d}\n' \
    "$ts" "$TEST_FILE" "$FIRST_RC" >> "$flake_path"

  # Append queue entry. Mod is best-effort guessed from the filename.
  mod="$(basename "$TEST_FILE" | sed -E 's/^(manual_)?([a-z_]+)_(engine_)?regression_test\.dart$/\2/; s/^(manual_)?([a-z_]+)_audit_batch_test\.dart$/\2/; s/^(manual_)?([a-z_]+)_position_probe_test\.dart$/\2/; s/_test\.dart$//')"
  qfile="$REPO_ROOT/agent/queue.yaml"
  slug="flake-$(echo "$TEST_FILE" | sed -E 's|.*/||; s|\..*$||')-$(date -u +%Y%m%d%H%M%S)"
  {
    echo ""
    echo "- id: ${mod:-shared}-flake-$slug"
    echo "  mod: ${mod:-shared}"
    echo "  status: pending"
    echo "  kind: kpi_regression"
    echo "  phase: tactics"
    echo "  severity: low"
    echo "  evidence:"
    echo "    report: agent/state/flakes.jsonl"
    echo "    line: 0"
    echo "  blunder_threshold_cp: 0"
    echo "  notes: \"Flaky test ${TEST_FILE} -- failed once then passed; investigate timing/non-determinism.\""
  } >> "$qfile"

  exit 0
fi
SECOND_RC=$?
echo "run-test-with-retry: both attempts failed (rc1=$FIRST_RC rc2=$SECOND_RC)" >&2
exit "$SECOND_RC"
