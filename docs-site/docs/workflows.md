---
sidebar_position: 5
title: Workflows
---

# Workflows Reference

## Story Splitting

When a story is too big for one iteration, Ralph can split it.

### When to Split

- 8+ acceptance criteria
- 5+ files to modify
- 50% through context and not close to done

### Process

1. **Recognize** — Acknowledge the story is too big
2. **Plan** — Break into substories (US-001a, US-001b, etc.)
3. **Validate** — Run `/critique-waves` for consensus (20 passes)
4. **Write** — Insert substories to PRD
5. **Exit** — Next iteration picks up first substory

## Blocked Task Handling

### What Blocks a Task

- External API unavailable (need API key)
- User decision required (ambiguous requirements)
- MCP tools fail or return errors
- Manual testing needed

### Behavior

When Ralph encounters a blocked task:
1. Marks in story JSON: `"status": "blocked"` with reason
2. Notes in progress.txt
3. Moves to next incomplete task
4. Commits the blocker note

When ALL tasks are blocked:
- Outputs `<promise>ALL_BLOCKED</promise>`
- Loop stops for user intervention

## docs.local/ Convention

`docs.local/` is a convention for local-only project documentation. It's **not a standard** — created for:

- Learnings that persist across Ralph iterations
- Archived PRDs from completed features
- Project-specific notes that shouldn't be in git

### Structure

```
your-project/
├── .gitignore          # Add: docs.local/
├── prd-json/           # Active PRD (Ralph reads this)
│   ├── index.json
│   └── stories/
├── progress.txt        # Current iteration notes
└── docs.local/         # Local-only, gitignored
    ├── README.md       # Index of learnings
    ├── learnings/      # Topic-specific files
    │   ├── auth.md
    │   └── rtl.md
    └── prd-archive/    # Completed PRDs
        └── 2024-01-feature-x/
```

### Setup

Add to your `.gitignore`:
```
docs.local/
```

### Why Gitignore?

- Learnings are often specific to your local setup
- Contains debug notes and experiments
- Completed PRDs bloat the repo
- You can always recover from git history

## Learnings System

Ralph persists learnings across iterations in a searchable structure.

### Structure

```
docs.local/
├── README.md                    # Index
├── learnings/                   # Topic files
│   ├── auth-patterns.md
│   ├── rtl-layouts.md
│   └── api-quirks.md
└── prd-archive/                 # Completed PRDs
```

### Usage

```bash
# Check learnings status
ralph-learnings

# Search learnings
grep -r "#auth" docs.local/learnings/
```

### Promoting Learnings

When a learning is important enough to persist globally:
1. Mark it in progress.txt: `[PROMOTE] Learning about X`
2. Add to project CLAUDE.md for project-wide knowledge
3. Add to ~/.claude/CLAUDE.md for global knowledge
