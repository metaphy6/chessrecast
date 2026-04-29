# `scripts/agent/`

Helpers the AI assistant runs **inside** the workspace. Read-only by design — these scripts never install OS packages, never touch `/etc`, and never modify global git config (per [AGENTS.md](../../AGENTS.md) §4).

## `session-bootstrap.sh`

Run **first thing** in every new Copilot Chat / Claude / Cursor session:

```bash
./scripts/agent/session-bootstrap.sh
```

It prints (and only prints):

- repo root, current `pwd`, current branch, last commit, working-tree cleanliness,
- whether [agent/state/current.json](../../agent/state/current.json) shows an orphaned `in_progress` task,
- whether [agent/state/checkpoint.json](../../agent/state/checkpoint.json) is present (= previous session was interrupted),
- the last 5 entries of [agent/state/log.jsonl](../../agent/state/log.jsonl),
- whether `frontend/build/native/linux/libchess_engine.so` is up-to-date vs the C sources,
- per-mod baseline freshness (warns if older than 7 days),
- queue task counts.

If anything is yellow / red, address it before claiming a new task. See [AGENTS.md](../../AGENTS.md) §5 for the recovery checklist.
