#!/usr/bin/env python3
"""
git_ops.py — ChessRecast workspace git automation.

Commit messages are derived from agent/tracking.csv when pending rows are
present, guaranteeing conventional commits come from structured agent data
rather than AI free-form text.  Agents NEVER call `git commit`; they append
rows to tracking.csv and stage files.  This script is the sole commit
ordinator — run via `make git` (push) or `make git.dry` (preview only).

Commands:
  dry   Preview staged changes, derived commit messages, and push queue.
  push  Commit staged changes (messages from CSV rows), write real SHAs
        back to tracking.csv, then push to origin/main.
"""

import csv
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CSV_FILE  = REPO_ROOT / "agent" / "tracking.csv"
CSV_REL   = "agent/tracking.csv"

# ── emoji constants ────────────────────────────────────────────────────────────
FILES  = "📂"
FILE   = "📄"
COMMIT = "📦"
PUSH   = "🚀"
OK     = "✅"
WARN   = "⚠️ "
ERR    = "❌"
SHA    = "🔑"
CSV_E  = "📋"
NONE   = "💤"
ARROW  = "→"
CHECK  = "✔"

# ── subprocess ─────────────────────────────────────────────────────────────────
def _run(cmd, *, capture: bool = False):
    kw: dict = {"cwd": REPO_ROOT}
    if capture:
        kw["capture_output"] = True
        kw["text"] = True
    return subprocess.run(cmd, **kw)


def _out(cmd) -> str:
    return _run(cmd, capture=True).stdout.strip()


# ── git state ──────────────────────────────────────────────────────────────────
def _staged() -> list[str]:
    raw = _out(["git", "diff", "--cached", "--name-only"])
    return [l.strip() for l in raw.splitlines() if l.strip()]


def _dirty() -> list[str]:
    """Short-status lines, e.g. 'M  file.dart', '?? foo.txt'."""
    raw = _out(["git", "status", "--short"])
    return [l.rstrip() for l in raw.splitlines() if l.strip()]


def _pending_log() -> list[str]:
    raw = _out(["git", "log", "origin/main..HEAD", "--oneline", "--decorate"])
    return [l for l in raw.splitlines() if l.strip()]


# ── conventional-commits enforcement ───────────────────────────────────────────
# type(scope)?: description    (scope and ! are optional)
_CC_TYPES = (
    "feat", "fix", "docs", "style", "refactor", "perf", "test",
    "chore", "ci", "build", "auto", "p2p", "revert",
)
_CC_RE = re.compile(
    r"^(?P<type>" + "|".join(_CC_TYPES) + r")"
    r"(?:\((?P<scope>[a-z0-9._\-/]+)\))?"
    r"(?P<bang>!)?"
    r": (?P<desc>\S.*\S|\S)$"
)


def _is_conventional(msg: str) -> bool:
    if not msg:
        return False
    head = msg.splitlines()[0].strip()
    return bool(_CC_RE.match(head))


def _normalize_to_conventional(msg: str, fallback_type: str = "chore",
                                fallback_scope: str = "workspace") -> str:
    """If `msg` is already conventional, return as-is. Otherwise wrap it."""
    if _is_conventional(msg):
        return msg
    head = (msg.splitlines()[0] if msg else "").strip() or "update"
    print(f"{WARN} Commit message not conventional — normalising: {head!r}")
    return f"{fallback_type}({fallback_scope}): {head}"


