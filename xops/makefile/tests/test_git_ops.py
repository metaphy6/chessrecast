"""
tests/test_git_ops.py — unit tests for xops/makefile/git_ops.py

Tests cover the grouped-commit helpers introduced to make `make git` /
`make git.dry` produce a single header commit with bullet-point sub-messages
instead of one commit per CSV row.

Run with:
    python -m pytest xops/makefile/tests/ -v
or:
    python xops/makefile/tests/test_git_ops.py
"""

import sys
import pathlib
import pytest

# Allow `import git_ops` even when cwd is the repo root.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from git_ops import (  # noqa: E402
    _build_grouped_msg,
    _common_phase_prefix,
    _dominant_type,
    _is_conventional,
    _msg_from_csv,
    _normalize_to_conventional,
)


# ── _common_phase_prefix ───────────────────────────────────────────────────────

def test_common_phase_prefix_first_segment_only():
    phases = ["0.1.bullet-1", "0.2.bullet-1", "0.3.bullet-1"]
    assert _common_phase_prefix(phases) == "0"


def test_common_phase_prefix_two_segments():
    phases = ["1.9.alpha", "1.9.beta", "1.9.gamma"]
    assert _common_phase_prefix(phases) == "1.9"


def test_common_phase_prefix_full_match():
    phases = ["2.3.bullet-1", "2.3.bullet-1"]
    assert _common_phase_prefix(phases) == "2.3.bullet-1"


def test_common_phase_prefix_single_element():
    assert _common_phase_prefix(["0.1.bullet-1"]) == "0.1.bullet-1"


def test_common_phase_prefix_empty():
    assert _common_phase_prefix([]) == ""


def test_common_phase_prefix_no_common():
    """Phases with completely different first segments share nothing."""
    assert _common_phase_prefix(["0.1.x", "1.2.y"]) == ""


def test_common_phase_prefix_no_dots():
    """Non-dotted phases (e.g. 'config') share the whole string if identical."""
    assert _common_phase_prefix(["config", "config"]) == "config"


# ── _dominant_type ─────────────────────────────────────────────────────────────

def test_dominant_type_feat_beats_chore():
    rows = [
        {"commit_message": "feat(p2p): add something"},
        {"commit_message": "chore(ops): cleanup"},
    ]
    assert _dominant_type(rows) == "feat"


def test_dominant_type_fix_beats_chore():
    rows = [
        {"commit_message": "fix(heir): fix castling"},
        {"commit_message": "chore(ops): cleanup"},
    ]
    assert _dominant_type(rows) == "fix"


def test_dominant_type_perf_beats_refactor():
    rows = [
        {"commit_message": "refactor(engine): clean up"},
        {"commit_message": "perf(search): faster move ordering"},
    ]
    assert _dominant_type(rows) == "perf"


def test_dominant_type_fallback_to_chore():
    rows = [{"commit_message": "not a conventional commit at all"}]
    assert _dominant_type(rows) == "chore"


def test_dominant_type_empty_rows():
    assert _dominant_type([]) == "chore"


def test_dominant_type_empty_messages():
    rows = [{"commit_message": ""}, {"commit_message": None}]
    assert _dominant_type(rows) == "chore"


# ── _build_grouped_msg — header format ────────────────────────────────────────

def _make_row(phase, msg, drift_kind="none", tests_added=0, run_id="run-1",
              action="commit"):
    return {
        "phase": phase,
        "commit_message": msg,
        "drift_kind": drift_kind,
        "tests_added": str(tests_added),
        "run_id": run_id,
        "action": action,
    }


