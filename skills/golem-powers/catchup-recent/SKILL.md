---
name: catchup-recent
description: Use when taking a short break (hours, not days) and need quick refresh. Reads only uncommitted changes (staged and unstaged). Covers quick catchup, refresh. NOT for: long breaks or full branch review (use catchup instead).
---

# Skill: Catchup Recent (Quick Context Recovery)

> Use for quick catch-up when you only need to see what's currently being worked on. Reads only modified/unstaged files, not the entire branch history.

## When to Use

- Short break from work (few hours)
- Want to see only uncommitted changes
- Quick refresh before continuing
- Before committing - review what will be staged

## Instructions

### Step 1: Get Status

Run:
```bash
git status --short
```

This shows:
- `M ` - Modified (staged)
- ` M` - Modified (unstaged)
- `MM` - Modified (both staged and unstaged changes)
- `A ` - Added (staged)
- `??` - Untracked

### Step 2: Read Modified Files

Read only files with `M` status (modified). Skip untracked (`??`) unless they appear relevant.

Focus on files that are:
- Currently being edited (unstaged `M`)
- Already staged for commit (staged `M` or `A`)

### Step 3: Quick Summary

After reading, provide a brief summary:
- Files currently being edited
- What changes appear to be in progress
- Ready to continue or need clarification

## Example Session

```
User: /golem-powers:catchup-recent

Claude: Let me see what's currently being worked on.

[Runs: git status --short]

 M src/components/TaskItem.tsx
 M src/components/TaskList.tsx
M  src/convex/tasks.ts
?? src/components/DeleteModal.tsx

Found 3 modified files and 1 untracked.

[Reads the 3 modified files]

**Quick Summary:**
- TaskItem.tsx: Adding delete button with onClick handler
- TaskList.tsx: Passing onDelete prop to TaskItem
- tasks.ts: Delete mutation already implemented (staged)
- DeleteModal.tsx: New untracked file (appears to be WIP)

**Current work:** Implementing delete functionality for tasks
**Status:** Delete mutation ready, UI integration in progress

Ready to continue?
```

## Difference from /golem-powers:catchup

| Catchup | Catchup-Recent |
|---------|---------------|
| All files changed in branch | Only uncommitted changes |
| `git diff --name-only main...HEAD` | `git status --short` |
| Full context recovery | Quick refresh |
| After long absence | After short break |

## Tips

- Combine with `git diff` to see actual line changes if needed
- For full branch context, use `/golem-powers:catchup` instead
- If status shows many files, consider committing in progress work first
