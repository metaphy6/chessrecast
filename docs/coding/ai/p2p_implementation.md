# P2P Roadmap implementation — agent harness

> Brief usage doc for the autonomous loop that drives [docs/P2P_ROADMAP.md](../../P2P_ROADMAP.md) from `[ ]` to `[x]`. Implementation rules live in the chat mode and prompts; this page is the user-facing index.

## File map

| File | Purpose |
|---|---|
| [.github/chatmodes/p2p-roadmap-implementer.chatmode.md](../../../.github/chatmodes/p2p-roadmap-implementer.chatmode.md) | The autonomous loop: allow-list, drift handling, rate-limit/resume protocol, model-agnostic guarantees, mandatory terminal states. |
| [.github/prompts/implement-roadmap.prompt.md](../../../.github/prompts/implement-roadmap.prompt.md) | `/implement-roadmap` — selects leaves via `INCLUDE`/`EXCLUDE`, writes failing test → implements → reviews → ticks → commits + pushes. |
| [.github/prompts/review-roadmap-phase.prompt.md](../../../.github/prompts/review-roadmap-phase.prompt.md) | `/review-roadmap-phase` — re-audits a ticked phase, auto-amends drift, downgrades dishonest ticks. |
| [.github/prompts/roadmap-status.prompt.md](../../../.github/prompts/roadmap-status.prompt.md) | `/roadmap-status` — read-only progress + drift report. |
| [agent/tracking.csv](../../../agent/tracking.csv) | Append-only audit log; **the only artefact written by these three commands** outside source code. |
| [agent/tracking.schema.md](../../../agent/tracking.schema.md) | Column definitions, drift kinds, invariants. |
| [xops/agent/tracking_append.sh](../../../xops/agent/tracking_append.sh) | The **only** sanctioned writer of the CSV; enforces every invariant under `flock`. |

## Usage

```text
/implement-roadmap                              # all phases, MAX=8
/implement-roadmap INCLUDE=3 EXCLUDE=3.3        # all of Phase 3 except §3.3
/implement-roadmap INCLUDE=0,1 EXCLUDE=1.6,1.10 # multiple phases & sub-skips
/implement-roadmap INCLUDE=7.* EXCLUDE=7.10 MAX=20
/implement-roadmap DRY_RUN=1 INCLUDE=4          # plan only, no edits
/review-roadmap-phase PHASE=3                   # re-audit phase 3
/review-roadmap-phase PHASE=3.3 STRICT=1        # downgrade any dishonest [x]
/roadmap-status                                 # global progress
/roadmap-status PHASE=3 RECENT=30               # phase-scoped, 30 last rows
```

`INCLUDE` / `EXCLUDE` accept dot-notation tokens (`0`–`19`, `3.3`, `7.9`, `3.3.bullet-2`) and globs (`7.*`). `EXCLUDE` always wins on overlap. Unrecognised arguments cause the command to **stop and ask** rather than guess.

## What the loop does, in plain English

1. Resolve the selection into a flat ordered leaf list.
2. For each leaf:
   - drift pre-check (already `[x]`? proof test still green? CSV consistent?),
   - **write the proof test first and confirm it fails** (the user's "no false positives" guarantee),
   - implement minimum diff inside the per-area allow-list,
   - re-run the test until green; if not green after 3 attempts → revert, file `kind: blocked_implementation`, move on,
   - self-review (spec match, test honesty, allow-list, cross-bullet drift),
   - flip the box, commit with `feat(p2p-<phase>): <summary> [<run-id>]` or `chore(p2p-<phase>): <summary> [<run-id>]`, `git pull --ff-only`, push,
   - log every action to `agent/tracking.csv` via the appender script.
3. When the **last leaf in a top-level phase** ticks, the loop runs `/review-roadmap-phase` inline for that phase before moving on.
4. End in one of `pushed` / `reverted` / `no-op` / `blocked` per [AGENTS.md](../../../AGENTS.md) §2.

## Drift handling

The loop watches for these drift kinds (see schema doc for full definitions): `spec_mismatch`, `missing_test`, `stale_box`, `extra_change`, `test_skipped`, `assertion_weakened`, `csv_tamper`, `roadmap_edit_outside_p2p`. On detection:

1. Write a `drift_detected` row.
2. Apply the prescribed fix (re-implement, revert offending commit, re-tick or un-tick the box, file a `kind: shared_edit` queue entry).
3. Write an `amend` row with the result.

Any drift the loop cannot auto-fix exits **`blocked`**, never silently shipped.

## Rate-limit & resume

If a tool call returns 429 / quota exceeded:

- Append `action=skip, status=blocked, notes="rate-limit cooling …"`.
- Write `agent/state/checkpoint.json` with `{run_id, phase, step, last_proof_test}`.
- Wait the cooldown the response specifies, or 5 min default. If long (>15 min) cooldown → exit cleanly so the user resumes later.
- The next `/implement-roadmap` invocation reads the checkpoint and resumes at the recorded leaf — already-`[x]` leaves are never re-implemented.

The user's stated tolerance: *"we can gracefully wait if rate limits are reached anyway."* The loop will wait, not work around.

## Model-agnostic guarantees

The chat mode uses only the standard VS Code Copilot tool surface. Every decision is written to the CSV so a different model (GPT, Claude, "auto") can resume an interrupted run without re-deriving the prior model's reasoning. Long-form reasoning is *never* required to advance the loop — every step is a concrete tool call (test run, edit, commit, append).

Tested with `auto` model selection. No provider-private features are used.

## Allow-list (full list in chat mode §2)

Edits restricted to: `frontend/lib/services/p2p/**`, `frontend/lib/services/identity/**`, `frontend/lib/services/clock/**`, `frontend/lib/services/replay/**`, `frontend/test/p2p/**`, `frontend/test/signaling/**`, `signaling/**`, `docs/P2P_ROADMAP.md` (single-box edits only), `docs/P2P_*.md`, `agent/tracking.csv` (via appender only), `agent/baselines/p2p_*.json`, `agent/reports/p2p/**`, `.github/workflows/p2p-*.yml`, plus dependency-manifest entries the roadmap explicitly names. Everything else requires a `kind: shared_edit` queue entry per [.github/copilot-instructions.md](../../../.github/copilot-instructions.md).

## What this harness does not do

- It does not track non-P2P work — it writes nothing to the chess-engine queue, baselines, or reports.
- It does not edit `AGENTS.md`, `CLAUDE.md`, the engine instructions, the chat mode, or other slash-command prompts.
- It does not force-push, rewrite history, or skip tests.
- It does not silently mark a phase complete without a passing proof test cited in the same commit.
- It does not "let the user commit it" — green gates → push, every time.

## Bootstrapping

The CSV starts with only its header line. The first `/implement-roadmap` invocation appends the first `plan` row; from then on the file grows append-only. If the file is ever corrupted (header changed, columns dropped, hand-edited), the loop detects `csv_tamper` and exits `blocked` until a human restores the header and rolls back the offending edit through `git`.
