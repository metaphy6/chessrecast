# CodeGraph — semantic code intelligence for every assistant

[CodeGraph](https://www.npmjs.com/package/@colbymchenry/codegraph) is a local
MCP server that builds a SQLite knowledge graph of the entire workspace
(symbols, callers, callees, routes) for 19+ languages — including our
**Dart**, **C**, **Go**, and **Python**.

Every AI assistant configured in this repo (VS Code Copilot Chat, Claude
Code, Cursor, Codex CLI) queries the graph through MCP instead of scanning
files with `grep`/`find`/`Read`, which the upstream benchmarks measure at
~35% cheaper / ~70% fewer tool calls on real codebases.

## What's checked in

| Path | Role |
|---|---|
| [xops/codegraph/VERSION](../../xops/codegraph/VERSION) | Single pin (e.g. `0.8.0`). |
| [xops/codegraph/sync-pin.sh](../../xops/codegraph/sync-pin.sh) | Propagates the pin to every config. |
| [xops/codegraph/check-updates.sh](../../xops/codegraph/check-updates.sh) | Warn-only npm-registry check. |
| [.vscode/mcp.json](../../.vscode/mcp.json) | VS Code Copilot Chat MCP server. |
| [.mcp.json](../../.mcp.json) | Claude Code project MCP. |
| [.cursor/mcp.json](../../.cursor/mcp.json) | Cursor project MCP. |
| [.cursor/rules/codegraph.mdc](../../.cursor/rules/codegraph.mdc) | Cursor rule reminding the agent to use the graph. |

The actual SQLite index (`.codegraph/`) is gitignored — it's regenerated on
demand and stays current via CodeGraph's built-in file watcher.

## First-time setup (per developer)

1. Make sure Node 20–24 is on PATH (`node --version`). On Linux the repo
   pins via `.tool-versions`; install via asdf or your distro.
2. **VS Code Copilot Chat** — open the workspace, accept the MCP server
   prompt. No extra step.
3. **Claude Code** — `.mcp.json` at repo root is picked up automatically.
4. **Cursor** — `.cursor/mcp.json` is picked up automatically.
5. **Codex CLI** — Codex's MCP config is user-global (`~/.codex/config.toml`)
   and cannot be checked in. Run:

   ```bash
   make codegraph.print-codex >> ~/.codex/config.toml
   ```

   …or paste the printed snippet manually.

6. Build the index:

   ```bash
   make codegraph.reindex
   ```

## Day-to-day commands

| Command | When |
|---|---|
| `make codegraph.status` | Verify the server starts and `.codegraph/` exists. |
| `make codegraph.reindex` | **Required** after a `git rebase` that moves many files, after a refactor that renames >10 symbols, or any time a query returns clearly stale symbols. |
| `make codegraph.check-updates` | Run weekly (or before starting a long agent loop). Reports if npm has a newer release. Never auto-bumps. |
| `make codegraph.sync-pin` | After editing `xops/codegraph/VERSION`, propagates the new pin everywhere. |

## When the agent must reindex (rule, not suggestion)

The autonomous-loop chatmode and slash commands treat the following as
explicit reindex triggers (see [AGENTS.md §9d](../../AGENTS.md#9d-readiness--features-performance-efficiency-are-first-class)):

- after a `git rebase` / `git pull --rebase`,
- after any feature commit that moves or renames >10 files,
- after a `kind: shared_edit` change in `frontend/native/engine/`,
- before answering a cross-mod / cross-area architecture question that
  relies on `codegraph_context` or `codegraph_explore`.

Skipping the reindex after a rebase is the canonical "graph is lying to me"
failure mode — agents must run `make codegraph.reindex` *before* trusting any
query result that contradicts what `git log` says.

## Upgrading the pin

```bash
# 1. Decide on a target version (changelog: https://github.com/colbymchenry/codegraph)
echo "0.9.0" > xops/codegraph/VERSION

# 2. Propagate
make codegraph.sync-pin

# 3. Rebuild
make codegraph.reindex

# 4. Verify with a smoke query in your primary assistant
#    (e.g. "use codegraph to list callers of search_think")

# 5. Stage and commit
#    Tracking row + git add per AGENTS.md §2
#    commit_message: "chore(tooling): bump codegraph to 0.9.0 [<run-id>]"
```

Once `make version.bump COMPONENT=codegraph LEVEL=minor NOTE=...` exists,
steps 1+5 collapse into a single command.

## Why we don't `@latest`

Reproducibility. Two agent sessions started 30 minutes apart could otherwise
speak to two different CodeGraph versions, silently changing the symbols
agents see and breaking the deterministic gate model in [AGENTS.md §2](../../AGENTS.md#2-mandatory-tracking-entry--stage-after-every-slash-command--human-pushes-via-make-git).
The pin + the weekly check is the deliberate trade-off.

## Privacy

CodeGraph is fully local. `node-sqlite3-wasm` + tree-sitter WASM parsers do
all the work; no network calls, no API keys, no telemetry. The only network
egress this integration introduces is the manual `make codegraph.check-updates`,
which hits `https://registry.npmjs.org` only when you ask.