def test_header_is_conventional_commit():
    rows = [
        _make_row("0.1.bullet-1", "feat(p2p-0.1): enumerate legacy [run-1]"),
        _make_row("0.2.bullet-1", "feat(p2p-0.2): add SavedGamesLocal [run-1]"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert _is_conventional(header), f"Header not conventional: {header!r}"


def test_header_uses_common_phase_scope():
    rows = [
        _make_row("1.9.a", "feat(x): a"),
        _make_row("1.9.b", "feat(x): b"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    # scope should be phase-1-9 (dots replaced by dashes)
    assert "phase-1-9" in header, f"Expected phase-1-9 in header: {header!r}"


def test_header_scope_for_top_level_phase():
    rows = [
        _make_row("0.1.bullet-1", "feat(x): a"),
        _make_row("0.2.bullet-1", "feat(x): b"),
        _make_row("0.3.bullet-1", "feat(x): c"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "phase-0" in header, f"Expected phase-0 in header: {header!r}"


def test_header_run_id_suffix():
    rows = [_make_row("0.1", "feat(x): a", run_id="p2p-20260515-abc")]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "[p2p-20260515-abc]" in header


def test_header_dominant_type():
    rows = [
        _make_row("0.1", "chore(ops): cleanup"),
        _make_row("0.2", "feat(p2p): new feature"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert header.startswith("feat("), f"Expected feat type: {header!r}"


# ── _build_grouped_msg — stats in header ──────────────────────────────────────

def test_impl_count_in_header():
    rows = [
        _make_row("1.1", "feat(x): a", drift_kind="none"),
        _make_row("1.2", "feat(x): b", drift_kind="none"),
        _make_row("1.3", "feat(x): c", drift_kind="extra_change"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "2 implementations" in header, f"Unexpected header: {header!r}"
    assert "1 drift" in header, f"Unexpected header: {header!r}"


def test_single_impl_no_plural():
    rows = [_make_row("2.1", "fix(heir): fix castling")]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "1 implementation" in header
    # no plural 's'
    assert "implementations" not in header


def test_tests_added_in_header():
    rows = [
        _make_row("0.1", "feat(x): a", tests_added=5),
        _make_row("0.2", "feat(x): b", tests_added=3),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "8 tests added" in header


def test_no_tests_omitted_from_header():
    rows = [_make_row("0.1", "feat(x): a", tests_added=0)]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "test" not in header


def test_no_drift_omitted_from_header():
    rows = [_make_row("0.1", "feat(x): a", drift_kind="none")]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "drift" not in header


# ── _build_grouped_msg — bullet points ────────────────────────────────────────

def test_bullet_count_matches_row_count():
    rows = [
        _make_row("0.1.bullet-1", "feat(p2p-0.1): first [run-1]"),
        _make_row("0.2.bullet-1", "feat(p2p-0.2): second [run-1]"),
        _make_row("0.3.bullet-1", "chore(ops): third [run-1]"),
    ]
    msg = _build_grouped_msg(rows)
    bullets = [l for l in msg.splitlines() if l.strip().startswith("*")]
    assert len(bullets) == 3


def test_bullet_format_starts_with_star():
    rows = [_make_row("0.1", "feat(x): something")]
    msg = _build_grouped_msg(rows)
    body_lines = msg.splitlines()[1:]
    assert len(body_lines) == 1
    assert body_lines[0].strip().startswith("*"), f"Expected bullet: {body_lines!r}"


def test_bullet_contains_individual_commit_message():
    rows = [
        _make_row("0.1", "feat(p2p-0.1): enumerate legacy usages [run-1]"),
        _make_row("0.2", "fix(p2p-0.2): corruption recovery [run-1]"),
    ]
    msg = _build_grouped_msg(rows)
    assert "enumerate legacy usages" in msg
    assert "corruption recovery" in msg


def test_single_row_still_has_header_and_bullet():
    row = _make_row("2.1", "fix(heir): fix castling [run-99]")
    msg = _build_grouped_msg([row])
    lines = msg.splitlines()
    assert len(lines) == 2  # header + 1 bullet
    assert _is_conventional(lines[0])
    assert lines[1].strip().startswith("*")
    assert "fix(heir): fix castling" in lines[1]


def test_empty_rows_returns_sensible_fallback():
    msg = _build_grouped_msg([])
    assert _is_conventional(msg.splitlines()[0])


# ── _build_grouped_msg — phase-less rows ──────────────────────────────────────

def test_no_phase_falls_back_to_workspace_scope():
    rows = [
        {"commit_message": "chore(ops): something", "action": "commit",
         "drift_kind": "none", "tests_added": "0", "run_id": "r1", "phase": ""},
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "workspace" in header


# ── _build_grouped_msg — multiple run_ids ─────────────────────────────────────

def test_multiple_run_ids_uses_first():
    rows = [
        _make_row("0.1", "feat(x): a", run_id="run-first"),
        _make_row("0.2", "feat(x): b", run_id="run-second"),
    ]
    msg = _build_grouped_msg(rows)
    header = msg.splitlines()[0]
    assert "[run-first]" in header
    assert "[run-second]" not in header


# ── full Phase-1 scenario (mirrors user's example) ────────────────────────────

def test_phase1_scenario_matches_expected_shape():
    """
    Simulate completing Phase 1 (sections 1.1–1.9): 9 implementation rows,
    1 drift row, 42 tests added.

    Expected header shape:
      feat(phase-1): 9 implementations, 1 drift, 42 tests added [p2p-run-1]
    Then 10 bullet lines.
    """
    rows = [
        _make_row(f"1.{i}", f"feat(p2p-1.{i}): impl {i} [p2p-run-1]",
                  tests_added=4, run_id="p2p-run-1")
        for i in range(1, 10)
    ] + [
        _make_row("1.9", "docs(p2p-1.9): spec update [p2p-run-1]",
                  drift_kind="extra_change", tests_added=6, run_id="p2p-run-1"),
    ]

    msg = _build_grouped_msg(rows)
    lines = msg.splitlines()
    header = lines[0]

    # Shape checks
    assert _is_conventional(header), f"Header not CC: {header!r}"
    assert "phase-1" in header, f"Missing phase-1 scope: {header!r}"
    assert "9 implementations" in header, f"Wrong impl count: {header!r}"
    assert "1 drift" in header, f"Wrong drift count: {header!r}"
    assert "42 tests added" in header, f"Wrong test count: {header!r}"
    assert "[p2p-run-1]" in header

    bullets = [l for l in lines[1:] if l.strip().startswith("*")]
    assert len(bullets) == 10, f"Expected 10 bullets, got {len(bullets)}"


# ── standalone runner ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    import unittest

    # Run with pytest if available, otherwise fall back to a manual scan.
    try:
        import pytest as _pt
        raise SystemExit(_pt.main([__file__, "-v"]))
    except ImportError:
        pass

    # Manual fallback
    passed = failed = 0
    fns = {k: v for k, v in globals().items() if k.startswith("test_")}
    for name, fn in fns.items():
        try:
            fn()
            print(f"  PASS  {name}")
            passed += 1
        except Exception as exc:
            print(f"  FAIL  {name}: {exc}")
            failed += 1
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)
