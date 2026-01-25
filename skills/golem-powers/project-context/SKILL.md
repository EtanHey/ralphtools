---
name: project-context
description: Use at session start or when unsure what tools are available. Auto-detects project stack and shows relevant skills. Covers project detection, what skills, available tools. NOT for: mid-session skill lookup (use /skills), invoking specific skills (call them directly).
user-invocable: true
disable-model-invocation: false
---

# Project Context (Auto-Detected)

This skill auto-detects your project's tools and tells you which skills are available.

## Detected Environment

!`~/.claude/commands/golem-powers/project-context/scripts/detect.sh 2>/dev/null || echo "Detection script not found"`

## Universal Skills (Always Available)

| Skill | When to Use |
|-------|-------------|
| `/golem-powers:ralph-commit` | For "Commit:" criteria - atomic commit + criterion check |
| `/golem-powers:coderabbit` | Code review before commits (iterate until clean) |
| `/golem-powers:context7` | Look up library docs when unsure about APIs |
| `/golem-powers:github` | Git operations, PRs, issues |
| `/golem-powers:create-pr` | Push branch and create PR |
| `/golem-powers:catchup` | Context recovery after long breaks |

## How to Use

1. **Check detected tools above** - See what's available in this project
2. **Use universal skills** - Always available regardless of project
3. **Use project-specific skills** - Only if detected above

Invoke any skill with `/golem-powers:skill-name` or read its SKILL.md for detailed workflows.
