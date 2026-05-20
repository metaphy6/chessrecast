#!/usr/bin/env bash
# xops/p2p/wire-version-pin-check.sh
#
# Phase 17 §17.6.4 — Verify the running binary's wire_version constant
# resolves to a commit SHA that appears in docs/P2P_PROTOCOL.md's version
# history table, confirming the build is pinned to a documented protocol rev.
#
# Usage:
#   ./xops/p2p/wire-version-pin-check.sh [--artefact <path>] [--version <string>]
#
# Options:
#   --artefact  Path to the built binary/lib whose wire_version string to
#               extract. Default: frontend/build/native/linux/libchess_engine.so
#   --version   Explicit wire_version string (skips artefact extraction).
#   --protocol  Path to the protocol doc. Default: docs/P2P_PROTOCOL.md
#   --dry-run   Print resolution steps without writing to budget JSON.
#
# Exits 0 if the wire_version appears in the protocol doc, 1 if not, 2 on
# infrastructure error.
#
# The script also records the result in agent/baselines/p2p_budgets.json
# under integrity.wire_version_to_protocol_doc_pinned.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUDGET_JSON="$REPO_ROOT/agent/baselines/p2p_budgets.json"

ARTEFACT_PATH="$REPO_ROOT/frontend/build/native/linux/libchess_engine.so"
WIRE_VERSION=""
PROTOCOL_DOC="$REPO_ROOT/docs/P2P_PROTOCOL.md"
DRY_RUN=0

usage() {
  echo "Usage: $0 [--artefact <path>] [--version <string>] [--protocol <path>] [--dry-run]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artefact)  ARTEFACT_PATH="$2";  shift 2 ;;
    --version)   WIRE_VERSION="$2";   shift 2 ;;
    --protocol)  PROTOCOL_DOC="$2";   shift 2 ;;
    --dry-run)   DRY_RUN=1;           shift ;;
    -h|--help)   usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

# ── Step 1: resolve wire_version ─────────────────────────────────────────────
if [[ -z "$WIRE_VERSION" ]]; then
  if [[ ! -f "$ARTEFACT_PATH" ]]; then
    echo "ERROR: artefact not found: $ARTEFACT_PATH" >&2
    echo "Provide --version <string> to skip artefact extraction." >&2
    exit 2
  fi
  # The wire_version is embedded as a null-terminated C string literal such as:
  #   static const char WIRE_VERSION[] = "p2p-v1.4-abc1234";
  # Extract via `strings` + grep for the known prefix pattern.
  WIRE_VERSION=$(strings "$ARTEFACT_PATH" 2>/dev/null \
    | grep -E '^p2p-v[0-9]+\.[0-9]+(-[a-f0-9]{7,})?$' \
    | head -1 || true)

  if [[ -z "$WIRE_VERSION" ]]; then
    echo "ERROR: could not find wire_version string in $ARTEFACT_PATH" >&2
    echo "Expected pattern: p2p-v<major>.<minor>[-<sha>]" >&2
    exit 2
  fi
fi

echo "wire_version: $WIRE_VERSION"

# ── Step 2: check protocol doc ───────────────────────────────────────────────
if [[ ! -f "$PROTOCOL_DOC" ]]; then
  echo "ERROR: protocol doc not found: $PROTOCOL_DOC" >&2
  exit 2
fi

if grep -qF "$WIRE_VERSION" "$PROTOCOL_DOC" 2>/dev/null; then
  PINNED=true
  echo "OK: '$WIRE_VERSION' found in $PROTOCOL_DOC"
else
  PINNED=false
  echo "FAIL: '$WIRE_VERSION' NOT found in $PROTOCOL_DOC" >&2
  echo "Every wire_version bump must be documented in the protocol version" >&2
  echo "history table before the build is promoted." >&2
fi

# ── Step 3: record result ─────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "0" && -f "$BUDGET_JSON" ]]; then
  python3 - "$BUDGET_JSON" "$PINNED" <<'EOF'
import json, sys
path, val = sys.argv[1], sys.argv[2] == "true"
data = json.load(open(path))
for l in data["leaves"]:
    if l["id"] == "integrity.wire_version_to_protocol_doc_pinned":
        l["baseline"] = val
        break
json.dump(data, open(path, "w"), indent=2)
EOF
fi

if [[ "$PINNED" == "false" ]]; then
  exit 1
fi

echo "wire-version-pin-check passed."
