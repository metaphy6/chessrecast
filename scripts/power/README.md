# `scripts/power/` — keep the workstation awake during agent sessions

Two helpers for GNOME (Ubuntu 24+ / Fedora Workstation):

| Script | What it does |
|--------|--------------|
| `agent-session-start.sh` | Disables auto-suspend on AC + auto-logout, sets screen blank to 2h. Backs up the pre-change values to `.power-backup.env`. |
| `agent-session-stop.sh`  | Restores: 3h auto-logout, 5h auto-suspend on AC, 5min screen blank, lid-close = suspend. Removes the backup file. |

## Quick use

Before kicking off `/improve-mod ALL` in Copilot Chat:

```bash
./scripts/power/agent-session-start.sh
```

When you're done (next morning, end of week, etc.):

```bash
./scripts/power/agent-session-stop.sh
```

The chess-mod-improver chat mode also reminds you to run these in its
pre-flight checklist.

## Notes

- Only GNOME (`gsettings`) is supported. On KDE/Cinnamon/etc. the script
  exits cleanly and prints a warning so you can adjust manually.
- Only the **per-user** GNOME keys are touched. We do not edit
  `/etc/systemd/logind.conf`, so other users / system policies are untouched.
- We deliberately leave **battery-power** timers alone. A laptop on battery
  should never be allowed to run an unattended agent overnight.
- Display still turns off after 2h to save the panel; the agent keeps
  running because logout/suspend are disabled.
