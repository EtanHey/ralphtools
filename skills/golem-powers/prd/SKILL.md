---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD."
---

# PRD Generator

Create PRDs for autonomous AI implementation via Ralph loop.

**Config files available:** Read from `~/.config/ralph/configs/` when needed:
- `iteration-rules.json` - Critical iteration rules
- `rtl-rules.json` - RTL layout rules (Hebrew/Arabic projects)
- `modal-rules.json` - Modal/dynamic state rules
- `mcp-tools.json` - Available MCP tools for verification

---

## The Job

1. Ask 3-5 clarifying questions (use `AskUserQuestion` tool)
2. Find git root: `git rev-parse --show-toplevel`
3. Create JSON output:
   - `prd-json/index.json` - Story order and stats
   - `prd-json/stories/{US-XXX}.json` - One file per story
4. Create `progress.txt` at git root
5. **STOP and say: "PRD ready. Run Ralph to execute."**

**🛑 DO NOT IMPLEMENT** - Ralph handles that externally.

---

## Story Rules

### Sizing (THE NUMBER ONE RULE)
Each story must complete in ONE context window (~10 min of AI work).

**Right-sized:** Add one component, update one action, fix one bug
**Too big (split):** "Build dashboard" → Schema + Queries + UI + Filters

### Ordering (Dependencies First)
1. Schema/database
2. Server actions
3. UI components
4. Verification stories (V-XXX)

### Acceptance Criteria
- Must be verifiable (not vague)
- Include "Typecheck passes"
- Include "Verify in browser" for UI stories
- Include commit criterion with proper type (see Commit Convention below)

### Commit Convention
Every story ends with a commit criterion. Match type to story:

| Story Type | Commit Type | Example |
|------------|-------------|---------|
| US-XXX (feature) | `feat:` | `feat: US-001 add login button` |
| BUG-XXX (bug fix) | `fix:` | `fix: BUG-001 resolve crash on empty state` |
| V-XXX (verification) | `test:` | `test: V-001 verify login flow` |
| TEST-XXX (e2e tests) | `test:` | `test: TEST-001 playwright tests for auth` |
| MP-XXX (infrastructure) | `refactor:` or `chore:` | `refactor: MP-001 restructure auth module` |
| AUDIT-XXX (audit/review) | `docs:` or `chore:` | `docs: AUDIT-001 update README` |

**Criterion format:**
```
"Commit: {type}: {STORY-ID} {description}"
```

**Examples:**
- `"Commit: feat: US-034 add user profile page"`
- `"Commit: fix: BUG-012 handle null response from API"`
- `"Commit: test: V-034 verify profile page renders correctly"`
- `"Commit: refactor: MP-002 migrate to modular contexts"`

---

## Conditional Rules

**For RTL projects (Hebrew/Arabic):**
Read `~/.config/ralph/configs/rtl-rules.json` and include RTL checklist in stories.

**For modals/dynamic states:**
Read `~/.config/ralph/configs/modal-rules.json` - each state = separate story.

---

## ⚠️ ADDING TO EXISTING PRD (CRITICAL)

**NEVER edit `index.json` directly when adding stories to an existing PRD!**

Use `prd-json/update.json` instead. Ralph auto-merges it on next run.

### To add new stories:
1. Create story files in `prd-json/stories/` (e.g., `US-034.json`)
2. Create `prd-json/update.json`:
```json
{
  "storyOrder": ["...existing IDs...", "US-034", "US-035"],
  "pending": ["...existing pending...", "US-034", "US-035"],
  "stats": { "total": 29, "pending": 8 }
}
```
3. Ralph merges update.json → index.json automatically, then deletes update.json

### Why update.json?
- Prevents merge conflicts
- Clear audit trail
- Multiple agents can queue changes safely

---

## JSON Templates

### index.json
```json
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-19T12:00:00Z",
  "stats": {"total": 4, "completed": 0, "pending": 4, "blocked": 0},
  "nextStory": "US-001",
  "storyOrder": ["US-001", "US-002", "V-001", "V-002"],
  "pending": ["US-001", "US-002", "V-001", "V-002"],
  "blocked": []
}
```

### Story JSON (prd-json/stories/US-XXX.json)
```json
{
  "id": "US-001",
  "title": "[Story Title]",
  "description": "[What and why]",
  "acceptanceCriteria": [
    {"text": "[Specific criterion]", "checked": false},
    {"text": "Typecheck passes", "checked": false},
    {"text": "Verify in browser", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
```

---

## Output

Create at repository root:
- `prd-json/index.json`
- `prd-json/stories/*.json`
- `prd-json/AGENTS.md` - Instructions for AI agents (see template below)
- `progress.txt`

### AGENTS.md Template
```markdown
# AI Agent Instructions for PRD

## ⚠️ NEVER EDIT index.json DIRECTLY

To add/modify stories, use `update.json`:

1. Create story files in `stories/`
2. Write changes to `update.json` (not index.json!)
3. Ralph merges automatically on next run

## Example update.json
\`\`\`json
{
  "storyOrder": ["existing...", "NEW-001"],
  "pending": ["existing...", "NEW-001"],
  "stats": { "total": X, "pending": Y }
}
\`\`\`

## Story ID Rules
- Check `archive/` for used IDs before creating new ones
- Use next available number (e.g., if US-033 exists, use US-034)
```

**Then say:**
> ✅ PRD saved to `prd-json/` with X stories + X verification stories.
> Run Ralph to execute. I will not implement - that's Ralph's job.

---

## Checklist

- [ ] prd-json/ created at repo root
- [ ] index.json has valid stats, storyOrder, pending
- [ ] AGENTS.md created with update.json instructions
- [ ] Each story has its own JSON file
- [ ] Stories ordered by dependency
- [ ] All criteria are verifiable
- [ ] Every story has "Typecheck passes"
- [ ] UI stories have "Verify in browser"
- [ ] Verification stories (V-XXX) for each US-XXX
- [ ] RTL rules included (if applicable) - read rtl-rules.json
- [ ] Modal rules followed (if applicable) - read modal-rules.json
