#!/usr/bin/env bash
# xops/power/agent-session-stop.sh
#
# Restore Linux/GNOME power-management settings to the defaults requested
# by the project owner:
#
#   • Auto-logout on idle : ENABLED, after 3 hours
#   • Auto-suspend on AC  : ENABLED, after 5 hours
#   • Screen blank        : default (5 minutes — GNOME factory default)
#   • Lid-close on AC     : suspend
#
# If xops/power/.power-backup.env exists (written by agent-session-start.sh)
# it is removed at the end, so the next start script call captures a fresh
# pre-agent baseline.
#
# Usage:
#   ./xops/power/agent-session-stop.sh
#
# Requires: gsettings (GNOME).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BACKUP_FILE="${SCRIPT_DIR}/.power-backup.env"

if ! command -v gsettings >/dev/null 2>&1; then
  echo "[agent-session-stop] gsettings not found — non-GNOME desktop?"
  echo "[agent-session-stop] Skipping. Restore your DE settings manually."
  exit 0
fi

LOGOUT_DELAY_SECONDS=$((3 * 60 * 60))   # 3h
SLEEP_AC_TIMEOUT_SECONDS=$((5 * 60 * 60)) # 5h
SCREEN_BLANK_SECONDS=$((5 * 60))        # 5 min — GNOME default

echo "[agent-session-stop] Restoring auto-logout: enabled, 3h"
gsettings set org.gnome.desktop.screensaver logout-enabled true
gsettings set org.gnome.desktop.screensaver logout-delay "uint32 ${LOGOUT_DELAY_SECONDS}"

echo "[agent-session-stop] Restoring auto-suspend on AC: enabled, 5h"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "${SLEEP_AC_TIMEOUT_SECONDS}"

echo "[agent-session-stop] Restoring screen blank: 5 minutes"
gsettings set org.gnome.desktop.session idle-delay "uint32 ${SCREEN_BLANK_SECONDS}"

echo "[agent-session-stop] Restoring lid-close on AC: suspend"
gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action 'suspend' || true

if [[ -f "${BACKUP_FILE}" ]]; then
  echo "[agent-session-stop] Removing stale backup ${BACKUP_FILE}"
  rm -f "${BACKUP_FILE}"
fi

echo "[agent-session-stop] Done. Current values:"
echo "  idle-delay              : $(gsettings get org.gnome.desktop.session idle-delay)"
echo "  sleep-inactive-ac-type  : $(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)"
echo "  sleep-inactive-ac-timeout: $(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)"
echo "  logout-enabled          : $(gsettings get org.gnome.desktop.screensaver logout-enabled)"
echo "  logout-delay            : $(gsettings get org.gnome.desktop.screensaver logout-delay)"
