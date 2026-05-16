#!/usr/bin/env bash
# §5.1.2 xops/p2p/bootstrap-dev.sh — hermetic P2P dev environment bootstrap
#
# Sets up every tool required to run the P2P CI suite (Layers 1-5) on a fresh
# Linux workstation.  Designed to be re-entrant: safe to run multiple times.
#
# Usage:
#   bash xops/p2p/bootstrap-dev.sh          # interactive
#   BOOTSTRAP_NON_INTERACTIVE=1 bash ...    # CI / unattended
#
# What it does:
#   1. Verifies OS and shell requirements
#   2. Installs/verifies Flutter (FLUTTER_VERSION)
#   3. Installs/verifies Go (GO_VERSION)
#   4. Installs build tools (cmake, build-essential) if missing
#   5. Runs `flutter pub get` in frontend/
#   6. Builds the native engine (.so) in frontend/build/native/linux/
#   7. Verifies the P2P test suite (L1-L5) is runnable (dry-compile)
#
# Tool versions are read from .tool-versions at the repo root (asdf-compatible).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_PREFIX="[bootstrap-dev]"

info()  { echo "$LOG_PREFIX INFO  $*"; }
warn()  { echo "$LOG_PREFIX WARN  $*" >&2; }
die()   { echo "$LOG_PREFIX ERROR $*" >&2; exit 1; }
ok()    { echo "$LOG_PREFIX OK    $*"; }

# ---------------------------------------------------------------------------
# 1. Read versions from .tool-versions (if present) or use hardcoded defaults
# ---------------------------------------------------------------------------
FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.5}"
GO_VERSION="${GO_VERSION:-1.26.2}"
DART_VERSION="${DART_VERSION:-3.8.1}"

if [[ -f "$REPO_ROOT/.tool-versions" ]]; then
  while IFS=' ' read -r tool version; do
    case "$tool" in
      flutter) FLUTTER_VERSION="$version" ;;
      golang)  GO_VERSION="$version" ;;
      dart)    DART_VERSION="$version" ;;
    esac
  done < "$REPO_ROOT/.tool-versions"
  info "Read versions from .tool-versions: flutter=$FLUTTER_VERSION go=$GO_VERSION dart=$DART_VERSION"
else
  warn ".tool-versions not found; using defaults: flutter=$FLUTTER_VERSION go=$GO_VERSION"
fi

# ---------------------------------------------------------------------------
# 2. OS check
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Linux" ]]; then
  die "This script targets Linux.  For macOS/Windows use the platform-specific bootstrap."
fi

info "Bootstrapping P2P dev environment on Linux"
info "Repo root: $REPO_ROOT"

# ---------------------------------------------------------------------------
# 3. Flutter
# ---------------------------------------------------------------------------
if command -v flutter &>/dev/null; then
  CURRENT_FLUTTER="$(flutter --version 2>&1 | head -1 | awk '{print $2}')"
  if [[ "$CURRENT_FLUTTER" == "$FLUTTER_VERSION" ]]; then
    ok "Flutter $FLUTTER_VERSION already installed"
  else
    warn "Flutter $CURRENT_FLUTTER found; expected $FLUTTER_VERSION"
    warn "Consider using asdf or FVM to switch: asdf install flutter $FLUTTER_VERSION"
  fi
else
  die "Flutter not found in PATH.  Install Flutter $FLUTTER_VERSION first:
  https://docs.flutter.dev/get-started/install/linux
  Or via asdf: asdf plugin add flutter && asdf install flutter $FLUTTER_VERSION"
fi

# ---------------------------------------------------------------------------
# 4. Go
# ---------------------------------------------------------------------------
if command -v go &>/dev/null; then
  CURRENT_GO="$(go version | awk '{print $3}' | sed 's/go//')"
  if [[ "$CURRENT_GO" == "$GO_VERSION" ]]; then
    ok "Go $GO_VERSION already installed"
  else
    warn "Go $CURRENT_GO found; expected $GO_VERSION"
    warn "Consider: asdf install golang $GO_VERSION"
  fi
