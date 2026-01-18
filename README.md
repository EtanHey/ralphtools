# Ralph - The Original AI Coding Loop

> *"Ralph is a Bash loop"* — Geoffrey Huntley

Run Claude (or any LLM) in an autonomous loop to execute PRD stories. Each iteration spawns a **fresh Claude instance** with clean context, ensuring consistent behavior across long coding sessions.

```
┌─────────────────────────────────────────────────────────────┐
│  while [ ] stories remain:                                  │
│    1. Spawn fresh Claude                                    │
│    2. Claude reads PRD.md, finds first [ ] story            │
│    3. Claude implements ONE story                           │
│    4. Claude marks [x], commits                             │
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
| PRD-driven with checkboxes | ✅ Yes | ❌ Single prompt |
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
1. Reads the PRD.md file (the source of truth)
2. Sees only checked `[x]` and unchecked `[ ]` boxes
3. Works on ONE story, marks it done, commits
4. Exits — next iteration is completely fresh

The PRD file IS the memory. Checkboxes ARE the state.

---

## Quick Start

```bash
# 1. Install
git clone https://github.com/YOUR_USERNAME/ralph.git ~/.config/ralph
echo '[[ -f ~/.config/ralph/ralph.zsh ]] && source ~/.config/ralph/ralph.zsh' >> ~/.zshrc
source ~/.zshrc

# 2. Generate a PRD with /prd command (see setup below)
claude
> /prd Add user authentication with JWT

# 3. Run Ralph
ralph 20  # 20 iterations
```

---

## Commands

| Command | Description |
|---------|-------------|
| `ralph [N] [sleep]` | Run N iterations (default 10) on `./PRD.md` |
| `ralph <app> N` | Run on `apps/<app>/PRD.md` with auto branch |
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
3. Saves `PRD.md` and `progress.txt` to your project root
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
│  3. Claude generates PRD.md + progress.txt                  │
│  4. Claude says "PRD ready. Run Ralph to execute."          │
│  5. You: ralph 20                                           │
│  6. Ralph executes stories autonomously                     │
└─────────────────────────────────────────────────────────────┘
```

---

## PRD Format

```markdown
**Working Directory:** `src`

### US-001: Add User Authentication

**Description:** Implement login/logout functionality

**Acceptance Criteria:**
- [ ] Login form with email/password
- [ ] Session management
- [ ] Logout button in header
- [ ] Typecheck passes

**⏹️ STOP - END OF US-001**

### US-002: Add Dashboard
...
```

Key rules:
- **One story per iteration** — Ralph completes exactly one story, then respawns
- **Stop markers** — `⏹️ STOP` prevents Claude from continuing to next story
- **Checkboxes are truth** — Next Claude only sees what's in PRD.md
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

Ralph has access to these MCP tools when available:

| Tool | Use Case |
|------|----------|
| **Figma MCP** | Compare implementation vs design |
| **Browser Tools** | Screenshots, console logs, audits |
| **Context7** | Up-to-date library documentation |
| **Claude in Chrome** | Interactive browser testing |

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
├── PRD.md              # Active PRD (Ralph reads this)
├── progress.txt        # Current iteration notes
└── docs.local/         # Local-only, gitignored
    ├── README.md       # Index of learnings
    ├── learnings/      # Topic-specific files
    │   ├── auth.md
    │   └── rtl.md
    └── prd-archive/    # Completed PRDs
        └── 2024-01-feature-x.md
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
1. Marks in PRD: `**Status:** ⏹️ BLOCKED: [reason]`
2. Notes in progress.txt
3. Moves to next incomplete task
4. Commits the blocker note

When ALL tasks are blocked:
- Outputs `<promise>ALL_BLOCKED</promise>`
- Loop stops for user intervention

---

## App-Specific Mode (Monorepos)

```bash
ralph frontend 30    # apps/frontend/PRD.md
ralph backend 30     # apps/backend/PRD.md
ralph mobile 30      # apps/mobile/PRD.md
```

Features:
- Auto-creates/switches to `feat/<app>-work` branch
- Uses app-specific PRD path
- Returns to original branch when done

Configure valid app names in `ralph.zsh`:
```bash
local valid_apps=("frontend" "backend" "mobile")
```

---

## Notifications

Enable with `-QN` flag. Uses [ntfy.sh](https://ntfy.sh) for push notifications.

Configure your topic in `ralph.zsh`:
```bash
local ntfy_topic="your-topic-name"
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

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_MODEL` | Default model | `opus` |
| `RALPH_MAX_ITERATIONS` | Default limit | `10` |
| `RALPH_SLEEP` | Seconds between iterations | `2` |

### Files

```
~/.config/ralph/
├── ralph.zsh           # Main script (source this)
├── skills/
│   ├── prd.md          # /prd command
│   └── critique-waves.md
├── docs.local/         # Local docs (gitignored)
└── .githooks/          # Pre-commit hooks
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
Checkboxes are the only state. If it's not in PRD.md, it didn't happen.

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
