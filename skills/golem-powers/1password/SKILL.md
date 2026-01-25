---
name: 1password
description: Use when managing secrets, credentials, API keys, or vault operations. Supports Environments (Beta) for .env mounting. Covers 1password, secrets, op, vault, migrate, credentials. NOT for: non-secret config (use regular config files).
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

## 🌟 PREFERRED: 1Password Environments (Beta)

**For .env file management, use 1Password Environments instead of manual CLI migration.**

[Official Docs →](https://developer.1password.com/docs/environments/) | [Full Workflow →](workflows/use-environment.md)

### Key Insight: UI Creation, CLI Access

**Environments are created in the 1Password desktop app UI - not via CLI.** However, once created, CLI tools can still interact with secrets via `op run` and `op inject`.

```
┌─────────────────────────────────────────────────────────────┐
│                    ENVIRONMENTS WORKFLOW                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  CREATION (UI Only)           ACCESS (Multiple Options)     │
│  ─────────────────            ─────────────────────────     │
│  1Password Desktop App   ──►  • Mounted .env (named pipe)   │
│  • Developer > Environments   • op run (env vars)           │
│  • NOT automatable            • op inject (config files)    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Why Environments?

- **Secrets never on disk** - Named pipe mount, not plaintext file
- **Real-time sync** - Changes in 1Password instantly available
- **Team sharing** - Grant access with granular permissions
- **Multi-device** - Same environment works across all your machines

### Setup Flow (One-Time in Desktop App)

1. **Enable Developer features** → Settings > Developer > Enable Developer Experience
2. **Create Environment** → Developer > Environments > New Environment
3. **Import your .env** → Click Import or manually add variables
4. **Set Mount Destination** → Destinations tab > Local .env file > Choose path
5. **Authorize** → Confirm when prompted

### Environments vs CLI: When to Use Each

| Scenario | Use Environments | Use CLI (`op run`/`op inject`) |
|----------|-----------------|-------------------------------|
| Local development | ✅ Best choice | Works but more setup |
| CI/CD pipelines | ❌ Can't automate creation | ✅ Service accounts |
| Team secrets | ✅ Built-in sharing | Manual sync needed |
| One-time scripts | Overkill | ✅ Quick and easy |
| Template configs | N/A | ✅ `op inject` with `.tpl` |

### Mounted .env vs op inject

**Mounted .env (Environments):**
```bash
# App reads .env.local directly (named pipe, no real file)
npm run dev
# Variables available automatically via dotenv
```

**op inject (CLI):**
```bash
# Template file with secret references (.env.template)
DATABASE_URL=op://prod/db/url
API_KEY=op://prod/api/key

# Inject at runtime
op inject -i .env.template -o .env && npm run build
# Remember to delete .env after!
```

**op run (CLI):**
```bash
# Pass secrets as environment variables
op run --env-file .env.template -- npm run build
# No temp file created, secrets in process env only
```

### Working Example: songscript

The `songscript` project uses Environments with 9 variables mounted to `.env.local`:
- Environment contains: `CONVEX_DEPLOY_KEY`, `ANTHROPIC_API_KEY`, etc.
- Destination: `.env.local` (named pipe, not actual file)
- Works seamlessly with `bun dev`, `npm run dev`, etc.

### Example: ralphtools Configuration

The `ralphtools` config could use Environments for sensitive settings:

1. **Create Environment** in 1Password: `ralphtools`
2. **Add variables**: `NTFY_TOPIC`, `ANTHROPIC_API_KEY`, `LINEAR_API_KEY`
3. **Mount to**: `~/.config/ralphtools/.env`
4. **Usage**: Scripts source the mounted file or use `op run`

```bash
# Option 1: Source mounted .env
source ~/.config/ralphtools/.env
ralph 10

# Option 2: Use op run with template
op run --env-file ~/.config/ralphtools/.env.template -- ralph 10
```

### Important Limitations (Beta)

| Limitation | Details |
|------------|---------|
| **UI-only creation** | Cannot create/edit environments via CLI |
| **Platform support** | Mac and Linux only (no Windows) |
| **Max mounts** | 10 enabled .env files per device |
| **Concurrent reads** | May have conflicts with multiple processes |
| **Edits in UI only** | Changes to mounted file are lost - edit in 1Password UI |
| **Beta status** | Feature may change |

### When to Use CLI Instead

Use `op run` or `op inject` ([workflows/migrate-env.md](workflows/migrate-env.md)) when:
- **CI/CD pipelines** - Need Service Accounts for automated access
- **Scripted operations** - Creating items programmatically
- **Template configs** - `.yml.tpl` or `.json.tpl` files with secret refs
- **Windows** - Environments not available on Windows

---

## Quick Actions

| What you want to do | Workflow |
|---------------------|----------|
| Use 1Password Environments | [workflows/use-environment.md](workflows/use-environment.md) |
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

**Setting up secrets for a project?**
- PREFERRED: Use Environments (desktop app UI)
- Use: [workflows/use-environment.md](workflows/use-environment.md)

**Need to find a secret?**
- Search by name, tag, or vault
- Use: [workflows/list-secrets.md](workflows/list-secrets.md)

**Adding credentials for a service?**
- Create new item with password/API key
- Use: [workflows/add-secret.md](workflows/add-secret.md)

**Have a .env file to secure?**
- For local dev: Use Environments (UI-based)
- For CI/CD: Use [workflows/migrate-env.md](workflows/migrate-env.md) or `scripts/migrate-env.sh`

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

## Vault Organization

### Vault Types

| Vault | Purpose | Example Items |
|-------|---------|---------------|
| `development` | Global dev tools | context7, github CLI tokens |
| `Private` | Personal secrets | SSH keys, personal accounts |
| `{project}` | Project-specific | linear API key, deploy keys |
| `Shared` | Team secrets | Shared service accounts |

### Creating Vaults

```bash
# Create project vault
op vault create "myproject" --description "MyProject secrets" --icon buildings

# Create tools vault
op vault create "development" --description "Global dev tools" --icon gears
```

### Where to Put Secrets

**Global dev tools** → `development` vault:
- context7, MCP tools, IDE plugins
- Used across all projects

**Project-specific** → `{project}` vault:
- Linear API keys (per workspace)
- Deploy keys, CI/CD tokens
- Database credentials

**Personal** → `Private` vault:
- SSH keys, personal tokens
- Accounts only you use

### Tagging Strategy

Use tags for cross-vault searching and organization:

```bash
# Add tags when creating
op item create --vault development --category "API Credential" \
  --title "context7" 'API_KEY[password]=xxx' \
  --tags "dev-tools,mcp,documentation"

# Search by tag across all vaults
op item list --tags "mcp"
op item list --tags "dev-tools"
```

**Recommended tags:**
| Tag | Use for |
|-----|---------|
| `dev-tools` | Development utilities |
| `mcp` | MCP server credentials |
| `ci-cd` | CI/CD pipeline secrets |
| `api-key` | Third-party API keys |
| `deploy` | Deployment credentials |
| `{project}` | Project name for filtering |

### Reference Format

```bash
# Vault/Item/Field
op://development/context7/API_KEY
op://myproject/linear/API_KEY
op://Private/github/token
```

---

## Safety Rules

1. **Never log secret values** - Only show masked versions
2. **Dry-run first** - Use `--dry-run` before actual migration
3. **Don't delete .env files** - Migration creates .env.template alongside
4. **Verify vault access** - Run `op vault list` before operations
5. **Backup before bulk changes** - Export vault if doing large migrations