# ── CSV: read pending rows ──────────────────────────────────────────────────────
def _pending_csv() -> list[dict]:
    """
    Return rows from tracking.csv where:
      commit_sha == 'pending'  AND
      action     == 'commit'   AND
      status     == 'completed'
    Results are ordered by ts_utc (file order = append order).
    """
    if not CSV_FILE.exists():
        return []
    try:
        with CSV_FILE.open(newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        return [
            r for r in rows
            if r.get("commit_sha", "").strip().lower() == "pending"
            and r.get("action",     "").strip().lower() == "commit"
            and r.get("status",     "").strip().lower() == "completed"
        ]
    except Exception as exc:
        print(f"{WARN} CSV parse error: {exc}")
        return []


# ── CSV: derive commit message ──────────────────────────────────────────────────
def _msg_from_csv(row: dict) -> str:
    """
    Return the commit message for this CSV row.

    If the row has a non-empty `commit_message` column that looks like a
    conventional commit, use it directly — no derivation needed.

    Otherwise fall back to assembling:  p2p(<scope>): <phase_title> [<run_id>]
    with validation warnings for missing fields.
    """
    explicit = (row.get("commit_message") or "").strip()
    if explicit:
        return _normalize_to_conventional(
            explicit,
            fallback_type="auto",
            fallback_scope=(row.get("component") or "workspace").split("/")[0] or "workspace",
        )

    # ── fallback: derive from phase / phase_title / run_id ──────────────────
    phase  = (row.get("phase")       or "").strip()
    title  = (row.get("phase_title") or "").strip()
    run_id = (row.get("run_id")      or "").strip()

    if not phase:
        print(f"{WARN} CSV row missing 'phase' — using fallback scope 'p2p'")
        phase = "p2p"
    if not title:
        print(f"{WARN} CSV row missing 'phase_title' — using fallback 'update'")
        title = "update"
    if not run_id:
        print(f"{WARN} CSV row missing 'run_id' — no run-id suffix")

    # Strip leading 'p2p-' to avoid 'p2p(p2p-phase-1)'
    scope  = phase[len("p2p-"):] if phase.lower().startswith("p2p-") else phase
    suffix = f" [{run_id}]" if run_id else ""
    return f"p2p({scope}): {title}{suffix}"


# ── CSV: write real SHA back ────────────────────────────────────────────────────
def _write_sha(run_ids: set[str], sha: str) -> bool:
    """Replace commit_sha='pending' with `sha` for matching run_ids.
    Returns True if the file was modified."""
    if not CSV_FILE.exists() or not run_ids:
        return False
    try:
        with CSV_FILE.open(newline="", encoding="utf-8") as f:
            reader     = csv.DictReader(f)
            fieldnames = list(reader.fieldnames or [])
            rows       = list(reader)
        changed = 0
        for row in rows:
            if (
                row.get("run_id", "") in run_ids
                and row.get("commit_sha", "").strip().lower() == "pending"
            ):
                row["commit_sha"] = sha
                changed += 1
        if not changed:
            return False
        with CSV_FILE.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)
        return True
    except Exception as exc:
        print(f"{WARN} Could not write SHA back to CSV: {exc}")
        return False


# ── fallback: auto-derive conventional commit from file paths ──────────────────
def _auto_type(files: list[str]) -> str:
    p = [f.lower() for f in files]
    if all(x.endswith(".md") or x.startswith("docs/")         for x in p): return "docs"
    if all("test" in x                                         for x in p): return "test"
    if all(x.startswith("frontend/native/")                   for x in p): return "perf"
    if all(x.startswith("backend/")                           for x in p): return "feat"
    if all(x.startswith(("agent/", "xops/", ".github/"))      for x in p): return "chore"
    return "chore"


def _auto_scope(files: list[str]) -> str:
    if not files:
        return "workspace"
    tops = {f.split("/")[0] for f in files}
    if len(tops) == 1:
        top = tops.pop()
        if top in ("frontend", "backend", "agent", "xops", "docs"):
            subs = {f.split("/")[1] for f in files if "/" in f}
            if len(subs) == 1:
                return subs.pop()
        return top
    return "workspace"


def _auto_msg(files: list[str]) -> str:
    if not files:
        return "chore(workspace): sync workspace [auto]"
    names   = [Path(f).name for f in files[:3]]
    summary = " ".join(names) + (f" (+{len(files)-3} more)" if len(files) > 3 else "")
    ts      = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    msg     = f"{_auto_type(files)}({_auto_scope(files)}): update {summary} [auto-{ts}]"
    # Defensive: ensure the auto-derived line is itself conventional.
    return _normalize_to_conventional(msg, fallback_type=_auto_type(files),
                                      fallback_scope=_auto_scope(files))


# ── display helpers ────────────────────────────────────────────────────────────
WIDTH = 60


def _dirty_paths(dirty: list[str]) -> list[str]:
    """Extract clean file paths from `git status --short` lines."""
    paths = []
    for line in dirty:
        if len(line) > 3 and line[2] == " ":
            path = line[3:].strip()
            # Renames: "old -> new" — take the new path
            if " -> " in path:
                path = path.split(" -> ", 1)[1].strip()
            paths.append(path)
    return paths


def _section(icon: str, title: str) -> None:
    print(f"\n{icon}  {title}")
    print("─" * WIDTH)


