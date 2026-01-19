# Ralph - The Original AI Coding Loop

> *"Ralph is a Bash loop"* — Geoffrey Huntley

Run Claude (or any LLM) in an autonomous loop to execute PRD stories. Each iteration spawns a **fresh Claude instance** with clean context, ensuring consistent behavior across long coding sessions.

```
┌─────────────────────────────────────────────────────────────┐
│  while stories remain in prd-json/:                         │
│    1. Spawn fresh Claude                                    │
│    2. Claude reads index.json, finds next story             │
│    3. Claude implements ONE story                           │
│    4. Claude marks criteria checked, commits                │
│    5. Loop                                                  │
│  done                                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 This is THE Original Ralph

Ralph was created by [Geoffrey Huntley](https://ghuntley.com/ralph/) as a simple but powerful concept: **a bash loop that feeds the same prompt to an AI agent repeatedly until completion**.

> **Note:** There's also a Claude Code plugin called `ralph-loop` that reimplements this concept using stop hooks inside a single Claude session. That's a different approach. **This repo is the original external bash loop** with additional features like PRD-driven development, fresh context per iteration, and learnings persistence.

| Feature | This Ralph (Original) | Claude Code Plugin |
|---------|----------------------|-------------------|
| Fresh context each iteration | ✅ Yes | ❌ Same session |
| PRD-driven with JSON criteria | ✅ Yes | ❌ Single prompt |
| Learnings persist across iterations | ✅ Yes | ❌ No |
| Monorepo support | ✅ Yes | ❌ No |
| Browser verification protocol | ✅ Yes | ❌ No |
| Story splitting with consensus | ✅ Yes | ❌ No |
| Blocked task handling | ✅ Yes | ❌ No |

---

## Why Fresh Context Matters

When Claude runs in a long session, it accumulates context that can:
- Cause confusion about what's already done
- Create "hallucinated memory" of non-existent code
- Lead to inconsistent behavior as context window fills

Ralph solves this by **spawning a fresh Claude every iteration**. Each Claude:
1. Reads `prd-json/index.json` (the source of truth)
2. Finds the next pending story in `prd-json/stories/`
3. Works on ONE story, marks criteria checked, commits
4. Exits — next iteration is completely fresh

The JSON files ARE the memory. Checked criteria ARE the state.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/EtanHey/ralph-tooling.git ~/.config/ralph

# 2. Interactive setup (recommended)
cd ~/.config/ralph
claude  # Opens Claude Code
# Then say: "Help me set up Ralph using SETUP.md"

# Or manual setup:
echo '[[ -f ~/.config/ralph/ralph.zsh ]] && source ~/.config/ralph/ralph.zsh' >> ~/.zshrc
source ~/.zshrc
mkdir -p ~/.claude/commands
ln -sf ~/.config/ralph/skills/prd.md ~/.claude/commands/prd.md
ln -sf ~/.config/ralph/skills/critique-waves.md ~/.claude/commands/critique-waves.md

# 3. In any project, generate a PRD
claude
> /prd Add user authentication with JWT

# 4. Run Ralph to execute
ralph 20  # 20 iterations
```

> **Tip:** For personalized configuration (notifications, app names), see `SETUP.md` or copy `ralph-config.local.example` to `ralph-config.local` and customize.

### Prerequisites
- **zsh** shell (bash may work with modifications)
- **Claude CLI** installed (`claude` command available)
- **git** for commits and branch management

---

## Commands

| Command | Description |
|---------|-------------|
| `ralph [N] [sleep]` | Run N iterations (default 10) on `./prd-json/` |
| `ralph <app> N` | Run on `apps/<app>/prd-json/` with auto branch |
| `ralph-init [app]` | Create PRD template |
| `ralph-archive [app]` | Archive completed stories |
| `ralph-status` | Show PRD status across all apps |
| `ralph-learnings` | Manage learnings files |
| `ralph-stop` | Kill running Ralph loops |

### Flags

