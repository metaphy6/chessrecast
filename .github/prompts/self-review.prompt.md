---
mode: chess-mod-improver
description: Re-run all per-mod regression tests + UI smoke + a 10-game spot-check audit per mod. File queue entries on regression. Revert offending commits.
---

# Self-review

Operate per [AGENTS.md](../../AGENTS.md). Goal: catch regressions that slipped past per-task gates by running a wider net.

## Pre-flight

1. Run [scripts/agent/session-bootstrap.sh](../../scripts/agent/session-bootstrap.sh).
2. `git switch main && git pull --ff-only`. Stop if dirty.

## Sweep

Run, in order, capturing each result. Do **not** abort on the first failure — collect everything, then act.

1. **All regression tests:**
   ```bash
   cd frontend
   CHESSRECAST_NATIVE_ENGINE_LIB=$PWD/build/native/linux/libchess_engine.so \
   LD_LIBRARY_PATH=$PWD/build/native/linux:$PWD \
   flutter test \
     test/heir_engine_regression_test.dart \
     test/friendly_fire_engine_regression_test.dart \
     test/kings_battle_engine_regression_test.dart \
     test/mercenary_engine_regression_test.dart \
     test/save_the_queen_engine_regression_test.dart \
     test/succession_engine_regression_test.dart \
     test/truce_engine_regression_test.dart \
     test/king_castling_policy_regression_test.dart \
     test/info_panel_overflow_test.dart \
     test/widget_test.dart \
     -r compact
   ```
2. **10-game spot-check audit** for every mod (use the first 10 lines of `agent/openings/<mod>.csv`, no early-stop). Save reports under `agent/reports/<mod>/selfreview-<run-id>.txt`.
3. **KPI dashboard** via [frontend/tool/kpi_dashboard.dart](../../frontend/tool/kpi_dashboard.dart) for all 7 mods.
4. **Manual test-honesty review**: read `git log --oneline -n 50 origin/main` and spot-check any commit whose diff touches a `_test.dart` file — confirm no `skip:` / `@Skip` / `markTestSkipped(` was added and no `expect(` was removed without a corresponding `kind: kpi_regression` or `kind: shared_edit` queue entry. Per [AGENTS.md](../../AGENTS.md) §3.

## Triage

For each failure:

- regression test failing → identify the offending commit (`git bisect` if non-obvious), file a `kind: blunder` or `kind: rule_violation` queue entry pointing at the commit and the failing test.
- KPI metric in `bad` status → file a `kind: kpi_regression` entry, severity `high`.
- test-diff lint complains → file a `kind: shared_edit` entry to revisit the suspicious test edit.

## Reverts

If a single commit on `main` is unambiguously the cause of a regression test failing, **revert it** with `git revert <sha>`, run the gate (regression + UI smoke), commit & push the revert with message `revert(<area>): <summary> — selfreview <run-id>`. Multiple ambiguous commits → file a queue entry, do not revert blindly.

## Terminal state

- **`pushed`** — at least one revert or queue-entry update was committed; push to `origin/main`, report SHAs.
- **`no-op`** — everything green, dashboard all `ok`, no diffs.
- **`blocked`** — bisect inconclusive; full report written to `agent/reports/_shared/selfreview-<run-id>.md`.

Per [AGENTS.md](../../AGENTS.md) §2, this command is forbidden from ending with "I'll leave the revert for you to decide" when a single-commit cause is clear.
