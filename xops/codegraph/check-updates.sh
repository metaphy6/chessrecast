#!/usr/bin/env bash
# Warn-only check: is there a newer @colbymchenry/codegraph on npm?
# Never bumps automatically — humans drive bumps per AGENTS.md §2.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PIN="$(tr -d '[:space:]' < "$REPO_ROOT/xops/codegraph/VERSION")"

# Fetch latest tag from the npm registry. No npm CLI dependency required.
LATEST="$(
  curl -fsSL --max-time 10 \
    'https://registry.npmjs.org/@colbymchenry/codegraph/latest' \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])' \
    2>/dev/null || true
)"

if [[ -z "$LATEST" ]]; then
  echo "codegraph: could not reach npm registry (offline or rate-limited). Pin = $PIN."
  exit 0
fi

if [[ "$LATEST" == "$PIN" ]]; then
  echo "codegraph: up to date (pin=$PIN, npm latest=$LATEST)."
  exit 0
fi

cat <<EOF
codegraph: NEWER VERSION AVAILABLE
  current pin (xops/codegraph/VERSION): $PIN
  npm latest:                            $LATEST

To upgrade:
  1. Read the changelog: https://www.npmjs.com/package/@colbymchenry/codegraph
  2. echo "$LATEST" > xops/codegraph/VERSION
  3. make codegraph.sync-pin
  4. make codegraph.reindex
  5. Verify it still works for the primary assistant, then stage + commit
     "chore(tooling): bump codegraph to $LATEST [<run-id>]".
EOF
