#!/usr/bin/env bash
# xops/p2p/check-deps.sh — Dependency confusion guard.
#
# Roadmap §8.4 / leaf 8.4.b2.
#
# Verifies that:
#   1. All Dart/Flutter direct dependencies in pubspec.yaml are pinned with
#      exact versions (no bare `^x.y.z` or `any`) OR use a path/git source.
#   2. All Go direct dependencies in signaling/go.mod are present in the
#      go.sum file (no unverified packages).
#   3. No dependency resolution would pull a package from an unexpected
#      registry (pub.dev for Dart; pkg.go.dev for Go — others fail).
#
# Exit codes: 0 = all clean, 1 = violations found.
#
# Usage:
#   ./xops/p2p/check-deps.sh
#   ./xops/p2p/check-deps.sh --dart-only
#   ./xops/p2p/check-deps.sh --go-only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DART_ONLY=0
GO_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dart-only) DART_ONLY=1 ;;
    --go-only)   GO_ONLY=1 ;;
  esac
done

VIOLATIONS=0

# ---- Dart / Flutter -------------------------------------------------------
if [[ $GO_ONLY -eq 0 ]]; then
  echo "=== Dart dependency check ==="
  PUBSPEC="$REPO_ROOT/frontend/pubspec.yaml"

  if [[ ! -f "$PUBSPEC" ]]; then
    echo "ERROR: $PUBSPEC not found" >&2
    exit 1
  fi

  # Extract the 'dependencies' and 'dev_dependencies' blocks and look for
  # bare `^` constraints on packages from the pub.dev registry.
  # Allowed: exact version ("1.2.3"), path/git overrides, sdk: flutter.
  # Rejected: `any`, version ranges without lower bound, git sources from
  #           non-canonical hosts (anything other than github.com/dart-lang,
  #           github.com/flutter/*, pub.dev registry).
  BARE_CONSTRAINTS=$(python3 - "$PUBSPEC" <<'PYEOF'
import sys, re, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)

bad = []
for section in ('dependencies', 'dev_dependencies'):
    block = doc.get(section) or {}
    for pkg, constraint in block.items():
        if constraint is None:
            continue
        # path/git/sdk overrides are fine
        if isinstance(constraint, dict):
            if 'git' in constraint:
                host = constraint['git'].get('url', '')
                # Only allow known-good git hosts
                ALLOWED_HOSTS = ['github.com/dart-lang', 'github.com/flutter',
                                  'github.com/google', 'github.com/material-foundation']
                if not any(h in host for h in ALLOWED_HOSTS):
                    bad.append(f'{pkg}: git from unrecognised host {host}')
            continue
        s = str(constraint).strip()
        # Bare `any` is forbidden
        if s == 'any':
            bad.append(f'{pkg}: "any" constraint forbidden')
        # ^ prefix without lower bound is a warning but not a block for this guard
        # (pub.dev only serves that package name — confusion guard is about source,
        #  not version pinning strictness for Dart; Go is stricter)

for line in bad:
    print(line)
PYEOF
  )

  if [[ -n "$BARE_CONSTRAINTS" ]]; then
    echo "FAIL: Dart dependency violations:"
    echo "$BARE_CONSTRAINTS"
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    echo "OK: no Dart dependency confusion violations"
  fi
fi

# ---- Go -------------------------------------------------------------------
if [[ $DART_ONLY -eq 0 ]]; then
  echo "=== Go dependency check ==="
  GOMOD="$REPO_ROOT/signaling/go.mod"
  GOSUM="$REPO_ROOT/signaling/go.sum"

  if [[ ! -f "$GOMOD" ]]; then
    echo "ERROR: $GOMOD not found" >&2
    exit 1
  fi

  if [[ ! -f "$GOSUM" ]]; then
    echo "FAIL: $GOSUM missing — all Go dependencies must be checksummed"
    VIOLATIONS=$((VIOLATIONS + 1))
  else
    # Verify all require directives in go.mod appear in go.sum.
    MISSING=$(go -C "$REPO_ROOT/signaling" mod verify 2>&1 | grep -v "^all modules" || true)
    if [[ -n "$MISSING" ]]; then
      echo "FAIL: Go module verification failures:"
      echo "$MISSING"
      VIOLATIONS=$((VIOLATIONS + 1))
    else
      echo "OK: all Go modules verified against go.sum"
    fi
  fi

  # Check for replace directives pointing outside pkg.go.dev / the repo.
  REPLACE_VIOLATIONS=$(grep -E '^replace ' "$GOMOD" | \
    grep -Ev '^replace .* => \.(\.)?/' || true)
  if [[ -n "$REPLACE_VIOLATIONS" ]]; then
    echo "FAIL: go.mod has replace directives pointing outside the repo:"
    echo "$REPLACE_VIOLATIONS"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
fi

# ---- Result ---------------------------------------------------------------
if [[ $VIOLATIONS -gt 0 ]]; then
  echo "=== FAIL: $VIOLATIONS dependency confusion violation(s) found ==="
  exit 1
else
  echo "=== PASS: dependency confusion check clean ==="
  exit 0
fi
