#!/usr/bin/env bash
# xops/p2p/check-artefact-size.sh
#
# Phase 17 §17.3.4 — APK/IPA size-delta enforcement.
#
# Usage:
#   ./xops/p2p/check-artefact-size.sh [--apk <path>] [--ipa <path>] [--base-apk <path>] [--base-ipa <path>]
#
# Checks that the delta between a P2P build artefact and its baseline is
# within the budgeted caps from agent/baselines/p2p_budgets.json:
#   APK delta ≤ 6 MB (efficiency.apk_size_increase_mb)
#   IPA delta ≤ 9 MB (efficiency.ipa_size_increase_mb)
#
# Exits 0 on success, 1 on budget breach, 2 on missing artefact / JSON.
#
# Caps are read from the budget JSON rather than hardcoded so a single
# authoritative source governs both the test and the CI enforcement step.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUDGET_JSON="$REPO_ROOT/agent/baselines/p2p_budgets.json"

APK_PATH=""
IPA_PATH=""
BASE_APK_PATH=""
BASE_IPA_PATH=""

usage() {
  echo "Usage: $0 [--apk <path>] [--ipa <path>] [--base-apk <path>] [--base-ipa <path>]" >&2
  echo "At least one of --apk / --ipa must be provided." >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)       APK_PATH="$2";      shift 2 ;;
    --ipa)       IPA_PATH="$2";      shift 2 ;;
    --base-apk)  BASE_APK_PATH="$2"; shift 2 ;;
    --base-ipa)  BASE_IPA_PATH="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ -z "$APK_PATH" && -z "$IPA_PATH" ]]; then
  usage
fi

# ── Read caps from budget JSON ────────────────────────────────────────────────
if [[ ! -f "$BUDGET_JSON" ]]; then
  echo "ERROR: $BUDGET_JSON not found." >&2
  exit 2
fi

_get_cap() {
  local leaf_id="$1"
  python3 - "$BUDGET_JSON" "$leaf_id" <<'EOF'
import json, sys
path, lid = sys.argv[1], sys.argv[2]
leaves = json.load(open(path))["leaves"]
m = next((l for l in leaves if l["id"] == lid), None)
if not m:
    print("MISSING")
    sys.exit(2)
print(m["cap"])
EOF
}

APK_CAP_MB=$(_get_cap "efficiency.apk_size_increase_mb")
IPA_CAP_MB=$(_get_cap "efficiency.ipa_size_increase_mb")

echo "Caps from budget JSON — APK: ${APK_CAP_MB} MB, IPA: ${IPA_CAP_MB} MB"

# ── Helper: size in bytes ─────────────────────────────────────────────────────
file_mb() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: artefact not found: $f" >&2
    exit 2
  fi
  python3 -c "import os; print(os.path.getsize('$f') / 1024 / 1024)"
}

# ── APK check ─────────────────────────────────────────────────────────────────
if [[ -n "$APK_PATH" ]]; then
  NEW_MB=$(file_mb "$APK_PATH")
  if [[ -n "$BASE_APK_PATH" ]]; then
    BASE_MB=$(file_mb "$BASE_APK_PATH")
    DELTA=$(python3 -c "print($NEW_MB - $BASE_MB)")
    echo "APK: base=${BASE_MB:.2f} MB, new=${NEW_MB:.2f} MB, delta=${DELTA:.2f} MB (cap=${APK_CAP_MB} MB)"
    BREACH=$(python3 -c "print(1 if float('$DELTA') > float('$APK_CAP_MB') else 0)")
  else
    echo "APK: size=${NEW_MB:.2f} MB (no base provided; cap=${APK_CAP_MB} MB, skipping delta check)"
    BREACH=0
  fi

  if [[ "$BREACH" == "1" ]]; then
    echo "BUDGET BREACH: APK delta ${DELTA} MB exceeds cap ${APK_CAP_MB} MB" >&2
    exit 1
  fi
fi

# ── IPA check ─────────────────────────────────────────────────────────────────
if [[ -n "$IPA_PATH" ]]; then
  NEW_MB=$(file_mb "$IPA_PATH")
  if [[ -n "$BASE_IPA_PATH" ]]; then
    BASE_MB=$(file_mb "$BASE_IPA_PATH")
    DELTA=$(python3 -c "print($NEW_MB - $BASE_MB)")
    echo "IPA: base=${BASE_MB:.2f} MB, new=${NEW_MB:.2f} MB, delta=${DELTA:.2f} MB (cap=${IPA_CAP_MB} MB)"
    BREACH=$(python3 -c "print(1 if float('$DELTA') > float('$IPA_CAP_MB') else 0)")
  else
    echo "IPA: size=${NEW_MB:.2f} MB (no base provided; cap=${IPA_CAP_MB} MB, skipping delta check)"
    BREACH=0
  fi

  if [[ "$BREACH" == "1" ]]; then
    echo "BUDGET BREACH: IPA delta ${DELTA} MB exceeds cap ${IPA_CAP_MB} MB" >&2
    exit 1
  fi
fi

echo "artefact-size check passed."
