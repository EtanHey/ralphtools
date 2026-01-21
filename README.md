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

### Model Flags

Specify up to two model flags: **first = main stories**, **second = verification stories**.

| Flag | Model | Browser MCPs |
|------|-------|--------------|
| `-O` | Claude Opus (default) | ✅ |
| `-S` | Claude Sonnet | ✅ |
| `-H` | Claude Haiku | ✅ |
| `-K` | [Kiro CLI](https://kiro.dev/) | ⚡️ (Internal Fallback) |
| `-G` | [Gemini CLI](https://github.com/google-gemini/gemini-cli) | ✅ |

### Examples

```bash
ralph 50              # Opus main, Haiku verify (default)
ralph 50 -G -H        # Gemini main, Haiku verify
ralph 50 -K -G        # Kiro main, Gemini verify
ralph 50 -G -G        # Gemini for all stories
```

---

## Why Fresh Context?

Long sessions accumulate confusion. Ralph solves this by **spawning fresh Claude every iteration**:
- JSON files ARE the memory
- Checked criteria ARE the state
- No hallucinated memory of non-existent code

---

## Alternative: Kiro CLI

[Kiro CLI](https://kiro.dev/) is AWS's agentic coding assistant — good when you're out of Claude tokens. Ralph uses the CLI (not the IDE) so it can run Kiro in a loop just like Claude Code.

**Note:** Ralph includes an internal **Brave Browser Manager** (`scripts/brave-manager.js`) that allows Kiro to perform browser verification even though it lacks native MCP support.

### Free Credits Deal

New users get **500 bonus credits** (30 days) when signing up with:
- GitHub / Google / AWS Builder ID

No AWS account required. ~50% of Kiro Pro's monthly allocation.

```bash
ralph -K 20    # Run with Kiro instead of Claude
```

| Feature | Claude Code | Kiro |
|---------|-------------|------|
| MCP tools | Full support | Limited (Ralph Fallback ✅) |
| Context window | Large | Smaller |
| Cost | Per-token | Credit-based |

---

## Alternative: Gemini CLI

[Gemini CLI](https://github.com/google-gemini/gemini-cli) is Google's AI terminal agent. Unlike Kiro, it **has browser MCPs** via chrome-devtools-mcp, so it can handle V-* verification stories.

**Note:** If the native MCP fails (common with Brave), Ralph will automatically fall back to the internal **Brave Browser Manager**.

---

## Requirements

- **zsh** (bash may work)
- **Claude CLI**, **Kiro CLI**, or **Gemini CLI**
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

### v1.4.0
- Internal Brave Browser Manager fallback (`scripts/brave-manager.js`)
- Kiro browser verification support via fallback
- Dynamic Gemini model selection (`-G-gemini-3-flash-preview`)
- Model-aware completions (`completedBy` field in JSON)

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
