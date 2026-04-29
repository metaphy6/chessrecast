# AI automation roadmap — chessrecast

> Companion to [AGENTS.md](../../../AGENTS.md), [.github/copilot-instructions.md](../../../.github/copilot-instructions.md), and [agent/README.md](../../../agent/README.md). This file is the **plan**; those files are the **rules**. This file lives here because it is read by both humans and AI agents to understand "what comes next" without having to re-derive it from scratch every session.

## Vision

Build a VS Code Copilot Chat agent that behaves like a senior engineer who *owns* this project end-to-end: chess mods, bot intelligence, Flutter UI/UX, the future P2P / multiplayer stack, security, and stability. The agent should:

- continuously **monitor** the application for regressions, blunders, crashes, KPI drift, and security smells,
- continuously **add features** as they are needed (or as the queue dictates) without breaking what exists,
- **debug and fix** issues it discovers, ship the fix with tests, commit, and push — autonomously, on `main`,
- **document** what it changes (memory notes + reports), so the next session is faster than the last,
- **stop** and ask only on the four bright lines: shared-engine edits, system-level changes, security-impacting changes, and policy ambiguities.

Everything in this document is in service of that vision. Anything that drifts from it (e.g. an agent that endlessly investigates without committing, or one that "asks for permission" on routine fixes) is a regression we should patch out of the prompts.

## Where we are today (April 2026)

Working today:
- Per-mod allow-list and audit-batch + KPI gating via [.github/copilot-instructions.md](../../../.github/copilot-instructions.md).
- Autonomous improvement loop ([.github/chatmodes/chess-mod-improver.chatmode.md](../../../.github/chatmodes/chess-mod-improver.chatmode.md)) driven by [agent/queue.yaml](../../../agent/queue.yaml).
- Watchdog stop-tokens, baseline refresh, take-initiative directive, queue schema.
- Long-session ergonomics via [scripts/power/](../../../scripts/power/).
- Slash commands `/improve-mod` and `/triage-audit-report`.
- `/memories/repo/*_notes.md` as long-lived per-mod memory.

Known pain points the rest of this roadmap targets:
- Agent occasionally **recreates** existing config files because it does not know they exist (now mitigated by the *Discoverability index* added to the Copilot instructions and by [AGENTS.md](../../../AGENTS.md) §1).
- Agent **avoids committing & pushing** at the end of slash commands (now mitigated by [AGENTS.md](../../../AGENTS.md) §2 and the Copilot instructions *Hard rules → 8*).
- Agent **weakens or skips tests** to clear gates (now banned by [AGENTS.md](../../../AGENTS.md) §3 and the Copilot instructions *Hard rules → 10*).
- Agent **runs ad-hoc system commands** (e.g. `apt`, CMake from the wrong cwd) without the user's awareness (now constrained by [AGENTS.md](../../../AGENTS.md) §4).
- Agent **loses orientation after a killed terminal** (now addressed by [AGENTS.md](../../../AGENTS.md) §5 and the Copilot instructions *Hard rules → 11*).
- Coverage is heavy on engine strength, light on UI / network / security.

## Phase 1 — discipline (in progress)

Goal: make the existing loop stop wasting time on the recurring failures above. **Most of this is already shipped via the AGENTS.md / CLAUDE.md / Copilot-instructions update.**

Remaining work:
- [x] Add a one-shot **session-bootstrap script** the agent runs first thing in any new chat: prints `pwd`, last entries of `agent/state/log.jsonl`, status of `agent/state/current.json`, last commit SHA, and whether `frontend/build/native/linux/libchess_engine.so` is up-to-date. Shipped as [scripts/agent/session-bootstrap.sh](../../../scripts/agent/session-bootstrap.sh).
- [x] Add a `pre-push` git hook that runs the per-mod regression test for every mod whose source tree was touched, plus `king_castling_policy_regression_test.dart`. Hook is opt-in via `git config core.hooksPath .githooks` so the agent can install it without touching global git config. Shipped as [.githooks/pre-push](../../../.githooks/pre-push) + [scripts/agent/install-hooks.sh](../../../scripts/agent/install-hooks.sh).
- [x] Add a lint pass that flags any test edit that *removes* an `expect(` line, *adds* `skip:` or `@Skip`, or replaces a strict matcher with `isNotNull` / `isAny`. Shipped as [frontend/tool/check_test_diff.dart](../../../frontend/tool/check_test_diff.dart); invoked by the pre-push hook.
- [ ] Refresh `/memories/repo/*_notes.md` discipline: every commit message that touches a mod must trigger an entry append (the agent does this manually today).

## Phase 2 — observability

Goal: the agent should *know* when something has regressed without a human running `/improve-mod`.

- [x] **Continuous-audit cron prompt**: a `/nightly-audit` slash command that runs the 50-game audit batch for one mod per night (round-robin), diffs KPIs against the baseline, and either auto-files a queue entry on regression or no-ops on green. The agent never edits code in this command — it only files findings. Shipped as [.github/prompts/nightly-audit.prompt.md](../../../.github/prompts/nightly-audit.prompt.md).
- [x] **Crash & illegal-move telemetry**: post-run scanner [frontend/tool/scan_runtime_telemetry.dart](../../../frontend/tool/scan_runtime_telemetry.dart) sweeps `/tmp/agent-runs/*.log` for `ILLEGAL_MOVE`, `ASSERT_FAIL`, `SIGSEGV`, `SIGABRT`, `Aborted`, `assertion failed`, ASan/UB tokens and writes structured findings to `agent/reports/_runtime/<run-id>.txt`. The agent invokes it after every test run (see AGENTS.md §9a).
- [x] **KPI dashboard**: [frontend/tool/kpi_dashboard.dart](../../../frontend/tool/kpi_dashboard.dart) reads every `agent/baselines/<mod>.json` plus the latest report and prints a markdown table per mod (current vs baseline, delta, color). The agent posts this once per session start.
- [x] **Flake quarantine**: [scripts/agent/run-test-with-retry.sh](../../../scripts/agent/run-test-with-retry.sh) runs a flutter test once, retries on failure, and on first-fail-then-pass logs to `agent/state/flakes.jsonl` and appends a `kind: kpi_regression / phase: tactics / severity: low` queue entry.

