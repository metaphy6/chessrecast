#!/usr/bin/env bash
# xops/p2p/audit-secrets.sh — §8.8 / leaf 8.8.b4
#
# Secret-hygiene audit gate.
# Verifies that no plaintext secret appears in:
#   - source files tracked by git (repository contents)
#   - CI/CD workflow files (GitHub Actions)
#   - Docker/container layer metadata (Dockerfile ARG/ENV)
#   - .env or env-file candidates
#
# Exits 0 if clean. Exits 1 and prints findings if any violation is detected.
#
# Usage:
#   ./xops/p2p/audit-secrets.sh              # audit whole repo
#   ./xops/p2p/audit-secrets.sh --help       # print this help
#
# Customise false-positive suppression via .audit-secrets-ignore (one regex per
# line, comments with #).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

IGNORE_FILE=".audit-secrets-ignore"
EXIT_CODE=0
FINDINGS=()

log()   { echo "[audit-secrets] $*"; }
warn()  { echo "[audit-secrets] WARN: $*" >&2; }
error() { echo "[audit-secrets] ERROR: $*" >&2; EXIT_CODE=1; }

# ---------------------------------------------------------------------------
# Load suppression patterns from optional ignore file.
# ---------------------------------------------------------------------------
declare -a SUPPRESS_PATTERNS=()
if [[ -f "$REPO_ROOT/$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    SUPPRESS_PATTERNS+=("$line")
  done < "$REPO_ROOT/$IGNORE_FILE"
fi

is_suppressed() {
  local match="$1"
  for pat in "${SUPPRESS_PATTERNS[@]+"${SUPPRESS_PATTERNS[@]}"}"; do
    if echo "$match" | grep -qE "$pat"; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Helper: scan files with a given regex.  Prints file:line for each hit.
# ---------------------------------------------------------------------------
scan_pattern() {
  local label="$1"
  local pattern="$2"
  shift 2
  local files=("$@")

  if [[ ${#files[@]} -eq 0 ]]; then
    return
  fi

  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[$label] $hit")
    EXIT_CODE=1
  done < <(grep -rnI --include="*.go" --include="*.dart" --include="*.yaml" \
    --include="*.yml" --include="*.env" --include="*.sh" \
    -E "$pattern" "${files[@]}" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# 1. Detect hardcoded high-entropy strings that look like secrets.
#    Heuristic: 32-128 hex or base64 chars in a variable assignment.
# ---------------------------------------------------------------------------
log "1/6  Scanning for hardcoded high-entropy strings…"
# Get all tracked (non-binary) files
mapfile -t TRACKED < <(git ls-files --cached --others --exclude-standard | grep -vE '\.(png|jpg|jpeg|gif|ico|woff|ttf|so|a|class|jar|zip|gz)$' || true)

HEX_PATTERN='(secret|token|hmac|password|passwd|api.?key|private.?key|signing.?key|HMAC_SECRET|KMS_KEY|FCM_KEY|APNS_KEY)\s*[:=]\s*["\x27][0-9a-fA-F]{32,128}["\x27]'
B64_PATTERN='(secret|token|hmac|password|passwd|api.?key|private.?key|signing.?key)\s*[:=]\s*["\x27][A-Za-z0-9+/]{40,}={0,2}["\x27]'

if [[ ${#TRACKED[@]} -gt 0 ]]; then
  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[hardcoded-hex-secret] $hit")
    EXIT_CODE=1
  done < <(grep -rnI -E "$HEX_PATTERN" "${TRACKED[@]}" 2>/dev/null || true)

  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[hardcoded-b64-secret] $hit")
    EXIT_CODE=1
  done < <(grep -rnI -E "$B64_PATTERN" "${TRACKED[@]}" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# 2. Detect plaintext secrets in .env files or files named *.env.
# ---------------------------------------------------------------------------
log "2/6  Scanning .env files…"
mapfile -t ENV_FILES < <(git ls-files --cached | grep -E '(\.env|\.env\.[a-z]+|env\.example)$' || true)
if [[ ${#ENV_FILES[@]} -gt 0 ]]; then
  # Flag any .env file that is tracked AND contains a non-example value:
  # real secrets look like KEY=<40+ char value that is not a placeholder>
  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[env-file-secret] $hit")
    EXIT_CODE=1
  done < <(grep -nE '^[A-Z_]+=.{32,}$' "${ENV_FILES[@]}" 2>/dev/null | grep -v '=<' | grep -v '=\$' | grep -v '#' || true)
fi

# ---------------------------------------------------------------------------
# 3. Detect secrets in CI/CD workflow files.
# ---------------------------------------------------------------------------
log "3/6  Scanning CI/CD workflow files…"
mapfile -t CI_FILES < <(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null || true)
if [[ ${#CI_FILES[@]} -gt 0 ]]; then
  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[ci-plaintext-secret] $hit")
    EXIT_CODE=1
  done < <(grep -nE '(password|secret|token|key):\s+[A-Za-z0-9+/]{16,}' "${CI_FILES[@]}" 2>/dev/null \
    | grep -v '\${{' | grep -v 'github\.token' || true)
fi

# ---------------------------------------------------------------------------
# 4. Detect Docker ARG/ENV that bake secrets into container layers.
# ---------------------------------------------------------------------------
log "4/6  Scanning Dockerfiles for baked-in secrets…"
mapfile -t DOCKERFILES < <(find . -name 'Dockerfile*' -not -path './archive/*' 2>/dev/null || true)
if [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[dockerfile-baked-secret] $hit")
    EXIT_CODE=1
  done < <(grep -nE '(ENV|ARG)\s+(SECRET|TOKEN|HMAC|PASSWORD|API_KEY|PRIVATE_KEY|SIGNING_KEY)\s*=' "${DOCKERFILES[@]}" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# 5. Check that secrets/ directory is SOPS-encrypted (not plain YAML/JSON).
# ---------------------------------------------------------------------------
log "5/6  Verifying secrets/ directory uses encrypted store…"
if [[ -d "secrets" ]]; then
  while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      if ! grep -q '"sops":' "$f" && ! grep -q 'sops:' "$f"; then
        if is_suppressed "$f"; then
          continue
        fi
        FINDINGS+=("[unencrypted-secret-file] $f — does not appear to be SOPS-encrypted")
        EXIT_CODE=1
      fi
    fi
  done < <(find secrets/ -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# 6. Detect PEM-encoded private keys committed to git.
# ---------------------------------------------------------------------------
log "6/6  Scanning for committed PEM private keys…"
if [[ ${#TRACKED[@]} -gt 0 ]]; then
  while IFS= read -r hit; do
    if is_suppressed "$hit"; then
      continue
    fi
    FINDINGS+=("[committed-pem-key] $hit")
    EXIT_CODE=1
  done < <(grep -rnI '-----BEGIN .* PRIVATE KEY-----' "${TRACKED[@]}" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo ""
if [[ ${#FINDINGS[@]} -eq 0 ]]; then
  log "All checks passed — no plaintext secrets detected."
  exit 0
else
  error "Found ${#FINDINGS[@]} potential secret exposure(s):"
  for f in "${FINDINGS[@]}"; do
    echo "  $f"
  done
  echo ""
  echo "Remediation:"
  echo "  1. Move secrets to SOPS-encrypted store: sops -e -i secrets/<file>.enc.yaml"
  echo "  2. Reference via \${{ secrets.NAME }} in CI (never hardcode)."
  echo "  3. Add a suppression pattern to $IGNORE_FILE if this is a confirmed false positive."
  echo "  4. File a 'kind: p2p_ops / severity: critical' queue entry if a real secret was exposed."
  exit 1
fi
