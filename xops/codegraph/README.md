# xops/codegraph — CodeGraph MCP integration

[CodeGraph](https://www.npmjs.com/package/@colbymchenry/codegraph) is a local
semantic code-intelligence MCP server used by every AI assistant configured in
this repo (VS Code Copilot Chat, Claude Code, Cursor, Codex CLI).

## Pin model

The single source of truth for which CodeGraph version we run is
[VERSION](VERSION). Every MCP config and doc that references a version is
generated from this file by [sync-pin.sh](sync-pin.sh).

| File | Role |
|---|---|
| [VERSION](VERSION) | Single pin. Bump via `make codegraph.bump`. |
| [sync-pin.sh](sync-pin.sh) | Rewrites every `@colbymchenry/codegraph@X.Y.Z` reference in the repo to match `VERSION`. |
| [check-updates.sh](check-updates.sh) | Asks the npm registry whether a newer version exists. Warn-only — never auto-bumps. |

## Make targets

```bash
make codegraph.status          # report current pin, indexed projects, watcher health
make codegraph.reindex         # rebuild the .codegraph/ index (use after big refactors/rebases)
make codegraph.check-updates   # warn if a newer version exists on npm (no changes made)
make codegraph.sync-pin        # propagate VERSION into all 4 MCP configs + docs
```

## Why we pin (and don't `@latest`)

Per [AGENTS.md](../../AGENTS.md) §2, every commit lands behind a deterministic
gate. `npx @latest` would let two agent sessions in the same week speak to
different CodeGraph versions, which silently changes the symbols /
explore-results agents see and breaks reproducibility of audit batches.

Pinning + a weekly `make codegraph.check-updates` keeps us current **with
human approval** rather than current **automatically**.

## Bumping the pin

Until `make version.bump` exists (see [bots/components.yaml](../../bots/components.yaml)),
the manual procedure is:

1. Edit [VERSION](VERSION) to the new release (e.g. `0.9.0`).
2. Run `make codegraph.sync-pin`.
3. Run `make codegraph.reindex` and verify CodeGraph still answers queries
   for every primary assistant.
4. Bump `tooling/codegraph` in [bots/components.yaml](../../bots/components.yaml).
5. Stage everything; commit message: `chore(tooling): bump codegraph to <ver> [<run-id>]`.

## Codex CLI note

Codex CLI's MCP config lives at `~/.codex/config.toml` (user-global), so it
cannot be checked in. Run `make codegraph.print-codex` to print the snippet to
paste into your global config. See [docs/guides/CODEGRAPH.md](../../docs/guides/CODEGRAPH.md).
