# `xops/agent/`

Helpers the AI assistant runs **inside** the workspace. Read-only by design — these scripts never install OS packages, never touch `/etc`, and never modify global git config (per [AGENTS.md](../../AGENTS.md) §4).

## `session-bootstrap.sh`

Run **first thing** in every new Copilot Chat / Claude / Cursor session:

```bash
./xops/agent/session-bootstrap.sh
```

It prints (and only prints):

- repo root, current `pwd`, current branch, last commit, working-tree cleanliness,
- whether [docs/tracking/state/current.json](../../docs/tracking/state/current.json) shows an orphaned `in_progress` task,
- whether [docs/tracking/state/checkpoint.json](../../docs/tracking/state/checkpoint.json) is present (= previous session was interrupted),
- the last 5 entries of [docs/tracking/state/log.jsonl](../../docs/tracking/state/log.jsonl),
- whether `frontend/build/native/linux/libchess_engine.so` is up-to-date vs the C sources,
- per-mod baseline freshness (warns if older than 7 days),
- queue task counts.

If anything is yellow / red, address it before claiming a new task. See [AGENTS.md](../../AGENTS.md) §5 for the recovery checklist.

## `safe-run.sh`

Crash-safe wrapper for any command whose failure would otherwise leave the agent stuck on "Analyzing…" because the terminal died and took its output buffer with it.

```bash
./xops/agent/safe-run.sh <tag> -- <command> [args...]
# example:
./xops/agent/safe-run.sh heir-batch -- flutter test test/manual_heir_audit_batch_test.dart
```

It always writes — *before* the parent shell can lose them:

- `/tmp/agent-runs/<run-id>.cmd` — the exact command, cwd, and env subset,
- `/tmp/agent-runs/<run-id>.log` — combined stdout + stderr (live `tee`),
- `/tmp/agent-runs/<run-id>.exit` — the exit code (only present on clean exit; absence ⇒ killed),

and on non-zero exit additionally writes `docs/tracking/state/last_failure.json` so the next [session-bootstrap.sh](session-bootstrap.sh) run surfaces the failure at the top of the next session. The wrapper exits with the wrapped command's exit code unchanged, so calling gates still see real failure.

Per [AGENTS.md](../../AGENTS.md) §5a, the agent must wrap risky / long commands (`flutter test`, `cmake`, audit batches, `git push`, etc.) with this script, and on any non-zero exit must follow the order **read .log → diagnose → fix → resume → mark resolved**. Never retry blindly; never silence non-zero exits with `|| true`.

### Visibility guarantees

`safe-run.sh` is also designed to defeat the chat UI's silent-"Executing…" failure mode:

- A loud `>>> EXECUTING [tag]` banner with the exact command, cwd, and log path is printed **before** the command starts, so the chat shows real content immediately.
- A heartbeat line `... safe-run: ALIVE elapsed=Ns log_lines=N last="..."` is emitted to stderr every 30s (override with `SAFE_RUN_HEARTBEAT_SECS=10`), proving the wrapper is alive even when the inner command is silent.
- Inner output is line-buffered via `stdbuf -oL -eL` (when available) so progress lines reach the terminal as they are produced rather than getting stuck in stdio buffers.
- A `<<< DONE [tag] exit=N elapsed=Ns` footer makes completion unambiguous.

If you ever want to watch a live run from a second terminal, the banner gives you the exact command:

```bash
tail -f /tmp/agent-runs/<run-id>.log
```
