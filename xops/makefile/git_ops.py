#!/usr/bin/env python3
"""
git_ops.py — ChessRecast workspace git automation.

Commit messages are derived from agent/p2p_tracking.csv when pending rows
are present, guaranteeing conventional commits come from structured agent
data rather than AI free-form text.

Commands:
  dry   Preview staged changes, derived commit message, and push queue.
  push  Commit staged changes (message from CSV or auto-derived), write
        the real SHA back to the CSV, then push to origin/main.
"""

import csv
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CSV_FILE  = REPO_ROOT / "agent" / "p2p_tracking.csv"
CSV_REL   = "agent/p2p_tracking.csv"

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


# ── CSV: read pending rows ──────────────────────────────────────────────────────
def _pending_csv() -> list[dict]:
    """
    Return rows from p2p_tracking.csv where:
      commit_sha == 'pending'  AND
      action     == 'commit'   AND
      status     == 'completed'
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
    Derive a conventional commit message from a p2p_tracking.csv row.
    Format: p2p(<scope>): <phase_title> [<run_id>]
    Validates that phase, phase_title, and run_id are non-empty.
    """
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
    summary = ", ".join(names) + (f" (+{len(files)-3} more)" if len(files) > 3 else "")
    ts      = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    return f"{_auto_type(files)}({_auto_scope(files)}): {summary} [auto-{ts}]"


# ── display helpers ────────────────────────────────────────────────────────────
WIDTH = 60


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
    """Read-only preview: staged changes, derived message, push queue."""
    dirty_list  = _dirty()
    staged_list = _staged()
    csv_rows    = _pending_csv()
    git_log     = _pending_log()

    # — uncommitted / staged files —
    if dirty_list:
        _section(FILES, "Uncommitted changes")
        for f in dirty_list:
            _file_line(f)
    else:
        print(f"\n{NONE}  No uncommitted changes")

    # — commit message preview —
    if csv_rows:
        _section(CSV_E, f"Commit message  (p2p_tracking.csv — {len(csv_rows)} pending row(s))")
        print(f"   {ARROW}  {_msg_from_csv(csv_rows[0])}")
        for r in csv_rows:
            print(f"      run_id={r.get('run_id','')}  "
                  f"phase={r.get('phase','')}  "
                  f"phase_title={r.get('phase_title','')}")
    elif staged_list:
        _section(FILE, "Commit message  (auto-derived — no pending CSV rows)")
        print(f"   {ARROW}  {_auto_msg(staged_list)}")

    # — local commits waiting to push —
    if git_log:
        _section(COMMIT, "Local commits pending push")
        for c in git_log:
            print(f"   {CHECK}  {c}")
    else:
        print(f"\n{NONE}  Nothing to push — origin/main is up to date")


def push():
    """
    Commit staged changes (message from CSV or auto-derived), write the real
    SHA back to the CSV in a follow-up commit, then push to origin/main.

    P2P mode  (CSV pending rows present):
      1. Stage all unstaged changes.
      2. Pop the tracking CSV from staging.
      3. Commit implementation files with message derived from CSV row.
      4. Write real SHA into CSV; stage + commit the update.

    Fallback mode  (no pending CSV rows):
      1. Stage all unstaged changes.
      2. Commit everything with an auto-derived conventional message.
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
            # ── P2P mode ────────────────────────────────────────────────────────
            msg = _msg_from_csv(csv_rows[0])
            _section(CSV_E, "Commit message  (from p2p_tracking.csv)")
            print(f"   {ARROW}  {msg}")

            # Remove tracking CSV from staging — it gets its own commit with the real SHA
            if CSV_REL in staged_list:
                _run(["git", "restore", "--staged", CSV_REL])

            impl_files = [f for f in staged_list if f != CSV_REL]
            sha = _out(["git", "rev-parse", "--short", "HEAD"])  # current HEAD (pre-commit)

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
                print(f"{WARN} Nothing to commit outside the tracking CSV.")

            # Write SHA back and commit just the CSV
            run_ids = {r["run_id"] for r in csv_rows}
            if _write_sha(run_ids, sha):
                _run(["git", "add", CSV_REL])
                run_id_label = csv_rows[0].get("run_id", "auto")
                csv_msg = f"chore(p2p): tracking sha update [{run_id_label}]"
                _run(["git", "commit", "-m", csv_msg])
                sha2 = _out(["git", "rev-parse", "--short", "HEAD"])
                print(f"{SHA}  CSV update: {sha2}  — {csv_msg}")

        else:
            # ── Fallback mode ────────────────────────────────────────────────────
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
