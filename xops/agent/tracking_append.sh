#!/usr/bin/env bash
# xops/agent/tracking_append.sh
#
# Atomically append ONE row to agent/tracking.csv.
# Enforces every invariant from agent/tracking.schema.md so an
# ill-formed row cannot land. Concurrent agent runs are serialised via
# flock(1) on the CSV file itself.
#
# All field arguments are passed as `--key=value` so the agent never has to
# count comma positions. Empty values are written as empty cells.
#
# Usage:
#   xops/agent/p2p_tracking_append.sh \
#     --run-id=<slug> --command=/implement-roadmap --model=<m> \
#     --phase=<p> --phase-title="<t>" --action=<a> --status=<s> \
#     [--commit-sha=pending|<sha>] [--files-changed=N] [--tests-added=N] \
#     [--tests-run=N] [--tests-passed=N] [--tests-failed=N] \
#     [--proof-test-paths="a;b"] [--roadmap-box-state="[ ]|[~]|[x]"] \
#     [--drift-kind=<k>] [--evidence-path=<p>] [--notes="..."] \
#     [--component=<c>] [--component-version=<v>] [--commit-message="..."]
#
# Defaults: counts → 0, drift-kind → none, box-state → "[ ]", others → "".
# Exit non-zero on any invariant violation; the row is NOT appended.

set -euo pipefail

CSV="agent/tracking.csv"
LOCK_FD=9

# --- defaults --------------------------------------------------------------
ts_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
run_id=""; command=""; model="unknown"; phase=""; phase_title=""
action=""; status=""; commit_sha=""
files_changed=0; tests_added=0; tests_run=0; tests_passed=0; tests_failed=0
proof_test_paths=""; roadmap_box_state="[ ]"; drift_kind="none"
evidence_path=""; notes=""
component=""; component_version=""; commit_message=""

# --- arg parsing -----------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --run-id=*)            run_id="${arg#*=}" ;;
    --command=*)           command="${arg#*=}" ;;
    --model=*)             model="${arg#*=}" ;;
    --phase=*)             phase="${arg#*=}" ;;
    --phase-title=*)       phase_title="${arg#*=}" ;;
    --action=*)            action="${arg#*=}" ;;
    --status=*)            status="${arg#*=}" ;;
    --commit-sha=*)        commit_sha="${arg#*=}" ;;
    --files-changed=*)     files_changed="${arg#*=}" ;;
    --tests-added=*)       tests_added="${arg#*=}" ;;
    --tests-run=*)         tests_run="${arg#*=}" ;;
    --tests-passed=*)      tests_passed="${arg#*=}" ;;
    --tests-failed=*)      tests_failed="${arg#*=}" ;;
    --proof-test-paths=*)  proof_test_paths="${arg#*=}" ;;
    --roadmap-box-state=*) roadmap_box_state="${arg#*=}" ;;
    --drift-kind=*)        drift_kind="${arg#*=}" ;;
    --evidence-path=*)     evidence_path="${arg#*=}" ;;
    --notes=*)             notes="${arg#*=}" ;;
    --component=*)         component="${arg#*=}" ;;
    --component-version=*) component_version="${arg#*=}" ;;
    --commit-message=*)    commit_message="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 64 ;;
  esac
done

# --- required fields -------------------------------------------------------
for var in run_id command model phase phase_title action status; do
  if [[ -z "${!var}" ]]; then
    echo "tracking_append: --${var//_/-} is required" >&2; exit 65
  fi
done

# --- enum validation -------------------------------------------------------
# Accept any /slash-command or bare identifier as the command string.
[[ "$command" =~ ^/[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$|^[a-zA-Z0-9_-]+$ ]] || {
  echo "invalid --command: '$command' (must start with / or be an identifier)" >&2; exit 65; }
case "$action" in
  plan|implement|test|review|amend|skip|gate_fail|drift_detected|commit|revert) ;;
  *) echo "invalid --action: $action" >&2; exit 65 ;;
