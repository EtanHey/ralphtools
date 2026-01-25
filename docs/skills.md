# Skills Reference

Ralph can leverage these skills during execution.

---

## When to Use Scripts vs Workflows

Skills can contain both **scripts** (executable bash files) and **workflows** (markdown documentation). Here's when to use each:

### Use Scripts When:

| Scenario | Why Scripts? |
|----------|--------------|
| API calls (GraphQL, REST) | Complex curl commands with auth, headers, JSON |
| Multi-step operations | Error handling, retries, structured output |
| Validation/verification | Consistent pass/fail output format |
| Dependency installation | Package managers, version checks |
| File processing | Archive creation, cleanup, migrations |

**Benefits:**
- Execute without loading code into context (only output enters conversation)
- Pre-tested, proven error handling
- Consistent structured output (SUCCESS/ERROR prefixes)
- Agent invokes script, gets clean result - no interpretation needed

### Use Workflows (Markdown) When:

| Scenario | Why Workflows? |
|----------|----------------|
| Simple CLI commands | `git checkout`, `npm install` - no script needed |
| Decision trees | "If X, do Y; if Z, do W" - markdown is clearer |
| User guidance | Instructions requiring human judgment |
| Documentation | API reference, troubleshooting guides |
| Routing | "For issue creation, use scripts/create-issue.sh" |

### Pattern: Script-Backed Skills

The recommended pattern for skills with bash operations:

```
skills/my-skill/
├── SKILL.md              # Router with "Available Scripts" table
├── scripts/
│   ├── operation-1.sh    # Standalone executable
│   └── operation-2.sh
└── workflows/
    ├── operation-1.md    # Routes to script, documents options
    └── troubleshoot.md   # Pure documentation
```

### Script Template

All scripts should follow this pattern:

```bash
#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

show_help() {
    echo "Usage: script.sh [options]"
    # ...
}

# Parse args, validate, execute...

echo -e "${GREEN}SUCCESS: Operation complete${NC}"
```

See `docs/skill-creation-guide.md` for the full pattern.

---

## Core Skills (Custom)

| Skill | File | Description |
|-------|------|-------------|
| `/prd` | `~/.claude/commands/prd.md` | Generate PRDs for Ralph |
| `/critique-waves` | `~/.claude/commands/critique-waves.md` | Multi-agent consensus verification |

## Superpowers Skills (via Plugin)

Requires the [Superpowers plugin](https://github.com/obra/superpowers).

| Skill | When to Use |
|-------|-------------|
| `superpowers:brainstorming` | Before creative work, exploring requirements |
| `superpowers:systematic-debugging` | When encountering bugs or test failures |
| `superpowers:test-driven-development` | Before implementing features |
| `superpowers:verification-before-completion` | Before claiming work is done |
| `superpowers:writing-plans` | When planning multi-step implementations |
| `superpowers:executing-plans` | When executing written plans |
| `superpowers:dispatching-parallel-agents` | For 2+ independent tasks |
| `superpowers:subagent-driven-development` | Multi-agent implementation |
| `superpowers:code-reviewer` | After completing major features |
| `superpowers:using-git-worktrees` | For isolated feature work |

## /critique-waves (Multi-Agent Consensus)

For critical verification, use multi-agent consensus. This spawns multiple agents to verify the same criteria — if any disagree, the issue is flagged.

### When to Use

- Story splitting decisions (is this too big?)
- RTL layout verification
- Design comparison verification
- Critical bug fixes

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Wave 1: 3 agents verify in parallel                        │
│    Agent 1: PASS                                            │
│    Agent 2: FAIL (found forbidden pattern)                  │
│    Agent 3: PASS                                            │
│  Result: 0 consecutive passes (reset due to failure)        │
│                                                             │
│  Fix the issue...                                           │
│                                                             │
│  Wave 2: 3 agents verify in parallel                        │
│    All PASS → 3 consecutive passes                          │
│                                                             │
│  ...continue until 20 consecutive passes...                 │
└─────────────────────────────────────────────────────────────┘
```

### Setup

```bash
cp ~/.config/claude-golem/skills/critique-waves.md ~/.claude/commands/critique-waves.md
```
