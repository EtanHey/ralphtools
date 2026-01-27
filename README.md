# 🤖 Claude Golem (Ralph)

### *The Autonomous Engineering Loop for Claude Code*

[![Shell](https://img.shields.io/badge/Shell-Zsh-blue.svg)](https://www.zsh.org/)
[![Runtime](https://img.shields.io/badge/Runtime-Bun-black.svg)](https://bun.sh/)
[![Engine](https://img.shields.io/badge/Engine-Claude--Code-orange.svg)](https://github.com/anthropics/claude-code)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Claude Golem** (codenamed `ralph`) is an autonomous wrapper and context-engineering framework for [Claude Code](https://github.com/anthropics/claude-code). It transforms Claude from a chat-based assistant into a persistent, self-correcting agent capable of executing complex PRDs through iterative development loops.

---

## ✨ Key Features

- **🔄 Autonomous Iteration:** Runs Claude in a continuous loop with self-correction and state persistence.
- **📊 Real-time Dashboard:** A React-based TUI (built with Bun/Ink) to monitor progress, costs, and model performance.
- **🛡️ Process Management:** Built-in tools to manage worktrees, clean up orphaned processes, and handle "context rot."
- **🔀 Smart Model Routing:** Automatically switch between Opus (planning), Sonnet (implementation), and Haiku (validation) to optimize cost and speed.
- **🔐 1Password Integration:** Securely injects environment variables and API keys directly from your vaults.
- **📋 Spec-Driven Workflow:** Native support for User Stories (US), Bugs, and PRDs with automated context loading.

---

## 🚀 Quick Start

### 1. Installation
Clone the repository and run setup:
```bash
git clone https://github.com/EtanHey/claude-golem.git ~/Gits/claude-golem
cd ~/Gits/claude-golem

# Run the interactive setup wizard (creates ~/.config/ralphtools/)
source ralph.zsh && ralph-setup
```

### 2. Configuration

Ralph stores its configuration in `~/.config/ralphtools/config.json`.
The setup wizard will help you configure:

* Your default model (Sonnet, Opus, etc.)
* Notification settings (via `ntfy.sh`)
* 1Password vault references

### 3. First Run

Start an autonomous loop for 50 iterations using Sonnet:

```bash
ralph 50 -S    # -S for Sonnet, -O for Opus
```

---

## 🛠 Command Reference

| Command | Description |
| --- | --- |
| `ralph [n]` | Start the autonomous loop for `n` iterations (Default: 100). |
| `ralph-start` | Initialize an isolated worktree for a new feature or bug. |
| `ralph-status` | Show live progress, current iteration, and session health. |
| `ralph-live` | Open the live React-Ink dashboard for the current session. |
| `ralph-logs` | View and tail crash logs or system errors. |
| `ralph-stop` | Gracefully stop the current Ralph session. |
| `ralph-kill-orphans` | Force-kill stuck `fswatch` or `bun` processes. |
| `ralph-cleanup` | Finish a session, merge the worktree, and clean up. |
| `ralph-costs` | Show estimated token usage and cost for the current session. |
| `ralph-init` | Generate a PRD and project context from a prompt file. |

---

## 📂 Project Structure & Workflow

### The "Story" Workflow

Ralph is optimized for a **Spec-Driven** approach. Before running the agent:

1. **Define:** Create a markdown file in `prompts/` (e.g., `prompts/US-123.md`).
2. **Initialize:** Run `ralph-init` to generate the PRD and project context.
3. **Execute:** Run `ralph` to begin the implementation loop.

### Directory Layout

* `lib/`: Core Zsh modules and command logic.
* `ralph-ui/`: TypeScript/Ink dashboard source code.
* `skills/`: Custom "Golem Powers" (MCP-like skills) injected into Claude.
* `contexts/`: Shared rules (like `CLAUDE.md`) for different project types.

---

## ⚙️ Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `RALPH_CONFIG_DIR` | `~/.config/ralphtools` | Primary configuration and library directory. |
| `RALPH_DEFAULT_MODEL` | `claude-3-5-sonnet` | Default model for autonomous execution. |
| `RALPH_NTFY_TOPIC` | *(None)* | Topic name for mobile/desktop notifications. |
| `RALPH_MAX_ITERATIONS` | `100` | Safety limit for autonomous loops. |
| `RALPH_NOTIFY` | `false` | Enable/disable system notifications. |

---

## 🧩 Advanced Features

### Smart Model Routing

Use flags to override the default model for specific tasks:

* `-O`: Opus - best for architecture and complex debugging
* `-S`: Sonnet - the default for implementation
* `-K`: Kiro - local LLMs via Ollama (qwen3-coder)
* `-G`: Gemini - Google's models via Gemini CLI

Smart routing auto-selects: `AUDIT`→Opus, `US`→Sonnet, `V/TEST`→Haiku

### 1Password Secrets

Ralph can fetch your `ANTHROPIC_API_KEY` securely. In your `config.json`:

```json
{
  "secrets": {
    "ANTHROPIC_API_KEY": "op://Private/Anthropic/credential"
  }
}

```

### Process Monitoring & Cleanup

If a session hangs, use `ralph-watch` to see the raw sub-agent output, or `ralph-kill-orphans --all` to reset the environment by clearing untracked `fswatch` and `bun` processes.

---

## 🤝 Contributing

1. Check `ralph-logs` for any current system bugs.
2. Run `ralph-terminal-check` to verify your environment.
3. Use the spec-driven workflow: create story in `prd-json/`, run `ralph`.

---

## The Ecosystem

This harness is part of a local-first development suite designed for rapid iteration:

* **[Zikaron](https://github.com/EtanHey/zikaron):** The memory engine. It indexes the conversation logs generated by this harness, providing a searchable local knowledge base of your agentic workflows.
* **[Songscript](https://github.com/EtanHey/songscript):** The proof of concept. A language-learning application built from the ground up using the Claude Golem autonomous loop.

---

## 🔄 Changelog

### v2.0.0
**Major architecture update with React Ink UI, modular codebase, and layered prompts.**
> **Note:** Repository renamed from `ralphtools` to `claude-golem` as part of this release to better reflect the project's scope as a Claude Code extension ecosystem.

-   **React Ink UI** is now the default runtime - modern terminal dashboard with live-updating progress.
-   **Modular codebase:** `Ralph.zsh` split into `lib/*.zsh` modules for maintainability.
-   **Layered AGENTS prompt:** Story-type-specific prompts (US.md, BUG.md, V.md, etc.) on top of `base.md`.
-   **`AGENTS.md` auto-update:** Prompts automatically refresh when skills are added/modified.
-   **CodeRabbit → BUG integration:** CR findings automatically become BUG stories if unfixable.
-   **`MP` story type:** Master Plan stories for infrastructure/architecture work.
-   **Comprehensive test suite:** 156+ ZSH tests + 83 Bun tests run on pre-commit.
-   **Context injection tests:** Verify modular context system integrity.
-   Config-driven approach: `ralph-setup` wizard replaces flag-heavy CLI.
-   Orphan process cleanup and crash logging (`ralph-logs`, `ralph-kill-orphans`).
-   Docusaurus documentation site at etanheyman.github.io/claude-golem/.

### v1.5.0
-   **`golem-powers` skills:** Unified skill namespace with executable pattern (`SKILL.md` + `scripts/`).
-   **Modular context system:** Layered `CLAUDE.md` with auto-detection (MP-002).
-   **`prd-manager` skill:** Atomic PRD operations (add-to-index, add-criterion, etc.).
-   **1Password vault organization:** Development vault for global tools, project vaults.
-   **Commit conventions:** Story-type based (feat/fix/test/refactor).
-   **TDD verification stories:** V-016/V-017 audit with failing tests first.
-   Skills migrated: context7, coderabbit, linear, worktrees, github, 1password.
-   Deprecated: `update` skill (replaced by `prd-manager`).

### v1.4.0
-   **Smart Model Routing:** `AUDIT`→`opus`, `US`→`sonnet`, `V`→`haiku`, story-level `"model"` override.
-   **Live criteria sync:** `fswatch` file watching, ANSI cursor updates (no flash).
-   **1Password Environments:** `op run --env-file` integration, `ralph-secrets` command.
-   **`ralph-setup` wizard:** `gum`-based first-run experience.
-   **Test framework:** zsh test suite with unit tests for config, cost tracking, notifications.
-   Per-iteration cost tracking with model-aware pricing.
-   Progress bars and compact output mode.

### v1.3.0
-   **JSON-based PRD format** (`prd-json/` replaces markdown PRD).
-   **Smart model routing** for story types (auto-select appropriate model).
-   **Configuration system** (`ralph-config.local` for project settings).
-   **Archive skill** (`/archive` command pointing to `ralph-archive`).

### v1.2.0
-   **Comprehensive documentation** rewrite for open source release.
-   **Skills documentation** with `/prd`, `/archive` commands.
-   **`docs.local` convention** for project-specific learnings.

### v1.1.0
-   **Browser tab checking** for MCP verification stories.
-   **Learnings directory** support (`docs.local/learnings/`).
-   **Pre-commit/pre-push hooks** with Claude Haiku validation.

### v1.0.0
-   Initial Ralph tooling release.
-   Core loop: spawn fresh Claude, read PRD, implement story, commit.
-   `ntfy` notification support (`-QN` flag).

---

## ⚖️ License

MIT © EtanHey

---

### *“Give Claude a body, and it will build you a world.”*
