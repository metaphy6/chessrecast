#!/usr/bin/env bash
# data-flow-completeness-check.sh
# Roadmap §18.1 — CI gate that ensures every P2P data write / network egress
# in tagged code has a corresponding row in docs/p2p/P2P_PRIVACY.md's
# "Data-flow inventory" table.
#
# Usage:
#   xops/p2p/data-flow-completeness-check.sh [--repo-root=<path>]
#
# Exit codes:
#   0  — all annotated writes are covered (or no annotations yet)
#   1  — one or more annotated writes reference an unknown data class
#   2  — the inventory section is missing from P2P_PRIVACY.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
for arg in "$@"; do
  case "$arg" in
    --repo-root=*) REPO_ROOT="${arg#--repo-root=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

PRIVACY_DOC="$REPO_ROOT/docs/p2p/P2P_PRIVACY.md"

# ---------------------------------------------------------------------------
# 1. Check the inventory section exists
# ---------------------------------------------------------------------------
if ! grep -q '## Data-flow inventory' "$PRIVACY_DOC" 2>/dev/null; then
  echo "ERROR: $PRIVACY_DOC does not contain a '## Data-flow inventory' section." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 2. Extract known data classes from the inventory table
#    Lines look like: | <data class> | <lifetime> | ...
# ---------------------------------------------------------------------------
known_classes=()
in_inventory=0
while IFS= read -r line; do
  if [[ "$line" == *"## Data-flow inventory"* ]]; then
    in_inventory=1
    continue
  fi
  # Stop at the next h2 section
  if [[ $in_inventory -eq 1 && "$line" =~ ^##[[:space:]] ]]; then
    break
  fi
  if [[ $in_inventory -eq 1 && "$line" =~ ^\|[[:space:]][A-Za-z] ]]; then
    # Extract first column (strip leading/trailing spaces)
    col1=$(echo "$line" | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Skip the header row separator
    if [[ "$col1" != "---"* && "$col1" != "Data class"* && -n "$col1" ]]; then
      known_classes+=("$col1")
    fi
  fi
done < "$PRIVACY_DOC"

if [[ ${#known_classes[@]} -eq 0 ]]; then
  echo "ERROR: No data-class rows found in the inventory table in $PRIVACY_DOC" >&2
  exit 2
fi

echo "INFO: Found ${#known_classes[@]} data classes in inventory:"
for cls in "${known_classes[@]}"; do
  echo "  - $cls"
done

# ---------------------------------------------------------------------------
# 3. Scan P2P-tagged code for @p2p-data annotations
#    Convention: // @p2p-data:<data-class>
#    Any annotation whose class is not in the inventory → fail.
# ---------------------------------------------------------------------------
P2P_DIRS=(
  "$REPO_ROOT/frontend/lib/services/p2p"
  "$REPO_ROOT/frontend/lib/services/identity"
  "$REPO_ROOT/frontend/lib/services/clock"
  "$REPO_ROOT/frontend/lib/services/replay"
  "$REPO_ROOT/signaling"
)

uncovered=()
for dir in "${P2P_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r hit; do
    # hit format: <file>:<lineno>:   // @p2p-data:Chat history (player)
    annotation=$(echo "$hit" | sed 's/.*@p2p-data:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    found=0
    for cls in "${known_classes[@]}"; do
      if [[ "$annotation" == "$cls" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      uncovered+=("$hit")
    fi
  done < <(grep -rn '@p2p-data:' "$dir" --include="*.dart" --include="*.go" 2>/dev/null || true)
done

# ---------------------------------------------------------------------------
# 4. Report
# ---------------------------------------------------------------------------
if [[ ${#uncovered[@]} -gt 0 ]]; then
  echo "ERROR: The following @p2p-data annotations reference unknown data classes:" >&2
  for u in "${uncovered[@]}"; do
    echo "  $u" >&2
  done
  echo "" >&2
  echo "Add the missing data class(es) to the '## Data-flow inventory' table in" >&2
  echo "  $PRIVACY_DOC" >&2
  exit 1
fi

echo "OK: All @p2p-data annotations are covered by the inventory."
exit 0
