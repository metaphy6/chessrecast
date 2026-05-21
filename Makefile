# ChessRecast — operational entry point
#
# All logic lives in xops/makefile/ Python scripts.
# The Makefile is a thin dispatcher only — no hardcoded commands.
#
# Usage:
#   make help       List all targets
#   make git        Push accumulated agent commits to origin/main
#   make git.dry    Preview what would be pushed (no changes)

XOPS_MK := xops/makefile
PYTHON   := python3

.PHONY: help git git.dry \
        codegraph.status codegraph.reindex codegraph.sync-pin \
        codegraph.check-updates codegraph.print-codex

## help                     List all available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /'

## git                      Stage any uncommitted changes + push all pending commits to origin/main
git:
	@$(PYTHON) $(XOPS_MK)/git_ops.py push

## git.dry                  Preview what 'make git' would commit and push (read-only)
git.dry:
	@$(PYTHON) $(XOPS_MK)/git_ops.py dry

## codegraph.status         Print CodeGraph pin + .codegraph/ state + server status
codegraph.status:
	@$(PYTHON) $(XOPS_MK)/codegraph_ops.py status

## codegraph.reindex        Rebuild the .codegraph/ index (run after big rebases/refactors)
codegraph.reindex:
	@$(PYTHON) $(XOPS_MK)/codegraph_ops.py reindex

## codegraph.sync-pin       Propagate xops/codegraph/VERSION into all MCP configs + docs
codegraph.sync-pin:
	@$(PYTHON) $(XOPS_MK)/codegraph_ops.py sync-pin

## codegraph.check-updates  Warn if a newer CodeGraph version exists on npm (read-only)
codegraph.check-updates:
	@$(PYTHON) $(XOPS_MK)/codegraph_ops.py check-updates

## codegraph.print-codex    Print the Codex CLI MCP snippet to paste into ~/.codex/config.toml
codegraph.print-codex:
	@$(PYTHON) $(XOPS_MK)/codegraph_ops.py print-codex
