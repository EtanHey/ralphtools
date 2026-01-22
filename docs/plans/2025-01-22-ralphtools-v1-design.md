# ralphtools v1.0 Design

**Date:** 2025-01-22
**Status:** Draft
**Author:** Etan + Claude

---

## Overview

**ralphtools** is an autonomous coding loop that executes PRD stories using AI models. It spawns fresh Claude/Gemini/Kiro instances in a loop, each working on one story until all are complete.

### The Problem

Running AI coding agents manually is tedious:
- Start Claude, give it context, watch it work
- When it finishes one task, start again for the next
- Choose which model to use (cost vs quality tradeoff)
- Track progress across sessions

### The Solution

```bash
brew install ralphtools
ralph 50  # Run up to 50 iterations automatically
```

---

## Distribution

### Primary: Homebrew

```bash
brew tap etanheyman/ralphtools
brew install ralphtools
```

**Why Homebrew:**
- Ralph's audience (devs using Claude CLI) likely already uses Homebrew
- Doesn't add Node as a dependency (Ralph is zsh scripts)
- Feels native for a CLI tool
- Easy versioning and auto-updates via `brew upgrade`

### Package Structure

**Installed files:**
```
/opt/homebrew/bin/ralph                    # Main CLI entry point
/opt/homebrew/share/ralphtools/
  ├── ralph.zsh                            # Main loop logic
  ├── lib/
  │   ├── models.zsh                       # Model routing logic
  │   ├── config.zsh                       # Config loading
  │   ├── updates.zsh                      # Version checking
  │   └── notifications.zsh                # Notification hooks
  └── changelogs/
      ├── v1.0.0.md
      ├── v1.1.0.md
      └── ...
```

**User config:**
```
~/.config/ralphtools/
  ├── config.json                          # User preferences
  └── hooks/
      └── notify.sh                        # Replaceable notification function
```

---

## Feature 1: Smart Model Routing

### Task Type Detection

Ralph detects story type from the ID prefix:

| Prefix | Task Type | Description |
|--------|-----------|-------------|
| `US-*` | User Story | Feature implementation |
| `V-*` | Verification | Browser/visual verification |
| `TEST-*` | Testing | E2E test creation |
| `BUG-*` | Bug Fix | Debugging and fixes |
| `AUDIT-*` | Audit | Security/code review |

### Model Assignment

Based on research (see `docs.local/model-research/tracker.md`):

| Task Type | Default Model | Rationale |
|-----------|---------------|-----------|
| US | Sonnet | Balanced quality/speed for implementation |
| V | Haiku (parallel) | Fast verification, multiple passes catch more |
| TEST | Haiku | Fast iteration, test generation well-suited |
| BUG | Sonnet | Root cause analysis needs reasoning |
| AUDIT | Opus | Maximum thoroughness for security |

### Parallel Verification

For V-* stories, Ralph can spawn **multiple Haiku agents in parallel**:
- Agent 1: Desktop viewport verification
- Agent 2: Mobile viewport verification
- Agent 3: Accessibility checks

All must pass for verification to complete. This catches more issues at lower cost than one Opus pass.

### Model Strategy Config

Users choose between:

1. **single** - One model for everything (predictable costs)
2. **smart** - Task-based routing (optimized cost/quality)

```json
{
  "modelStrategy": "smart",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },
  "parallelVerification": true,
  "parallelAgents": 2
}
```

Or simple mode:

```json
{
  "modelStrategy": "single",
  "defaultModel": "opus"
}
```

---

## Feature 2: Quick Start Flow

### Inline Config on First Run

Like Next.js - pretty CLI prompts with arrow-key selection (using Node + clack/ink for setup only):

```
$ ralph

┌  ralphtools v1.0.0
│
◆  No config found. Quick setup:
│
◇  Model strategy?
│  ● Smart routing (different models per task type)
│  ○ Single model (one model for everything)
│
◇  Default model?
│  ○ Opus (highest quality, slowest)
│  ● Sonnet (balanced)
│  ○ Haiku (fastest, cheapest)
│
◇  Max iterations?
│  50 (enter to accept, or type number)
│
◇  Enable notifications?
│  ○ Yes (via ntfy.sh)
│  ● No
│
└  ✓ Config saved! Starting Ralph...

🚀 Starting Ralph - Max 50 iterations
```