| Flag | Description |
|------|-------------|
| `-QN` | Enable notifications via [ntfy](https://ntfy.sh) |
| `-S` | Use Sonnet model (faster, cheaper) |

---

## The /prd Command

Ralph executes PRDs, but first you need to create one. The `/prd` command is a Claude Code skill that generates well-structured PRDs automatically.

### What It Does

1. Asks 3-5 clarifying questions about your feature
2. Generates a complete PRD with properly-sized stories
3. Saves to `prd-json/` directory (index.json + stories/*.json)
4. **Stops** — it does NOT implement (that's Ralph's job)

### Setup

```bash
# 1. Create the commands directory
mkdir -p ~/.claude/commands

# 2. Copy the /prd skill
cp ~/.config/ralph/skills/prd.md ~/.claude/commands/prd.md

# 3. Use it in any project
claude
> /prd Build a todo app with drag-and-drop
```

### Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. You: /prd "Add feature X"                               │
│  2. Claude asks clarifying questions                        │
│  3. Claude generates prd-json/ (index.json + stories/)      │
│  4. Claude says "PRD ready. Run Ralph to execute."          │
│  5. You: ralph 20                                           │
│  6. Ralph executes stories autonomously                     │
└─────────────────────────────────────────────────────────────┘
```

---

## PRD Format (JSON)

Ralph uses a JSON-based PRD format stored in `prd-json/`:

```
prd-json/
├── index.json          # Story order and metadata
└── stories/
    ├── US-001.json     # Individual story files
    ├── US-002.json
    └── ...
```

**index.json:**
```json
{
  "title": "Feature Name",
  "workingDirectory": "src",
  "stories": ["US-001", "US-002"]
}
```

**stories/US-001.json:**
```json
{
  "id": "US-001",
  "title": "Add User Authentication",
  "description": "Implement login/logout functionality",
  "criteria": [
    { "id": "c1", "text": "Login form with email/password", "checked": false },
    { "id": "c2", "text": "Session management", "checked": false },
    { "id": "c3", "text": "Logout button in header", "checked": false },
    { "id": "c4", "text": "Typecheck passes", "checked": false }
  ]
}
```

Key rules:
- **One story per iteration** — Ralph completes exactly one story, then respawns
- **JSON criteria are truth** — `checked: true` marks completion
- **Incremental progress** — Criteria are checked one-by-one and committed
- **Verification stories** — V-XXX stories for visual verification

---

## Available Skills & Features

Ralph can leverage these skills during execution. Each skill can be invoked with `/skill-name` in Claude Code, or Ralph can use them automatically when relevant.

### Core Skills (Custom)

| Skill | File | Description |
|-------|------|-------------|
| `/prd` | `~/.claude/commands/prd.md` | Generate PRDs for Ralph |
| `/critique-waves` | `~/.claude/commands/critique-waves.md` | Multi-agent consensus verification |

### Superpowers Skills (via Plugin)

If you have the [Superpowers plugin](https://github.com/obra/superpowers) installed:

| Skill | When to Use |
|-------|-------------|
| `superpowers:brainstorming` | Before creative work, exploring requirements |
| `superpowers:systematic-debugging` | When encountering bugs or test failures |
| `superpowers:test-driven-development` | Before implementing features |
| `superpowers:verification-before-completion` | Before claiming work is done |
| `superpowers:writing-plans` | When planning multi-step implementations |
| `superpowers:executing-plans` | When executing written plans |
| `superpowers:dispatching-parallel-agents` | For 2+ independent tasks |
| `superpowers:subagent-driven-development` | Multi-agent implementation |
| `superpowers:code-reviewer` | After completing major features |
| `superpowers:using-git-worktrees` | For isolated feature work |

### MCP Tools

Ralph can use these MCP (Model Context Protocol) tools for enhanced verification. MCPs are optional but recommended for visual/browser testing.

| Tool | Use Case | Source |
|------|----------|--------|
| **Claude in Chrome** | Browser automation, screenshots, clicking, form filling | [Claude Code Docs](https://code.claude.com/docs/en/chrome) |
| **Browser Tools** | Console logs, network errors, accessibility audits | [AgentDeskAI/browser-tools-mcp](https://github.com/AgentDeskAI/browser-tools-mcp) |
| **Context7** | Up-to-date library documentation lookup | [upstash/context7](https://github.com/upstash/context7) |
| **Figma MCP** | Compare implementation vs Figma designs | [Figma MCP Guide](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server) |

### MCP Setup

**Claude in Chrome** (built into Claude Code):
1. Install the [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude-in-chrome/) from Chrome Web Store
2. Open Chrome and Claude Code - they connect automatically
3. See [full docs](https://code.claude.com/docs/en/chrome) for details

**Browser Tools** (console logs, audits):
```bash
# Install the Chrome extension from:
# https://github.com/AgentDeskAI/browser-tools-mcp

# Add to Claude Code:
claude mcp add browser-tools -- npx @anthropic/browser-tools-mcp@latest
```

**Context7** (library documentation):
```bash
# Add to Claude Code (requires API key from upstash.com):
claude mcp add context7 -- npx -y @upstash/context7-mcp

# Usage: Add "use context7" to prompts for up-to-date docs
```

**Figma MCP** (design comparison):
```bash
# Add Figma's official remote server:
claude mcp add --transport http figma https://mcp.figma.com/mcp

# Or install the plugin:
claude plugin install figma@claude-plugins-official

# Requires Figma account - see setup guide above
```

> **Note:** Ralph works without MCPs, but browser verification stories (V-XXX) require Claude in Chrome or Browser Tools to take screenshots and verify UI.

---

## /critique-waves (Multi-Agent Consensus)

For critical verification, use multi-agent consensus. This spawns multiple agents to verify the same criteria — if any disagree, the issue is flagged.

### When to Use

- Story splitting decisions (is this too big?)
- RTL layout verification
- Design comparison verification
- Critical bug fixes

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Wave 1: 3 agents verify in parallel                        │
│    Agent 1: PASS                                            │
│    Agent 2: FAIL (found forbidden pattern)                  │
│    Agent 3: PASS                                            │
│  Result: 0 consecutive passes (reset due to failure)        │
│                                                             │
│  Fix the issue...                                           │
│                                                             │
│  Wave 2: 3 agents verify in parallel                        │
│    All PASS → 3 consecutive passes                          │
│                                                             │
│  ...continue until 20 consecutive passes...                 │
└─────────────────────────────────────────────────────────────┘
```

### Setup

```bash
cp ~/.config/ralph/skills/critique-waves.md ~/.claude/commands/critique-waves.md
```

---

## docs.local/ Convention

`docs.local/` is a convention we created for local-only project documentation. It's **not a standard** — we made it because we needed a place for:

- Learnings that persist across Ralph iterations
- Archived PRDs from completed features
- Project-specific notes that shouldn't be in git

### Structure

```
your-project/
├── .gitignore          # Add: docs.local/
├── prd-json/           # Active PRD (Ralph reads this)
│   ├── index.json
│   └── stories/
├── progress.txt        # Current iteration notes
└── docs.local/         # Local-only, gitignored
    ├── README.md       # Index of learnings
    ├── learnings/      # Topic-specific files
    │   ├── auth.md
    │   └── rtl.md
    └── prd-archive/    # Completed PRDs
        └── 2024-01-feature-x/
```

### Setup

Add to your `.gitignore`:
```
docs.local/
```

### Why Gitignore?

- Learnings are often specific to your local setup
- Contains debug notes and experiments
- Completed PRDs bloat the repo
- You can always recover from git history

---

## Learnings System

Ralph persists learnings across iterations in a searchable structure.

### Structure

```
docs.local/
├── README.md                    # Index
├── learnings/                   # Topic files
│   ├── auth-patterns.md
│   ├── rtl-layouts.md
│   └── api-quirks.md
└── prd-archive/                 # Completed PRDs
```

### Usage

```bash
# Check learnings status
ralph-learnings

# Search learnings
grep -r "#auth" docs.local/learnings/
```

### Promoting Learnings

When a learning is important enough to persist globally:
1. Mark it in progress.txt: `[PROMOTE] Learning about X`
2. Add to project CLAUDE.md for project-wide knowledge
3. Add to ~/.claude/CLAUDE.md for global knowledge

---

## Browser Verification

Ralph integrates with Claude-in-Chrome for visual verification.

### Setup

Open two Chrome tabs before running Ralph:
- **Tab 1:** Desktop viewport (1440px+)
- **Tab 2:** Mobile viewport (375px)

### Protocol

At each iteration start, Ralph:
1. Calls `mcp__claude-in-chrome__tabs_context_mcp`
2. Reports: "✓ Browser tabs available" or "⚠️ Not available"
3. If not available: marks browser steps as BLOCKED, continues other work

### Rules

- **Never resize viewport** — use the correct tab
- **Always `left_click`** — never `right_click`
- **Take screenshots** to verify visual changes
- **Check console** for errors

---

## Story Splitting

When a story is too big for one iteration, Ralph can split it.

### When to Split

- 8+ acceptance criteria
- 5+ files to modify
- 50% through context and not close to done

### Process

1. **Recognize** — Acknowledge the story is too big
2. **Plan** — Break into substories (US-001a, US-001b, etc.)
3. **Validate** — Run `/critique-waves` for consensus (20 passes)
4. **Write** — Insert substories to PRD
5. **Exit** — Next iteration picks up first substory

---

## Blocked Task Handling

### What Blocks a Task

- External API unavailable (need API key)
- User decision required (ambiguous requirements)
- MCP tools fail or return errors
- Manual testing needed

### Behavior

When Ralph encounters a blocked task:
1. Marks in story JSON: `"status": "blocked"` with reason
2. Notes in progress.txt
3. Moves to next incomplete task
4. Commits the blocker note

When ALL tasks are blocked:
- Outputs `<promise>ALL_BLOCKED</promise>`
- Loop stops for user intervention

---

## App-Specific Mode (Monorepos)

```bash
ralph frontend 30    # apps/frontend/prd-json/
ralph backend 30     # apps/backend/prd-json/
ralph mobile 30      # apps/mobile/prd-json/
```

Features:
- Auto-creates/switches to `feat/<app>-work` branch
- Uses app-specific PRD path
- Returns to original branch when done

Configure valid app names in `ralph-config.local`:
```bash
export RALPH_VALID_APPS="frontend backend mobile expo"
```

---

## Notifications

Enable with `-QN` flag. Uses [ntfy.sh](https://ntfy.sh) for push notifications.

Configure in `ralph-config.local`:
```bash
export RALPH_NTFY_TOPIC="your-topic-name"
export RALPH_NTFY_TOPIC_PATTERN="{project}-{app}"  # For app mode
```

Notifications sent:
- Iteration complete (with remaining task count)
- All tasks complete
- All tasks blocked
- Max iterations reached

---

## Pre-Commit Hooks

Safety hooks prevent common bugs:

### Pre-Commit
- ZSH syntax check (`zsh -n`)
- Custom bug pattern detection
- Retry logic integrity
- Brace/bracket balance

### Pre-Push
- Dry run test
- Function completeness
- Critical pattern validation
- Documentation check

---

## Configuration

### Personal Config File

Copy `ralph-config.local.example` to `ralph-config.local` and customize:

```bash
cp ~/.config/ralph/ralph-config.local.example ~/.config/ralph/ralph-config.local
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_NTFY_TOPIC` | Notification topic | `ralph-notifications` |
| `RALPH_NTFY_TOPIC_PATTERN` | App-mode topic pattern | `{project}-{app}` |
| `RALPH_DEFAULT_MODEL` | Default model | `opus` |
| `RALPH_MAX_ITERATIONS` | Default iteration limit | `10` |
| `RALPH_SLEEP_SECONDS` | Seconds between iterations | `2` |
| `RALPH_VALID_APPS` | Valid app names (space-separated) | `frontend backend mobile expo public admin` |

### Files

```
~/.config/ralph/
├── ralph.zsh                   # Main script (source this)
├── ralph-config.local          # Your personal config (gitignored)
├── ralph-config.local.example  # Config template
├── skills/
│   ├── prd.md                  # /prd command
│   └── critique-waves.md
├── configs/                    # Rule configs (RTL, modals, etc.)
├── scripts/                    # Helper scripts
├── tests/                      # Test scripts
└── .githooks/                  # Pre-commit hooks
```

---

## Requirements

- **zsh** (bash may work with modifications)
- **Claude CLI** (`claude` command available)
- **git** (for commits and branch management)
- Optional: Chrome + Claude-in-Chrome extension
- Optional: ntfy app for notifications
- Optional: Superpowers plugin for additional skills

---

## Philosophy

Ralph embodies several principles from Geoffrey Huntley's original concept:

### 1. Iteration > Perfection
Don't aim for perfect on first try. Let the loop refine the work.

### 2. Fresh Context = Consistent Behavior
Each iteration starts clean. No accumulated confusion.

### 3. PRD is Truth
JSON criteria are the only state. If it's not checked in prd-json/, it didn't happen.

### 4. Failures Are Data
When Ralph fails, it leaves notes for the next iteration.

### 5. Human Sets Direction, Ralph Executes
The PRD is the contract. Ralph fulfills it.

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make changes (pre-commit hooks will validate)
4. Submit PR

The pre-commit hooks ensure code quality.

---

## License

MIT License - See LICENSE file

---

## Credits

- **Original Concept:** [Geoffrey Huntley](https://ghuntley.com/ralph/)
- **Superpowers Plugin:** [obra/superpowers](https://github.com/obra/superpowers)
- **This Implementation:** Built with learnings from production use

---

## Changelog

### v1.3.0
- JSON-based PRD format (prd-json/) replaces markdown PRD.md
- Incremental criterion checking with commits per criterion
- Configuration system with `ralph-config.local` for personal settings
- Claude Haiku pre-push hook for personal info detection
- SETUP.md for interactive Claude Code guided setup

### v1.2.0
- Comprehensive README with skills documentation
- Clear distinction from Claude Code plugin
- docs.local convention documented
- /prd command setup instructions

### v1.1.0
- Browser tab checking protocol
- Learnings directory structure
- Variable quoting for safety

### v1.0.0
- Initial release
- App-specific mode
- Blocked task handling
- Helper commands
