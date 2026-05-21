#!/usr/bin/env python3
"""xops/makefile/codegraph_ops.py — dispatcher for `make codegraph.*` targets.

Per AGENTS.md §2 nothing here commits or pushes. All targets are local-only
and either: read state, regenerate config from xops/codegraph/VERSION, or
shell out to `npx -y @colbymchenry/codegraph@<pin>`.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = REPO_ROOT / "xops" / "codegraph" / "VERSION"


def _pin() -> str:
    return VERSION_FILE.read_text().strip()


def _npx(*args: str, check: bool = True) -> int:
    cmd = ["npx", "-y", f"@colbymchenry/codegraph@{_pin()}", *args]
    print(f"$ {' '.join(cmd)}", flush=True)
    return subprocess.run(cmd, cwd=REPO_ROOT, check=check).returncode


def status() -> int:
    pin = _pin()
    cg_dir = REPO_ROOT / ".codegraph"
    print(f"codegraph pin       : {pin}")
    print(f".codegraph/ present : {cg_dir.exists()}")
    if cg_dir.exists():
        sizes = sum(p.stat().st_size for p in cg_dir.rglob('*') if p.is_file())
        print(f".codegraph/ size    : {sizes / 1024:.1f} KiB")
    print()
    return _npx("status", check=False)


def reindex() -> int:
    # `init -i` is the documented post-rebase/post-refactor command.
    return _npx("init", "-i", check=False)


def sync_pin() -> int:
    script = REPO_ROOT / "xops" / "codegraph" / "sync-pin.sh"
    return subprocess.run(["bash", str(script)], cwd=REPO_ROOT).returncode


def check_updates() -> int:
    script = REPO_ROOT / "xops" / "codegraph" / "check-updates.sh"
    return subprocess.run(["bash", str(script)], cwd=REPO_ROOT).returncode


def print_codex() -> int:
    pin = _pin()
    print(
        "# Paste into ~/.codex/config.toml (Codex CLI is user-global; cannot be checked in)\n"
        "[mcp_servers.codegraph]\n"
        'command = "npx"\n'
        f'args = ["-y", "@colbymchenry/codegraph@{pin}", "serve", "--mcp"]\n'
    )
    return 0


DISPATCH = {
    "status": status,
    "reindex": reindex,
    "sync-pin": sync_pin,
    "check-updates": check_updates,
    "print-codex": print_codex,
}


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in DISPATCH:
        print(f"usage: {argv[0]} <{ '|'.join(DISPATCH) }>", file=sys.stderr)
        return 2
    return DISPATCH[argv[1]]() or 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
