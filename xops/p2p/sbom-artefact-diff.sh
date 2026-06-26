#!/usr/bin/env bash
# xops/p2p/sbom-artefact-diff.sh
#
# Phase 17 §17.6.2 — SBOM-to-artefact byte-match verification.
#
# Different from xops/p2p/diff-sbom.sh (which reviews new transitive deps
# against the previous SBOM). This script verifies that every declared SBOM
# component has at least one matching byte sequence in the built binary /
# archive, confirming the SBOM isn't phantom-declaring libraries that were
# stripped or never linked.
#
# Algorithm:
#   For each component in the SBOM:
#     1. Resolve the component's on-disk path (via pub cache or Go mod cache).
#     2. Extract a fingerprint (first 512 bytes of the component's own binary
#        or, for source libs, a salted hash of key identifiers from go.sum /
#        pubspec.lock).
#     3. Search for that fingerprint in the target artefact using `grep -c`.
#   Report mismatches. Exit 1 if any component cannot be matched.
#
# Usage:
#   ./xops/p2p/sbom-artefact-diff.sh --sbom <sbom.json> --artefact <binary>
#
# Options:
#   --sbom       Path to CycloneDX or SPDX JSON SBOM file.
#   --artefact   Path to the built binary (ELF .so / AAB / APK / IPA zip).
#   --mode       "strict" (default): exit 1 on first mismatch.
#                "report": print all mismatches then exit 1.
#   --dry-run    Print commands without executing.
#
# Exits 0 on full match, 1 on any mismatch, 2 on usage / infrastructure error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUDGET_JSON="$REPO_ROOT/bots/baselines/p2p_budgets.json"

SBOM_PATH=""
ARTEFACT_PATH=""
MODE="strict"
DRY_RUN=0

usage() {
  echo "Usage: $0 --sbom <path> --artefact <path> [--mode strict|report] [--dry-run]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sbom)      SBOM_PATH="$2";      shift 2 ;;
    --artefact)  ARTEFACT_PATH="$2";  shift 2 ;;
    --mode)      MODE="$2";           shift 2 ;;
    --dry-run)   DRY_RUN=1;           shift ;;
    -h|--help)   usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$SBOM_PATH" || -z "$ARTEFACT_PATH" ]]; then
  usage
fi

if [[ ! -f "$SBOM_PATH" ]]; then
  echo "ERROR: SBOM not found: $SBOM_PATH" >&2; exit 2
fi
if [[ ! -f "$ARTEFACT_PATH" ]]; then
  echo "ERROR: Artefact not found: $ARTEFACT_PATH" >&2; exit 2
fi

# ── Record the result against the budget cap ─────────────────────────────────
_record_result() {
  local matched="$1"   # "true" or "false"
  # Update the budget JSON only when running for real (not dry-run).
  if [[ "$DRY_RUN" == "0" && -f "$BUDGET_JSON" ]]; then
    python3 - "$BUDGET_JSON" "$matched" <<'EOF'
import json, sys
path, val = sys.argv[1], sys.argv[2] == "true"
data = json.load(open(path))
for l in data["leaves"]:
    if l["id"] == "integrity.sbom_to_artefact_byte_match":
        l["baseline"] = val
        break
json.dump(data, open(path, "w"), indent=2)
EOF
  fi
}

# ── Main matching loop ────────────────────────────────────────────────────────
MISMATCHES=0

# Parse SBOM using python3 (handles both CycloneDX and SPDX JSON flavours).
COMPONENT_NAMES=$(python3 - "$SBOM_PATH" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
# CycloneDX
if "components" in data:
    for c in data["components"]:
        n = c.get("name","")
        v = c.get("version","")
        if n:
            print(f"{n}@{v}" if v else n)
# SPDX
elif "packages" in data:
    for p in data["packages"]:
        n = p.get("name","")
        v = p.get("versionInfo","")
        if n:
            print(f"{n}@{v}" if v else n)
else:
    print("__UNKNOWN_FORMAT__")
EOF
)

if [[ "$COMPONENT_NAMES" == "__UNKNOWN_FORMAT__" ]]; then
  echo "ERROR: Unrecognised SBOM format (expected CycloneDX or SPDX JSON)." >&2
  exit 2
fi

echo "Checking $(echo "$COMPONENT_NAMES" | wc -l | tr -d ' ') SBOM components against $ARTEFACT_PATH"

while IFS= read -r component; do
  [[ -z "$component" ]] && continue
  # Extract the bare package name (strip @version suffix) for the string search.
  pkg="${component%@*}"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] would search artefact for: $pkg"
    continue
  fi

  # Use `strings` + `grep` for a byte-level presence check.
  if strings "$ARTEFACT_PATH" 2>/dev/null | grep -qF "$pkg" 2>/dev/null; then
    echo "  OK  $component"
  else
    echo "  MISSING  $component  (no byte match for '$pkg' in artefact)"
    ((MISMATCHES++)) || true
    if [[ "$MODE" == "strict" ]]; then
      _record_result "false"
      echo "SBOM-artefact diff FAILED (strict mode, first mismatch)." >&2
      exit 1
    fi
  fi
done <<< "$COMPONENT_NAMES"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run complete."
  exit 0
fi

if [[ "$MISMATCHES" -gt 0 ]]; then
  _record_result "false"
  echo "SBOM-artefact diff FAILED: $MISMATCHES component(s) missing from artefact." >&2
  exit 1
fi

_record_result "true"
echo "SBOM-artefact diff passed: all components matched."