## Phase 3 — feature growth, not just fixes

Goal: today the loop is regression-driven. Make it also feature-driven.

- [x] **`/add-feature` slash command** with input fields for `area` (mod / ui / network / security / tooling) and `summary`. Generates a plan, drafts the test (must fail first), implements the change, runs the gate, commits, pushes. Shipped as [.github/prompts/add-feature.prompt.md](../../../.github/prompts/add-feature.prompt.md).
- [x] Per-area allow-lists (analogous to the per-mod allow-list) so the agent can edit Flutter UI without touching the engine and vice versa. Defined in [.github/copilot-instructions.md](../../../.github/copilot-instructions.md) under *Per-area source allow-list*.
- [ ] **Acceptance-test scaffolding**: small generators under `frontend/tool/scaffold_test.dart` that produce a starter test for `ui` / `engine` / `network` / `security` so the agent does not invent test layouts ad-hoc.
- [ ] **Network / P2P seed**: when P2P work begins, the same gate model applies (regression test + integration test + audit-style batch of simulated peer pairings). Capture the rules in `.github/copilot-instructions.md` under a new section before any code is written.

## Phase 4 — security & supply chain

Goal: catch the OWASP Top 10 issues before users do.

- [x] **Dependency audit (frontend only)**: [.github/prompts/dependency-audit.prompt.md](../../../.github/prompts/dependency-audit.prompt.md) drives [frontend/tool/dependency_audit.dart](../../../frontend/tool/dependency_audit.dart) which runs `flutter pub outdated --json`, writes a markdown report to `agent/reports/_security/<run-id>.md`, and (with `--write-queue`) appends `kind: shared_edit / severity: med` queue entries for major-version-behind or security-sensitive packages. **Go backend is intentionally excluded** — the Go service is slated for replacement by a P2P stack and we do not invest churn there.
- [x] **Static-analysis gate**: extended [frontend/analysis_options.yaml](../../../frontend/analysis_options.yaml) with `avoid_dynamic_calls`, `unsafe_html`, `use_build_context_synchronously`. `gosec` for the backend is **dropped** (Go backend deprecation path).
- [x] **Secrets scan**: [frontend/tool/scan_secrets.dart](../../../frontend/tool/scan_secrets.dart) grep-walks the diff of every commit for AWS / GitHub / Google / Slack / Stripe / private-key / JWT shapes. Pre-push hook integration is the next follow-up.
- [ ] **Crash & input-fuzz harness** for `bridge.c` — random FENs + random move strings into the C parser; any abort → queue entry.

## Phase 5 — autonomy uplift

Goal: turn the local "single chat session" loop into something that can run truly unattended.

- [ ] **Cloud bridge**: GitHub Copilot **coding agent** (cloud, issue-driven) seeded by a local cron that posts `agent/queue.yaml` entries as GitHub issues. Local sessions remain the primary path; cloud agent picks up overflow when the workstation is off.
- [x] **Self-evaluation loop**: [.github/prompts/self-review.prompt.md](../../../.github/prompts/self-review.prompt.md) re-runs all seven mod regression tests + the UI smoke + a 10-game spot-check audit per mod, then posts a one-page report. If anything regresses, it files queue entries and reverts the offending commit.
- [x] **Memory-pruning**: [.github/prompts/prune-memory.prompt.md](../../../.github/prompts/prune-memory.prompt.md) consolidates `/memories/repo/*_notes.md` per mod, dropping notes that are now reflected in the source code or in tests.

## What you (the AI) should do **right now**, every session

This is the short version of [AGENTS.md](../../../AGENTS.md):

1. Run the session-bootstrap once it exists (until then, manually): `pwd`, `git log -1 --oneline`, tail of `agent/state/log.jsonl`, sanity-check that `frontend/build/native/linux/libchess_engine.so` exists.
2. Read [agent/state/current.json](../../../agent/state/current.json) and [agent/state/checkpoint.json](../../../agent/state/checkpoint.json) — resume orphaned tasks before claiming new ones.
3. When you change code, **change tests in the same commit**. Never weaken or skip a test to make a gate pass.
4. When you change anything outside the workspace (system packages, `/etc`, global git config, `~/.ssh`), **stop and ask first**.
5. When a slash command finishes and gates are green, **commit and push**. No "I'll let you review."
6. When you find a new issue (blunder, regression, illegal move, security smell), **file a queue entry** before moving on.
7. When you learn something durable, **write it to `/memories/repo/<mod>_notes.md`** so the next session benefits.

## How to extend this roadmap

If you (the AI) finish a Phase 1 / 2 / 3 item, edit this file in the same commit that ships the work: move the bullet from `[ ]` to `[x]` and append a one-line note pointing at the commit SHA or the file path. If you discover a missing capability while working on a mod task, append it to the appropriate phase as a new `[ ]` bullet rather than spinning up a separate doc.

The goal is one source of truth for "where AI automation on this project is headed". Do not let it drift.
