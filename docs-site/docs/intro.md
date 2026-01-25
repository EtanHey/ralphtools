---
sidebar_position: 1
title: Introduction
slug: /
---

# Ralph Documentation

Ralph is an autonomous AI coding agent that runs Claude in a loop to execute PRD (Product Requirements Document) stories. It's designed for developers who want to leverage AI for autonomous code generation with proper task tracking and verification.

## What is Ralph?

Ralph takes a PRD with acceptance criteria and executes each story autonomously:

1. **Reads** the current PRD state from `prd-json/`
2. **Executes** the next pending story
3. **Marks** criteria as complete as it works
4. **Commits** changes when done
5. **Loops** until all stories are complete or blocked

## Quick Start

```bash
# Install Ralph
git clone https://github.com/etanheyman/claude-golem.git ~/.config/claude-golem
source ~/.config/claude-golem/ralph.zsh

# Initialize a PRD in your project
ralph-init

# Run Ralph for 50 iterations
ralph 50
```

## Key Features

- **Autonomous Execution**: Ralph runs without human intervention until completion
- **JSON-based PRDs**: Structured story format with acceptance criteria
- **Smart Model Routing**: Automatically selects Claude model based on task type
- **Live Progress Updates**: Real-time progress bars in terminal
- **Session Isolation**: Keep your Claude sessions clean with worktree mode
- **Push Notifications**: Get notified via ntfy.sh when Ralph needs attention

## Documentation Sections

| Section | Description |
|---------|-------------|
| [Configuration](./configuration.md) | Environment variables, config files, and options |
| [PRD Format](./prd-format.md) | JSON story format and criteria structure |
| [Skills](./skills.md) | Available skills and how to use them |
| [Workflows](./workflows.md) | Story splitting, blocked tasks, learnings |
| [Live Updates](./live-updates.md) | Real-time progress monitoring |
| [MCP Tools](./mcp-tools.md) | Browser automation and verification |
| [Session Isolation](./session-isolation.md) | Worktree mode for clean sessions |

## Commands

| Command | Description |
|---------|-------------|
| `ralph [N]` | Run N iterations on PRD |
| `ralph-init` | Create PRD template |
| `ralph-status` | Show PRD status |
| `ralph-live` | Watch progress in real-time |
| `ralph-archive` | Archive completed stories |
| `ralph-setup` | Configure Ralph settings |

## Getting Help

- [GitHub Issues](https://github.com/etanheyman/claude-golem/issues) - Report bugs or request features
- [Skills Reference](./skills.md) - Learn about available skills
- [Troubleshooting](./mcp-tools.md#troubleshooting) - Common issues and fixes
