---
name: ralph-commit
description: Atomic test-and-commit for Ralph stories. Runs tests, commits if pass, marks criterion checked. If tests fail, neither happens.
---

# Skill: Ralph Commit (Atomic Test + Commit + Check)

> Use when hitting a "Commit: ..." acceptance criterion in a Ralph story. This skill atomically runs tests, commits, and marks the criterion as checked - or does nothing if tests fail.

## When to Use

- You've completed all other acceptance criteria for a story
- The last criterion is "Commit: feat/fix: STORY-ID description"
- You want to ensure tests pass before committing

## Usage

```bash
# Basic usage
./scripts/run.sh --story=US-106 --message="feat: US-106 description"

# With specific files to stage
./scripts/run.sh --story=US-106 --message="feat: US-106 description" --files="src/ tests/"
```

## What It Does

1. **Runs test suite** (test-ralph.zsh, test-skills.zsh, bun tests)
2. **If tests PASS:**
   - Stages files (specified or all changed)
   - Commits with message
   - Marks the commit criterion as checked in story JSON
   - Reports success
3. **If tests FAIL:**
   - Reports which tests failed
   - Does NOT commit
   - Does NOT mark criterion
   - Suggests: fix code, update test, or create BUG story

## Flags

| Flag | Description |
|------|-------------|
| `--story=ID` | Story ID (e.g., US-106, BUG-028) |
| `--message=MSG` | Commit message |
| `--files=PATHS` | Files to stage (default: auto-detect from story) |
| `--skip-skills` | Skip skills tests (faster) |
| `--dry-run` | Show what would happen without doing it |

## Example

```bash
# After completing US-106 work:
./scripts/run.sh --story=US-106 --message="feat: US-106 UI foundation - derived stats and status file protocol"

# Output on success:
# ✓ Tests passed (77 zsh, 16 skills, 83 bun)
# ✓ Committed: feat: US-106 UI foundation...
# ✓ Marked criterion checked in US-106.json

# Output on failure:
# ✗ Tests failed: test-skills.zsh (2 failures)
# → Fix the failing tests or create BUG story
# → Commit criterion NOT checked
```
