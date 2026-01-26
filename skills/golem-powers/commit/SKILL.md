---
name: commit
description: Use when ready to commit changes. Runs CodeRabbit review first, then commits if review passes.
---

# Commit with Code Review

Runs CodeRabbit review on staged changes, then commits if approved.

## Flow

1. Check for staged changes
2. Run CodeRabbit review (`cr review --plain` for headless/Claude compatibility)
3. Show review results
4. If review passes → prompt for commit message → commit
5. If review fails → show issues → ask user if they want to proceed anyway

## Usage

```bash
# Stage your changes first
git add <files>

# Then invoke the skill
/commit
```

## What This Skill Does

When invoked, Claude will:

1. **Check staged changes**: Run `git diff --staged --stat` to show what's staged
2. **Run CodeRabbit**: Execute `cr review --plain` (headless mode, works from Claude)
3. **Evaluate results**:
   - If CR passes (no critical issues): proceed to commit
   - If CR fails: show issues and ask user for decision
4. **Commit**: Generate commit message based on changes, commit with co-author

## Manual Steps (if not using this skill)

```bash
# 1. Stage changes
git add -A

# 2. Run CodeRabbit (--plain for headless)
cr review --plain

# 3. If passes, commit
git commit -m "feat: description

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Requirements

- `cr` CLI installed (CodeRabbit)
- Changes staged with `git add`

## Notes

- This is for interactive use, not Ralph execution
- For Ralph stories, use `/ralph-commit` instead
- Does NOT push - that's a separate action
