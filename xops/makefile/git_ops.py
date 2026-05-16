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
  push  Commit each pending run_id group as its own commit (group 1 = all
        staged files; groups 2+ = empty commits), then push. No write-back.
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


# ── CSV: read pending rows ──────────────────────────────────────────────────────
def _pending_csv() -> list[dict]:
    """
    Return rows from tracking.csv where:
      commit_sha == 'pending'  AND
      action     == 'commit'   AND
      status     == 'completed'  (also accepts legacy typo 'complete')
    Additionally filters out run_ids already present in git log (idempotency
    guard — no SHA write-back required).
    Results are ordered by file (append) order.
    """
    if not CSV_FILE.exists():
        return []
    try:
        with CSV_FILE.open(newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        pending = [
            r for r in rows
            if r.get("commit_sha", "").strip().lower() == "pending"
            and r.get("action",     "").strip().lower() == "commit"
            and r.get("status",     "").strip().lower() in ("completed", "complete")
        ]
        if not pending:
            return []
        # Idempotency: skip run_ids already in git history.
        log_text = _out(["git", "log", "--all", "--format=%B"])
        return [
            r for r in pending
            if f"[{r.get('run_id', '').strip()}]" not in log_text
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
        return explicit

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


# ── grouped commit message ─────────────────────────────────────────────────────
_CC_RE = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)"
    r"(?:\([a-z0-9._\-/]+\))?!?: .+"
)


def _is_conventional(msg: str) -> bool:
    return bool(_CC_RE.match((msg.splitlines()[0] if msg else "").strip()))


def _build_single_msg(csv_rows: list[dict]) -> str:
    """One commit message for a single run_id group.

    - Single row  → use its commit_message directly.
    - Multiple rows → first row's message as title, rest as body bullets.
    """
    if not csv_rows:
        return "chore(workspace): no pending rows"
    first_msg = _msg_from_csv(csv_rows[0])
    if not _is_conventional(first_msg):
        first_msg = f"chore(workspace): {first_msg}"
    if len(csv_rows) == 1:
        return first_msg
    bullets = [f" * {_msg_from_csv(r)}" for r in csv_rows[1:]]
    return first_msg + "\n\n" + "\n".join(bullets)


def _group_by_run_id(csv_rows: list[dict]) -> list[tuple[str, list[dict]]]:
    """Group pending rows by run_id, preserving first-occurrence order.
    Returns [(run_id, [rows]), ...] in the order run_ids first appear."""
    seen: dict[str, list[dict]] = {}
    order: list[str] = []
    for row in csv_rows:
        rid = (row.get("run_id") or "unknown").strip()
        if rid not in seen:
            seen[rid] = []
            order.append(rid)
        seen[rid].append(row)
    return [(rid, seen[rid]) for rid in order]


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
    """Read-only preview: staged changes, one commit per run_id group, push queue."""
    dirty_list  = _dirty()
    staged_list = _staged()
    csv_rows    = _pending_csv()
    git_log     = _pending_log()

    # — uncommitted / staged files —
    if dirty_list:
        _section(FILES, "Uncommitted changes  (would be staged by `make git`)")
        for f in dirty_list:
            _file_line(f)
    else:
        print(f"\n{NONE}  No uncommitted changes")

    # — commit preview — one block per run_id group —
    new_commits: list[str] = []
    if csv_rows:
        groups = _group_by_run_id(csv_rows)
        n = len(groups)
        for i, (run_id, rows) in enumerate(groups):
            files_label = "all staged files" if i == 0 else "empty commit (run_id record)"
            _section(CSV_E,
                f"Commit {i+1}/{n}  "
                f"[{run_id} · {len(rows)} row(s) · {files_label}]")
            msg = _build_single_msg(rows)
            for line in msg.splitlines():
                if not line.strip():
                    continue
                prefix = "   " if line.startswith(" *") else f"   {ARROW} "
                print(f"{prefix} {line.lstrip()}")
            new_commits.append(msg.splitlines()[0])
    elif dirty_list or staged_list:
        all_paths = list(dict.fromkeys(
            [p[3:].strip() for p in dirty_list if len(p) > 3 and p[2] == " "]
            + staged_list
        ))
        msg = _auto_msg(all_paths)
        _section(FILE, "Commit message  (auto-derived — no pending CSV rows)")
        print(f"   {ARROW}  {msg}")
        new_commits.append(msg)

    # — what would be pushed —
    push_queue = new_commits + git_log
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
    One commit per run_id group — rows with the same run_id are one task and
    land in a single commit; different run_ids become separate commits.

    No SHA write-back: idempotency is handled by cross-checking run_ids
    against git log in _pending_csv().  re-running `make git` safely skips
    run_ids already in history.

    Commit ordering:
      Group 1  — all staged implementation files (normal commit)
      Group 2+ — empty commits (`--allow-empty`) that record the run_id
                 message in git log without touching the working tree

    Fallback mode (no pending CSV rows):
      Commit all staged changes with an auto-derived conventional message.
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
            # ── Tracked mode: one commit per run_id group ────────────────────
            groups = _group_by_run_id(csv_rows)
            n = len(groups)

            for i, (run_id, rows) in enumerate(groups):
                is_first    = (i == 0)
                files_label = "all staged files" if is_first else "empty commit (run_id record)"
                msg         = _build_single_msg(rows)

                _section(CSV_E,
                    f"Commit {i+1}/{n}  "
                    f"[{run_id} · {len(rows)} row(s) · {files_label}]")
                for line in msg.splitlines():
                    if not line.strip():
                        continue
                    prefix = "   " if line.startswith(" *") else f"   {ARROW} "
                    print(f"{prefix} {line.lstrip()}")

                if is_first:
                    _section(FILES, "Files in this commit")
                    for f in staged_list:
                        print(f"   {FILE}  {f}")
                    r = _run(["git", "commit", "-m", msg])
                else:
                    r = _run(["git", "commit", "--allow-empty", "-m", msg])

                if r.returncode != 0:
                    print(f"\n{ERR}  Commit {i+1}/{n} failed.")
                    sys.exit(r.returncode)

                sha = _out(["git", "rev-parse", "--short", "HEAD"])
                print(f"\n{SHA}  SHA: {sha}")

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
