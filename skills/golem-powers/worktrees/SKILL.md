---
name: worktrees
description: Use when starting isolated feature work. Creates git worktrees to prevent branch cross-contamination. Covers worktree, isolated development, parallel features, branch isolation. NOT for: simple branch switching (use git checkout), Linear-only operations (use linear).
---

# Git Worktrees

> Create isolated working directories for each task. Worktrees share git history but have separate working files, preventing cross-contamination between branches.

## Quick Actions

| What you want to do | Workflow |
|---------------------|----------|
| Create new worktree from branch name | [workflows/create.md](workflows/create.md) |
| Create worktree from Linear issue | [workflows/from-linear.md](workflows/from-linear.md) |
| List active worktrees | [workflows/list.md](workflows/list.md) |
| Switch to a worktree | [workflows/switch.md](workflows/switch.md) |
| Clean up completed worktrees | [workflows/cleanup.md](workflows/cleanup.md) |

---

## Default Paths

Worktrees are created at: `~/worktrees/<repo>/<branch>`

Example:
- Main repo: `/Users/me/projects/my-app`
- Worktree: `~/worktrees/my-app/feature-login`

---

## Environment Setup (Automatic)

Worktrees automatically handle:
- **Env files**: Uses 1Password `op inject` if `.env.template` exists, else copies `.env*.local` from source
- **Dependencies**: Auto-detects package manager (bun/pnpm/yarn/npm) and installs

| Condition | Action |
|-----------|--------|
| `.env.template` + `op` available | `op inject -i .env.template -o .env.local` |
| `op inject` fails | Fallback: copy from source repo |
| No `.env.template` | Copy all `.env*.local` from source |

---

## Quick Commands

```bash
# List all worktrees
git worktree list

# Create worktree with new branch
git worktree add ~/worktrees/$(basename "$PWD")/feature-name -b feature-name

# Remove worktree
git worktree remove ~/worktrees/$(basename "$PWD")/feature-name

# Prune stale references
git worktree prune
```

---

## Troubleshooting

**"fatal: 'path' already exists"**
- Worktree or directory already exists at that path
- Remove existing directory or choose different name

**"branch already exists"**
- Branch was created previously
- Use without `-b` flag: `git worktree add <path> <existing-branch>`

**"Cannot create worktree from detached HEAD"**
- Must be on a branch in main repo
- Run `git checkout main` first
