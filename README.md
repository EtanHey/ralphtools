# Ralph - The Original AI Coding Loop

[![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/EtanHey/claude-golem?utm_source=oss&utm_medium=github&utm_campaign=EtanHey%2Fclaude-golem&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)](https://coderabbit.ai)

**[📚 Documentation](https://etanheyman.github.io/ralphtools/)** | **[GitHub](https://github.com/etanheyman/ralphtools)**

> *"Ralph is a Bash loop"* — Geoffrey Huntley

Run Claude (or any LLM) in an autonomous loop to execute PRD stories. Each iteration spawns a **fresh Claude instance** with clean context.

```
while stories remain:
  1. Spawn fresh Claude
  2. Claude reads prd-json/, finds next story
  3. Claude implements ONE story, commits
  4. Loop
done
```

---

## Quick Start

```bash
# Install
git clone https://github.com/EtanHey/ralph-tooling.git ~/.config/ralph
echo 'source ~/.config/ralph/ralph.zsh' >> ~/.zshrc
source ~/.zshrc

# Setup skills
mkdir -p ~/.claude/commands
ln -sf ~/.config/ralph/skills/prd.md ~/.claude/commands/prd.md

# Use
claude                        # Open Claude Code
> /prd Add user authentication  # Generate PRD
ralph 20                      # Execute 20 iterations
```

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

### Flags

| Flag | Description |
|------|-------------|
| `-QN` | Enable [ntfy](https://ntfy.sh) notifications |

### Model Flags

Model selection is handled automatically by **smart routing**:
- AUDIT-* stories → Opus (thorough analysis)
- US-* stories → Sonnet (balanced)
- V-* stories → Haiku (fast verification)
- Story-level override via `"model": "opus"` in JSON

| Flag | Model | Browser Automation |
|------|-------|-------------------|
| `-O` | Claude Opus | Claude-in-Chrome MCP |
| `-S` | Claude Sonnet | Claude-in-Chrome MCP |

Use `ralph-setup` to configure your default model preferences.

### Examples

```bash
ralph 50              # Run 50 iterations with smart routing
ralph myapp 20        # Run on apps/myapp/ (monorepo)
```

---

## Skills System

Ralph includes a library of skills that provide workflows for common tasks. Skills are stored in `~/.config/ralph/skills/` and made available to Claude via symlinks in `~/.claude/commands/`.

### Sourcing Skills in Other Projects

Projects can access Ralph's skills automatically - they're globally available through `~/.claude/commands/`. No per-project configuration needed.

**How it works:**
1. Ralph's skills are in `~/.config/ralph/skills/` (the cloned repo)
2. Symlinks in `~/.claude/commands/` point to these skills
3. Claude Code finds skills via `~/.claude/commands/` automatically
4. All projects get the same skills without duplication

### Available Skills

| Skill | Description |
|-------|-------------|
| `/prd` | PRD generation for Ralph |
| `/update` | Add or modify PRD stories safely |
| `/archive` | Archive completed PRD stories |
| `/convex` | Convex workflows: dev server, deployment, user deletion |
| `/1password` | Secret management, .env migration |
| `/github` | Commits, PRs, issues |
| `/linear` | Linear issue management |
| `/worktrees` | Git worktree isolation |
| `/brave` | Brave browser automation (fallback) |
| `/coderabbit` | Code review workflows |
| `/critique-waves` | Iterative verification with parallel agents |
| `/skills` | List available skills |

### Updating Skills

Skills auto-update when you pull ralphtools:

```bash
cd ~/.config/ralph && git pull
# Skills update immediately - symlinks point to latest files
```

### Adding Skills to a New Machine

```bash
# After cloning ralphtools, use the /ralph-install skill
claude
> /ralph-install   # Follow setup workflow

# Or manually symlink all skills:
cd ~/.config/ralph
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
op inject -i ~/.config/ralph/skills/.env.template -o ~/.config/ralph/skills/.env
source ~/.config/ralph/skills/.env

# Option 2: op run (inject for single command)
op run --env-file=~/.config/ralph/skills/.env.template -- claude

# Option 3: Shell alias (recommended)
alias claude-with-keys='op run --env-file=~/.config/ralph/skills/.env.template -- claude'
```

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

Extend context loading in `~/.config/ralphtools/config.json`:

```json
{
  "contexts": {
    "directory": "~/.claude/contexts",
    "additional": ["workflow/testing.md", "workflow/rtl.md"]
  }
}
```

---

## CodeRabbit Integration

Ralph integrates with [CodeRabbit](https://coderabbit.ai) for free AI-powered code reviews before commits.

### How It Works

1. After Claude finishes implementing a story, Ralph instructs it to run `cr review`
2. If issues (CRITICAL/HIGH/MEDIUM) are found, Claude fixes them
3. Re-runs CodeRabbit until clean
4. Only then commits the changes

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

CodeRabbit is **opt-in** per repo. Configure in `~/.config/ralphtools/registry.json`:

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

### Adding More Repos

```bash
# Via wizard
ralph-setup → Configure CodeRabbit

# Or manually edit ~/.config/ralphtools/registry.json
# Add repo names to coderabbit.repos array
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

### v1.5.0 (In Progress)
- **golem-powers skills**: Unified skill namespace with executable pattern (SKILL.md + scripts/)
- **React Ink UI**: Modern terminal dashboard (`--ui-ink` flag, US-085/US-093)
- **Modular context system**: Layered CLAUDE.md with `@context:` directives (MP-002)
- **Kiro model variants**: kiro-haiku, kiro-sonnet, kiro-opus routing
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
- **Progressive disclosure skills**: GitHub + 1Password skills (SKILL.md → workflows/)
- **Box drawing alignment**: emoji width calculation, variation selector handling
- **ANSI color fixes**: full escape sequences, semantic color schemes
- **ralph-setup wizard**: gum-based first-run experience
- **Multi-agent audit**: AUDIT-001 pattern with parallel verification
- **Test framework**: zsh test suite with unit tests for config, cost tracking, notifications
- **GitHub Actions CI**: automated testing workflow (TEST-005)
- **Brave Browser Manager**: internal fallback for browser automation
- Per-iteration cost tracking with model-aware pricing
- Per-project MCP configuration (`ralph-projects`)
- Project launcher auto-generation (US-009)
- Parallel verification infrastructure (US-006, US-007)
- `ralph --version` flag
- Compact ntfy notifications with emoji labels (3-line format)
- Error handling for 'No messages returned' Claude CLI error (BUG-002)
- .env to 1Password migration (US-012)
- Progress bars and compact output mode (US-015, US-016)
- AGENTS.md auto-sync to all AI tools (US-017)
- Enhanced iteration status with gum interactivity (US-021)

### v1.3.0
- **JSON-based PRD format** (`prd-json/` replaces markdown PRD)
- **Smart model routing** for story types (auto-select appropriate model)
- **Configuration system** (`ralph-config.local` for project settings)
- **Per-iteration cost tracking**: costs.json with token estimates
- **Archive skill** (`/archive` command pointing to `ralph-archive`)
- `completedAt` timestamp tracking
- `ralph-live` enhanced status mode
- `ralph-auto` auto-restart wrapper
- Incremental criteria checking with robust retry logic
- Dev server self-start + end iteration on infrastructure blockers
- Update queue for criteria count display
- Fail-safe when Claude output is unclear
- Smarter error detection to avoid false positives

### v1.2.0
- **Comprehensive documentation** rewrite for open source release
- **Skills documentation** with /prd, /archive commands
- **docs.local convention** for project-specific learnings
- Enhanced helper commands with better UX
- Real-time output capture with `script` command
- Proper Ctrl+C handling
- Line-buffered output with `tee`

### v1.1.0
- **Browser tab checking** for MCP verification stories
- **Learnings directory** support (`docs.local/learnings/`)
- **Pre-commit/pre-push hooks** with Claude Haiku validation
- Improved retry logic and command execution
- Sonnet model flag (`-S`)
- Use pipestatus to capture claude exit code
- Quote all variables in conditionals for safer evaluation

### v1.0.0
- Initial Ralph tooling release
- Core loop: spawn fresh Claude, read PRD, implement story, commit
- `ralph [N]` command for N iterations
- `ralph-init`, `ralph-status`, `ralph-stop` commands
- ntfy notification support (`-QN` flag)
- Real-time output with `ralph-watch`
- CLAUDE.md with commit/push instructions
