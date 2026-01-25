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
  "stories": ["US-001", "US-002"]
}
```

## Story JSON (stories/US-XXX.json)

```json
{
  "id": "US-001",
  "title": "Add User Authentication",
  "description": "Implement login/logout functionality",
  "criteria": [
    { "id": "c1", "text": "Login form with email/password", "checked": false },
    { "id": "c2", "text": "Session management", "checked": false },
    { "id": "c3", "text": "Logout button in header", "checked": false },
    { "id": "c4", "text": "Typecheck passes", "checked": false }
  ]
}
```

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
cp ~/.config/claude-golem/skills/prd.md ~/.claude/commands/prd.md
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
