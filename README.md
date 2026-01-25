# Ralph v2.0 - The Original AI Coding Loop

[![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/EtanHey/claude-golem?utm_source=oss&utm_medium=github&utm_campaign=EtanHey%2Fclaude-golem&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)](https://coderabbit.ai)

**[📚 Full Documentation](https://etanheyman.github.io/claude-golem/)** | **[GitHub](https://github.com/etanheyman/claude-golem)**

> *"Ralph is a Bash loop"* — Geoffrey Huntley

Run Claude (or any LLM) in an autonomous loop to execute PRD stories. Each iteration spawns a **fresh Claude instance** with clean context.

```
while stories remain:
  1. Spawn fresh Claude with story-type-specific prompt
  2. Claude reads prd-json/, finds next story
  3. Claude implements ONE story, runs CodeRabbit, commits
  4. Loop
done
```

---

## Quick Start

```bash
# 1. Clone and source
git clone https://github.com/EtanHey/claude-golem.git ~/.config/claude-golem
echo 'source ~/.config/claude-golem/ralph.zsh' >> ~/.zshrc
source ~/.zshrc

# 2. Run setup wizard (configures skills, symlinks, preferences)
ralph-setup

# 3. Use
claude                           # Open Claude Code
> /prd Add user authentication   # Generate PRD
ralph 20                         # Execute 20 iterations
```

**That's it!** Ralph auto-detects your project stack and loads the right contexts.

---

## Commands

| Command | Description |
|---------|-------------|
| `ralph [N]` | Run N iterations (default 10) |
| `ralph <app> N` | Run on `apps/<app>/prd-json/` (monorepo) |
| `ralph-init [app]` | Create PRD template |
| `ralph-status` | Show PRD status |
| `ralph-live [N]` | Live refreshing status (default: 3s) |
| `ralph-watch` | Live tail of current Ralph output |
| `ralph-stop` | Kill running loops |
| `ralph-archive [app]` | Archive completed stories to docs.local/ |
| `ralph-learnings` | Manage learnings in docs.local/learnings/ |
| `ralph-costs` | Show cost tracking summary |
| `ralph-start` | Create worktree for isolated Ralph session |
| `ralph-cleanup` | Merge changes and remove worktree |

### ralph-start Flags

| Flag | Description |
|------|-------------|
| `--install` | Run package manager install in worktree |
| `--dev` | Start dev server in background after setup |
| `--symlink-deps` | Symlink node_modules from main repo (faster than install) |
| `--1password` | Use 1Password injection via `.env.template` |
| `--no-env` | Skip copying `.env` and `.env.local` files |

Package manager is auto-detected from lock files (bun.lockb → bun, pnpm-lock.yaml → pnpm, yarn.lock → yarn, else npm).

### .worktree-sync.json

Create a `.worktree-sync.json` in your repo root to configure custom worktree sync rules:

```json
{
  "sync": {
    "files": [
      "secrets.json",
      "config/local.yaml"
    ],
    "symlinks": [
      ".cache",
      "data"
    ],
    "commands": [
      "cp .env.example .env",
      "make setup"
    ]
  }
}
```

- **files**: Additional files/directories to copy to worktree
- **symlinks**: Files/directories to symlink instead of copy
- **commands**: Post-setup commands to run in the worktree

---

## Configuration

Ralph is **config-driven** - use `ralph-setup` wizard instead of flags. Config is stored in `~/.config/claude-golem/config.json`.

```bash
ralph-setup   # Interactive wizard for all settings
```

### Runtime Mode: Bun vs Bash

Ralph v2.0 defaults to **Bun/React Ink UI** for a modern terminal dashboard with live-updating progress.

| Runtime | Description | When to Use |
|---------|-------------|-------------|
| **bun** (default) | React Ink dashboard, live updates | Standard use |
| **bash** | Traditional zsh output | No Bun installed, debugging |

```bash
# Override for one session
ralph 20 --ui-bash

# Change default via wizard
ralph-setup   # Select runtime preference
```

### Smart Model Routing

Models are assigned automatically based on story type:

| Story Type | Model | Rationale |
|------------|-------|-----------|
| `AUDIT-*` | Opus | Thorough analysis |
| `MP-*` | Opus | Master plans, architecture |
| `US-*` | Sonnet | Feature implementation |
| `BUG-*` | Sonnet | Bug fixes |
| `V-*` | Haiku | Fast verification |
| `TEST-*` | Haiku | Test creation |

Override per-story: add `"model": "opus"` to story JSON.

### Notifications

Enable push notifications via [ntfy](https://ntfy.sh):

```bash
ralph 20 -QN   # Notify on completion/failure
```

### Examples

```bash
ralph 50              # Run 50 iterations with smart routing
ralph myapp 20        # Run on apps/myapp/ (monorepo)
ralph 10 --ui-bash    # Force bash UI for debugging
```

---

## Skills System

Ralph includes a library of skills that provide workflows for common tasks. Skills are stored in `~/.config/claude-golem/skills/` and made available to Claude via symlinks in `~/.claude/commands/`.

### Sourcing Skills in Other Projects

Projects can access Ralph's skills automatically - they're globally available through `~/.claude/commands/`. No per-project configuration needed.

**How it works:**
1. Ralph's skills are in `~/.config/claude-golem/skills/` (the cloned repo)
2. Symlinks in `~/.claude/commands/` point to these skills
3. Claude Code finds skills via `~/.claude/commands/` automatically
4. All projects get the same skills without duplication

### Available Skills

| Skill | Description |
|-------|-------------|
| `/project-context` | **Auto-detect project tools and MCP servers** |
| `/prd` | PRD generation for Ralph |
| `/prd-manager` | Add or modify PRD stories safely |
| `/archive` | Archive completed PRD stories |
| `/convex` | Convex workflows: dev server, deployment, user deletion |
| `/1password` | Secret management, .env migration |
| `/github` | Commits, PRs, issues |
| `/linear` | Linear issue management |
| `/worktrees` | Git worktree isolation |
| `/brave` | Brave browser automation (fallback) |
| `/coderabbit` | Code review workflows |
| `/context7` | Library documentation lookup |
| `/ralph-commit` | Atomic commit + criterion check for Ralph |
| `/critique-waves` | Iterative verification with parallel agents |
| `/catchup` | Context recovery after long breaks |
| `/skills` | List available skills |

### Project Context Detection

Run `/project-context` at session start to auto-detect:

- **Project tools**: Convex, Linear, Supabase, UI frameworks, 1Password, PRD
- **MCP servers**: Shows installed MCPs with skill alternatives
- **Git context**: Current branch and project root

```bash
# Example output:
| Detected | Tool | Skill |
|----------|------|-------|
| ✅ | Convex | `/golem-powers:convex` |
| ✅ | Linear | `/golem-powers:linear` |
| ✅ | 1Password | `/golem-powers:1password` |

## MCP Servers (with Skill Alternatives)
| MCP Server | Installed | Skill Alternative |
|------------|-----------|-------------------|
| Linear | ✅ plugin | `/golem-powers:linear` - uses API directly |
| Context7 | ✅ plugin | `/golem-powers:context7` - uses API directly |
| Obsidian | via community plugin | See [Obsidian MCP](#obsidian-mcp) below |
```

**Tip:** Skills call APIs directly and are often faster than MCP servers.

### Updating Skills

Skills auto-update when you pull claude-golem:

```bash
cd ~/.config/claude-golem && git pull
# Skills update immediately - symlinks point to latest files
```

### Adding Skills to a New Machine

```bash
# After cloning claude-golem, use the /ralph-install skill
claude
> /ralph-install   # Follow setup workflow

# Or manually symlink all skills:
cd ~/.config/claude-golem
for skill in skills/*.md; do
  ln -sf "$(pwd)/$skill" ~/.claude/commands/
done
for skill in skills/*/; do
  ln -sf "$(pwd)/${skill%/}" ~/.claude/commands/
done
```

### Skills Environment Variables

Some skills require API keys. These are managed via 1Password to avoid storing secrets in files.

**Required Keys:**

| Skill | Key | 1Password Path |
|-------|-----|----------------|
| `/context7` | `CONTEXT7_API_KEY` | `op://Private/claude-golem/context7/API_KEY` |
| `/linear` | `LINEAR_API_KEY` | `op://Private/claude-golem/linear/API_KEY` |

**Setup (one-time):**

```bash
# 1. Add your API keys to 1Password
op item create --category "API Credential" --vault "Private" --title "claude-golem"
op item edit "claude-golem" --vault "Private" "context7.API_KEY[concealed]=ctx7sk_your_key"
op item edit "claude-golem" --vault "Private" "linear.API_KEY[concealed]=lin_api_your_key"

# 2. Verify setup
op read "op://Private/claude-golem/context7/API_KEY" | head -c 10
```

**Usage:**

```bash
# Option 1: op inject (creates .env file)
op inject -i ~/.config/claude-golem/skills/.env.template -o ~/.config/claude-golem/skills/.env
source ~/.config/claude-golem/skills/.env

# Option 2: op run (inject for single command)
op run --env-file=~/.config/claude-golem/skills/.env.template -- claude

# Option 3: Shell alias (recommended)
alias claude-with-keys='op run --env-file=~/.config/claude-golem/skills/.env.template -- claude'
```

### Obsidian MCP

Connect Claude to your Obsidian vault using the [Claude Code MCP plugin](https://github.com/iansinnott/obsidian-claude-code-mcp).

**Setup via wizard:**

```bash
ralph-setup
# Select "📓 Configure Obsidian MCP"
```

**Manual setup:**

```bash
./scripts/install-obsidian-mcp.sh
```

**Prerequisites:**
- Obsidian installed
- Claude Code MCP plugin installed from Obsidian Community Plugins

**How it works:**
1. The plugin runs an MCP server inside Obsidian (default port: 22360)
2. Claude Code connects via WebSocket or HTTP/SSE
3. Use `/ide` in Claude Code CLI to auto-discover your vault

**MCP Configuration (for settings.json):**

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:22360/sse"]
    }
  }
}
```

**1Password integration:**

Store the MCP URL securely:
```bash
op item create --category "API Credential" --vault "Private" --title "Obsidian-MCP" "url=http://localhost:22360/sse"
```

Then reference in config:
```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["mcp-remote", "op://Private/Obsidian-MCP/url"]
    }
  }
}
```

**Troubleshooting:**

| Issue | Solution |
|-------|----------|
| Connection refused | Ensure Obsidian is running with the plugin enabled |
| Port in use | Change port in plugin settings (Settings → Community Plugins → Claude Code) |
| Multiple vaults | Each vault needs a unique port (22360, 22361, etc.) |
| /ide not finding vault | Check for `.lock` files in `~/.config/claude/ide/` |

---

## Modular Context System

Ralph builds a **layered context** for each iteration, giving Claude the right instructions for your specific project.

> 📖 **Full documentation:** [docs/claude-md-layering.md](docs/claude-md-layering.md)

### Context Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTEXT BUILDING FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. BASE (always)         ~/.claude/contexts/base.md           │
│        │                   └─ Core rules, safety, patterns      │
│        ▼                                                        │
│   2. WORKFLOW              ~/.claude/contexts/workflow/ralph.md │
│        │                   └─ Ralph-specific: commits, PRD      │
│        ▼                                                        │
│   3. TECH (auto-detect)    ~/.claude/contexts/tech/*.md         │
│        │                   └─ Next.js, Convex, Supabase...      │
│        ▼                                                        │
│   4. ADDITIONAL (config)   Custom contexts from config.json     │
│        │                                                        │
│        ▼                                                        │
│   ╔═════════════════════════════════════════════════════════╗   │
│   ║  CONCATENATED → --append-system-prompt → Claude CLI     ║   │
│   ╚═════════════════════════════════════════════════════════╝   │
└─────────────────────────────────────────────────────────────────┘
```

