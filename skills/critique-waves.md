Run iterative waves of critique agents until consensus is achieved.

**⚠️ CRITICAL PERFORMANCE LIMIT ⚠️**
**NEVER run more than 3 agents in parallel - this is a HARD LIMIT for Mac performance.**

## Setup Phase

1. **Create verification folder**: `docs.local/<BRANCH-NAME>/`
2. **Create instructions.md** with:
   - Context (what this PR/change does)
   - Files to verify (with full paths)
   - FORBIDDEN patterns (things that should NOT exist)
   - REQUIRED patterns (things that MUST exist)
   - Output format for agents
3. **Create tracker.md** with:
   - Goal (e.g., "20 Consecutive Passes")
   - Current status (passes, rounds)
   - Files under verification table
   - Wave log table

## Execution Phase

**Process:**
1. Launch Wave N: 3 agents in parallel (use Task tool with general-purpose subagent)
2. Each agent:
   - Reads the file(s) they're assigned
   - Checks FORBIDDEN patterns (FAIL if found)
   - Checks REQUIRED patterns (FAIL if missing)
   - Writes findings to `docs.local/<BRANCH>/round-N-agent-{1,2,3}.md`
3. Wait for all 3 agents to complete
4. Update tracker.md with results
5. If ANY agent FAILs:
   - Fix the issues
   - Reset consecutive pass count to 0
   - Run another wave
6. If all 3 PASS, increment consecutive passes
7. Continue until goal reached (e.g., 20 consecutive passes)

## Agent Prompt Template

```
VERIFICATION AGENT - Wave N, Agent X

File: `<full-path-to-file>`

VERIFY these requirements:
- FORBIDDEN: [pattern that must NOT exist]
- REQUIRED: [pattern that MUST exist]

Write to `docs.local/<BRANCH>/round-N-agent-X.md`:
# Round N - Agent X
**VERDICT:** PASS or FAIL
**Details:** [brief summary]
```

## Tracker Format

```markdown
# <TICKET> Verification Tracker

## Goal: 20 Consecutive Passes

## Current Status
- **Consecutive Passes:** 0
- **Total Rounds:** 0

## Files Under Verification
| # | File | Purpose |
|---|------|---------|
| 1 | `path/to/file1.ts` | Description |
| 2 | `path/to/file2.sql` | Description |

## Verification Rules

### FORBIDDEN Patterns (FAIL if found):
- Pattern 1
- Pattern 2

### REQUIRED Patterns (FAIL if missing):
- Pattern 1
- Pattern 2

## Wave Log
| Round | Agent 1 | Agent 2 | Agent 3 | Result |
|-------|---------|---------|---------|--------|
| 1     | PASS    | PASS    | PASS    | 3/3    |
```

## Critical Rules

- **NEVER run more than 3 agents in parallel**
- Agents write to separate MD files (no shared state)
- Update tracker after EACH wave
- Reset pass count on ANY failure
- All files in ONE folder: `docs.local/<BRANCH>/`
- Maximum 10 rounds (if still no consensus, escalate to user)

## Example Session

```
Setting up docs.local/feature-branch/...
Created instructions.md and tracker.md

Wave 1: Launching 3 agents...
Results: Agent 1 PASS, Agent 2 FAIL (found forbidden pattern), Agent 3 PASS
Consecutive: 0 (reset due to failure)

Fixing issue found by Agent 2...

Wave 2: Launching 3 agents...
Results: All 3 PASS
Consecutive: 3

Wave 3: Launching 3 agents...
Results: All 3 PASS
Consecutive: 6

...

Wave 7: Launching 3 agents...
Results: All 3 PASS
Consecutive: 21

GOAL ACHIEVED: 21 consecutive passes (exceeded 20 goal)
```
