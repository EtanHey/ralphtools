# Ralph - The Original AI Coding Loop

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
| `ralph-init` | Create PRD template |
| `ralph-status` | Show PRD status |
| `ralph-stop` | Kill running loops |

### Flags

| Flag | Description |
|------|-------------|
| `-QN` | Enable [ntfy](https://ntfy.sh) notifications |
| `-S` | Use Sonnet (faster, cheaper) |
| `-H` | Use Haiku (fastest, cheapest) |
| `-K` | Use [Kiro CLI](https://kiro.dev/) for US-*/BUG-* stories |

### Model Routing

| Story Type | Model Used |
|------------|------------|
| `V-*` (verification) | Always Claude Haiku (needs browser MCPs) |
| `US-*` (user stories) | Flag-specified model |
| `BUG-*` (bug fixes) | Flag-specified model |

**Example:** `ralph -K 50` runs Kiro for US-*/BUG-* stories, auto-switches to Claude Haiku for V-* stories.

---

## Why Fresh Context?

Long sessions accumulate confusion. Ralph solves this by **spawning fresh Claude every iteration**:
- JSON files ARE the memory
- Checked criteria ARE the state
- No hallucinated memory of non-existent code

---

## Alternative: Kiro CLI

[Kiro CLI](https://kiro.dev/) is AWS's agentic coding assistant — good when you're out of Claude tokens. Ralph uses the CLI (not the IDE) so it can run Kiro in a loop just like Claude Code.

### Free Credits Deal

New users get **500 bonus credits** (30 days) when signing up with:
- GitHub / Google / AWS Builder ID

No AWS account required. ~50% of Kiro Pro's monthly allocation.

```bash
ralph -K 20    # Run with Kiro instead of Claude
```

| Feature | Claude Code | Kiro |
|---------|-------------|------|
| MCP tools | Full support | Limited |
| Context window | Large | Smaller |
| Cost | Per-token | Credit-based |

**Pricing:** Free (50/mo) → Pro $19 (1,000) → Pro+ $39 (3,000)

---

## Requirements

- **zsh** (bash may work)
- **Claude CLI** or **Kiro CLI**
- **git**
- Optional: Chrome + Claude-in-Chrome, ntfy, [Superpowers plugin](https://github.com/obra/superpowers)

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

### v1.3.0
- JSON-based PRD format (`prd-json/`)
- Kiro support (`-K` flag)
- Configuration system (`ralph-config.local`)
- Claude Haiku pre-push hook

### v1.2.0
- Comprehensive docs, skills documentation
- docs.local convention

### v1.1.0
- Browser tab checking, learnings directory

### v1.0.0
- Initial release
