<!--
CLAUDE.md — entry point for Claude (Anthropic / Claude Code).

Claude reads this file by convention. To avoid drift between assistants, this
file delegates to AGENTS.md (which is shared across all AI coding assistants
working in this repo) and to the Copilot-specific instructions.
-->

# CLAUDE.md — chessrecast

Hello, Claude. This repository is configured for multi-assistant work. To stay consistent with GitHub Copilot Chat (the primary assistant here), please read and follow these documents in order:

1. [AGENTS.md](AGENTS.md) — non-negotiable cross-cutting rules: discoverability, mandatory commit/push, tests-move-with-code, system-change guardrails, session recovery, security.
2. [.github/copilot-instructions.md](.github/copilot-instructions.md) — engine/mod/build/test rules, per-mod allow-list, audit-batch recipes, watchdog protocol.
3. [docs/coding/ai/automation.md](docs/coding/ai/automation.md) — AI automation roadmap and the larger vision for what an AI engineer on this project is expected to own.

When AGENTS.md and the Copilot instructions disagree, **AGENTS.md wins** for cross-cutting concerns; the Copilot instructions win for engine/mod work.

A short summary of what matters most, even if you read nothing else:

- This repo's `main` branch is open to direct commits **only after** every gate in `.github/copilot-instructions.md` → *Hard rules → 4* passes. No force-push, no `--no-verify`, ever.
- Every slash command (`/improve-mod`, `/triage-audit-report`, …) **must end** with either a commit + push to `origin/main`, a revert, a clean no-op, or a documented `blocked` checkpoint. There is no "I'll let the user commit this" exit.
- Every code change ships its tests in the same commit. Skipping or weakening a test to make a gate green is a hard violation.
- Do not run system-level commands (`apt`, `systemctl`, `/etc/**`, global git config, …) without an explicit per-occurrence "go" from the user. Inside the workspace, act freely.
- Sessions can die mid-task. Always read `agent/state/current.json`, `agent/state/checkpoint.json`, and the tail of `agent/state/log.jsonl` before doing real work.

Tooling notes specific to Claude Code:

- This project ships VS Code tasks (e.g. `Frontend: Rebuild Native Engine`). If you do not have access to VS Code task execution, the equivalent shell is `cd frontend && cmake --build build/native/linux`.
- Slash-command prompts live under [.github/prompts/](.github/prompts/). They are written for VS Code Copilot Chat but are readable as plain Markdown — you can follow the same procedures from Claude Code.
- The `/memories/repo/*_notes.md` referenced in the Copilot instructions is a Copilot-specific memory feature. The equivalent for Claude is the `agent/reports/` and `agent/state/log.jsonl` files plus your own session notes.

If anything in this repo seems to invite shortcutting (skipping a test, silencing a warning, force-pushing, installing a system package without asking), assume the rule is intentional and ask before bypassing it.
