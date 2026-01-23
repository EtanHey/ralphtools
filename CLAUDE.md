# Etan's Tools

Central tooling repo: Ralph, skills, CLAUDE.md management.

---

## CLAUDE_COUNTER SYSTEM

**CRITICAL**: Every response MUST include `CLAUDE_COUNTER: N` at the end.

- Start at 10
- Decrement by 1 with each response
- When counter reaches 0: re-read this CLAUDE.md, reset to 10

This prevents drift toward shallow responses and ensures ongoing alignment.

---

## 🚨 CRITICAL: Commit Rules

**After ANY edit to files in this repo:**

1. `git add <specific-files>` (NOT -A, to avoid secrets)
2. `git commit -m "type: description"` (feat/fix/docs/refactor)
3. **ASK before push** - user's global rule

**Why:** Version-controlled to track regressions. Uncommitted changes invisible to future sessions.

---

## Scratchpad for Complex Tasks

Use `claude.scratchpad.md` (gitignored) for:
- Tracking multi-step operations
- Storing intermediate results
- Notes that persist across messages
- **Check after `/compact`** for ongoing work context

---

## Thinking Before Doing

**Anti-patterns to AVOID:**
- Jumping straight to code without understanding
- Suggesting first solution that comes to mind
- Adding dependencies without checking existing
- Assuming full context from brief description
- Researching patterns then NOT implementing them (like I just did)

**DO:**
- Read existing code before suggesting changes
- Check for existing utilities/patterns
- Ask clarifying questions
- Apply learnings immediately, not just discuss them

---

## Files

| File | Purpose |
|------|---------|
| `ralph.zsh` | Main Ralph function + helpers |
| `README.md` | Docs with changelog |
| `CLAUDE.md` | This file - instructions for Claude |
| `skills/` | Skill definitions |
| `tests/` | Test suite |

## Versioning

- **Patch** (v1.0.X): Bug fixes, minor tweaks
- **Minor** (v1.X.0): New features, new commands
- **Major** (vX.0.0): Breaking changes

### 🚨 Version Release Rules

**Before ANY version bump:**

1. **Update README.md changelog** with all features/fixes
2. **Run critique-waves** - must get 6 consecutive agent passes
3. **Verify scope** - significant enough for release

**DO NOT** bump version for:
- Single bug fixes (batch them)
- Documentation-only changes
- Internal refactors with no user impact

**DO** bump version for:
- New commands or flags
- New skills
- Breaking changes
- Significant UX improvements

---

## Testing Changes

After editing `ralph.zsh`:
```bash
source ~/.config/ralph/ralph.zsh
```

Run tests before commit:
```bash
./tests/test-ralph.zsh
```

---

## Learnings

Project-specific learnings in `docs.local/learnings/` (gitignored):

| File | Topics |
|------|--------|
| `terminal-box-alignment.md` | ANSI escapes, emoji width, box padding |

---

## Active Tasks

**Check after context reset:**
- `docs.local/current-task.md` - if exists, resume from there
- `prd-json/index.json` - current PRD state
- `claude.scratchpad.md` - ongoing work notes
