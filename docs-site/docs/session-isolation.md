---
sidebar_position: 9
title: Session Isolation
---

# Session Isolation (Worktree Mode)

Ralph can pollute your Claude `/resume` history with dozens of iteration sessions. Session isolation solves this by running Ralph in a git worktree, which Claude treats as a separate project.

## How Claude Sessions Work

Claude stores session history per-directory in `~/.claude/projects/`. Each unique directory path gets its own session storage:

```
~/.claude/projects/-Users-etanheyman-Desktop-Gits-myproject/
~/.claude/projects/-Users-etanheyman-Desktop-Gits-myproject--worktrees-ralph-session/
```

When you run `/resume` in Claude, it shows sessions from the *current directory only*.

## The Problem

Without isolation:
- Ralph runs 50+ iterations in your main project
- Each iteration creates a session entry
- Your `/resume` list is flooded with Ralph sessions
- Hard to find your actual work sessions

## The Solution: Worktrees

Git worktrees create a linked copy of your repo at a different path. Claude sees this as a separate project, so Ralph sessions stay isolated.

## Commands

### `ralph-start [args]`

Creates an isolated worktree and outputs the command to run Ralph:

```bash
ralph-start 50 -S
```

Output:
```
🌳 Ralph Session Isolation

📁 Creating worktree at: ~/worktrees/myproject/ralph-session
   Source branch: master

✓ Worktree created
✓ Copied prd-json/ to worktree
✓ Copied progress.txt to worktree

─────────────────────────────────────────────────────────────

Session isolated! Run this command to start Ralph:

  cd ~/worktrees/myproject/ralph-session && source ~/.config/ralph/ralph.zsh && ralph 50 -S

─────────────────────────────────────────────────────────────

When done, run ralph-cleanup from the worktree to merge back.
```

### `ralph-cleanup [--force]`

Run from within the worktree to merge changes back and clean up:

```bash
ralph-cleanup
```

This will:
1. Prompt to commit any uncommitted changes
2. Sync `prd-json/` and `progress.txt` back to main repo
3. Merge the worktree branch into your main branch
4. Remove the worktree
5. Delete the temporary branch

Use `--force` to skip confirmation prompts.

## Workflow

```bash
# 1. In your main project
cd ~/projects/myproject
ralph-start 50 -S

# 2. Copy and run the output command
cd ~/worktrees/myproject/ralph-session && source ~/.config/ralph/ralph.zsh && ralph 50 -S

# 3. Watch Ralph run (optional, new terminal)
ralph-live

# 4. When done, clean up from the worktree
ralph-cleanup

# 5. Back in main project, verify
cd ~/projects/myproject
git log --oneline -5  # See merged commits
```

## File Locations

| Path | Purpose |
|------|---------|
| `~/worktrees/<repo>/ralph-session/` | Worktree location |
| `~/.claude/projects/-...-worktrees-ralph-session/` | Claude session storage |
| `prd-json/` | Copied to worktree, synced back |
| `progress.txt` | Copied to worktree, synced back |

## Tips

1. **Existing worktree?** `ralph-start` will offer to resume it
2. **Clean up failed?** Run `git worktree prune` in main repo
3. **See all worktrees:** `git worktree list`
4. **Manual removal:** `git worktree remove ~/worktrees/repo/ralph-session --force`

## Caveats

- Session history is lost when worktree is deleted (by design)
- GitHub issue #15776 tracks potential session preservation
- If you need to keep history, manually move `~/.claude/projects/...worktree.../` before cleanup
