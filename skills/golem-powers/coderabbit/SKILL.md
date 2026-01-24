---
name: coderabbit
description: CodeRabbit - AI Code Review
execute: scripts/review.sh
---

# CodeRabbit - AI Code Review

Fast AI code reviews via CodeRabbit CLI. Free for open source.

## Allowed Repositories

This skill is only available for:
- **claude-golem** (ralphtools)
- **songscript**

Before using, verify you're in an allowed repo:
```bash
basename $(git rev-parse --show-toplevel 2>/dev/null)
# Must be: claude-golem, ralphtools, or songscript
```

## Quick Commands

```bash
cr review --plain           # Human-readable review
cr review --prompt-only     # For AI agents (minimal tokens)
cr review --type uncommitted # Only unstaged changes
cr review --base main       # Compare against main branch
```

## Workflows

| Workflow | Use Case |
|----------|----------|
| [review](workflows/review.md) | Standard code review |
| [verify](workflows/verify.md) | Quick verification for Ralph V-* stories |
| [security](workflows/security.md) | Security-focused review |
| [accessibility](workflows/accessibility.md) | A11y audit for UI changes |
| [secrets](workflows/secrets.md) | Scan for hardcoded secrets/keys |
| [pr-ready](workflows/pr-ready.md) | Pre-PR comprehensive check |

## Output Modes

| Flag | Best For | Token Usage |
|------|----------|-------------|
| `--plain` | Humans reading in terminal | High |
| `--prompt-only` | AI agents (Ralph, Claude) | Low |
| (default) | Interactive TUI | N/A |

## Integration with Ralph

For V-* verification stories, CodeRabbit runs FIRST as a fast pre-check:

1. `cr review --prompt-only --type committed` - Quick scan
2. If issues found → Fix before Claude verification
3. If clean → Proceed to full Claude verification

This reduces Claude API costs and catches obvious issues fast.

## Configuration

Optional `.coderabbit.yaml` in repo root for custom rules:

```yaml
reviews:
  language: en
  path_filters:
    - "!**/*.test.ts"
    - "!**/node_modules/**"
```

## Requirements

- CodeRabbit CLI installed: `curl -fsSL https://cli.coderabbit.ai/install.sh | sh`
- Authenticated: `cr auth login`
- Must run from git repository root
