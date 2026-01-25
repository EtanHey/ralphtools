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

## Step 3: Install Skills

Symlink Ralph skills to Claude Code commands directory.

```bash
# Create commands directory if needed
mkdir -p ~/.claude/commands

# Symlink /prd command
ln -sf ~/.config/claude-golem/skills/prd.md ~/.claude/commands/prd.md

# Symlink /critique-waves command
ln -sf ~/.config/claude-golem/skills/critique-waves.md ~/.claude/commands/critique-waves.md
```

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
- [ ] Skills symlinked to `~/.claude/commands/`
- [ ] `ralph-help` works in new terminal
- [ ] (Optional) Git hooks set up for contributors

---

## What's Next?

1. **Create a PRD**: In any project, run `/prd Add feature X`
2. **Run Ralph**: Execute with `ralph 20` (20 iterations max)
3. **Monitor**: Use `ralph-status` or `ralph-live` to watch progress