def _file_line(path: str) -> None:
    """Print a file line, stripping git short-status prefix when present."""
    if len(path) > 3 and path[2] == " ":
        char  = path[0].strip() or path[1].strip()
        label = {"M": "modified", "A": "added", "D": "deleted",
                 "R": "renamed",  "?": "untracked"}.get(char, char)
        clean = path[3:]
        print(f"   {FILE}  {clean:<46}  ({label})")
    else:
        print(f"   {FILE}  {path}")


# ── commands ───────────────────────────────────────────────────────────────────
def dry():
    """Read-only preview: staged changes, derived commit messages, push queue."""
    dirty_list  = _dirty()
    staged_list = _staged()
    csv_rows    = _pending_csv()
    git_log     = _pending_log()

    # Effective file set: everything `push()` would include after `git add -A`.
    # Preserves order, deduplicates (staged paths already appear in dirty_list
    # as "M " / "A " prefix lines, so use dirty_paths as the canonical list).
    all_paths = list(dict.fromkeys(_dirty_paths(dirty_list) + staged_list))

    # — uncommitted / staged files —
    if dirty_list:
        _section(FILES, "Uncommitted changes  (would be staged by `make git`)")
        for f in dirty_list:
            _file_line(f)
    else:
        print(f"\n{NONE}  No uncommitted changes")

    # — commit message preview — always show what commits would be created —
    if csv_rows:
        _section(CSV_E, f"Commits that would be created  (tracking.csv — {len(csv_rows)} row(s))")
        for i, r in enumerate(csv_rows, start=1):
            msg = _msg_from_csv(r)
            label = "(all staged/dirty files)" if i == 1 else "(tracking.csv update)"
            print(f"   {ARROW}  [{i}] {msg}")
            print(f"         {label}  run_id={r.get('run_id','')}  "
                  f"component={r.get('component','')}  "
                  f"phase={r.get('phase','')}")
        # Final tracking SHA-update commit
        run_id_label = csv_rows[0].get("run_id", "auto")
        print(f"   {ARROW}  [+] chore(tracking): sha update [{run_id_label}]")
        print(f"         (tracking.csv SHA back-fill)")
    elif all_paths:
        _section(FILE, "Commit that would be created  (auto-derived — no pending CSV rows)")
        print(f"   {ARROW}  {_auto_msg(all_paths)}")
    else:
        print(f"\n{NONE}  No changes and no pending CSV rows — nothing to commit")

    # — what would be pushed —
    # Tally commits that would be created from dirty/staged changes.
    new_commits: list[str] = []
    if csv_rows:
        for i, r in enumerate(csv_rows, start=1):
            new_commits.append(_msg_from_csv(r))
        run_id_label = csv_rows[0].get("run_id", "auto")
        new_commits.append(f"chore(tracking): sha update [{run_id_label}]")
    elif all_paths:
        new_commits.append(_auto_msg(all_paths))

    push_queue = new_commits + git_log   # new commits land first, then existing ones

    if push_queue:
        _section(PUSH, f"Would be pushed to origin/main  ({len(push_queue)} commit(s))")
        for c in new_commits:
            print(f"   {ARROW}  {c}  (new)")
        for c in git_log:
            print(f"   {CHECK}  {c}  (already committed)")
    else:
        print(f"\n{NONE}  Nothing to commit or push — working tree clean, origin/main up to date")


