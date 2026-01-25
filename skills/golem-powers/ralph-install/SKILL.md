---
name: ralph-install
description: Use when setting up Ralph/ralphtools for the first time. Checks dependencies, installs CLIs, configures 1Password tokens. Covers install ralph, setup ralph, dependencies. NOT for: daily Ralph usage (skills already installed).
---

# Ralph Install Wizard

> Guides new users through ralphtools setup. Checks for required CLIs, configures tokens in 1Password, sets up the golem-powers symlink, and validates everything works.

## Available Scripts

Run these directly - standalone setup and validation:

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/check-deps.sh` | Check dependencies | `bash ~/.claude/commands/golem-powers/ralph-install/scripts/check-deps.sh` |
| `scripts/install-deps.sh` | Install missing | `bash ~/.claude/commands/golem-powers/ralph-install/scripts/install-deps.sh --all` |
| `scripts/validate.sh` | Full validation | `bash ~/.claude/commands/golem-powers/ralph-install/scripts/validate.sh` |

---

## Quick Start

For a full installation, run through these workflows in order:

| Step | Workflow | Purpose |
|------|----------|---------|
| 1 | [check-deps](workflows/check-deps.md) | Verify required CLIs are installed (including Bun) |
| 2 | [install-deps](workflows/install-deps.md) | Install missing dependencies via brew (+ CodeRabbit via curl) |
| 3 | [setup-tokens](workflows/setup-tokens.md) | Configure API tokens in 1Password (claude-golem item) |
| 4 | [setup-symlinks](workflows/setup-symlinks.md) | Create golem-powers symlink, remove old symlinks |
| 5 | [validate](workflows/validate.md) | Verify installation works end-to-end |

---

## Required Dependencies

### Core CLIs

| CLI | Purpose | Check Command |
|-----|---------|---------------|
| `gh` | GitHub CLI for PRs, issues | `gh --version` |
| `op` | 1Password CLI for secrets | `op --version` |
| `gum` | Interactive prompts | `gum --version` |
| `fswatch` | File watching for live mode | `fswatch --version` |
| `jq` | JSON processing | `jq --version` |
| `git` | Version control | `git --version` |

### TypeScript Skills

| CLI | Purpose | Check Command |
|-----|---------|---------------|
| `bun` | TypeScript runtime for golem-powers | `bun --version` |
| `cr` | CodeRabbit CLI for code review (optional) | `cr --version` |

---

## Required API Keys

These keys are stored in 1Password under the `claude-golem` item:

| Key | Purpose | 1Password Path |
|-----|---------|----------------|
| Context7 | Library documentation lookup | `op://Private/claude-golem/context7/API_KEY` |
| Linear | Issue tracking integration | `op://Private/claude-golem/linear/API_KEY` |

**Setup:**
```bash
# Create the claude-golem item with sections
op item create --category "API Credential" --vault "Private" --title "claude-golem"
op item edit "claude-golem" --vault "Private" "context7.API_KEY[concealed]=ctx7sk_your_key"
op item edit "claude-golem" --vault "Private" "linear.API_KEY[concealed]=lin_api_your_key"
```

---

## Golem-Powers Symlink

All skills are under the `golem-powers` namespace. Create a single symlink:

```bash
mkdir -p ~/.claude/commands
ln -sf /path/to/ralphtools/skills/golem-powers ~/.claude/commands/golem-powers
```

Skills are then available as `/golem-powers:skill-name`:
- `/golem-powers:1password`
- `/golem-powers:convex`
- `/golem-powers:github`
- `/golem-powers:linear`
- `/golem-powers:context7`
- `/golem-powers:coderabbit`
- etc.

---

## Configuration Paths

| Path | Purpose |
|------|---------|
| `~/.config/ralphtools/` | Main config directory |
| `~/.config/ralphtools/config.json` | User settings |
| `~/.claude/commands/golem-powers` | Skills symlink |
| `~/.claude/CLAUDE.md` | Global Claude instructions |
| `~/.claude/contexts/` | Modular context files |

---

## Contexts Directory

The contexts directory contains reusable CLAUDE.md modules:

```
~/.claude/contexts/
├── base.md               # Universal rules (scratchpad, AIDEV-NOTE, type safety)
├── tech/
│   ├── nextjs.md         # Next.js patterns
│   ├── supabase.md       # Supabase patterns
│   ├── convex.md         # Convex patterns
│   └── react-native.md   # React Native patterns
└── workflow/
    ├── interactive.md    # Interactive Claude rules (CLAUDE_COUNTER)
    ├── ralph.md          # Ralph autonomous execution
    ├── rtl.md            # RTL layout rules
    ├── testing.md        # Testing standards
    └── design-system.md  # Component guidelines
```

Projects reference contexts with `@context:` directives:
```markdown
## Contexts
@context: base
@context: tech/nextjs
@context: workflow/rtl
```

The contexts are in the ralphtools repo at `~/.claude/contexts/` (not symlinked, copied during setup).

---

## Troubleshooting

### Homebrew not installed

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1Password CLI not connecting to app

Ensure:
1. 1Password 8 desktop app is installed
2. Settings > Developer > CLI integration is enabled
3. Biometric unlock is enabled for CLI

### Bun not installing via brew

Try the official installer:
```bash
curl -fsSL https://bun.sh/install | bash
```

### Skills not appearing in Claude

Check the golem-powers symlink:
```bash
ls -la ~/.claude/commands/golem-powers
```

If missing or broken, run [setup-symlinks](workflows/setup-symlinks.md) workflow.