User can arrow through options or just hit Enter repeatedly to accept defaults and start immediately.

### Skip Setup Entirely

```bash
ralph --skip-setup 50    # Use defaults, start immediately
ralph -y 50              # Same, short flag
```

### Reconfigure Anytime

```bash
ralph config             # Full interactive setup
ralph config --secrets   # Just secrets
ralph config --models    # Just model routing
ralph config --show      # Print current config
ralph config --reset     # Start fresh
```

---

## Feature 3: Interactive Config System

### Full Setup Experience

On `ralph config` (or first run without `--skip-setup`):

```
$ ralph 50

👋 Welcome to ralphtools!

Let me help you set up your configuration.

**Model Strategy**
Ralph can use different AI models for different task types to optimize
cost and quality. Or you can use one model for everything.

Which do you prefer?
  1. Smart routing (recommended) - Different models per task type
  2. Single model - One model for everything

> 1

Great! For smart routing, here are the defaults based on benchmarks:
  - US (User Stories): Sonnet - balanced quality/speed
  - V (Verification): Haiku parallel - fast, cheap, multiple passes
  - BUG (Bug fixes): Sonnet - needs reasoning for root cause
  - AUDIT (Security): Opus - maximum thoroughness

Accept these defaults? (y/n)
> y

**Notifications**
Want notifications when Ralph completes or hits blockers?
  1. Yes, via ntfy.sh
  2. No notifications

> 1

Enter your ntfy.sh topic name:
> etans-ralph

✅ Configuration saved to ~/.config/ralphtools/config.json

Starting Ralph...
```

### Config Command

Users can reconfigure anytime:

```bash
ralph config              # Interactive Claude-guided setup
ralph config --reset      # Start fresh
ralph config --show       # Print current config
```

---

## Feature 3: Post-Update Changelog Prompts

### Version Tracking

Ralph stores last-run version in config:

```json
{
  "lastVersion": "1.2.0",
  ...
}
```

### Update Detection

On each `ralph` run:
1. Compare installed version vs `lastVersion` in config
2. If different, show changelog and prompt

### Update Flow

```
$ ralph 50

📦 ralphtools updated: v1.2.0 → v1.3.0

What's new in v1.3.0:
━━━━━━━━━━━━━━━━━━━━━
• Smart model routing now supports Gemini 3 Flash
• New --preset flag for quick model profiles
• Bug fix: Notification hook now receives iteration count

This update has new config options. Configure now? (y/n)
> y

[Claude spawns to walk through new options]
```

If user says `n`, Ralph continues normally. They can run `ralph config` later.

### Changelog Files

Each version has a changelog in the package:

```markdown
<!-- changelogs/v1.3.0.md -->
# v1.3.0

## New Features
- Smart model routing now supports Gemini 3 Flash
- New `--preset` flag for quick model profiles
  - `--preset=budget` (all Haiku)
  - `--preset=balanced` (Sonnet main, Haiku verify)
  - `--preset=quality` (Opus main, Sonnet verify)

## Bug Fixes
- Notification hook now receives iteration count in metadata

## Config Changes
- New `models.TEST` option (defaults to "haiku")
- New `presets` section for custom presets
```

---

## Feature 4: Replaceable Notification Hooks

### Default: ntfy.sh

Out of the box, Ralph uses ntfy.sh for notifications:

```bash
curl -s -d "$message" "ntfy.sh/${topic}"
```

### Hook Interface

Notifications go through a function that users can replace:

```bash
# ~/.config/ralphtools/hooks/notify.sh

ralph_notify() {
  local event="$1"      # Event type
  local message="$2"    # Human-readable message
  local metadata="$3"   # JSON with details

  # Default implementation: ntfy.sh
  local topic=$(jq -r '.notifications.ntfyTopic' ~/.config/ralphtools/config.json)
  curl -s -d "$message" "ntfy.sh/${topic}" > /dev/null
}
```

### Event Types

| Event | When | Metadata |
|-------|------|----------|
| `iteration_complete` | After each iteration | `{story_id, iteration, remaining}` |
| `story_complete` | Story marked done | `{story_id, duration, model}` |
| `all_complete` | All stories done | `{total_iterations, duration}` |
| `blocked` | Story blocked | `{story_id, reason}` |
| `all_blocked` | All remaining blocked | `{blocked_stories: [...]}` |
| `error` | Crash/API error | `{error, retry_count}` |

