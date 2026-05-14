---
mode: ask
description: Consolidate /memories/repo/*_notes.md per mod, dropping notes already reflected in source / tests. Read-only for code; only the memory tool changes.
---

# Prune memory

Goal: keep `/memories/repo/*_notes.md` lean. Notes that have been crystallised into source code, tests, or docs are no longer worth carrying in context.

## Procedure

For each mod in (heir, friendly_fire, kings_battle, mercenary, save_the_queen, succession, truce):

1. View `/memories/repo/<mod>_notes.md` (or `<mod>_regression_notes.md`, etc.) via the memory tool.
2. For each bullet point, classify:
   - **stale** — refers to behavior that has since been fixed in source (verify by `grep_search` in `frontend/native/engine/` or `frontend/lib/mods/<mod>/`).
   - **codified** — covered by a regression test (`grep_search` in `frontend/test/<mod>_*`).
   - **superseded** — replaced by a later note in the same file.
   - **live** — still useful context for the next session.
3. Rewrite the file keeping only **live** notes, ordered by relevance. Add a one-line header `# <mod> — pruned <YYYY-MM-DD>`.

## Rules

- Do **not** edit any source / test / doc file in this command.
- Do **not** delete a note just because it is "old" — only because it is stale, codified, or superseded.
- If a note describes a behavior that is **not** covered by source or tests but is still relevant, *file a queue entry* asking for a regression test, then keep the note.

## Terminal state

This command writes only to memory, not to git. Acceptable end states:

- **`done`** — memory pruned, count of notes-before vs notes-after reported per mod.
- **`no-op`** — every mod's notes were already current.

No commit is required for memory-only changes (memory is not in git). If queue entries were filed, append a tracking row and stage: `xops/agent/tracking_append.sh --run-id=<id> --command=/prune-memory ... --commit-message="chore(memory): file follow-ups from prune-memory [<id>]"` then `git add agent/queue.yaml`. Push accumulates for `make git`.
