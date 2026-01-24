---
sidebar_position: 2
title: CLAUDE.md Layering
---

# CLAUDE.md Layering System

Claude Code reads CLAUDE.md files from multiple locations, merging them into a unified instruction set. This document defines the hierarchy and what belongs at each level.

## Three-Tier Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│  1. GLOBAL LAYER (~/.claude/CLAUDE.md)                          │
│     User-wide preferences that apply to ALL projects            │
├─────────────────────────────────────────────────────────────────┤
│  2. PROJECT LAYER (project/CLAUDE.md)                           │
│     Project-specific rules, tooling, and patterns               │
├─────────────────────────────────────────────────────────────────┤
│  3. PERSONAL LAYER (optional: project/.claude/CLAUDE.md)        │
│     User-specific overrides for shared projects (gitignored)    │
└─────────────────────────────────────────────────────────────────┘
```

**Priority Order:** Personal > Project > Global

Later layers can override earlier ones. If both global and project define commit rules, project wins.

## Layer 1: Global (~/.claude/CLAUDE.md)

**Location:** `~/.claude/CLAUDE.md`
**Purpose:** User-wide preferences that apply everywhere

### What Belongs Here

| Category | Examples |
|----------|----------|
| **Tool Preferences** | Browser choice (Brave/Chrome), terminal app |
| **Commit Rules** | "Never push without asking", "Never auto-commit" |
| **Python Version** | `python3` not `python` |
| **Global Patterns** | Multi-agent verification workflow, data extraction patterns |
| **MCP Tool Usage** | Tempmail rate limiting, usage tracking files |
| **Cross-Project Skills** | `/prd` for PRD work, `/1password` for secrets |
| **Learnings Locations** | Where to store global vs project learnings |

### What Does NOT Belong Here

- Project-specific paths or file structures
- Team coding standards (put in project CLAUDE.md)
- Repo-specific tooling (npm vs bun, etc.)

## Layer 2: Project (project/CLAUDE.md)

**Location:** `<project-root>/CLAUDE.md`
**Purpose:** Project-specific rules and context

### What Belongs Here

| Category | Examples |
|----------|----------|
| **Project Structure** | File locations, directory conventions |
| **Tooling** | Package manager (npm/bun/pnpm), test runner |
| **Coding Standards** | Naming conventions, architecture patterns |
| **Execution Modes** | Ralph vs Interactive Claude detection |
| **Project Skills** | Custom skills specific to this project |
| **Active Tasks** | Where to find current work (PRD, scratchpad) |
| **Testing** | How to run tests, pre-commit hooks |
| **Versioning** | Release rules, changelog requirements |

### What Does NOT Belong Here

- Personal preferences (use global or personal layer)
- Sensitive information (API keys, secrets)
- Machine-specific paths (use environment variables)

## Layer 3: Personal (project/.claude/CLAUDE.md)

**Location:** `<project-root>/.claude/CLAUDE.md`
**Purpose:** User-specific overrides for shared projects

### When to Use

- Team projects where you have different preferences
- Override team commit rules for your workflow
- Personal tooling that shouldn't affect others

### Example Use Cases

```markdown
# My Personal Overrides

## Commit Rules
I prefer to batch commits - override the "commit after each change" rule.

## Browser
Use Safari instead of team's Chrome preference.
```

:::important
Add `.claude/` to `.gitignore` to keep personal overrides out of version control.
:::

## How Claude Merges Layers

Claude reads all available CLAUDE.md files and combines them:

1. **Global** is read first (baseline)
2. **Project** is layered on top (adds/overrides)
3. **Personal** is layered last (final overrides)

### Merge Rules

| Scenario | Result |
|----------|--------|
| Only global defines X | Global's X is used |
| Project overrides global's X | Project's X is used |
| Personal overrides project's X | Personal's X is used |
| Sections don't overlap | All sections are included |

### Conflict Resolution

Later layers win. If global says "always commit" and project says "never auto-commit", project wins.

**Best Practice:** Don't contradict between layers. Use personal layer sparingly for true personal preferences.

## Skill Pointers

Include these pointers in your global CLAUDE.md to ensure Claude uses the right skills:

### PRD Management
```markdown
### When Working with PRDs or Ralph:
**Use `/prd` skill** for:
- Creating new PRDs
- Adding stories to existing PRDs
- Story JSON format (criteria objects, file locations)
- The update.json pattern for safe story additions
```

### Secrets Management
```markdown
### When Working with Secrets:
**Use `/1password` skill** for:
- Setting up 1Password Environments (PREFERRED)
- Migrating .env files to 1Password
- Retrieving secrets for CI/CD
- MCP config secret scanning
```

## Templates

### Global Layer Template

```markdown
# Claude Global Instructions

---

## Tool Preferences

- **Browser:** Brave (NOT Chrome or Safari)
- **Python:** Use `python3`, not `python`

---

## Commit Rules

- NEVER push without explicit permission
- NEVER auto-commit unless explicitly told
- Ask before any commit in interactive sessions

---

## Skill Pointers

### PRD Work
Use `/prd` skill for creating and managing PRDs.

### Secrets
Use `/1password` skill for secrets management.

---

## Global Patterns

### Learnings Locations
- **Project-Level:** `docs.local/learnings/` (gitignored)
- **Global:** `~/.claude/learnings/`
```

### Project Layer Template

```markdown
# Project: <project-name>

<one-line description>

---

## Project Structure

| Path | Purpose |
|------|---------|
| `src/` | Source code |
| `tests/` | Test files |
| `docs/` | Documentation |

---

## Tooling

- **Package Manager:** bun/npm/pnpm
- **Test Runner:** vitest/jest/pytest
- **Linter:** eslint/prettier

---

## Active Tasks

**Check after context reset:**
- `docs.local/current-task.md` - if exists, resume
- `claude.scratchpad.md` - ongoing work notes

---

## Testing

```bash
bun test        # Run all tests
bun lint        # Run linter
```

---

## Project-Specific Rules

(any rules unique to this project)
```

## Quick Reference

| Layer | Location | Scope | Versioned? |
|-------|----------|-------|------------|
| Global | `~/.claude/CLAUDE.md` | All projects | No (local) |
| Project | `project/CLAUDE.md` | One project | Yes (shared) |
| Personal | `project/.claude/CLAUDE.md` | One project, one user | No (gitignored) |

## See Also

- [Skills Reference](../skills.md) - Available skills
- [Configuration](../configuration.md) - Environment setup
