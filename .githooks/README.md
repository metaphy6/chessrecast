# `.githooks/`

Repo-local git hooks. **Opt-in** so the agent can never silently change a contributor's git config.

## Install (run once per workstation)

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

To uninstall:

```bash
git config --unset core.hooksPath
```

## Hooks

- [`pre-push`](pre-push) — refuses to push if the working tree is dirty, scans the diff for silenced / weakened tests via `frontend/tool/check_test_diff.dart`, builds the native lib if needed, then runs `king_castling_policy_regression_test.dart` plus the `*_engine_regression_test.dart` for every mod whose source tree was touched.

The agent **must not** use `git push --no-verify`. Bypass is for human emergencies only.

See [AGENTS.md](../AGENTS.md) §2 for the commit/push policy this hook enforces.
