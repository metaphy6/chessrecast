#!/usr/bin/env bash
# scripts/agent/install-hooks.sh
#
# Opt-in installer. Per AGENTS.md §4, the agent itself does not run this — the
# user does, once per workstation. It only changes the LOCAL git config of this
# repo (core.hooksPath), not the global config.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push 2>/dev/null || true

echo "Installed: core.hooksPath=.githooks (this repo only)"
echo "To uninstall: git config --unset core.hooksPath"
