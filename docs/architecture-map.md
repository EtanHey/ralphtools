# Architecture Visual Map

> ASCII art diagrams showing the Ralph/Golem system architecture.

---

## System Overview

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                           CLAUDE-GOLEM ECOSYSTEM                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │                            USER INTERFACE                                │ ║
║  │                                                                          │ ║
║  │   ralph 50        ralph-setup       ralph-archive      ralph-status     │ ║
║  │   ┌──────┐        ┌──────────┐      ┌────────────┐     ┌────────────┐   │ ║
║  │   │Run 50│        │Configure │      │Archive PRD │     │View Status │   │ ║
║  │   │iters │        │Projects  │      │Stories     │     │& Progress  │   │ ║
║  │   └──┬───┘        └────┬─────┘      └─────┬──────┘     └──────┬─────┘   │ ║
║  └──────┼─────────────────┼──────────────────┼───────────────────┼─────────┘ ║
║         │                 │                  │                   │           ║
║         ▼                 ▼                  ▼                   ▼           ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │                         ORCHESTRATION LAYER                              │ ║
║  │                                                                          │ ║
║  │  ┌────────────────────────────────────────────────────────────────────┐ │ ║
║  │  │  ralph.zsh                                                         │ │ ║
║  │  │  ═══════════                                                       │ │ ║
║  │  │  • Main execution loop                                             │ │ ║
║  │  │  • Sources lib/*.zsh modules                                       │ │ ║
║  │  │  • Spawns Claude CLI                                               │ │ ║
║  │  │  • Handles completion signals                                      │ │ ║
║  │  └────────────────────────────────────────────────────────────────────┘ │ ║
║  │                                                                          │ ║
║  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│ ║
║  │  │ralph-models │ │ralph-ui    │ │ralph-watcher│ │ralph-worktrees     ││ ║
║  │  │─────────────│ │─────────────│ │─────────────│ │─────────────────────││ ║
║  │  │Model routing│ │Colors, bars│ │Live updates │ │Session isolation   ││ ║
║  │  │Cost tracking│ │Formatting  │ │Orphan cleanup│ │Git worktree mgmt   ││ ║
║  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│ ║
║  │                                                                          │ ║
║  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│ ║
║  │  │ralph-secrets│ │ralph-setup │ │ralph-commands│ │ralph-registry      ││ ║
║  │  │─────────────│ │─────────────│ │─────────────│ │─────────────────────││ ║
║  │  │1Password    │ │Setup wizard│ │jqf helper   │ │Project config      ││ ║
║  │  │integration  │ │Interactive │ │Session mgmt │ │MCP definitions     ││ ║
║  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│ ║
║  └─────────────────────────────────────────────────────────────────────────┘ ║
║                                                                               ║
║         │                                                                     ║
║         ▼                                                                     ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │                         AI EXECUTION LAYER                               │ ║
║  │                                                                          │ ║
║  │  ┌────────────────────────────────────────────────────────────────────┐ │ ║
║  │  │  Claude CLI (claude -p "...")                                      │ │ ║
║  │  │  ════════════════════════════                                      │ │ ║
║  │  │                                                                    │ │ ║
║  │  │  Inputs:                          Outputs:                         │ │ ║
║  │  │  • Ralph Base Prompt              • File edits                     │ │ ║
║  │  │  • AGENTS.md context              • Git commits                    │ │ ║
║  │  │  • CLAUDE.md rules                • Story JSON updates             │ │ ║
║  │  │  • Story JSON                     • Completion signals             │ │ ║
║  │  │                                   • Blocked signals                │ │ ║
║  │  │                                                                    │ │ ║
║  │  │  Uses:                                                             │ │ ║
║  │  │  • Skills (/coderabbit, /github, /linear, etc.)                   │ │ ║
║  │  │  • MCP tools (browser, figma, etc.)                               │ │ ║
║  │  └────────────────────────────────────────────────────────────────────┘ │ ║
║  └─────────────────────────────────────────────────────────────────────────┘ ║
║                                                                               ║
║         │                                                                     ║
║         ▼                                                                     ║
║  ┌─────────────────────────────────────────────────────────────────────────┐ ║
║  │                            DATA LAYER                                    │ ║
║  │                                                                          │ ║
║  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌────────────────┐ │ ║
║  │  │ PRD State            │  │ Context Files        │  │ Global Config  │ │ ║
║  │  │ ════════════         │  │ ═══════════════      │  │ ═════════════  │ │ ║
║  │  │                      │  │                      │  │                │ │ ║
║  │  │ prd-json/            │  │ CLAUDE.md            │  │ ~/.config/     │ │ ║
║  │  │ ├─ index.json        │  │ AGENTS.md            │  │ ralphtools/    │ │ ║
║  │  │ ├─ stories/*.json    │  │ progress.txt         │  │ ├─ config.json │ │ ║
║  │  │ └─ update.json       │  │ contexts/            │  │ ├─ registry   │ │ ║
║  │  │                      │  │                      │  │ └─ costs.jsonl│ │ ║
║  │  └──────────────────────┘  └──────────────────────┘  └────────────────┘ │ ║
║  └─────────────────────────────────────────────────────────────────────────┘ ║
║                                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Iteration Flow

```
                    ┌─────────────────────────┐
                    │      ralph N            │
                    │   (start N iterations)  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │ for i in 1..N           │
                    │ ┌─────────────────────┐ │
                    │ │  Read PRD State     │ │
                    │ │  • index.json       │ │
                    │ │  • nextStory        │ │
                    │ └──────────┬──────────┘ │
                    │            │            │
                    │            ▼            │
                    │ ┌─────────────────────┐ │
                    │ │  Select Model       │ │
                    │ │  • Story type       │ │
                    │ │  • Config routing   │ │
                    │ └──────────┬──────────┘ │
                    │            │            │
                    │            ▼            │
                    │ ┌─────────────────────┐ │
                    │ │  Build Prompt       │ │
                    │ │  • Base prompt      │ │
                    │ │  • AGENTS.md        │ │
                    │ │  • Story rules      │ │
                    │ └──────────┬──────────┘ │
                    │            │            │
                    │            ▼            │
                    │ ┌─────────────────────┐ │
                    │ │  Spawn Claude       │ │
                    │ │  ┌───────────────┐  │ │
                    │ │  │ Claude works  │  │ │
                    │ │  │ on story      │  │ │
                    │ │  │ criteria...   │  │ │
                    │ │  └───────────────┘  │ │
                    │ └──────────┬──────────┘ │
                    │            │            │
                    │            ▼            │
                    │ ┌─────────────────────┐ │
                    │ │  Check Output       │ │
                    │ └──────────┬──────────┘ │
                    │            │            │
                    │    ┌───────┼───────┐    │
                    │    │       │       │    │
                    │    ▼       ▼       ▼    │
                    │ COMPLETE  MORE  BLOCKED │
                    │    │    STORIES   │     │
                    │    │       │       │    │
                    └────┼───────┼───────┼────┘
                         │       │       │
                         ▼       │       ▼
                    ┌─────────┐  │  ┌─────────────┐
                    │ Exit    │  │  │ Log blocker │
                    │ Success │  │  │ Check if    │
                    └─────────┘  │  │ all blocked │
                                 │  └──────┬──────┘
                                 │         │
                           ┌─────┘         │
                           │               ▼
                           │         ┌─────────────┐
                           │         │ ALL_BLOCKED │
                           │         │ Exit warn   │
                           │         └─────────────┘
                           │
                           ▼
                    (next iteration)
```

---

## Story State Flow

```
              ┌───────────────────────────────────────────────────┐
              │                    CREATED                         │
              │  story JSON created in prd-json/stories/           │
              └─────────────────────────┬─────────────────────────┘
                                        │
                                        │ added to index.pending[]
                                        ▼
              ┌───────────────────────────────────────────────────┐
              │                    PENDING                         │
              │  waiting in queue for execution                    │
              └─────────────────────────┬─────────────────────────┘
                                        │
                                        │ becomes index.nextStory
                                        ▼
              ┌───────────────────────────────────────────────────┐
              │                  IN PROGRESS                       │
              │  Claude actively working on acceptance criteria    │
              │                                                    │
              │  ┌─────────────────────────────────────────────┐  │
              │  │ Acceptance Criteria:                        │  │
              │  │ [x] Create database migration               │  │
              │  │ [x] Add TypeScript types                    │  │
              │  │ [ ] Run CodeRabbit review                   │  │
              │  │ [ ] Commit: feat: US-001 description        │  │
              │  └─────────────────────────────────────────────┘  │
              └──────────────┬────────────────────┬───────────────┘
                             │                    │
              blocker found  │                    │ all criteria checked
                             │                    │
                             ▼                    ▼
              ┌──────────────────────┐  ┌──────────────────────┐
              │       BLOCKED        │  │      COMPLETED       │
              │ ──────────────────── │  │ ──────────────────── │
              │                      │  │                      │
              │ blockedBy: "reason"  │  │ passes: true         │
              │ moved to blocked[]   │  │ completedAt: "..."   │
              │                      │  │ removed from pending │
              └───────────┬──────────┘  └──────────────────────┘
                          │
                          │ user adds to update.json:
                          │ moveToPending: ["US-XXX"]
                          ▼
              ┌───────────────────────────────────────────────────┐
              │                    PENDING                         │
              │  back in queue after blocker resolved              │
              └───────────────────────────────────────────────────┘
```

---

## Model Routing Decision Tree

```
                    ┌─────────────────────────────┐
                    │ Determine Model for Story   │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────┐
                    │ Story has .model field?     │
                    └──────────────┬──────────────┘
                                   │
                          ┌────────┴────────┐
                          │                 │
                         YES                NO
                          │                 │
                          ▼                 ▼
              ┌───────────────────┐  ┌─────────────────────────────┐
              │ Use story.model   │  │ CLI override flag?          │
              │ (story-level)     │  │ (--opus, --sonnet, --haiku) │
              └───────────────────┘  └──────────────┬──────────────┘
                                                    │
                                           ┌────────┴────────┐
                                           │                 │
                                          YES                NO
                                           │                 │
                                           ▼                 ▼
              ┌───────────────────┐  ┌─────────────────────────────┐
              │ Use CLI flag      │  │ Config strategy = "smart"?  │
              │ model             │  └──────────────┬──────────────┘
              └───────────────────┘                 │
                                           ┌────────┴────────┐
                                           │                 │
                                          YES                NO
                                           │                 │
                                           ▼                 ▼
              ┌───────────────────────────────────┐  ┌────────────────────┐
              │ Use config.models[taskType]       │  │ Use config.        │
              │                                   │  │ defaultModel       │
              │ US-* → sonnet                     │  │ (usually opus)     │
              │ V-*  → haiku                      │  └────────────────────┘
              │ BUG-* → sonnet                    │
              │ MP-* → opus                       │
              │ AUDIT-* → opus                    │
              │ TEST-* → haiku                    │
              └───────────────────────────────────┘
```

---

## Context System

```
                    ┌─────────────────────────────────────────────────┐
                    │              Project CLAUDE.md                   │
                    │                                                  │
                    │  @context: base                                  │
                    │  @context: skill-index                           │
                    │  @context: workflow/interactive                  │
                    │  @context: workflow/ralph                        │
                    │  @context: golem-system                          │
                    │                                                  │
                    │  ## Project-Specific Rules                       │
                    │  (unique to this project only)                   │
                    └────────────────────┬────────────────────────────┘
                                         │
                                         │ resolves to
                                         ▼
          ┌──────────────────────────────────────────────────────────────────┐
          │                                                                   │
          │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
          │  │ contexts/       │  │ contexts/       │  │ contexts/       │  │
          │  │ base.md         │  │ workflow/       │  │ golem-system.md │  │
          │  │ ─────────────── │  │ interactive.md  │  │ ─────────────── │  │
          │  │                 │  │ ralph.md        │  │                 │  │
          │  │ • Scratchpad    │  │ ─────────────── │  │ • Philosophy    │  │
          │  │ • AIDEV-NOTE    │  │                 │  │ • Architecture  │  │
          │  │ • Type safety   │  │ • COUNTER       │  │ • Data flow     │  │
          │  │ • Doc fetching  │  │ • Git safety    │  │ • Components    │  │
          │  │                 │  │ • Commit rules  │  │                 │  │
          │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
          │                                                                   │
          │  ┌─────────────────────────────────────────────────────────────┐│
          │  │                 Project-Specific Rules                      ││
          │  │  • File tree structure                                      ││
          │  │  • Custom commands                                          ││
          │  │  • Unique patterns                                          ││
          │  └─────────────────────────────────────────────────────────────┘│
          │                                                                   │
          └──────────────────────────────────────────────────────────────────┘
                                         │
                                         │ Claude receives
                                         ▼
                    ┌─────────────────────────────────────────────────┐
                    │          Full Effective Context                  │
                    │  (base + workflow + tech + project-specific)     │
                    └─────────────────────────────────────────────────┘
```

---

## Skills Architecture

```
          ┌─────────────────────────────────────────────────────────────────┐
          │                         SKILL INVOCATION                         │
          └─────────────────────────────────────────────────────────────────┘
                                         │
                                         │ Skill tool called
                                         ▼
          ┌─────────────────────────────────────────────────────────────────┐
          │  skills/golem-powers/                                            │
          │  ├── prd/                                                        │
          │  │   ├── SKILL.md         ◄── Skill definition loaded           │
          │  │   ├── workflows/                                              │
          │  │   │   └── create.md                                           │
          │  │   └── scripts/                                                │
          │  │       └── init-prd.sh                                         │
          │  │                                                               │
          │  ├── coderabbit/                                                 │
          │  │   ├── SKILL.md                                                │
          │  │   └── workflows/                                              │
          │  │       ├── review.md                                           │
          │  │       └── security.md                                         │
          │  │                                                               │
          │  ├── github/                                                     │
          │  │   └── SKILL.md                                                │
          │  │                                                               │
          │  └── ... (26+ skills)                                            │
          └─────────────────────────────────────────────────────────────────┘
                                         │
                                         │ SKILL.md contents
                                         ▼
          ┌─────────────────────────────────────────────────────────────────┐
          │  Claude receives skill instructions                              │
          │  • What the skill does                                           │
          │  • Commands to run                                               │
          │  • Expected outputs                                              │
          │  • Error handling                                                │
          └─────────────────────────────────────────────────────────────────┘
```

---

## Cost Tracking

```
          ┌─────────────────────────────────────────────────────────────────┐
          │                        COST TRACKING FLOW                        │
          └─────────────────────────────────────────────────────────────────┘

          ┌────────────────┐     ┌────────────────┐     ┌────────────────┐
          │  Iteration     │     │  Model         │     │  Token Usage   │
          │  Starts        │────▶│  Selected      │────▶│  Counted       │
          └────────────────┘     └────────────────┘     └────────────────┘
                                                                │
                                                                ▼
          ┌─────────────────────────────────────────────────────────────────┐
          │  Pricing Applied                                                 │
          │  ────────────────                                                │
          │                                                                  │
          │  Model      │ Input ($/M) │ Output ($/M) │ Cache Create │ Read │
          │  ───────────┼─────────────┼──────────────┼──────────────┼──────│
          │  haiku      │    $1.00    │    $5.00     │    $1.25     │ $0.10│
          │  sonnet     │    $3.00    │   $15.00     │    $3.75     │ $0.30│
          │  opus       │   $15.00    │   $75.00     │   $18.75     │ $1.50│
          └─────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
          ┌─────────────────────────────────────────────────────────────────┐
          │  ~/.config/ralphtools/costs.jsonl                                │
          │  ═══════════════════════════════                                 │
          │                                                                  │
          │  {"timestamp":"2026-01-25T...","storyId":"US-001","model":"sonnet",│
          │   "taskType":"US","durationSeconds":45,"status":"success",       │
          │   "tokens":{"input":52000,"output":8500},"estimatedCost":0.28}   │
          │  {"timestamp":"2026-01-25T...","storyId":"V-001","model":"haiku",│
          │   "taskType":"V","durationSeconds":12,"status":"success",        │
          │   "tokens":{"input":15000,"output":2000},"estimatedCost":0.025}  │
          └─────────────────────────────────────────────────────────────────┘
```

---

## See Also

- [docs/architecture.md](./architecture.md) - Detailed component documentation
- [contexts/golem-system.md](../contexts/golem-system.md) - System philosophy
- [lib/README.md](../lib/README.md) - Module documentation
