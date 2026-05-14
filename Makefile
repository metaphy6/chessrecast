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

.PHONY: help git git.dry

## help       List all available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /'

## git        Stage any uncommitted changes + push all pending commits to origin/main
git:
	@$(PYTHON) $(XOPS_MK)/git_ops.py push

## git.dry    Preview what 'make git' would commit and push (read-only)
git.dry:
	@$(PYTHON) $(XOPS_MK)/git_ops.py dry