### Auto-Detection Magic

Ralph scans your project and loads relevant tech contexts:

| Detected File/Pattern | Context Loaded |
|----------------------|----------------|
| `next.config.{js,mjs,ts}` | `tech/nextjs.md` |
| `convex.json` or `convex/` | `tech/convex.md` |
| `supabase/` or supabase in package.json | `tech/supabase.md` |
| Expo or React Native markers | `tech/react-native.md` |

### Directory Structure

```
~/.claude/contexts/
├── base.md                 # 🔒 Core rules (ALWAYS loaded)
├── workflow/
│   ├── ralph.md           # 🤖 Ralph autonomous mode
│   └── interactive.md     # 💬 Human-in-loop mode
└── tech/
    ├── nextjs.md          # ⚡ Next.js patterns
    ├── convex.md          # 🔄 Convex patterns
    ├── supabase.md        # 🗄️ Supabase patterns
    └── react-native.md    # 📱 React Native patterns
```

### Configuration

Extend context loading in `~/.config/claude-golem/config.json`:

```json
{
  "contexts": {
    "directory": "~/.claude/contexts",
    "additional": ["workflow/testing.md", "workflow/rtl.md"]
  }
}
```

---

## Story-Type Prompts (AGENTS.md)

Ralph uses **layered prompts** that adapt to the story type being worked on.