def push():
    """
    Commit staged changes (messages from tracking.csv rows), write real SHAs
    back to tracking.csv in a follow-up commit, then push to origin/main.

    Tracked mode  (CSV pending rows present):
      For each pending row (in append order):
        - Row 1: commit all implementation files with that row's message.
        - Rows 2+: no new impl files; each gets its own commit (tracking entry
          + message from its CSV row) once the SHA from row 1 is resolved.
      Finally: commit the tracking.csv SHA updates.

    Fallback mode  (no pending CSV rows):
      Stage all changes, commit with an auto-derived conventional message.
    """
    dirty_list  = _dirty()
    staged_list = _staged()

    # Always stage everything that is unstaged
    if dirty_list:
        _run(["git", "add", "-A"])
        staged_list = _staged()

    if staged_list:
        csv_rows = _pending_csv()

        if csv_rows:
            # ── Tracked mode ────────────────────────────────────────────────
            # Remove tracking CSV from staging — it gets its own commit
            if CSV_REL in staged_list:
                _run(["git", "restore", "--staged", CSV_REL])

            impl_files = [f for f in staged_list if f != CSV_REL]

            # Row 1: commit all implementation files
            first_row = csv_rows[0]
            msg       = _msg_from_csv(first_row)
            _section(CSV_E, f"Commit 1/{len(csv_rows)}  (tracking.csv row 1)")
            print(f"   {ARROW}  {msg}")

            if impl_files:
                _section(FILES, "Files in this commit")
                for f in impl_files:
                    print(f"   {FILE}  {f}")

                r = _run(["git", "commit", "-m", msg])
                if r.returncode != 0:
                    print(f"\n{ERR}  Commit failed.")
                    sys.exit(r.returncode)

                sha = _out(["git", "rev-parse", "--short", "HEAD"])
                print(f"\n{SHA}  SHA: {sha}")
            else:
                sha = _out(["git", "rev-parse", "--short", "HEAD"])
                print(f"{WARN} No implementation files staged; only updating tracking.csv.")

            _write_sha({first_row["run_id"]}, sha)

            # Rows 2+: each gets its own commit with its message (no new impl files)
            for i, row in enumerate(csv_rows[1:], start=2):
                row_msg = _msg_from_csv(row)
                _section(CSV_E, f"Commit {i}/{len(csv_rows)}  (tracking.csv row {i})")
                print(f"   {ARROW}  {row_msg}")
                _write_sha({row["run_id"]}, sha)   # same sha — these rows share the impl commit
                _run(["git", "add", CSV_REL])
                # Skip if nothing actually changed (CSV may already have been committed
                # in a previous iteration). Empty commits would abort push entirely.
                staged_now = _staged()
                if not staged_now:
                    print(f"   {NONE}  No CSV delta for row {i} — skipping commit.")
                    continue
                r = _run(["git", "commit", "-m", row_msg])
                if r.returncode != 0:
                    print(f"\n{WARN}  Tracking commit {i} failed; continuing to push.")
                    continue
                sha = _out(["git", "rev-parse", "--short", "HEAD"])
                print(f"   {SHA}  {sha}")

            # Final: commit remaining tracking.csv SHA updates (only if something is staged).
            _run(["git", "add", CSV_REL])
            if _staged():
                run_id_label = first_row.get("run_id", "auto")
                csv_msg = f"chore(tracking): sha update [{run_id_label}]"
                r = _run(["git", "commit", "-m", csv_msg])
                if r.returncode == 0:
                    sha2 = _out(["git", "rev-parse", "--short", "HEAD"])
                    print(f"\n{SHA}  CSV update: {sha2}  — {csv_msg}")
                else:
                    print(f"{WARN}  Final CSV update commit failed; continuing to push.")

        else:
            # ── Fallback mode ────────────────────────────────────────────────
            msg = _auto_msg(staged_list)
            _section(FILE, "Commit message  (auto-derived — no pending CSV rows)")
            print(f"   {ARROW}  {msg}")
            _section(FILES, "Files in this commit")
            for f in staged_list:
                print(f"   {FILE}  {f}")

            r = _run(["git", "commit", "-m", msg])
            if r.returncode != 0:
                print(f"\n{ERR}  Commit failed.")
                sys.exit(r.returncode)

            sha = _out(["git", "rev-parse", "--short", "HEAD"])
            print(f"\n{SHA}  SHA: {sha}")

    # — push —
    git_log = _pending_log()
    if not git_log:
        print(f"\n{NONE}  Nothing to push — origin/main is up to date.")
        sys.exit(0)

    _section(COMMIT, "Commits being pushed")
    for c in git_log:
        print(f"   {CHECK}  {c}")

    r = _run(["git", "pull", "--ff-only"])
    if r.returncode != 0:
        print(f"\n{ERR}  Fast-forward pull failed. Resolve divergence then re-run `make git`.")
        sys.exit(r.returncode)

    print(f"\n{PUSH}  Pushing to origin/main …")
    r = _run(["git", "push", "origin", "main"])
    if r.returncode != 0:
        print(f"\n{ERR}  Push failed.")
        sys.exit(r.returncode)

    final = _out(["git", "log", "origin/main~1..origin/main", "--oneline"])
    print(f"\n{OK}  {final}")


# ── entry point ────────────────────────────────────────────────────────────────
_COMMANDS = {"dry": dry, "push": push}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in _COMMANDS:
        print(__doc__)
        print(f"Commands: {', '.join(_COMMANDS)}")
        sys.exit(1)
    _COMMANDS[sys.argv[1]]()
