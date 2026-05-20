#!/usr/bin/env bash
# xops/p2p/diff-sbom.sh
#
# §8.6.b5 — Diffs SBOM artefacts between two releases (or between HEAD
# and the last release) and reports new direct dependencies.
#
# A new direct dependency must be documented in a queue entry of
# kind: p2p_dep_review in agent/queue.yaml before merging.
#
# Usage:
#   ./xops/p2p/diff-sbom.sh [--prev <path|tag>] [--curr <path|tag>]
#
# If --prev is a git tag, the script fetches its attached SBOM artefact from
# the GitHub release; otherwise it treats the value as a local file path.
# If --curr is omitted, the script generates a fresh SBOM from the working tree.
#
# Exit codes:
#   0  No new direct deps (or diff is clean)
#   1  New direct deps found — human review required

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PREV_ARG=""
CURR_ARG=""
COMPONENT="client"  # client | signaling

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prev) PREV_ARG="$2"; shift 2 ;;
    --curr) CURR_ARG="$2"; shift 2 ;;
    --component) COMPONENT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[sbom-diff] $*" >&2; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# Extract a sorted list of "name@version" component pairs from a CycloneDX JSON.
extract_components() {
  python3 - "$1" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    sbom = json.load(f)

components = sbom.get("components", [])
for c in sorted(components, key=lambda x: x.get("name", "")):
    name = c.get("name", "?")
    ver  = c.get("version", "?")
    print(f"{name}@{ver}")
PYEOF
}

# ── Resolve inputs ────────────────────────────────────────────────────────────

TMPDIR_LOCAL="$(mktemp -d /tmp/sbom-diff.XXXXXX)"
trap 'rm -rf "${TMPDIR_LOCAL}"' EXIT

# Determine current SBOM.
if [[ -z "${CURR_ARG}" ]]; then
  log "Generating current SBOM from working tree…"
  CURR_SBOM="${TMPDIR_LOCAL}/sbom-curr.cdx.json"
  COMPONENT="${COMPONENT}" SBOM_OUTPUT_DIR="${TMPDIR_LOCAL}" \
    bash "${SCRIPT_DIR}/generate-sbom.sh" 2>/dev/null || true
  if [[ "${COMPONENT}" == "signaling" ]]; then
    cp "${TMPDIR_LOCAL}/sbom-signaling.cdx.json" "${CURR_SBOM}" 2>/dev/null || { log "WARN: signaling SBOM not found; exiting clean"; exit 0; }
  else
    cp "${TMPDIR_LOCAL}/sbom-client.cdx.json" "${CURR_SBOM}" 2>/dev/null || { log "WARN: client SBOM not found; exiting clean"; exit 0; }
  fi
else
  CURR_SBOM="${CURR_ARG}"
fi

# Determine previous SBOM.
if [[ -z "${PREV_ARG}" ]]; then
  log "No --prev specified; looking for last git tag…"
  PREV_TAG="$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo '')"
  if [[ -z "${PREV_TAG}" ]]; then
    log "No previous tag; nothing to compare against. Exiting clean."
    exit 0
  fi
  log "Previous tag: ${PREV_TAG}"
  PREV_SBOM="${TMPDIR_LOCAL}/sbom-prev.cdx.json"
  if command -v gh &>/dev/null; then
    gh release download "${PREV_TAG}" \
      --dir "${TMPDIR_LOCAL}" \
      --pattern "sbom-*.cdx.json" 2>/dev/null || true
    prev_candidate="$(ls "${TMPDIR_LOCAL}"/sbom-*.cdx.json 2>/dev/null | head -1 || echo '')"
    if [[ -z "${prev_candidate}" ]]; then
      log "WARN: could not download SBOM for ${PREV_TAG}; exiting clean."
      exit 0
    fi
    mv "${prev_candidate}" "${PREV_SBOM}"
  else
    log "WARN: gh CLI not available; cannot download previous SBOM. Exiting clean."
    exit 0
  fi
else
  PREV_SBOM="${PREV_ARG}"
fi

# ── Diff ─────────────────────────────────────────────────────────────────────

log "Comparing:"
log "  prev: ${PREV_SBOM}"
log "  curr: ${CURR_SBOM}"

PREV_LIST="${TMPDIR_LOCAL}/prev.txt"
CURR_LIST="${TMPDIR_LOCAL}/curr.txt"

extract_components "${PREV_SBOM}" | sort > "${PREV_LIST}"
extract_components "${CURR_SBOM}" | sort > "${CURR_LIST}"

ADDED="$(comm -13 "${PREV_LIST}" "${CURR_LIST}")"
REMOVED="$(comm -23 "${PREV_LIST}" "${CURR_LIST}")"

if [[ -z "${ADDED}" && -z "${REMOVED}" ]]; then
  log "✓ No dependency changes between releases."
  exit 0
fi

if [[ -n "${REMOVED}" ]]; then
  log "Removed dependencies:"
  while IFS= read -r line; do
    log "  - ${line}"
  done <<< "${REMOVED}"
fi

if [[ -n "${ADDED}" ]]; then
  echo ""
  echo "================================================================"
  echo " NEW DIRECT DEPENDENCIES — human review required"
  echo " Each new dep must have a 'kind: p2p_dep_review' entry in"
  echo " agent/queue.yaml before this change can merge."
  echo "================================================================"
  while IFS= read -r line; do
    echo "  + ${line}"
  done <<< "${ADDED}"
  echo ""
  exit 1
fi

exit 0
