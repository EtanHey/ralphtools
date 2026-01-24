# Ralph Scripts

This directory contains utility scripts for Ralph tooling and development workflows.

## Pre-Commit Hook System

Ralph uses a pre-commit hook to ensure code quality before commits. The hook is located at `.githooks/pre-commit` and configured via `git config core.hooksPath .githooks`.

### What the Hook Checks

The pre-commit hook runs **8 checks** in order:

| # | Check | Description | Blocking? |
|---|-------|-------------|-----------|
| 1 | ZSH Syntax | `zsh -n` validation on staged .zsh files | ✅ Yes |
| 2 | ShellCheck | Linting for staged .sh files | ✅ Yes |
| 3 | Custom Patterns | Bug prevention patterns (break/continue, eval, long sleeps) | ✅ Critical patterns only |
| 4 | Retry Logic | Validates retry loop structure has continue, max_retries, counter | ✅ Yes |
| 5 | Brace Balance | Ensures { } are balanced (critical for functions) | ✅ Yes |
| 6 | JSON Validation | `jq` syntax check on staged .json files | ✅ Yes |
| 7 | Test Suite | Runs `tests/test-ralph.zsh` and `tests/test-skills.zsh` | ✅ Yes |
| 8 | AGENTS.md Sync | Syncs AGENTS.md to AI tool files when modified | ⚠️ Warning only |

### Exit Codes

- **Exit 0**: All checks passed (or only warnings)
- **Exit 1**: One or more blocking errors found

### Bypassing the Hook

For emergencies only (not recommended for feature commits):

```bash
git commit --no-verify -m "emergency fix"
```

When you bypass the hook:
- Tests are NOT run
- Syntax is NOT checked
- You may introduce bugs that break CI/CD

### Enabling the Hook

The hook is enabled via `git config core.hooksPath .githooks`. To set this up:

```bash
# Option 1: Run setup script
./scripts/setup-hooks.sh

# Option 2: Manual configuration
git config core.hooksPath .githooks
```

### Testing the Hook Manually

```bash
# Run pre-commit checks without committing
./.githooks/pre-commit

# Run just the test suite
./tests/test-ralph.zsh
```

### Hook Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🔍 Ralph Pre-Commit Checks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/8] ZSH Syntax Check
  ✓ ralph.zsh

[2/8] ShellCheck Linting
  ✓ No .sh files staged

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ ALL CHECKS PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Troubleshooting

**Hook not running?**
- Check `git config core.hooksPath` returns `.githooks`
- Check `.githooks/pre-commit` is executable (`chmod +x`)

**Tests failing unexpectedly?**
- Run tests directly: `./tests/test-ralph.zsh`
- Check test output for specific failures

**Need to bypass for emergency?**
- Use `git commit --no-verify` but fix issues ASAP
- Consider creating a BUG story for the underlying issue

## Other Scripts

| Script | Purpose |
|--------|---------|
| `setup-hooks.sh` | Configure git to use .githooks directory |
| `sync-agents.sh` | Sync AGENTS.md to AI tool config files |
| `context-migrate.zsh` | Analyze CLAUDE.md for context extraction |

## Related Files

- `.githooks/pre-commit` - The actual pre-commit hook
- `tests/test-ralph.zsh` - Ralph test suite (49+ tests)
- `tests/test-skills.zsh` - Skills test suite