### Custom Hook Example: Slack

```bash
# ~/.config/ralphtools/hooks/notify.sh

ralph_notify() {
  local event="$1"
  local message="$2"
  local metadata="$3"

  # Custom: Send to Slack
  curl -X POST "$SLACK_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"Ralph: $message\", \"metadata\": $metadata}"
}
```

### Custom Hook Example: macOS Native

```bash
ralph_notify() {
  local event="$1"
  local message="$2"

  # macOS notification center
  osascript -e "display notification \"$message\" with title \"Ralph\""
}
```

---

## Config File Schema

### Full Example

```json
{
  "$schema": "https://ralphtools.dev/schemas/config.schema.json",
  "version": "1.0.0",
  "lastVersion": "1.0.0",

  "modelStrategy": "smart",
  "defaultModel": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },

  "parallelVerification": true,
  "parallelAgents": 2,

  "notifications": {
    "enabled": true,
    "ntfyTopic": "etans-ralph",
    "events": ["all_complete", "all_blocked", "error"]
  },

  "defaults": {
    "maxIterations": 50,
    "sleepSeconds": 2
  }
}
```

### Minimal Example

```json
{
  "modelStrategy": "single",
  "defaultModel": "opus",
  "notifications": {
    "enabled": false
  }
}
```

---

## CLI Interface

### Commands

```bash
ralph [iterations] [flags]     # Run the loop
ralph config                   # Interactive config setup
ralph config --show            # Print current config
ralph config --reset           # Reset to defaults
ralph status                   # Show PRD progress
ralph live                     # Live-updating status
ralph stop                     # Kill running Ralph processes
ralph whatsnew                 # Show changelog for current version
ralph --version                # Print version
ralph --help                   # Show help
```

### Flags

```bash
# Model overrides (override config for this run)
-O, --opus                     # Force Opus for all
-S, --sonnet                   # Force Sonnet for all
-H, --haiku                    # Force Haiku for all
-G, --gemini                   # Use Gemini CLI

# Presets (shorthand for common configs)
--preset=budget                # All Haiku
--preset=balanced              # Sonnet main, Haiku verify
--preset=quality               # Opus main, Sonnet verify

# Notifications
-QN, --quiet-notify            # Enable quiet notifications
-VN, --verbose-notify          # Notify on every iteration

# Other
--dry-run                      # Show what would run, don't execute
--no-update-check              # Skip version check
```

---

## Rollout Phases

### Phase 0: Package Current Code (v0.1.0)
- Package existing ralph.zsh as Homebrew formula
- Get `brew install ralphtools` working
- No new features, just distribution
- **Success:** Can install and run Ralph via Homebrew

### Phase 1: Quick Start + Config System (v0.2.0)
- Pretty CLI prompts (Node + clack) for setup
- `~/.config/ralphtools/config.json`
- `ralph config` command
- First-run inline setup with skip option
- **Success:** Users can configure with arrow keys, or skip to defaults

### Phase 2: Smart Model Routing (v1.0.0)
- Implement task type detection
- Add model routing based on config
- Add `--preset` flags
- **Success:** V-* tasks use Haiku, US-* use Sonnet by default

### Phase 3: Update System (v1.1.0)
- Add version tracking
- Add changelog files
- Add post-update prompts
- **Success:** After `brew upgrade`, user sees what's new

### Phase 4: Notification Hooks (v1.2.0)
- Add replaceable notify function
- Add event types and metadata
- Document custom hook examples
- **Success:** Users can plug in Slack/Discord/custom

### Phase 5: Parallel Verification (v1.3.0)
- Implement parallel Haiku agents for V-* stories
- Add `parallelAgents` config
- Aggregate results from parallel runs
- **Success:** V-* stories run 2-3 agents in parallel

### Phase 6: Project Launchers (v1.4.0)
- `ralph projects add/remove/list`
- Auto-generate `runProject`, `openProject`, `ralphProject` functions
- Per-project MCP configuration
- Replace repo-claude-v2.zsh functionality
- **Success:** `runUnion`, `openDomica` etc. work with proper MCPs

### Phase 7: 1Password Integration (v1.5.0)
- `ralph secrets migrate .env` - convert to 1Password
- `.env.template` with `op://` references
- Optional 1Password for secrets (file-based default)
- Auto-generate CLAUDE.md docs for projects
- **Success:** Projects run with secrets from 1Password, no plaintext .env

