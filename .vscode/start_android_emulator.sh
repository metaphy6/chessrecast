#!/usr/bin/env bash
set -euo pipefail

# .vscode helper to start a named Android AVD only if not already running
# Usage: .vscode/start_android_emulator.sh <avd-name>

SDK_DIR="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
EMU_BIN="${SDK_DIR}/emulator/emulator"

if [ ! -x "$EMU_BIN" ]; then
  # Try fallback location under $HOME
  EMU_BIN="$HOME/Android/Sdk/emulator/emulator"
fi

if [ ! -x "$EMU_BIN" ]; then
  echo "emulator binary not found. Check ANDROID_SDK_ROOT or install emulator under: $HOME/Android/Sdk/emulator"
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <avd-name>"
  echo "Available AVDs:"
  "$EMU_BIN" -list-avds || true
  exit 2
fi

AVD_NAME="$1"

# Check if an emulator process already exists for this AVD (ps/pgrep check)
if pgrep -af "emulator" | grep -qE -- "-avd\s+$AVD_NAME"; then
  echo "Emulator for AVD $AVD_NAME already running. Skipping start."
  exit 0
fi

# Start emulator in background with optimizations for UI responsiveness
nohup "$EMU_BIN" @"$AVD_NAME" -no-snapshot-save -gpu host >/dev/null 2>&1 &
EMUPID=$!
echo "Starting AVD $AVD_NAME (pid=$EMUPID). Waiting for device to appear..."

# Wait for device to show up via adb
ADB_BIN="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}/platform-tools/adb"
if [ ! -x "$ADB_BIN" ]; then
  ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"
fi

if [ ! -x "$ADB_BIN" ]; then
  echo "adb not found; waiting might fail. Make sure platform-tools installed and in PATH."
  exit 0
fi

for i in $(seq 1 60); do
  sleep 2
  if "$ADB_BIN" devices | grep -q "emulator-"; then
    echo "Emulator detected via adb. Boot may continue in the background."
    # Wait for boot to complete, then apply dev settings
    "$ADB_BIN" -s emulator-5554 wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done' 2>/dev/null
    # Suppress ANR dialogs for system processes during development
    "$ADB_BIN" -s emulator-5554 shell settings put secure anr_show_background 0 2>/dev/null
    "$ADB_BIN" -s emulator-5554 shell settings put global hidden_api_policy 1 2>/dev/null
    echo "Boot complete. Dev settings applied."
    exit 0
  fi
done

echo "Timed out waiting for emulator to be detected by adb. Check the emulator UI or logs."
exit 0
