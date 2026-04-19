#!/usr/bin/env bash
# scripts/power/agent-session-start.sh
#
# Keep this Linux/GNOME workstation awake and logged-in for the duration of
# a long Copilot agent session (e.g. an overnight `/improve-mod ALL` run).
#
# Effect (persistent — survives reboot until you run agent-session-stop.sh):
#   • Auto-suspend on AC          : DISABLED
#   • Auto-logout on idle         : DISABLED
#   • Screen blank (display off)  : 2 hours of inactivity
#   • Lid-close on AC             : do nothing (laptops only)
#
# What it does NOT touch:
#   • Battery-power timers (we never want a laptop on battery to run forever).
#   • The screen lock when the user manually locks the session.
#   • systemd-logind.conf — we leave system-wide power untouched and only
#     change the per-user GNOME settings, so other users are unaffected.
#
# Idempotent: safe to run multiple times. Saves the previous values to
# scripts/power/.power-backup.env so agent-session-stop.sh can restore them
# (the stop script also has hard-coded fallbacks if the backup is missing).
#
# Usage:
#   ./scripts/power/agent-session-start.sh
#
# Requires: gsettings (GNOME). On non-GNOME desktops the script prints a
# warning and exits 0 without changing anything.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BACKUP_FILE="${SCRIPT_DIR}/.power-backup.env"

if ! command -v gsettings >/dev/null 2>&1; then
  echo "[agent-session-start] gsettings not found — non-GNOME desktop?"
  echo "[agent-session-start] Skipping. Configure your DE manually if needed."
  exit 0
fi

# 2 hours expressed in seconds.
SCREEN_BLANK_SECONDS=$((2 * 60 * 60))

echo "[agent-session-start] Saving current values to ${BACKUP_FILE}"
{
  echo "# Saved by agent-session-start.sh on $(date -Iseconds)"
  echo "PREV_IDLE_DELAY=$(gsettings get org.gnome.desktop.session idle-delay)"
  echo "PREV_SLEEP_AC_TIMEOUT=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)"
  echo "PREV_SLEEP_AC_TYPE=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)"
  echo "PREV_LOGOUT_ENABLED=$(gsettings get org.gnome.desktop.screensaver logout-enabled)"
  echo "PREV_LOGOUT_DELAY=$(gsettings get org.gnome.desktop.screensaver logout-delay)"
  echo "PREV_LID_CLOSE_AC=$(gsettings get org.gnome.settings-daemon.plugins.power lid-close-ac-action)"
} >"${BACKUP_FILE}"

echo "[agent-session-start] Disabling auto-suspend on AC"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

echo "[agent-session-start] Disabling auto-logout on idle"
gsettings set org.gnome.desktop.screensaver logout-enabled false
gsettings set org.gnome.desktop.screensaver logout-delay 0

echo "[agent-session-start] Setting screen blank to 2 hours"
gsettings set org.gnome.desktop.session idle-delay "uint32 ${SCREEN_BLANK_SECONDS}"

echo "[agent-session-start] Lid-close on AC: do nothing"
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'nothing' || true

echo "[agent-session-start] Done. Verify with:"
echo "  gsettings get org.gnome.desktop.session idle-delay"
echo "  gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type"
echo "  gsettings get org.gnome.desktop.screensaver logout-enabled"
echo
echo "[agent-session-start] Run scripts/power/agent-session-stop.sh to restore defaults."
