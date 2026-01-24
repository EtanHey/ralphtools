---
sidebar_position: 1
title: Skill Creation Guide
---

# Skill Creation Guide: Progressive Disclosure Architecture

> **Purpose:** This guide teaches how to create Claude Code skills that minimize context consumption while maximizing capability. Skills should replace MCPs where possible for better scalability.

## Why Skills Over MCPs?

| Aspect | MCP | Skills |
|--------|-----|--------|
| **Context Load** | All tools loaded at startup (~1000+ tokens each) | Progressive: ~100 tokens metadata, rest on-demand |
| **Scalability** | 2-3 MCPs max before accuracy drops | Effectively unlimited skills |
| **Portability** | Requires server infrastructure | Just markdown files |
| **Execution** | Real-time API calls | Scripts execute without loading code into context |

**Rule of Thumb:**
- **Use MCP** for: Real-time external API connectivity you don't control
- **Use Skills** for: Procedural knowledge, workflows, CLI tool wrappers, domain expertise

## Progressive Disclosure: The Core Pattern

### Three-Tier Loading Model

```
┌─────────────────────────────────────────────────────────────┐
│  TIER 1: Metadata (ALWAYS loaded)         ~100 tokens      │
│  ├── name: skill-name                                       │
│  └── description: When to use this skill...                │
├─────────────────────────────────────────────────────────────┤
│  TIER 2: SKILL.md body (loaded when triggered)  <500 lines │
│  ├── Decision router / workflow selector                    │
│  └── Pointers to detailed files                            │
├─────────────────────────────────────────────────────────────┤
│  TIER 3: Reference files (loaded as needed)    unlimited   │
│  ├── workflows/*.md - Step-by-step procedures              │
│  ├── reference/*.md - API docs, schemas                    │
│  └── scripts/*.sh   - Executed, never loaded into context  │
└─────────────────────────────────────────────────────────────┘
```

### Context Budget Impact

| Approach | Tokens Before Work | % of 200k Context |
|----------|-------------------|-------------------|
| Bloated SKILL.md (2000 lines) | ~15,000 | 7.5% |
| Minimal router (50 lines) | ~500 | 0.25% |
| **Savings** | **14,500 tokens** | **~100 extra conversation turns** |

## Directory Structure

### Simple Skill (single file)
```
~/.claude/commands/
└── my-skill.md
```

### Complex Skill (progressive disclosure)
```
~/.claude/commands/my-skill/
├── SKILL.md              # Router only (~50-150 lines)
├── workflows/
│   ├── create.md         # "How to create X"
│   ├── update.md         # "How to update X"
│   └── troubleshoot.md   # "When things go wrong"
├── reference/
│   ├── api.md            # API documentation
│   └── examples.md       # Code examples
└── scripts/
    ├── validate.sh       # Validation script
    └── execute.sh        # Main execution script
```

## SKILL.md Structure

### Required: YAML Frontmatter

```yaml
---
name: skill-name
description: Third-person description of WHEN to use this skill. Include trigger keywords users might say.
---
```

**Frontmatter Rules:**
- `name`: lowercase, hyphens only, max 64 chars, no "claude" or "anthropic"
- `description`: max 1024 chars, third person, NO workflow summary

### Bad vs Good Descriptions

```yaml
# BAD: Summarizes workflow (Claude may follow description, skip body)
description: Commits code by staging files, writing message, and pushing to remote

# BAD: First person
description: I help you commit code to GitHub

# BAD: Too vague
description: Git helper

# GOOD: Trigger conditions only, third person
description: Use when committing code, creating PRs, managing issues, or any git/GitHub operations. Wraps gh CLI.
```

### SKILL.md Body: Router Pattern

```markdown
# Skill Name

## Quick Actions

**Creating something?** → See [workflows/create.md](workflows/create.md)
**Updating something?** → See [workflows/update.md](workflows/update.md)
**Something broken?** → See [workflows/troubleshoot.md](workflows/troubleshoot.md)

## Available Scripts

Run these directly - they handle errors and edge cases:

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/validate.sh` | Check prerequisites | `bash scripts/validate.sh` |
| `scripts/execute.sh` | Main operation | `bash scripts/execute.sh <args>` |
```

**Key Principle:** SKILL.md tells Claude WHERE to look, not HOW to do things.

## Workflow Files: Imperative Instructions

Workflow files tell Claude exactly what to DO. They are loaded only when needed.

### Structure

```markdown
# [Action] Workflow

