#!/usr/bin/env python3
"""
git_ops.py — Managed git push for ChessRecast workspace.

All logic for `make git` and `make git.dry` lives here; the Makefile
is a thin shim that delegates to this script.

Commands:
  dry   Show pending local commits and any uncommitted changes.
         No state is mutated.
  push  Stage uncommitted changes (if any) + auto-commit, then push
         all local commits to origin/main.
"""

import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd, *, capture=False):
    kwargs: dict = {"cwd": REPO_ROOT}
    if capture:
        kwargs["capture_output"] = True
        kwargs["text"] = True
    return subprocess.run(cmd, **kwargs)


def _out(cmd) -> str:
    return _run(cmd, capture=True).stdout.strip()


def _pending() -> str:
    return _out(["git", "log", "origin/main..HEAD", "--oneline", "--decorate"])


def _dirty() -> str:
    return _out(["git", "status", "--short"])


def _conv_type(files: list[str]) -> str:
    """Infer conventional-commit type from the list of changed file paths."""
    paths = [f.lower() for f in files]
    if all(p.startswith("docs/") or p.endswith(".md") for p in paths):
        return "docs"
    if all(p.startswith("frontend/test/") or "test" in p for p in paths):
        return "test"
    if all(p.startswith("agent/") or p.startswith("xops/") or p.startswith(".github/") for p in paths):
        return "chore"
    if all(p.startswith("frontend/native/") for p in paths):
        return "perf"
    if all(p.startswith("backend/") for p in paths):
        return "feat"
    return "chore"


def _conv_scope(files: list[str]) -> str:
    """Infer a short conventional-commit scope from the changed file paths."""
    if not files:
        return "workspace"
    prefixes = {f.split("/")[0] for f in files}
    if len(prefixes) == 1:
        top = prefixes.pop()
        # one level deeper for common top-level dirs
        if top in ("frontend", "backend", "agent", "xops", "docs"):
            second = {f.split("/")[1] for f in files if len(f.split("/")) > 1}
            if len(second) == 1:
                return second.pop()
        return top
    return "workspace"


def _auto_message() -> str:
    """Build a conventional-commit message from the staged diff stat."""
    names = _out(["git", "diff", "--cached", "--name-only"])
    files = [l.strip() for l in names.splitlines() if l.strip()]
    if not files:
        return "chore(workspace): sync workspace [auto]"
    ctype = _conv_type(files)
    scope = _conv_scope(files)
    summary = ", ".join(files[:3])
    if len(files) > 3:
        summary += f" (+{len(files) - 3} more)"
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    return f"{ctype}({scope}): {summary} [auto-{ts}]"


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def dry():
    """Preview what make git would do — no changes made."""
    dirty = _dirty()
    print("=== Uncommitted changes ===")
    print(dirty if dirty else "(none)")
    print()

    pending = _pending()
    print("=== Commits pending push to origin/main ===")
    if pending:
        print(pending)
        print()
        _run(["git", "log", "origin/main..HEAD", "--stat", "--oneline"])
    else:
        print("(none — origin/main is already up to date)")


def push():
    """Stage + auto-commit any uncommitted changes, then push all pending commits."""
    dirty = _dirty()
    if dirty:
        print("Uncommitted changes detected — staging and auto-committing:")
        print(dirty)
        print()
        _run(["git", "add", "-A"])
        msg = _auto_message()
        print(f"Auto-commit message: {msg}")
        r = _run(["git", "commit", "-m", msg])
        if r.returncode != 0:
            print("ERROR: auto-commit failed.")
            sys.exit(r.returncode)
        print()

    pending = _pending()
    if not pending:
        print("Nothing to push — origin/main is already up to date.")
        sys.exit(0)

    print("=== Commits to be pushed ===")
    print(pending)
    print()

    print("Pulling latest from origin/main (--ff-only) ...")
    r = _run(["git", "pull", "--ff-only"])
    if r.returncode != 0:
        print("ERROR: Fast-forward pull failed. Resolve divergence, then re-run `make git`.")
        sys.exit(r.returncode)

    print("Pushing to origin/main ...")
    r = _run(["git", "push", "origin", "main"])
    if r.returncode != 0:
        print("ERROR: Push failed.")
        sys.exit(r.returncode)

    print()
    print("=== Pushed ===")
    _run(["git", "log", "origin/main~1..origin/main", "--oneline", "--decorate"])


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

_COMMANDS = {"dry": dry, "push": push}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in _COMMANDS:
        print(__doc__)
        print(f"Available commands: {', '.join(_COMMANDS)}")
        sys.exit(1)
    _COMMANDS[sys.argv[1]]()
