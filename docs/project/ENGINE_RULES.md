# Chess Engine / Mod / Audit Rules

> **Read before any engine or mod change.**
> This file was extracted from `AGENTS.md` §9 and `.github/copilot-instructions.md`
> to keep the cross-cutting rulebook short. AGENTS.md §1 points here.

---

## Game-quality charter

Users open ChessRecast expecting a **classical chess bot**, not a toy. Every
patch must keep all four phases of play strong:

1. **Openings.** Develop minor pieces before the queen, contest the centre
   (e/d files), castle by ply ~16, do not move the king or rook before
   castling unless forced.
2. **Middlegame.** Find tactics down to the audit-batch reference depth
   (depth 6 / 500 ms / skill 4) without the worst-miss exceeding **2.00 cp**
   on any opening line in a 50-game batch.
3. **Endgame.** Convert obvious technical wins (K+Q vs K, K+R vs K, K+P vs K,
   pawn endgames). Mod-specific finales per
   [`docs/game/GAME_MODS_DOCUMENTATION.md`](../game/GAME_MODS_DOCUMENTATION.md).
4. **Strategy & tactics — mod-aware.** Each mod has a unique meta layer
   (see game docs). Per-mod `*_refine_result` blocks in `bridge.c` are the
   **only** place where a mod may deviate from the shared engine.

A change is acceptable only when it improves ≥1 bucket and regresses **none**
of the KPIs in `bots/baselines/<mod>.json` by more than **5%**.

---

## Per-mod isolation (allow-list)

When fixing a single mod, only edit:

- `frontend/lib/mods/<mod>.dart` (and `frontend/lib/mods/<mod>/**`)
- `frontend/lib/engine/<mod>_*.dart` (if present)
- Per-mod `*_refine_result` blocks inside `frontend/native/engine/bridge.c`
- `frontend/native/engine/eval/eval_<mod>.c`
- `frontend/native/engine/search/heuristics_<mod>.c`
- The mod's own tests: `frontend/test/manual_<mod>_*` and `frontend/test/<mod>_*`

**Shared code** (`search.c`, `eval.c`, `bridge.c` outside `*_refine_result`,
`engine.dart`, `native.dart`) requires a `kind: shared_edit` queue entry with
severity ≥ high before touching.

---

## Audit gate (required before every commit)

Run in this order, abort on first failure:

1. `<mod>_engine_regression_test.dart` — green
2. `king_castling_policy_regression_test.dart` — green
3. Mod's rule-mechanics test (mercenary, save_the_queen, succession, truce have one) — green
4. `info_panel_overflow_test.dart` + `widget_test.dart` — green
5. Fresh **≥50-game** audit batch via `manual_<mod>_audit_batch_test.dart`
6. KPI delta vs `bots/baselines/<mod>.json` — no metric regresses >5%

On any failure: `git restore .`, record `gate_fail` in `docs/tracking/state/log.jsonl`,
file a queue entry, and do not commit.

---

## Queue entry schema (`bots/queue.yaml`)

```yaml
- id: <slug>
  kind: blunder | rule_violation | crash | kpi_regression | shared_edit | opening_book | flake
  severity: critical | high | medium | low
  mod: <mod>
  status: pending | in_progress | done | blocked
  blunder_threshold_cp: 2.0   # only for kind: blunder
  notes: |
    <evidence: FEN + UCI + report path + line number>
```

---

## Vigilance protocol

### Monitoring — never run blind

- Every `flutter test` runs with live progress (`<MOD>_BATCH_LIVE_PROGRESS=1`,
  `-r compact`) and is teed to `/tmp/agent-runs/<mod>-<run-id>.log`.
- After every run, invoke `frontend/tool/scan_runtime_telemetry.dart` to
  fold `ILLEGAL_MOVE` / `ASSERT_FAIL` / `SIGSEGV` / `Aborted` lines into
  `bots/reports/_runtime/`. New findings → queue entries before committing.
- At session start, post the KPI table from `frontend/tool/kpi_dashboard.dart`
  and flag any metric in `bad` or `warn` state.

### Detection — every blunder is a finding

- Worst-miss ≥ 2.00 cp → stop batch, capture FEN, file `kind: blunder`.
- Rule violation (illegal castle, illegal en-passant, missed mod constraint) →
  always `severity: high`.
- Crash / abort / segfault → `kind: crash / severity: critical`.
- KPI regression >5% → `kind: kpi_regression`.
- Evidence required: FEN + UCI + report path + line number.

### Action — start over rather than half-fix

- When a finding is confirmed, pause the current task.
- After a fix, start the audit batch **from scratch** for the affected mod.
- If a fix introduces a regression elsewhere, `git revert`, file `kind: shared_edit`, stop.

### Restart conditions

Start the current task over when:

1. Native lib is older than any `frontend/native/engine/**/*.c` file → rebuild.
2. A KPI dashboard cell flipped from `ok` to `bad` → triage first.
3. A `severity: critical` entry lands in the queue → address it before continuing.
4. Upstream `main` moved → `git pull --rebase`, re-run gate.
5. A previously-green test is now red without source change → flake; use
   `xops/agent/run-test-with-retry.sh`.

---

## Run recipes

Working directory: `frontend/`. Export native-lib env vars first.

### Baseline batch (≥50 games, no early stop)

```bash
CHESSRECAST_NATIVE_ENGINE_LIB=$PWD/build/native/linux/libchess_engine.so \
LD_LIBRARY_PATH=$PWD/build/native/linux:$PWD \
<PREFIX>_BATCH_OPENINGS="$(paste -sd ';' ../bots/openings/<mod>.csv)" \
<PREFIX>_BATCH_MAX_PLIES=120 \
<PREFIX>_BATCH_LIVE_PROGRESS=1 \
<PREFIX>_BATCH_REPORT_PATH=../bots/reports/<mod>/<run-id>.txt \
flutter test test/manual_<mod>_audit_batch_test.dart --run-skipped -r compact 2>&1 \
  | tee /tmp/agent-runs/<mod>-<run-id>.log
```

### Triage batch (watchdog, stop on large miss)

```bash
... same as above but add ...
<PREFIX>_BATCH_STOP_AT_DELTA=2.00 \
```

---

## CodeGraph discipline for engine work

Run `make codegraph.reindex` before trusting any graph query when:

1. A `git rebase` moved >5 files.
2. A feature commit renamed/moved >10 symbols.
3. A `kind: shared_edit` change landed in `frontend/native/engine/`.
4. A graph result contradicts `git log -p` for the same path.

Run `make codegraph.check-updates` at the start of any long autonomous session.
Never bump CodeGraph silently.
