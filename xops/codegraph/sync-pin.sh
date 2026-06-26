#!/usr/bin/env bash
# Propagate xops/codegraph/VERSION into every place that mentions
# @colbymchenry/codegraph@<ver>. Idempotent. Run after editing VERSION.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="$REPO_ROOT/xops/codegraph/VERSION"
PIN="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [[ -z "$PIN" ]]; then
  echo "ERROR: $VERSION_FILE is empty" >&2
  exit 1
fi

# Files that contain a pin and must stay in lockstep.
FILES=(
  "$REPO_ROOT/.vscode/mcp.json"
  "$REPO_ROOT/.cursor/mcp.json"
  "$REPO_ROOT/.mcp.json"
  "$REPO_ROOT/docs/guides/CODEGRAPH.md"
)

changed=0
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "skip (missing): $f"
    continue
  fi
  before="$(sha1sum "$f" | awk '{print $1}')"
  # Rewrite any @colbymchenry/codegraph@<semver> occurrence.
  sed -E -i \
    "s|@colbymchenry/codegraph@[0-9]+\.[0-9]+\.[0-9]+|@colbymchenry/codegraph@${PIN}|g" \
    "$f"
  after="$(sha1sum "$f" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    echo "updated: $f"
    changed=$((changed+1))
  else
    echo "ok     : $f"
  fi
done

# Sync bots/components.yaml: tooling/codegraph version.
COMP="$REPO_ROOT/bots/components.yaml"
if [[ -f "$COMP" ]]; then
  before="$(sha1sum "$COMP" | awk '{print $1}')"
  # Only rewrite the version field inside the tooling/codegraph block.
  python3 - "$COMP" "$PIN" <<'PY'
import re, sys, pathlib
p, pin = pathlib.Path(sys.argv[1]), sys.argv[2]
text = p.read_text()
pat = re.compile(r'(tooling/codegraph:\s*\n\s*version:\s*")[0-9]+\.[0-9]+\.[0-9]+(")')
new = pat.sub(rf'\g<1>{pin}\g<2>', text)
p.write_text(new)
PY
  after="$(sha1sum "$COMP" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    echo "updated: $COMP"
    changed=$((changed+1))
  else
    echo "ok     : $COMP"
  fi
fi

echo
echo "Pin = $PIN  (files changed: $changed)"
