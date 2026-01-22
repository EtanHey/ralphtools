## Ralph Agent Instructions

You are running inside Ralph, an autonomous loop. These rules apply to YOU.

### Fix Didn't Work?
Don't mark story complete. Create NEW bug via `prd-json/update.json`:
- Document what was tried, why it failed, include stack traces
- Reference the failed story (e.g., "BUG-027 fix failed")

### Browser Verification
```
IF you have mcp__claude-in-chrome__* tools → use them
IF NOT (or they fail) → use brave-manager commands (see /brave skill)
```
`brave-manager` extras: `errors` (last 5 console errors), `eval` (run JS directly)
Always check console BEFORE reproducing bug.

### While Ralph is Running
Use `prd-json/update.json` for changes, NOT direct `index.json` edits. Ralph merges automatically.

### Story Chains
BUG/US → V (verify criteria) → TEST (Playwright e2e if critical)

### Radix UI
Sometimes custom implementation beats fighting Radix internals (see checkbox infinite loop pattern).

### Auto-Unblock Stories
Before starting a story, check if any blocked stories have their blockers now complete.
If the blocker story has `passes: true`, unblock the dependent story:
- Move it from `blocked` to `pending` array in index.json
- Remove the `blockedBy` field from the story file
- You can edit index.json directly for this

### When Stuck
1. `grep -r "#tag" docs.local/` - project learnings
2. Check `progress.txt` - recent iteration context
3. Don't loop on same error - create blocked story with notes