esac
case "$status" in
  started|in_progress|passed|failed|reverted|blocked|completed) ;;
  *) echo "invalid --status: $status" >&2; exit 65 ;;
esac
case "$drift_kind" in
  none|spec_mismatch|missing_test|stale_box|extra_change|test_skipped|assertion_weakened|csv_tamper|edit_outside_scope) ;;
  *) echo "invalid --drift-kind: $drift_kind" >&2; exit 65 ;;
esac
case "$roadmap_box_state" in
  "[ ]"|"[~]"|"[x]") ;;
  *) echo "invalid --roadmap-box-state: $roadmap_box_state" >&2; exit 65 ;;
esac

# --- numeric validation ----------------------------------------------------
for n in files_changed tests_added tests_run tests_passed tests_failed; do
  [[ "${!n}" =~ ^[0-9]+$ ]] || { echo "$n must be an integer" >&2; exit 65; }
done
if (( tests_passed + tests_failed != tests_run )); then
  echo "tests_passed ($tests_passed) + tests_failed ($tests_failed) != tests_run ($tests_run)" >&2
  exit 65
fi

# --- box-state invariant ---------------------------------------------------
if [[ "$roadmap_box_state" == "[x]" ]]; then
  if (( tests_failed != 0 )); then
    echo "box [x] but tests_failed=$tests_failed" >&2; exit 65
  fi
  case "$action" in
    commit|review) ;;
    *) echo "box [x] only allowed with action=commit|review (got $action)" >&2; exit 65 ;;
  esac
fi

# --- commit_sha invariant --------------------------------------------------
if [[ "$action" == "commit" ]]; then
  # Accept 'pending' (written by agent before make git commits) or a real hex SHA
  if [[ "$commit_sha" != "pending" ]] && ! [[ "$commit_sha" =~ ^[0-9a-f]{7,40}$ ]]; then
    echo "action=commit requires --commit-sha=pending or --commit-sha=<7-40 hex>" >&2; exit 65
  fi
elif [[ "$action" == "revert" ]]; then
  [[ "$commit_sha" =~ ^[0-9a-f]{7,40}$ ]] || {
    echo "action=revert requires --commit-sha=<7-40 hex>" >&2; exit 65; }
else
  [[ -z "$commit_sha" ]] || {
    echo "--commit-sha forbidden for action=$action" >&2; exit 65; }
fi

# --- CSV escape ------------------------------------------------------------
csv_escape() {
  local v="$1"
  if [[ "$v" == *,* || "$v" == *\"* || "$v" == *$'\n'* ]]; then
    v="${v//\"/\"\"}"
    printf '"%s"' "$v"
  else
    printf '%s' "$v"
  fi
}

row=""
for v in \
  "$ts_utc" "$run_id" "$command" "$model" "$phase" "$phase_title" \
  "$action" "$status" "$commit_sha" "$files_changed" "$tests_added" \
  "$tests_run" "$tests_passed" "$tests_failed" "$proof_test_paths" \
  "$roadmap_box_state" "$drift_kind" "$evidence_path" "$notes" \
  "$component" "$component_version" "$commit_message"; do
  row+="$(csv_escape "$v"),"
done
row="${row%,}"

# --- locked atomic append --------------------------------------------------
[[ -f "$CSV" ]] || { echo "$CSV not found (cwd=$PWD)" >&2; exit 66; }

exec {LOCK_FD}>>"$CSV"
flock -x "$LOCK_FD"

# Monotone ts_utc check.
last_ts="$(tail -n 1 "$CSV" | awk -F, 'NR==1{gsub(/^"|"$/,"",$1); print $1}')"
if [[ -n "$last_ts" && "$last_ts" != "ts_utc" ]]; then
  if [[ "$ts_utc" < "$last_ts" ]]; then
    echo "ts_utc $ts_utc < previous $last_ts (clock went backward?)" >&2
    exit 67
  fi
fi

printf '%s\n' "$row" >>"$CSV"
flock -u "$LOCK_FD"
exec {LOCK_FD}>&-
echo "appended: $action/$status phase=$phase box=$roadmap_box_state"