else
  die "Go not found in PATH.  Install Go $GO_VERSION:
  https://go.dev/doc/install
  Or via asdf: asdf plugin add golang && asdf install golang $GO_VERSION"
fi

# ---------------------------------------------------------------------------
# 5. Build tools (cmake, make, gcc)
# ---------------------------------------------------------------------------
info "Checking build tools..."
MISSING_TOOLS=()
for tool in cmake make gcc; do
  if ! command -v "$tool" &>/dev/null; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  warn "Missing build tools: ${MISSING_TOOLS[*]}"
  if [[ "${BOOTSTRAP_NON_INTERACTIVE:-0}" == "1" ]]; then
    info "Non-interactive mode: attempting apt-get install..."
    sudo apt-get update -qq
    sudo apt-get install -y cmake build-essential
  else
    echo "$LOG_PREFIX PROMPT Install missing tools via apt? [y/N]"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      sudo apt-get update -qq
      sudo apt-get install -y cmake build-essential
    else
      die "Cannot continue without build tools.  Install manually: sudo apt-get install cmake build-essential"
    fi
  fi
fi
ok "Build tools present"

# ---------------------------------------------------------------------------
# 6. Flutter pub get
# ---------------------------------------------------------------------------
info "Running flutter pub get in frontend/..."
cd "$REPO_ROOT/frontend"
flutter pub get --no-example
ok "flutter pub get complete"

# ---------------------------------------------------------------------------
# 7. Native engine build
# ---------------------------------------------------------------------------
NATIVE_BUILD_DIR="$REPO_ROOT/frontend/build/native/linux"
NATIVE_LIB="$NATIVE_BUILD_DIR/libchess_engine.so"
NATIVE_SRC_DIR="$REPO_ROOT/frontend/native/engine"

if [[ ! -f "$NATIVE_LIB" ]]; then
  info "Native engine not found — building..."
  cmake -B "$NATIVE_BUILD_DIR" -S "$NATIVE_SRC_DIR" \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "$NATIVE_BUILD_DIR" --parallel "$(nproc)"
  ok "Native engine built: $NATIVE_LIB"
else
  # Check if .so is stale vs source
  if find "$NATIVE_SRC_DIR" -name "*.c" -newer "$NATIVE_LIB" | grep -q .; then
    warn "Native engine is older than C sources — rebuilding..."
    cmake --build "$NATIVE_BUILD_DIR" --parallel "$(nproc)"
    ok "Native engine rebuilt"
  else
    ok "Native engine up to date: $NATIVE_LIB"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Verify P2P test suite is runnable (dry compile)
# ---------------------------------------------------------------------------
info "Verifying P2P test suite compiles..."
export CHESSRECAST_NATIVE_ENGINE_LIB="$NATIVE_LIB"
export LD_LIBRARY_PATH="$NATIVE_BUILD_DIR"

# Dry-run: compile but don't execute tests (--dry-run not available in flutter
# test; instead we run a single fast test to confirm harness is wired)
flutter test test/p2p/transport/fake_transport_test.dart \
  -r compact --concurrency=1 \
  --name="delivers bytes from A to B in FIFO order"

ok "P2P test harness confirmed runnable"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "$LOG_PREFIX Bootstrap complete."
echo ""
echo "  Run L1-L5 tests:"
echo "    cd frontend"
echo "    CHESSRECAST_NATIVE_ENGINE_LIB=$NATIVE_LIB \\"
echo "    LD_LIBRARY_PATH=$NATIVE_BUILD_DIR \\"
echo "    flutter test test/p2p/ -r compact --concurrency=4"
echo ""
echo "  Signaling server tests:"
echo "    cd signaling && go test ./... -race -count=1"
echo "============================================================"