---

## CI/CD & Code Quality

### CodeRabbit (Free for Open Source)

Add [CodeRabbit](https://github.com/marketplace/coderabbitai) for AI-powered code reviews on PRs:

1. Install from GitHub Marketplace (free for public repos)
2. Add `.coderabbit.yaml` to repo root:

```yaml
# .coderabbit.yaml
language: en
reviews:
  profile: assertive
  request_changes_workflow: true
  high_level_summary: true
  poem: false
  review_status: true
  collapse_walkthrough: false
  auto_review:
    enabled: true
    drafts: false
chat:
  auto_reply: true
```

**Benefits:**
- Automatic PR reviews catch issues before merge
- Free for open source
- Learns project patterns over time

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: zsh tests/test-ralph.zsh

  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update Homebrew tap
        run: ./scripts/update-homebrew-tap.sh
```

---

## Security: Separating Sensitive Data

**CRITICAL:** Current `~/.config/ralph/` contains sensitive tokens that must NOT be open sourced:
- Supabase tokens (`sbp_...`)
- Linear API keys (`lin_api_...`)
- Tempmail API keys
- ntfy topics (personal)

### Strategy: Keep Secrets Local

**Open source repo (ralphtools):**
- Core ralph.zsh logic
- Config schema (what fields exist)
- Example config with placeholders
- No actual tokens

**Local only (never committed):**
- `~/.config/ralphtools/config.json` - user's actual config with tokens
- `~/.config/ralphtools/hooks/` - custom hooks
- `.env` files with secrets

### Files to Exclude

```gitignore
# .gitignore for ralphtools repo
config.json
*.local
.env*
hooks/
ralph-config.local

# Example files ARE committed
config.example.json
hooks.example/
```

### repo-claude-v2.zsh Tokens

The `SUPABASE_TOKENS` and `LINEAR_TOKENS` in `repo-claude-v2.zsh` are **your personal tokens**. For open source:

1. Move token definitions to `~/.config/ralphtools/secrets.local` (gitignored)
2. Source secrets file if it exists
3. Open source version has empty placeholder arrays

```zsh
# In open source ralph.zsh
typeset -A SUPABASE_TOKENS
typeset -A LINEAR_TOKENS

# Load user's secrets if they exist
[[ -f "$RALPH_CONFIG_DIR/secrets.local" ]] && source "$RALPH_CONFIG_DIR/secrets.local"
```

```zsh
# ~/.config/ralphtools/secrets.local (gitignored, user creates)
SUPABASE_TOKENS=(
  [myproject]="sbp_xxx"
)
LINEAR_TOKENS=(
  [myproject]="lin_api_xxx"
)
```

### Option B: 1Password Integration (Optional)

For users with 1Password - secrets live in vault, injected at runtime. Not required.

**CLI Onboarding:** If user selects 1Password during `ralph config`, the CLI should:
1. Check if `op` CLI is installed, if not guide through `brew install 1password-cli`
2. Check if signed in, if not guide through `op account add` and `eval $(op signin)`
3. Help create vault structure with prompts
4. Test connection before completing setup

This ensures flawless 1Password setup for users who choose it.

### 1Password for MCP Server Credentials

**Reference:** https://1password.com/blog/securing-mcp-servers-with-1password-stop-credential-exposure-in-your-agent

Instead of hardcoding MCP credentials in Claude's config:

```json
// BAD: Hardcoded in ~/.claude.json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase", "--access-token", "sbp_xxx"]
    }
  }
}
```

Use 1Password secret references:

```json
// GOOD: 1Password reference
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase", "--access-token", "op://vault/supabase/token"]
    },
    "linear": {
      "env": {
        "LINEAR_API_TOKEN": "op://vault/linear/api-token"
      }
    }
  }
}
```

Then run Claude with `op run` to inject secrets:

```bash
op run -- claude
```

**Benefits:**
- No credentials in config files (safe to commit)
- Single source of truth in 1Password
- Touch ID/biometric auth
- Audit trail of credential access
- Works for ALL MCP servers (Supabase, Linear, Figma, etc.)

**Ralph integration:**
- `ralph config` can help set up MCP credentials in 1Password
- Generate `.claude.json` with `op://` references
- Wrap claude calls with `op run --` automatically