## Prerequisites
- [ ] Condition 1 verified
- [ ] Condition 2 verified

## Steps

### Step 1: [Action verb]

Run:
```bash
command --with-flags
```

Expected output: [description]

If error: [what to do]

### Step 2: [Action verb]

Run:
```bash
next-command
```

### Step 3: Verify

Run:
```bash
verification-command
```

Success looks like: [description]

## Troubleshooting

**Error: [specific error]**
→ [specific fix]
```

### Bad vs Good Workflow Instructions

```markdown
# BAD: Passive reference (Claude doesn't know to execute)
You can use `gh issue create` to create issues.
The --title flag sets the title.
The --body flag sets the body.

# GOOD: Imperative instruction (Claude knows to act)
## Create an Issue

1. Run:
   ```bash
   gh issue create --title "$TITLE" --body "$BODY" --label "$LABELS"
   ```

2. Verify creation:
   ```bash
   gh issue view --json number,url
   ```

3. Report the issue URL to the user.
```

## Scripts: Deterministic Execution

Scripts execute WITHOUT loading code into context. Only output enters the conversation.

### Script Best Practices

```bash
#!/bin/bash
# scripts/smart-commit.sh
# Purpose: Stage, commit, and optionally push with co-author

set -e  # Exit on error

# Handle errors explicitly - don't punt to Claude
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

# Validate inputs
if [ -z "$1" ]; then
    echo "ERROR: Commit message required"
    echo "Usage: smart-commit.sh <message> [--push]"
    exit 1
fi

MESSAGE="$1"
SHOULD_PUSH="${2:-}"

# Stage changes (specific files preferred, but default to all for convenience)
git add -A

# Check if there are changes
if git diff --cached --quiet; then
    echo "INFO: No changes to commit"
    exit 0
fi

# Commit with co-author
git commit -m "$MESSAGE

Co-Authored-By: Claude <noreply@anthropic.com>"

# Optionally push
if [ "$SHOULD_PUSH" = "--push" ]; then
    git push
    echo "SUCCESS: Committed and pushed"
else
    echo "SUCCESS: Committed (not pushed)"
fi

# Return useful info
git log -1 --oneline
```

### Why Scripts > Generated Code

| Aspect | Generated Code | Pre-written Scripts |
|--------|---------------|---------------------|
| Reliability | May have bugs | Tested and proven |
| Token cost | Code enters context | Only output enters context |
| Speed | Generation time | Instant execution |
| Error handling | Often missing | Built-in |

## Checklist: Before Deploying a Skill

### Metadata
- [ ] `name` is lowercase with hyphens only
- [ ] `description` starts with "Use when..."
- [ ] `description` includes trigger keywords
- [ ] `description` is third person
- [ ] `description` does NOT summarize the workflow

### Structure
- [ ] SKILL.md body < 500 lines
- [ ] SKILL.md routes to workflow files (doesn't contain procedures)
- [ ] Workflow files use imperative language ("Run:", "Verify:")
- [ ] Scripts handle errors explicitly
- [ ] No deeply nested file references (max 1 level from SKILL.md)

### Context Efficiency
- [ ] Reference docs split by domain/use-case
- [ ] Large API docs in separate files
- [ ] Code examples in scripts, not inline
- [ ] Mutually exclusive content in separate files

### Testing
- [ ] Tested with direct invocation (`/skill-name`)
- [ ] Tested with natural language trigger
- [ ] Verified Claude executes (not just reads) instructions
- [ ] Confirmed correct workflow file loads for each use case

## Example: Minimal GitHub Skill

### ~/.claude/commands/github/SKILL.md

```yaml
---
name: github
description: Use when committing, pushing, creating PRs, managing issues, or any git/GitHub CLI operations. Wraps gh and git commands.
---
```

```markdown
# GitHub Operations

## Quick Reference

| Task | Workflow |
|------|----------|
| Commit changes | [workflows/commits.md](workflows/commits.md) |
| Create/view issues | [workflows/issues.md](workflows/issues.md) |
| Create/merge PRs | [workflows/pull-requests.md](workflows/pull-requests.md) |
| Auth problems | [workflows/troubleshooting.md](workflows/troubleshooting.md) |

## Prerequisites

Verify before any operation:
```bash
gh auth status
```

If "Bad credentials" → Run troubleshooting workflow
```

**Total: ~40 lines, ~400 tokens**

## References

- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Agent Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
