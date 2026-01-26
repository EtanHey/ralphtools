# Local Models Reference

Models used across Ralph (claude-golem) and Zikaron projects.

## Currently Installed (Ollama)

| Model | Size | Purpose |
|-------|------|---------|
| `qwen3-coder-64k:latest` | 18 GB | Local coding assistant (64k context) |
| `qwen3-coder:latest` | 18 GB | Local coding assistant |
| `qwen2.5-coder:7b` | 4.7 GB | Lighter coding assistant |
| `llama3.1:8b` | 4.9 GB | General purpose local LLM |
| `nomic-embed-text:latest` | 274 MB | Embeddings for Zikaron |

**Total local storage:** ~46 GB

## Usage by Project

### Zikaron (Knowledge Pipeline)

| Model | Purpose |
|-------|---------|
| `nomic-embed-text` | Vector embeddings for semantic search |

Zikaron uses `nomic-embed-text` (274 MB) exclusively for generating embeddings when indexing Claude Code conversations and markdown files.

### Ralph (Autonomous Coding Loop)

Ralph uses **cloud models** via Claude Code CLI, with smart routing by story type:

| Story Type | Model | Use Case |
|------------|-------|----------|
| AUDIT-* | opus | Deep analysis, verification |
| MP-* | opus | Major implementations |
| US-* | sonnet | User stories, features |
| BUG-* | sonnet | Bug fixes |
| V-* | haiku | Quick verifications |
| TEST-* | haiku | Test writing |

**Local model option:** `--model kiro` flag routes to local Ollama models for offline/cost-free operation.

## Cloud vs Local Comparison

| Aspect | Cloud (Claude) | Local (Ollama) |
|--------|----------------|----------------|
| Cost | Per-token billing | Free after download |
| Speed | Fast (API) | Depends on hardware |
| Quality | Best (opus/sonnet) | Good (qwen3-coder) |
| Privacy | Data sent to API | Fully local |
| Offline | No | Yes |

## Model Download Commands

```bash
# Zikaron embeddings (required)
ollama pull nomic-embed-text

# Local coding (optional, for ralph --model kiro)
ollama pull qwen3-coder
ollama pull qwen2.5-coder:7b   # Lighter alternative
ollama pull llama3.1:8b        # General purpose
```

## Storage Locations

- Ollama models: `~/.ollama/models/`
- Zikaron database: `~/.local/share/zikaron/chromadb/`