**Setup:**
1. Install 1Password CLI: `brew install 1password-cli`
2. Create a vault item "ralphtools" with fields for each token
3. Configure ralph to pull from 1Password

**In config.json:**
```json
{
  "secrets": {
    "provider": "1password",
    "vault": "Development",
    "item": "ralphtools"
  }
}
```

**Ralph loads secrets via `op`:**
```zsh
# In ralph.zsh
_ralph_load_secrets() {
  local provider=$(jq -r '.secrets.provider // "file"' "$RALPH_CONFIG")

  case "$provider" in
    1password)
      local vault=$(jq -r '.secrets.vault' "$RALPH_CONFIG")
      local item=$(jq -r '.secrets.item' "$RALPH_CONFIG")

      # Load each secret from 1Password
      SUPABASE_TOKENS[domica]=$(op read "op://$vault/$item/supabase-domica" 2>/dev/null)
      SUPABASE_TOKENS[union]=$(op read "op://$vault/$item/supabase-union" 2>/dev/null)
      LINEAR_TOKENS[domica]=$(op read "op://$vault/$item/linear-domica" 2>/dev/null)
      LINEAR_TOKENS[union]=$(op read "op://$vault/$item/linear-union" 2>/dev/null)
      ;;
    file)
      [[ -f "$RALPH_CONFIG_DIR/secrets.local" ]] && source "$RALPH_CONFIG_DIR/secrets.local"
      ;;
  esac
}
```

**Benefits:**
- No secrets on disk
- 1Password handles encryption, sync, access control
- Touch ID / biometric unlock
- Audit trail of secret access
- Works across machines automatically

**1Password Item Structure:**
```
Item: ralphtools (in "Development" vault)
├── supabase-domica: sbp_1bb193...
├── supabase-union: sbp_fac649...
├── linear-domica: lin_api_nfKne...
├── linear-union: lin_api_TOEZbe...
├── tempmail-api-key: mk_L5sEK7...
└── ntfy-topic: etans-ralph
```

---

## Feature 6: Project Launchers (repoClaude replacement)

### The Problem

Currently `repo-claude-v2.zsh` has hardcoded project configs with tokens. We want:
1. Per-project launch commands (`runUnion`, `openDomica`)
2. Secrets pulled from 1Password (or local file)
3. Auto-configure MCPs per project

### Project Registry

In `~/.config/ralphtools/projects.json`:

```json
{
  "projects": {
    "union": {
      "path": "~/Desktop/Gits/union",
      "displayName": "Union",
      "codename": "cantaloupe",
      "mcps": ["Context7", "linear", "supabase", "browser-tools", "figma"],
      "secrets": {
        "vault": "cantaloupe",
        "supabase": "supabase-token",
        "linear": "linear-token"
      }
    },
    "domica": {
      "path": "~/Desktop/Gits/domica",
      "displayName": "Domica",
      "mcps": ["Context7", "linear", "supabase", "browser-tools", "figma"],
      "secrets": {
        "vault": "domica",
        "supabase": "supabase-token",
        "linear": "linear-token"
      }
    },
    "songscript": {
      "path": "~/Desktop/Gits/songscript",
      "displayName": "SongScript",
      "mcps": ["Context7", "tempmail"],
      "secrets": null
    }
  }
}
```

### Generated Commands

Ralph generates shell functions for each project:

```bash
# Auto-generated in ~/.config/ralphtools/projects.sh (sourced in .zshrc)

runUnion() {
  cd ~/Desktop/Gits/union || return 1
  _ralph_setup_mcps "union"
  op run --env-file .env.template -- claude "$@"
}

openUnion() {
  cd ~/Desktop/Gits/union || return 1
  code .
  runUnion
}

ralphUnion() {
  cd ~/Desktop/Gits/union || return 1
  _ralph_setup_mcps "union"
  ralph "$@"
}

# Same pattern for domica, songscript, etc.
```

### Add/Remove Projects

```bash
ralph projects add union ~/Desktop/Gits/union
ralph projects remove union
ralph projects list
ralph projects regenerate   # Rebuild projects.sh
```

---

## Feature 7: 1Password .env Automation

### The Pattern

Instead of storing secrets in plaintext `.env` files, use `.env.template` with secret references:

```bash
# .env.template (committed to git - safe!)
DATABASE_URL=op://cantaloupe/supabase/connection-string
SUPABASE_KEY=op://cantaloupe/supabase/anon-key
LINEAR_TOKEN=op://cantaloupe/linear/api-token
```

```bash
# Run with secrets injected (never touch disk)
op run --env-file .env.template -- npm run dev
```

### Auto-Convert Existing .env Files

**Important:** This is a guided process, not just a script, because secrets are sensitive.

Ralph walks through each `.env` file interactively:

```bash
ralph secrets migrate .env

┌  Migrating .env to 1Password
│
◇  Found 5 secrets in .env
│  DATABASE_URL=postgres://...
│  SUPABASE_KEY=sbp_...
│  LINEAR_TOKEN=lin_api_...
│  API_SECRET=sk_...
│  DEBUG=true (skipped - not a secret)
│
◇  Which vault?
│  ● cantaloupe (existing)
│  ○ Create new vault
│
◇  Item name?
│  union-env
│
└  ✓ Created op://cantaloupe/union-env with 4 secrets
   ✓ Generated .env.template with secret references
   ✓ Added .env to .gitignore

Your .env.template:
  DATABASE_URL=op://cantaloupe/union-env/DATABASE_URL
  SUPABASE_KEY=op://cantaloupe/union-env/SUPABASE_KEY
  LINEAR_TOKEN=op://cantaloupe/union-env/LINEAR_TOKEN
  DEBUG=true
```

### Calling Different .env Files

Each project can have multiple .env templates for different environments:

```
myproject/
├── .env.template           # Default/development
├── .env.staging.template   # Staging environment
├── .env.production.template # Production
```

**Usage:**
```bash
# Development (default)
op run --env-file .env.template -- npm run dev

# Staging
op run --env-file .env.staging.template -- npm run build

# Production (careful!)
op run --env-file .env.production.template -- npm run deploy
```

The templates can reference different 1Password vaults/items:
```bash
# .env.template (dev)
DATABASE_URL=op://dev-vault/myproject/database-url

# .env.production.template
DATABASE_URL=op://prod-vault/myproject/database-url
```

### Per-Repo Run Functions

Each project can have a `run` function that uses its `.env.template`:

```bash
# In project's package.json scripts or Makefile
"dev": "op run --env-file .env.template -- next dev"

# Or Ralph generates wrapper
runUnion() {
  cd ~/Desktop/Gits/union
  op run --env-file .env.template -- "$@"
}

# Usage
runUnion npm run dev
runUnion bun dev
```

### Claude Awareness

Add to project's `CLAUDE.md`:

```markdown
## Running This Project

This project uses 1Password for secrets. To run:

\`\`\`bash
runUnion npm run dev        # Uses op run with .env.template
# OR
op run --env-file .env.template -- npm run dev
\`\`\`

Never create plaintext .env files. Use .env.template with op:// references.
```

Ralph can auto-generate this section when setting up a project:

```bash
ralph projects setup union --with-claude-docs
```

---

## Open Questions

1. **Gemini/Kiro support** - Should config allow specifying these as model options?
2. **Cost tracking** - Should Ralph estimate/track costs per session?
3. **Remote sync** - Should config sync across machines?
4. **Project-level config** - Allow `.ralphtools.json` in project root to override global?
5. **Monorepo support** - Handle apps/expo, apps/public style structures?

---

## Success Metrics

- **Distribution:** >10 installs via Homebrew in first month
- **Cost savings:** Users report ~40% cost reduction with smart routing
- **Config adoption:** >80% of users run `ralph config` on first use
- **Update engagement:** >50% of users interact with post-update prompts

---

## Appendix: Model Research Summary

From `docs.local/model-research/tracker.md`:

| Model | SWE-bench | Speed | Cost (M tokens) |
|-------|-----------|-------|-----------------|
| Claude Opus 4.5 | 80.9% | Slowest | $5 / $25 |
| Claude Sonnet 4.5 | 77.2% | Balanced | $3 / $15 |
| Claude Haiku 4.5 | 73.3% | 4-5x faster | $1 / $5 |
| Gemini 3 Flash | 78% | 3x faster | $0.50 / $3 |

**Key insight:** Haiku is 90% of Sonnet quality at 20% the cost. Perfect for V-* tasks.
