# Ralph Setup Guide

> **For Claude Code**: Follow this guide to help users set up Ralph interactively.

---

## Overview

Ralph is an autonomous coding loop that executes PRD stories. This guide will:
1. Configure your preferences (notifications, apps, etc.)
2. Set up shell integration
3. Install Claude Code skills
4. Verify everything works

---

## Step 1: Create Personal Configuration

Create `ralph-config.local` with the user's preferences.

### Questions to Ask

**1. Notifications (ntfy.sh)**
- "Do you want push notifications when Ralph completes iterations? (requires ntfy app)"
- If yes: "What topic name would you like? (e.g., 'my-ralph' - you'll subscribe to this in ntfy)"
- If yes + using app mode: "For app-specific notifications, what pattern? Use {project} and {app} as placeholders (e.g., 'my-{project}-{app}')"

**2. Monorepo Apps**
- "Do you use a monorepo with apps/ directory?"
- If yes: "What are your app names? (space-separated, e.g., 'frontend backend mobile')"

**3. Model Preference**
- "Default model: Opus (smarter, slower) or Sonnet (faster, cheaper)?"

### Create Config File

Based on answers, create `~/.config/claude-golem/ralph-config.local`:

```bash
# User's Ralph Configuration
# This file is gitignored - personal settings only

# Notifications (comment out to disable)
export RALPH_NTFY_TOPIC="[user's topic]"
export RALPH_NTFY_TOPIC_PATTERN="[user's pattern]"

# Valid apps for monorepo (space-separated)
export RALPH_VALID_APPS="[user's apps]"

# Model preference (opus or sonnet)
export RALPH_DEFAULT_MODEL="opus"
```

---

## Step 2: Shell Integration

Add Ralph to the user's shell.

### For Zsh (~/.zshrc)

```bash
# Check if already added
grep -q "ralph.zsh" ~/.zshrc

# If not, add it
echo '' >> ~/.zshrc
echo '# Ralph - Autonomous Coding Loop' >> ~/.zshrc
echo '[[ -f ~/.config/claude-golem/ralph.zsh ]] && source ~/.config/claude-golem/ralph.zsh' >> ~/.zshrc
```

### For Bash (~/.bashrc)

```bash
echo '' >> ~/.bashrc
echo '# Ralph - Autonomous Coding Loop' >> ~/.bashrc
echo '[[ -f ~/.config/claude-golem/ralph.zsh ]] && source ~/.config/claude-golem/ralph.zsh' >> ~/.bashrc
```

---

## Step 3: Install Skills and Contexts

Set up skills and modular contexts for Claude.

### 3a: Symlink Skills

```bash
# Create commands directory if needed
mkdir -p ~/.claude/commands

# Symlink golem-powers (all skills as a single symlink)
ln -sf ~/.config/claude-golem/skills/golem-powers ~/.claude/commands/golem-powers
```

### 3b: Install Contexts

Contexts are modular CLAUDE.md snippets that get loaded into Claude sessions.

```bash
# Create contexts directory
mkdir -p ~/.claude/contexts

# Symlink contexts from the repo
ln -sf ~/.config/claude-golem/contexts/* ~/.claude/contexts/
```

Available contexts:
- `base.md` - Universal rules (scratchpad, AIDEV-NOTE, type safety)
- `skill-index.md` - Available skills reference
- `workflow/interactive.md` - Interactive Claude rules
- `workflow/ralph.md` - Ralph autonomous execution
- `tech/*.md` - Technology-specific contexts (nextjs, supabase, etc.)

---

## Step 4: Set Up Git Hooks (Optional)

For contributors to ralph-tooling itself:

```bash
cd ~/.config/ralph
./scripts/setup-hooks.sh
```

---

## Step 5: Verify Installation

Run these checks:

```bash
# 1. Source the config (or open new terminal)
source ~/.config/claude-golem/ralph.zsh

# 2. Check ralph command exists
which ralph || type ralph

# 3. Check config loaded
echo "Topic: $RALPH_NTFY_TOPIC"
echo "Apps: $RALPH_VALID_APPS"

# 4. Check help works
ralph-help
```

---

