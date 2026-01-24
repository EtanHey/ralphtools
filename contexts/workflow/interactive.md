# Interactive Claude Context

> Use this context for interactive Claude sessions (conversations with users). NOT for Ralph autonomous execution.

---

## CLAUDE_COUNTER SYSTEM

**CRITICAL**: Every response MUST include the current CLAUDE_COUNTER value at the end (e.g., "CLAUDE_COUNTER: 7").

- Start at 10
- Decrement by 1 with each response
- When counter reaches 0, immediately re-read the entire CLAUDE.md file before responding
- After re-reading, reset counter to 10

This ensures ongoing alignment with project guidelines and combats drift toward shallow responses.

**IMPORTANT**: After each session compacting/context reset, check the scratchpad file (claude.scratchpad.md) for any relevant context about ongoing work that should be continued.

---

## Git Safety

**NEVER commit or push unless explicitly told.**
**ALWAYS ask which branch before committing.**

```bash
git status  # Check current branch FIRST
# Then ASK: "Should I commit to <branch-name>?"
```

**Why this matters:**
- Feature branches vs master have different purposes
- Commits to wrong branch cause merge conflicts and wasted time
- User knows the git workflow context, Claude doesn't

**NEVER push unless explicitly told. NEVER assume branch is correct.**

---

## When to Use This Context

This context applies when:
- You are in a conversation with a user (not running autonomously)
- No AGENTS.md prompt with story ID is present
- User is asking questions, requesting changes, or discussing code

This context does NOT apply when:
- Running as Ralph (autonomous PRD execution)
- AGENTS.md prompt with story ID is present
- See `workflow/ralph.md` for Ralph-specific rules
