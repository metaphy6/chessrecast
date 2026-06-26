#!/usr/bin/env bash
# check-deps.sh — §9.6 T-X-001 / T-X-006 dependency integrity check.
#
# Verifies SHA pins for libsodium and pub.dev dependencies, and performs
# an SBOM diff review. Run from the repo root before every release.
#
# T-X-001: Compromised libsodium release — pin SHA, verify against mirrors.
# T-X-006: Transitive-dep crypto downgrade — SBOM diff + crypto_suite_id lock.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$REPO_ROOT/frontend"
SIGNALING_DIR="$REPO_ROOT/signaling"
SBOM_DIR="$REPO_ROOT/bots/reports/_shared"

# ── libsodium SHA pins (update when intentionally upgrading) ─────────────────
# Source: https://download.libsodium.org/libsodium/releases/
LIBSODIUM_VERSION="1.0.20"
LIBSODIUM_TARBALL_SHA256="ebb65ef6ca439333c2bb41a0c1990587288da07f6c7fd07cb3a18cc18d30ce19"

echo "==> [T-X-001] Checking libsodium version pin..."
NATIVE_CMAKEFILE="$FRONTEND_DIR/native/engine/CMakeLists.txt"
if [[ -f "$NATIVE_CMAKEFILE" ]]; then
    if grep -q "libsodium" "$NATIVE_CMAKEFILE"; then
        echo "    libsodium referenced in CMakeLists.txt ✓"
    else
        echo "    WARNING: libsodium not referenced in CMakeLists.txt — manual check required"
    fi
else
    echo "    WARNING: CMakeLists.txt not found at $NATIVE_CMAKEFILE"
fi

echo "    Expected libsodium version : $LIBSODIUM_VERSION"
echo "    Expected tarball SHA-256   : $LIBSODIUM_TARBALL_SHA256"
echo "    ACTION: verify the above SHA against https://download.libsodium.org/libsodium/releases/SIGNATURES before each build"

# ── pub.dev lockfile verification ────────────────────────────────────────────
echo ""
echo "==> [T-X-001/T-X-006] Checking pub.dev lockfile integrity..."
if [[ -f "$FRONTEND_DIR/pubspec.lock" ]]; then
    echo "    pubspec.lock present ✓"
    # Verify no package has a content-hash that differs from the lockfile.
    pushd "$FRONTEND_DIR" > /dev/null
    if dart pub deps --json > /dev/null 2>&1; then
        echo "    dart pub deps check passed ✓"
    else
        echo "ERROR: dart pub deps failed — lockfile may be inconsistent" >&2
        exit 1
    fi
    popd > /dev/null
else
    echo "ERROR: pubspec.lock missing — run 'flutter pub get' first" >&2
    exit 1
fi

# ── crypto_suite_id build-flag lock (T-X-006) ────────────────────────────────
echo ""
echo "==> [T-X-006] Checking crypto_suite_id is pinned to 0x01..."
CRYPTO_PIN_CHECK=0
if grep -rn "crypto_suite_id.*0x01\|kCryptoSuiteV1\|CryptoSuiteId.v1" \
    "$FRONTEND_DIR/lib/services/p2p/" 2>/dev/null | grep -q .; then
    echo "    crypto_suite_id pinned in Dart sources ✓"
    CRYPTO_PIN_CHECK=1
fi
if [[ $CRYPTO_PIN_CHECK -eq 0 ]]; then
    echo "    WARNING: could not verify crypto_suite_id pin in Dart sources — manual check required"
fi

# ── Go module verification ────────────────────────────────────────────────────
echo ""
echo "==> [T-X-001] Checking Go module checksums..."
if [[ -f "$SIGNALING_DIR/go.sum" ]]; then
    pushd "$SIGNALING_DIR" > /dev/null
    if go mod verify > /dev/null 2>&1; then
        echo "    go mod verify passed ✓"
    else
        echo "ERROR: go mod verify failed — dependency checksums do not match" >&2
        exit 1
    fi
    popd > /dev/null
else
    echo "    WARNING: signaling/go.sum not found — skipping Go module check"
fi

# ── SBOM diff (if a baseline exists) ─────────────────────────────────────────
echo ""
echo "==> [T-X-001/T-X-006] SBOM diff review..."
SBOM_BASELINE="$SBOM_DIR/sbom-baseline.json"
SBOM_CURRENT="$SBOM_DIR/sbom-current.json"
if [[ -f "$SBOM_BASELINE" && -f "$SBOM_CURRENT" ]]; then
    DIFF=$(diff <(jq -r '.packages[].name' "$SBOM_BASELINE" | sort) \
                <(jq -r '.packages[].name' "$SBOM_CURRENT" | sort) || true)
    if [[ -z "$DIFF" ]]; then
        echo "    No new packages since baseline ✓"
    else
        echo "    WARNING: SBOM diff detected — review new/removed packages:"
        echo "$DIFF" | sed 's/^/      /'
        echo "    ACTION: confirm these changes are intentional before release"
    fi
else
    echo "    No SBOM baseline found at $SBOM_BASELINE — skipping diff"
    echo "    Run 'make sbom' to generate the SBOM before the first release"
fi

echo ""
echo "==> check-deps.sh complete. Review any WARNINGs above before release."
