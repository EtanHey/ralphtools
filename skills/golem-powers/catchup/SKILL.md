---
name: catchup
description: Recover context for long-running sessions by reading all files changed since diverging from main branch
---

# Skill: Catchup (Full Branch Context Recovery)

> Use when returning to a session after extended time (48+ hours) or when context has been lost. Reads ALL files changed in the current branch vs main.

## When to Use

- Starting work on a branch after being away
- Context window overflow - need to rebuild understanding
- Multiple people worked on branch - need to see all changes
- Reviewing what's been done on a feature branch

## Instructions

### Step 1: Get Changed Files

Run:
```bash
git diff --name-only main...HEAD
```

This shows all files changed in the current branch compared to when it diverged from main.

### Step 2: Read All Changed Files

For EACH file listed in the output, read it completely using the Read tool.

**Read in this order (dependencies first):**
1. Schema/database files (`schema.ts`, `convex/`, `prisma/`)
2. Config files (`package.json`, `tsconfig.json`, `.env.example`)
3. Server/API files (`actions/`, `api/`, `server/`)
4. Components/UI files (`components/`, `app/`)
5. Tests (`tests/`, `*.test.ts`)

### Step 3: Summarize Context

After reading all files, summarize:
- What feature/fix is being worked on
- Current state of implementation
- What appears to be left to do

## Example Session

```
User: /golem-powers:catchup

Claude: Let me recover the branch context.

[Runs: git diff --name-only main...HEAD]

Found 12 changed files:
- convex/schema.ts
- convex/tasks.ts
- components/TaskList.tsx
- components/TaskItem.tsx
- app/tasks/page.tsx
...

[Reads each file]

**Context Summary:**
This branch implements a task management feature:
- Schema adds `tasks` table with title, status, assignee fields
- TaskList component displays paginated tasks
- TaskItem has edit/delete actions (delete not yet implemented)
- Page integrates with auth, shows tasks for logged-in user

**Remaining work appears to be:**
- Implement delete confirmation modal
- Add loading states
- Write tests
```

## Tips

- If the diff is huge (50+ files), consider using `/golem-powers:catchup-recent` for just recent changes first
- Check `git log main...HEAD --oneline` to see commit history for additional context
- Look for TODO/FIXME comments in the code to understand remaining work
