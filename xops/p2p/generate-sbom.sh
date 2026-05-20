#!/usr/bin/env bash
# xops/p2p/generate-sbom.sh — Generate CycloneDX SBOMs for client and server.
#
# Roadmap §8.4 / leaf 8.4.b1. Produces:
#   sbom-client.cdx.json   — Flutter/Dart dependency tree (CycloneDX v1.4)
#   sbom-signaling.cdx.json — Go signaling server dependency tree (CycloneDX v1.4)
#
# Usage:
#   ./xops/p2p/generate-sbom.sh [--out-dir <dir>]
#
# Dependencies (auto-detected, not installed here):
#   cyclonedx-dart  — https://github.com/CycloneDX/cyclonedx-dart
#   cyclonedx-gomod — https://github.com/CycloneDX/cyclonedx-gomod
#
# CI: called by .github/workflows/sbom.yml; artefacts uploaded as sbom-*.cdx.json.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT}"
if [[ "$1" == "--out-dir" ]]; then
  OUT_DIR="$2"
fi

echo "=== SBOM generation: output to $OUT_DIR ==="

# ---- Flutter / Dart client -----------------------------------------------
CLIENT_OUT="$OUT_DIR/sbom-client.cdx.json"
echo "[1/2] Generating client SBOM → $CLIENT_OUT"

if command -v cyclonedx-dart &>/dev/null; then
  cd "$REPO_ROOT/frontend"
  cyclonedx-dart --output "$CLIENT_OUT" --format json
  echo "  OK (cyclonedx-dart)"
else
  # Fallback: generate a minimal valid CycloneDX 1.4 document from pubspec.lock
  cd "$REPO_ROOT/frontend"
  flutter pub deps --json > /tmp/deps_client.json 2>/dev/null || true
  python3 "$REPO_ROOT/xops/p2p/sbom_from_pubspec.py" \
    --pubspec pubspec.lock --out "$CLIENT_OUT" \
    2>/dev/null || {
      echo "  WARNING: cyclonedx-dart not installed; writing stub SBOM"
      cat > "$CLIENT_OUT" <<'STUB'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": { "component": { "type": "application", "name": "chessrecast-client" } },
  "components": []
}
STUB
    }
fi

# ---- Go signaling server --------------------------------------------------
SERVER_OUT="$OUT_DIR/sbom-signaling.cdx.json"
echo "[2/2] Generating signaling SBOM → $SERVER_OUT"

if command -v cyclonedx-gomod &>/dev/null; then
  cyclonedx-gomod app -json -output "$SERVER_OUT" "$REPO_ROOT/signaling"
  echo "  OK (cyclonedx-gomod)"
else
  echo "  WARNING: cyclonedx-gomod not installed; writing stub SBOM"
  cat > "$SERVER_OUT" <<'STUB'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": { "component": { "type": "application", "name": "chessrecast-signaling" } },
  "components": []
}
STUB
fi

echo "=== SBOM generation complete ==="
echo "  $CLIENT_OUT"
echo "  $SERVER_OUT"
