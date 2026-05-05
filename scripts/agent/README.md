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

## `safe-run.sh`

Crash-safe wrapper for any command whose failure would otherwise leave the agent stuck on "Analyzing…" because the terminal died and took its output buffer with it.

```bash
./scripts/agent/safe-run.sh <tag> -- <command> [args...]
# example:
./scripts/agent/safe-run.sh heir-batch -- flutter test test/manual_heir_audit_batch_test.dart
```

It always writes — *before* the parent shell can lose them:

- `/tmp/agent-runs/<run-id>.cmd` — the exact command, cwd, and env subset,
- `/tmp/agent-runs/<run-id>.log` — combined stdout + stderr (live `tee`),
- `/tmp/agent-runs/<run-id>.exit` — the exit code (only present on clean exit; absence ⇒ killed),

and on non-zero exit additionally writes `agent/state/last_failure.json` so the next [session-bootstrap.sh](session-bootstrap.sh) run surfaces the failure at the top of the next session. The wrapper exits with the wrapped command's exit code unchanged, so calling gates still see real failure.

Per [AGENTS.md](../../AGENTS.md) §5a, the agent must wrap risky / long commands (`flutter test`, `cmake`, audit batches, `git push`, etc.) with this script, and on any non-zero exit must follow the order **read .log → diagnose → fix → resume → mark resolved**. Never retry blindly; never silence non-zero exits with `|| true`.