### How It Works

1. Each iteration loads a **base prompt** with universal rules
2. Then layers a **story-type-specific prompt** on top:
   - `US.md` - Feature implementation guidance
   - `BUG.md` - Debugging workflow, root cause analysis
   - `V.md` - TDD verification approach
   - `TEST.md` - Test creation best practices
   - `AUDIT.md` - Comprehensive review checklist
   - `MP.md` - Master plan/architecture guidance

Prompts are stored in `~/.config/claude-golem/prompts/`.

### AGENTS.md Auto-Update

Your project's `prd-json/AGENTS.md` is automatically refreshed when:
- New skills are added to `~/.claude/commands/`
- Prompts are updated in `~/.config/claude-golem/prompts/`
- You run `ralph-setup` context migration

---

## CodeRabbit Integration

Ralph integrates with [CodeRabbit](https://coderabbit.ai) for free AI-powered code reviews before commits.

### How It Works

1. After Claude finishes implementing a story, it runs `cr review --prompt-only`
2. If issues are found, Claude fixes them and re-reviews
3. **Maximum 3 iterations** - if issues persist, they become BUG stories
4. Only commits after passing CodeRabbit review

### CodeRabbit → BUG Story Pattern

When CodeRabbit finds issues that can't be fixed in the current iteration:

```json
// prd-json/update.json is created automatically
{
  "newStories": [{
    "id": "BUG-XXX",
    "title": "Fix CodeRabbit finding: [issue]",
    "type": "bug",
    "priority": "medium"
  }]
}
```

This ensures no issues are silently ignored while allowing forward progress.

### Setup

```bash
# Install CodeRabbit CLI
npm install -g coderabbit

# Configure via ralph-setup
ralph-setup
# Choose "Configure CodeRabbit"
# Enable and specify repos (or * for all)
```

### Configuration

CodeRabbit is **opt-in** per repo. Configure in `~/.config/claude-golem/registry.json`:

```json
{
  "coderabbit": {
    "enabled": true,
    "repos": ["claude-golem", "songscript"]
  }
}
```

Or use `*` for all repos:
```json
{
  "coderabbit": {
    "enabled": true,
    "repos": ["*"]
  }
}
```

---

## Why Fresh Context?

Long sessions accumulate confusion. Ralph solves this by **spawning fresh Claude every iteration**:
- JSON files ARE the memory
- Checked criteria ARE the state
- No hallucinated memory of non-existent code

---

## Requirements

- **zsh** (bash may work)
- **Claude Code CLI**
- **git**
- Optional: Claude-in-Chrome extension, ntfy, [Superpowers plugin](https://github.com/obra/superpowers)

---

## Documentation

Detailed docs for AI agents in [`docs/`](docs/):

| Doc | Contents |
|-----|----------|
| [prd-format.md](docs/prd-format.md) | JSON structure, /prd command |
| [skills.md](docs/skills.md) | All skills reference |
| [mcp-tools.md](docs/mcp-tools.md) | Browser automation setup |
| [configuration.md](docs/configuration.md) | Environment variables, files |
| [workflows.md](docs/workflows.md) | Story splitting, blocked tasks, learnings |

---

## Philosophy

1. **Iteration > Perfection** — Let the loop refine
2. **Fresh Context = Consistent Behavior** — No accumulated confusion
3. **PRD is Truth** — JSON criteria are the only state
4. **Failures Are Data** — Notes for next iteration
5. **Human Sets Direction, Ralph Executes**

---

## Credits

- **Original Concept:** [Geoffrey Huntley](https://ghuntley.com/ralph/)
- **Superpowers Plugin:** [obra/superpowers](https://github.com/obra/superpowers)

---

## Changelog

### v2.0.0
**Major architecture update with React Ink UI, modular codebase, and layered prompts.**

> **Note:** Repository renamed from `ralphtools` to `claude-golem` as part of this release to better reflect the project's scope as a Claude Code extension ecosystem.

- **React Ink UI** is now the default runtime - modern terminal dashboard with live-updating progress
- **Modular codebase**: `ralph.zsh` split into `lib/*.zsh` modules for maintainability
- **Layered AGENTS prompt**: Story-type-specific prompts (US.md, BUG.md, V.md, etc.) on top of base.md
- **AGENTS.md auto-update**: Prompts automatically refresh when skills are added/modified
- **CodeRabbit → BUG integration**: CR findings automatically become BUG stories if unfixable
- **MP story type**: Master Plan stories for infrastructure/architecture work
- **Comprehensive test suite**: 156+ ZSH tests + 83 Bun tests run on pre-commit
- **Context injection tests**: Verify modular context system integrity
- Config-driven approach: `ralph-setup` wizard replaces flag-heavy CLI
- Orphan process cleanup and crash logging (`ralph-logs`, `ralph-kill-orphans`)
- Docusaurus documentation site at etanheyman.github.io/claude-golem/

### v1.5.0
- **golem-powers skills**: Unified skill namespace with executable pattern (SKILL.md + scripts/)
- **Modular context system**: Layered CLAUDE.md with auto-detection (MP-002)
- **prd-manager skill**: Atomic PRD operations (add-to-index, add-criterion, etc.)
- **1Password vault organization**: development vault for global tools, project vaults
- **Commit conventions**: Story-type based (feat/fix/test/refactor)
- **TDD verification stories**: V-016/V-017 audit with failing tests first
- Skills migrated: context7, coderabbit, linear, worktrees, github, 1password
- Deprecated: update skill (replaced by prd-manager)

### v1.4.0
- **Smart Model Routing**: AUDIT→opus, US→sonnet, V→haiku, story-level `"model"` override
- **Live criteria sync**: fswatch file watching, ANSI cursor updates (no flash)
- **1Password Environments**: `op run --env-file` integration, `ralph-secrets` command
- **ralph-setup wizard**: gum-based first-run experience
- **Test framework**: zsh test suite with unit tests for config, cost tracking, notifications
- Per-iteration cost tracking with model-aware pricing
- Progress bars and compact output mode

### v1.3.0
- **JSON-based PRD format** (`prd-json/` replaces markdown PRD)
- **Smart model routing** for story types (auto-select appropriate model)
- **Configuration system** (`ralph-config.local` for project settings)
- **Archive skill** (`/archive` command pointing to `ralph-archive`)

### v1.2.0
- **Comprehensive documentation** rewrite for open source release
- **Skills documentation** with /prd, /archive commands
- **docs.local convention** for project-specific learnings

### v1.1.0
- **Browser tab checking** for MCP verification stories
- **Learnings directory** support (`docs.local/learnings/`)
- **Pre-commit/pre-push hooks** with Claude Haiku validation

### v1.0.0
- Initial Ralph tooling release
- Core loop: spawn fresh Claude, read PRD, implement story, commit
- ntfy notification support (`-QN` flag)
