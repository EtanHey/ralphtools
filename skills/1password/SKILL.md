---
name: 1password
description: Use when managing secrets, credentials, API keys, or vault operations. Covers 1password, secrets, op, vault, migrate, credentials, mcp config secrets.
---

# 1Password Operations

> Secret management skill using 1Password CLI (`op`). Routes to workflows for specific operations.

## Prerequisites Check

Run first:
```bash
op account list
```

If "not signed in" or error: See [workflows/troubleshoot.md](workflows/troubleshoot.md)

---

## Quick Actions

| What you want to do | Workflow |
|---------------------|----------|
| List secrets in vault | [workflows/list-secrets.md](workflows/list-secrets.md) |
| Add a new secret | [workflows/add-secret.md](workflows/add-secret.md) |
| Migrate .env to 1Password | [workflows/migrate-env.md](workflows/migrate-env.md) |
| Migrate MCP config secrets | [workflows/migrate-mcp.md](workflows/migrate-mcp.md) |
| Fix auth/biometric issues | [workflows/troubleshoot.md](workflows/troubleshoot.md) |

---

## Available Scripts

Execute directly - they handle errors and edge cases:

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/migrate-env.sh` | Migrate .env with project/service nesting | `bash ~/.claude/commands/1password/scripts/migrate-env.sh .env [--dry-run]` |
| `scripts/scan-mcp-secrets.sh` | Find API keys in MCP configs | `bash ~/.claude/commands/1password/scripts/scan-mcp-secrets.sh` |

---

## Decision Tree

**Need to find a secret?**
- Search by name, tag, or vault
- Use: [workflows/list-secrets.md](workflows/list-secrets.md)

**Adding credentials for a service?**
- Create new item with password/API key
- Use: [workflows/add-secret.md](workflows/add-secret.md)

**Have a .env file to secure?**
- Auto-categorize by service (anthropic, supabase, etc.)
- Use: [workflows/migrate-env.md](workflows/migrate-env.md) or `scripts/migrate-env.sh`

**MCP configs have hardcoded keys?**
- Scan and migrate to 1Password references
- Use: [workflows/migrate-mcp.md](workflows/migrate-mcp.md)

**Biometric timeout or auth problems?**
- Token refresh, re-auth, session issues
- Use: [workflows/troubleshoot.md](workflows/troubleshoot.md)

---

## Service Auto-Detection

When migrating secrets, keys are auto-categorized:

| Key prefix | Service folder |
|------------|----------------|
| `ANTHROPIC_*` | anthropic/ |
| `OPENAI_*` | openai/ |
| `SUPABASE_*` | supabase/ |
| `DATABASE_*`, `DB_*` | db/ |
| `STRIPE_*` | stripe/ |
| `AWS_*` | aws/ |
| `GITHUB_*` | github/ |
| Other | misc/ |

Item path format: `{project}/{service}/{key}`

---

## Safety Rules

1. **Never log secret values** - Only show masked versions
2. **Dry-run first** - Use `--dry-run` before actual migration
3. **Don't delete .env files** - Migration creates .env.template alongside
4. **Verify vault access** - Run `op vault list` before operations
5. **Backup before bulk changes** - Export vault if doing large migrations
