# Claude-Golem Architecture

> A comprehensive guide to the Ralph autonomous coding system and its components.

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Configuration](#configuration)
6. [Extension Points](#extension-points)

---

## Overview

Claude-Golem is an autonomous coding system that executes PRD (Product Requirements Document) stories using Claude AI. The system is built around several key principles:

- **Stateless Iterations** - Each Claude session is independent
- **File-Based State** - All persistent data lives in JSON/markdown files
- **Incremental Progress** - One story per iteration, committed atomically
- **Human Oversight** - User controls when to run and reviews results

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         User Interface                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Terminal Commands                                          │  │
│  │  • ralph [N]        - Run N iterations                      │  │
│  │  • ralph-setup      - Configuration wizard                  │  │
│  │  • ralph-archive    - Archive completed stories             │  │
│  │  • ralph-status     - View PRD status                       │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Orchestration Layer                         │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  ralph.zsh                                                  │  │
│  │  • Main execution loop                                      │  │
│  │  • Model selection                                          │  │
│  │  • Cost tracking                                            │  │
│  │  • Progress display                                         │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  lib/*.zsh modules                                          │  │
│  │  • ralph-commands  - Helper functions                       │  │
│  │  • ralph-models    - Model routing                          │  │
│  │  • ralph-secrets   - 1Password integration                  │  │
│  │  • ralph-ui        - Display formatting                     │  │
│  │  • ralph-watcher   - File watching, orphan cleanup          │  │
│  │  • ralph-worktrees - Git worktree isolation                 │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                        AI Execution Layer                        │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Claude CLI                                                 │  │
│  │  • Receives Ralph Base Prompt                               │  │
│  │  • Reads AGENTS.md context                                  │  │
│  │  • Executes story acceptance criteria                       │  │
│  │  • Uses Skills as needed                                    │  │
│  │  • Outputs completion/blocked signals                       │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                         Data Layer                               │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  PRD State (prd-json/)                                      │  │
│  │  • index.json   - Queue state, stats, nextStory             │  │
│  │  • stories/*.json - Individual story definitions            │  │
│  │  • update.json  - Mid-run story additions                   │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Context Files                                              │  │
│  │  • CLAUDE.md    - Project instructions                      │  │
│  │  • AGENTS.md    - Ralph-specific context                    │  │
│  │  • progress.txt - Iteration history                         │  │
│  └────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Global Config (~/.config/ralphtools/)                      │  │
│  │  • config.json  - User preferences                          │  │
│  │  • registry.json - Project registry                         │  │
│  │  • costs.jsonl  - Cost tracking history                     │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

### Repository Layout

```
claude-golem/
├── ralph.zsh              # Main entry point
├── lib/                   # Modular zsh libraries
│   ├── ralph-commands.zsh # Helper commands (jqf, ralph-session)
│   ├── ralph-models.zsh   # Model selection and routing
│   ├── ralph-registry.zsh # Project configuration
│   ├── ralph-secrets.zsh  # 1Password integration
│   ├── ralph-setup.zsh    # Interactive setup wizard
│   ├── ralph-ui.zsh       # Colors and formatting
│   ├── ralph-watcher.zsh  # File watching, orphan cleanup
│   ├── ralph-worktrees.zsh# Git worktree management
│   └── README.md          # Module documentation
├── bun/                   # TypeScript core
│   ├── core/
│   │   ├── index.ts       # Module exports
│   │   ├── config.ts      # Configuration loading
│   │   ├── models.ts      # Model routing logic
│   │   ├── costs.ts       # Cost calculation
│   │   ├── stories.ts     # PRD operations
│   │   └── claude.ts      # Claude CLI interface
│   └── package.json
├── contexts/              # Shared CLAUDE.md contexts
│   ├── base.md            # Universal rules
│   ├── golem-system.md    # System philosophy
│   ├── skill-index.md     # Available skills list
│   ├── skill-descriptions.md
│   ├── tech/              # Technology-specific
│   │   ├── nextjs.md
│   │   ├── convex.md
│   │   └── ...
│   ├── workflow/          # Workflow-specific
│   │   ├── interactive.md
│   │   ├── ralph.md
│   │   └── ...
│   └── README.md
├── skills/                # Claude skills
│   └── golem-powers/
│       ├── prd/           # PRD creation
│       ├── coderabbit/    # Code review
│       ├── github/        # Git operations
│       └── ...
├── tests/                 # Test suite
│   └── test-ralph.zsh
├── scripts/               # Utility scripts
├── docs/                  # Public documentation
│   ├── architecture.md    # This file
│   └── architecture-map.md
└── docs.local/            # Local documentation (gitignored)
    ├── learnings/
    └── ralph-ideas.md
```

### User Configuration Directory

```
~/.config/ralphtools/
├── config.json           # User preferences
├── registry.json         # Project registry
├── costs.jsonl           # Cost tracking
├── user-prefs.json       # UI preferences
├── ralph-pids.txt        # Process tracking
└── logs/                 # Crash logs
    └── crash-*.log
```

### Project PRD Directory

```
<project>/prd-json/
├── index.json            # PRD state
│   {
│     "stats": { "total": 5, "completed": 2, "pending": 2, "blocked": 1 },
│     "nextStory": "US-003",
│     "storyOrder": ["US-001", "US-002", "US-003", "V-001", "BUG-001"],
│     "pending": ["US-003", "V-001"],
│     "blocked": ["BUG-001"]
│   }
├── stories/
│   ├── US-001.json       # Completed
│   ├── US-002.json       # Completed
│   ├── US-003.json       # In progress
│   ├── V-001.json        # Pending
│   └── BUG-001.json      # Blocked
├── update.json           # Optional: add stories mid-run
└── AGENTS.md             # Ralph-specific instructions
```

---

## Component Details

### 1. ralph.zsh - Main Orchestrator

The main entry point that:
- Sources all lib/*.zsh modules
- Parses command-line arguments
- Manages the iteration loop
- Spawns Claude with appropriate prompts
- Handles completion/blocked signals

Key functions:
- `ralph()` - Main entry point
- `_ralph_run_iteration()` - Single iteration execution
- `_ralph_check_completion()` - Check PRD state
- `_ralph_cleanup()` - Session cleanup

### 2. lib/ralph-models.zsh - Model Routing

Determines which AI model to use based on:
1. Story-level override (in story JSON)
2. CLI flags (--opus, --sonnet, --haiku)
3. Config-based smart routing
4. Default model

Default routing table:
```
US-*    → sonnet  (balanced)
V-*     → haiku   (fast verification)
TEST-*  → haiku   (repetitive)
BUG-*   → sonnet  (investigation)
AUDIT-* → opus    (deep analysis)
MP-*    → opus    (architecture)
```

### 3. lib/ralph-watcher.zsh - Live Progress

Provides real-time progress updates:
- Uses fswatch (macOS) or inotifywait (Linux)
- Updates progress bars without terminal flashing
- Tracks orphan processes for cleanup

### 4. lib/ralph-worktrees.zsh - Session Isolation

Git worktree support for isolated Ralph sessions:
- `ralph-start` - Create isolated worktree
- `ralph-cleanup` - Merge and remove worktree
- `ralph-archive` - Archive completed stories

### 5. bun/core/ - TypeScript Core

Shared logic extracted to TypeScript:
- Type-safe story manipulation
- Cost calculation with model pricing
- Claude output parsing
- Configuration validation

### 6. Skills System

Skills are packaged capabilities:
```
skills/golem-powers/<skill-name>/
├── SKILL.md            # Skill definition
├── workflows/          # Sub-workflows
│   └── <workflow>.md
└── scripts/            # Supporting scripts
    └── *.sh
```

Invoked via `Skill` tool, not direct file reads.

---

## Data Flow

### Iteration Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                        Start Iteration                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Read PRD State                                                │
│    • Load index.json                                             │
│    • Get nextStory                                               │
│    • Load story JSON                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Select Model                                                  │
│    • Check story-level override                                  │
│    • Apply config routing                                        │
│    • Log model choice                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Build Prompt                                                  │
│    • Ralph Base Prompt                                           │
│    • Story-type-specific rules (MP, US, V, etc.)                │
│    • Project AGENTS.md                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Spawn Claude                                                  │
│    • claude -p "prompt" --model <model>                         │
│    • Wait for completion                                         │
│    • Capture output                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Parse Output                                                  │
│    • Check for <promise>COMPLETE</promise>                      │
│    • Check for <promise>ALL_BLOCKED</promise>                   │
│    • Extract token usage                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. Post-Processing                                               │
│    • Log cost to costs.jsonl                                     │
│    • Update progress.txt                                         │
│    • Send notifications (if configured)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. Loop Decision                                                 │
│    • COMPLETE → Exit success                                     │
│    • ALL_BLOCKED → Exit with warning                             │
│    • More stories → Next iteration                               │
│    • Max iterations → Exit                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Story State Machine

```
              ┌─────────────────────────────────────┐
              │            Created                   │
              │  (story JSON added to stories/)      │
              └───────────────┬─────────────────────┘
                              │
                              │ Added to index.pending
                              ▼
              ┌─────────────────────────────────────┐
              │            Pending                   │
              │  (waiting in queue)                  │
              └───────────────┬─────────────────────┘
                              │
                              │ Becomes nextStory
                              ▼
              ┌─────────────────────────────────────┐
              │          In Progress                 │
              │  (Claude working on criteria)        │
              └───────┬───────────────────┬─────────┘
                      │                   │
          Blocker     │                   │ All criteria
          encountered │                   │ checked
                      ▼                   ▼
         ┌────────────────────┐  ┌────────────────────┐
         │      Blocked       │  │     Completed      │
         │ (blockedBy set)    │  │ (passes=true)      │
         └─────────┬──────────┘  └────────────────────┘
                   │
                   │ User unblocks
                   │ (via update.json)
                   ▼
              ┌─────────────────────────────────────┐
              │            Pending                   │
              │  (back in queue)                     │
              └─────────────────────────────────────┘
```

---

## Configuration

### config.json Schema

```json
{
  "runtime": "bun",
  "uiMode": "live",
  "modelStrategy": "smart",
  "defaultModel": "opus",
  "unknownTaskType": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus",
    "MP": "opus"
  },
  "notifications": {
    "enabled": true,
    "ntfyTopic": "my-ralph-notifications",
    "events": ["all_complete", "error", "blocked"]
  },
  "defaults": {
    "maxIterations": 50,
    "sleepSeconds": 2
  },
  "pricing": {
    "haiku": { "input": 1, "output": 5 },
    "sonnet": { "input": 3, "output": 15 },
    "opus": { "input": 15, "output": 75 }
  }
}
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `RALPH_MODEL` | Override model selection |
| `RALPH_DEBUG` | Enable debug output |
| `RALPH_DEBUG_LIVE` | Debug live progress updates |
| `ANTHROPIC_API_KEY` | Claude API key |
| `RALPH_NTFY_TOPIC` | Notification topic |

---

## Extension Points

### Adding a New Skill

1. Create directory: `skills/golem-powers/<skill-name>/`
2. Create `SKILL.md` with skill definition
3. Optionally add workflows and scripts
4. Test with `Skill` tool invocation

### Adding a New Context

1. Create file: `contexts/<category>/<name>.md`
2. Add detection pattern to migration script
3. Document in `contexts/README.md`
4. Reference with `@context: <category>/<name>`

### Adding a New Model

1. Update `bun/core/config.ts` types
2. Add pricing to `bun/core/costs.ts`
3. Add CLI mapping to `bun/core/models.ts`
4. Update `lib/ralph-models.zsh` routing

### Adding a New Story Type

1. Define prefix convention (e.g., `PERF-*`)
2. Add to model routing table
3. Optionally add story-type-specific prompt rules
4. Document in AGENTS.md template

---

## See Also

- [contexts/golem-system.md](../contexts/golem-system.md) - Philosophy and design decisions
- [contexts/README.md](../contexts/README.md) - Context system documentation
- [lib/README.md](../lib/README.md) - Module documentation
- [docs/architecture-map.md](./architecture-map.md) - Visual architecture diagram
