---
name: github
description: Use when doing git operations, creating PRs, or managing GitHub issues. Provides gh CLI commands. Covers git, github, commits, PRs, issues, branches, worktrees. NOT for: Linear issues (use linear), code reviews (use coderabbit).
---

# Skill: GitHub & Git Operations

> Use `gh` CLI and git commands through this skill. No GitHub MCP required.

## Prerequisites
- `gh` CLI installed (`brew install gh`)
- Authenticated: `gh auth login`

---

## Quick Reference

### Issues
```bash
# Create issue
gh issue create --title "Title" --body "Description" --label "bug"

# List issues
gh issue list
gh issue list --assignee @me
gh issue list --label "enhancement"

# View issue
gh issue view 123

# Close issue
gh issue close 123
```

### Pull Requests
```bash
# Create PR (from current branch)
gh pr create --title "Title" --body "Description"

# Create PR with template
gh pr create --title "feat: add feature" --body "$(cat <<'EOF'
## Summary
- Change 1
- Change 2

## Test plan
- [ ] Test A
- [ ] Test B
EOF
)"

# List PRs
gh pr list
gh pr list --author @me

# View PR
gh pr view 123

# Checkout PR locally
gh pr checkout 123

# Merge PR
gh pr merge 123 --squash
```

### Commits (Git)
```bash
# Stage specific files (preferred over git add -A)
git add file1.ts file2.ts

# Commit with co-author
git commit -m "$(cat <<'EOF'
feat: description of change

More details here.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Check status
git status

# View diff
git diff
git diff --staged
```

### Branches
```bash
# Create and switch
git checkout -b feat/new-feature

# Push with upstream
git push -u origin feat/new-feature

# Delete branch (after merge)
git branch -d feat/old-feature
```

### Worktrees (Isolated Development)
```bash
# Create worktree for a feature
git worktree add ../project-feature feat/feature-name

# List worktrees
git worktree list

# Remove worktree
git worktree remove ../project-feature
```

---

## Common Workflows

### Start New Feature
```bash
git checkout -b feat/feature-name
# ... make changes ...
git add changed-files.ts
git commit -m "feat: add feature"
git push -u origin feat/feature-name
gh pr create --title "feat: add feature" --body "Description"
```

### Fix a Bug from Issue
```bash
# View the issue first
gh issue view 42

# Create branch
git checkout -b fix/issue-42

# ... fix the bug ...
git add .
git commit -m "fix: resolve issue #42"
git push -u origin fix/issue-42
gh pr create --title "fix: resolve issue #42" --body "Closes #42"
```

### Create Issue for Future Work
```bash
gh issue create \
  --title "feat: future enhancement" \
  --body "## Description
What needs to be done.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2" \
  --label "enhancement"
```

---

## Safety Rules

1. **Never force push to main/master** - Always create feature branches
2. **Stage specific files** - Avoid `git add -A` which can include secrets
3. **Check before commit** - Run `git status` and `git diff --staged`
4. **Don't commit secrets** - Check for .env, credentials, API keys
5. **Ask before destructive operations** - reset --hard, branch -D, etc.

---

## Troubleshooting

### Auth Issues - GITHUB_TOKEN Conflict (Common!)

**Symptom:** `gh` commands fail with "Bad credentials" even though `gh auth status` shows you're logged in.

**Cause:** An old/expired `GITHUB_TOKEN` in your shell config (`.zshrc`, `.bashrc`) overrides the valid keyring auth.

**Diagnosis:**
```bash
gh auth status
# Look for: "The token in GITHUB_TOKEN is invalid"
# And: "Active account: false" even though logged in
```

**Fix:**
```bash
# 1. Find where GITHUB_TOKEN is set
grep -r "GITHUB_TOKEN" ~/.zshrc ~/.bashrc ~/.zprofile 2>/dev/null

# 2. Remove that line from your shell config (or comment it out)
# The gh CLI uses keyring auth now which is better (auto-refreshes)

# 3. Unset in current session
unset GITHUB_TOKEN

# 4. Verify it works
gh auth status  # Should show "Active account: true"
```

**Why this happens:** Old GitHub workflows used personal access tokens exported as `GITHUB_TOKEN`. The `gh` CLI now uses OAuth via keyring, which is more secure and auto-refreshes. The old env var takes precedence and breaks things.

### Re-authenticate
```bash
gh auth login
```

### Push Rejected
```bash
# Fetch and rebase
git fetch origin
git rebase origin/main

# Then push
git push
```