## Quick Test

In any git repository:

```bash
# Initialize a test PRD
ralph-init

# Check status
ralph-status

# Clean up test files
rm -rf prd-json progress.txt
```

---

## Wiring a New Project

To add a new project to the Ralph ecosystem with launchers and contexts:

### Step 1: Add to Registry

Edit `~/.config/ralphtools/registry.json` and add your project:

```json
{
  "projects": {
    "myproject": {
      "path": "/path/to/myproject",
      "displayName": "MyProject Claude",
      "mcps": ["Context7", "browser-tools"],
      "mcpsLight": ["Context7"],
      "contexts": ["base", "skill-index", "workflow/interactive"],
      "secrets": {},
      "created": "2026-01-25T00:00:00Z"
    }
  }
}
```

**Required fields:**
- `path`: Absolute path to the project directory
- `mcps`: Array of MCP servers to enable (from `mcpDefinitions`)
- `contexts`: Array of context files to load (without `.md` extension)

**Optional fields:**
- `displayName`: Human-readable name (for logs/notifications)
- `mcpsLight`: Subset of MCPs for lighter sessions
- `secrets`: Project-specific secrets (use `op://` references for 1Password)

### Step 2: Choose Contexts

Select contexts based on your project's tech stack:

| If your project uses... | Add this context |
|------------------------|------------------|
| Universal (all projects) | `base`, `skill-index` |
| Interactive Claude | `workflow/interactive` |
| Ralph autonomous | `workflow/ralph` |
| Next.js | `tech/nextjs` |
| React Native/Expo | `tech/react-native` |
| Supabase | `tech/supabase` |
| Convex | `tech/convex` |
| RTL layouts (Hebrew/Arabic) | `workflow/rtl` |
| Dual-language / i18n | `workflow/i18n` |

Run `/context-audit` in your project to detect recommended contexts.

### Step 3: Regenerate Launchers

After updating `registry.json`, regenerate the launcher functions:

```bash
# In any terminal with Ralph loaded
_ralph_generate_launchers_from_registry
```

This creates `run{Name}()`, `open{Name}()`, and `{name}Claude()` functions.

### Step 4: Verify

```bash
# Source the new launchers
source ~/.config/ralphtools/launchers.zsh

# Test your launcher
myprojectClaude
```

### Example: Complete Registry Entry

For a Next.js project with Supabase:

```json
"myapp": {
  "path": "/Users/me/projects/myapp",
  "displayName": "MyApp Claude",
  "mcps": ["Context7", "browser-tools", "supabase"],
  "mcpsLight": ["Context7"],
  "contexts": [
    "base",
    "skill-index",
    "tech/nextjs",
    "tech/supabase",
    "workflow/interactive"
  ],
  "secrets": {
    "SUPABASE_ACCESS_TOKEN": "op://MyVault/supabase/ACCESS_TOKEN"
  },
  "created": "2026-01-25T00:00:00Z"
}
```

---

## Troubleshooting

### "ralph: command not found"
- Open a new terminal, or run: `source ~/.zshrc`

### Config not loading
- Check file exists: `ls ~/.config/claude-golem/ralph-config.local`
- Check syntax: `zsh -n ~/.config/claude-golem/ralph-config.local`

### Skills not available
- Check symlinks: `ls -la ~/.claude/commands/`
- Recreate: `ln -sf ~/.config/claude-golem/skills/prd.md ~/.claude/commands/prd.md`

---

## Summary Checklist

- [ ] `ralph-config.local` created with preferences
- [ ] Shell integration added to `.zshrc` or `.bashrc`
- [ ] Skills symlinked to `~/.claude/commands/golem-powers`
- [ ] Contexts symlinked to `~/.claude/contexts/`
- [ ] `ralph-help` works in new terminal
- [ ] (Optional) Projects wired in `registry.json` with contexts
- [ ] (Optional) Git hooks set up for contributors

---

## What's Next?

1. **Create a PRD**: In any project, run `/prd Add feature X`
2. **Run Ralph**: Execute with `ralph 20` (20 iterations max)
3. **Monitor**: Use `ralph-status` or `ralph-live` to watch progress
