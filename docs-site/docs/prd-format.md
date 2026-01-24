---
sidebar_position: 3
title: PRD Format
---

# PRD Format Reference

Ralph uses a JSON-based PRD format stored in `prd-json/`.

## Directory Structure

```
prd-json/
├── index.json          # Story order and metadata
└── stories/
    ├── US-001.json     # Individual story files
    ├── US-002.json
    └── ...
```

## index.json

```json
{
  "title": "Feature Name",
  "workingDirectory": "src",
  "pending": ["US-001", "US-002"],
  "blocked": [],
  "nextStory": "US-001",
  "stats": {
    "total": 2,
    "completed": 0,
    "pending": 2,
    "blocked": 0
  }
}
```

## Story JSON (stories/US-XXX.json)

```json
{
  "id": "US-001",
  "title": "Add User Authentication",
  "description": "Implement login/logout functionality",
  "type": "feature",
  "priority": "high",
  "status": "pending",
  "acceptanceCriteria": [
    { "text": "Login form with email/password", "checked": false },
    { "text": "Session management", "checked": false },
    { "text": "Logout button in header", "checked": false },
    { "text": "Typecheck passes", "checked": false }
  ],
  "dependencies": [],
  "passes": false
}
```

## Story Types

| Type | Prefix | Purpose |
|------|--------|---------|
| User Story | `US-XXX` | Feature implementation |
| Bug Fix | `BUG-XXX` | Bug fixes |
| Verification | `V-XXX` | Visual/browser verification |
| Test | `TEST-XXX` | E2E test stories |
| Master Plan | `MP-XXX` | Infrastructure/refactoring |
| Audit | `AUDIT-XXX` | Review/audit tasks |

## Key Rules

- **One story per iteration** — Ralph completes exactly one story, then respawns
- **JSON criteria are truth** — `checked: true` marks completion
- **Incremental progress** — Criteria are checked one-by-one and committed
- **Verification stories** — V-XXX stories for visual verification

## The /prd Command

The `/prd` command is a Claude Code skill that generates PRDs.

### What It Does

1. Asks 3-5 clarifying questions about your feature
2. Generates a complete PRD with properly-sized stories
3. Saves to `prd-json/` directory (index.json + stories/*.json)
4. **Stops** — it does NOT implement (that's Ralph's job)

### Setup

```bash
mkdir -p ~/.claude/commands
ln -s ~/.config/ralphtools/skills/golem-powers ~/.claude/commands/golem-powers
```

### Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. You: /prd "Add feature X"                               │
│  2. Claude asks clarifying questions                        │
│  3. Claude generates prd-json/ (index.json + stories/)      │
│  4. Claude says "PRD ready. Run Ralph to execute."          │
│  5. You: ralph 20                                           │
│  6. Ralph executes stories autonomously                     │
└─────────────────────────────────────────────────────────────┘
```

## Story Chaining

```
BUG-001 (fix) → V-001 (verify) → TEST-001 (e2e if critical)
US-001 (feature) → V-001 (verify)
```

## Adding Stories During Execution

**Use `update.json` pattern** - don't edit `index.json` directly while Ralph is running:

```json
// prd-json/update.json
{
  "newStories": [
    {
      "id": "BUG-002",
      "title": "Fix regression from US-001",
      "type": "bug",
      "priority": "high",
      "acceptanceCriteria": [
        {"text": "Fix the crash", "checked": false}
      ]
    }
  ]
}
```

Ralph will merge `update.json` into `index.json` automatically.
