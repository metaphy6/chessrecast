---
mode: chess-mod-improver
description: Kick off the autonomous improvement loop across the full queue (all mods). No quickpick — sends immediately.
---

# Improve mod: ALL

Run [`/improve-mod`](improve-mod.prompt.md) with `mod = ALL`.

Follow the entire procedure in [improve-mod.prompt.md](improve-mod.prompt.md) verbatim — pre-flight, task selection, empty-queue auto-discovery, watchdog, gating, commit/push — substituting `ALL` everywhere `${input:mod}` appears. Honour `chess-mod-improver` chat mode and `.github/copilot-instructions.md` (Game-quality charter, Take-initiative directive, Live test-watchdog protocol).
