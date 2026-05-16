#!/usr/bin/env bash
# xops/p2p/verify-reproducible-build.sh
#
# §6.5.5 — Verifies that the ChessRecast Android APK / iOS IPA build is
# reproducible from the current source tree.
#
# Reproducible build = two independent builds from the same source commit
# (with no network access for dependencies beyond the initial fetch) produce
# byte-for-byte identical artefacts.
#
# Usage:
#   ./xops/p2p/verify-reproducible-build.sh [--platform android|ios|all]
#
# The script:
#   1. Builds the release artefact once (build A).
#   2. Clears only the Gradle / Xcode derived data caches (not the pub cache).
#   3. Builds again (build B).
#   4. Compares SHA-256 digests; fails if they differ.
#
# Prerequisites:
#   - Flutter SDK on PATH.
#   - Android: ANDROID_HOME set, Gradle ≥ 7.
#   - iOS: macOS with Xcode ≥ 15 and code-signing disabled (ad-hoc or None).
#   - REPO_ROOT must be the workspace root (auto-detected if running from there).
#
# Environment:
#   PLATFORM   android|ios|all (default: android)
#   KEEP_ARTEFACTS  if set to 1, do not delete build outputs after comparison
#   LOGFILE    path to write a machine-readable JSON result (default: stdout)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FRONTEND_DIR="${REPO_ROOT}/frontend"

PLATFORM="${PLATFORM:-android}"
KEEP_ARTEFACTS="${KEEP_ARTEFACTS:-0}"
LOGFILE="${LOGFILE:-}"

log() { echo "[repro-build] $*" >&2; }
die() { echo "[repro-build] FATAL: $*" >&2; exit 1; }

# ── Helpers ──────────────────────────────────────────────────────────────────

sha256_of() {
  # Portable SHA-256 (sha256sum on Linux, shasum -a 256 on macOS).
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

build_android() {
  local label="$1"
  log "Building Android release APK (${label})…"
  (
    cd "${FRONTEND_DIR}"
    flutter build apk --release --no-pub 2>&1
  )
  local apk
  apk="$(find "${FRONTEND_DIR}/build/app/outputs/flutter-apk" -name "*.apk" | head -1)"
  [[ -f "${apk}" ]] || die "APK not found after build ${label}"
  echo "${apk}"
}

build_ios() {
  local label="$1"
  log "Building iOS release IPA (${label}) — code signing disabled…"
  (
    cd "${FRONTEND_DIR}"
    flutter build ipa --release --no-pub \
      --export-method ad-hoc \
      --no-codesign 2>&1 || true  # --no-codesign may not be available; ignore
  )
  local ipa
  ipa="$(find "${FRONTEND_DIR}/build/ios/ipa" -name "*.ipa" | head -1)"
  [[ -f "${ipa}" ]] || die "IPA not found after build ${label}"
  echo "${ipa}"
}

clean_caches_android() {
  log "Cleaning Android Gradle caches (not pub cache)…"
  (
    cd "${FRONTEND_DIR}/android"
    ./gradlew clean --quiet 2>&1 || true
  )
  rm -rf "${FRONTEND_DIR}/build/app"
}

clean_caches_ios() {
  log "Cleaning Xcode derived data…"
  rm -rf ~/Library/Developer/Xcode/DerivedData 2>/dev/null || true
  rm -rf "${FRONTEND_DIR}/build/ios"
}

verify_platform() {
  local platform="$1"
  local artefact_a artefact_b sha_a sha_b

  case "${platform}" in
    android)
      artefact_a="$(build_android "A")"
      sha_a="$(sha256_of "${artefact_a}")"
      log "Build A SHA-256: ${sha_a}  (${artefact_a})"
      cp "${artefact_a}" "${artefact_a}.build-a"

      clean_caches_android

      artefact_b="$(build_android "B")"
      sha_b="$(sha256_of "${artefact_b}")"
      log "Build B SHA-256: ${sha_b}  (${artefact_b})"
      ;;
    ios)
      artefact_a="$(build_ios "A")"
      sha_a="$(sha256_of "${artefact_a}")"
      log "Build A SHA-256: ${sha_a}  (${artefact_a})"
      cp "${artefact_a}" "${artefact_a}.build-a"

      clean_caches_ios

      artefact_b="$(build_ios "B")"
      sha_b="$(sha256_of "${artefact_b}")"
      log "Build B SHA-256: ${sha_b}  (${artefact_b})"
      ;;
    *)
      die "Unknown platform: ${platform}.  Use android, ios, or all."
      ;;
  esac

  if [[ "${sha_a}" == "${sha_b}" ]]; then
    log "✓ REPRODUCIBLE — both builds match: ${sha_a}"
    emit_result "${platform}" "pass" "${sha_a}" ""
    [[ "${KEEP_ARTEFACTS}" == "1" ]] || rm -f "${artefact_b}" "${artefact_b%.apk}.build-a" "${artefact_b%.ipa}.build-a" 2>/dev/null || true
    return 0
  else
    log "✗ NOT REPRODUCIBLE — build A: ${sha_a}, build B: ${sha_b}"
    emit_result "${platform}" "fail" "${sha_a}" "${sha_b}"
    return 1
  fi
}

emit_result() {
  local platform="$1" status="$2" sha_a="$3" sha_b="$4"
  local json
  json="{\"platform\":\"${platform}\",\"status\":\"${status}\",\"sha_a\":\"${sha_a}\",\"sha_b\":\"${sha_b}\",\"run_id\":\"${RUN_ID:-}\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
  if [[ -n "${LOGFILE}" ]]; then
    echo "${json}" >> "${LOGFILE}"
  else
    echo "${json}"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  # Parse --platform flag.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform) PLATFORM="$2"; shift 2 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  log "Repo root: ${REPO_ROOT}"
  log "Platform:  ${PLATFORM}"

  # Ensure pub deps are present but do not re-fetch during builds.
  (cd "${FRONTEND_DIR}" && flutter pub get --no-precompile 2>&1)

  local exit_code=0
  if [[ "${PLATFORM}" == "all" ]]; then
    verify_platform android || exit_code=$?
    verify_platform ios     || exit_code=$?
  else
    verify_platform "${PLATFORM}" || exit_code=$?
  fi

  exit "${exit_code}"
}

main "$@"
