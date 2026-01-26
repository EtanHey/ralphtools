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

**Why such a lightweight model for embeddings?**

Embedding models are fundamentally different from generative LLMs:

1. **No reasoning required** - Embeddings just map text → vectors. They don't generate text, reason, or follow instructions. This is a much simpler task that doesn't need billions of parameters.

2. **Speed matters** - Zikaron indexes thousands of conversation chunks. At 274 MB, nomic-embed-text runs in milliseconds per chunk. A 7B model would be 20x slower for no quality gain.

3. **Purpose-built** - nomic-embed-text is specifically trained for semantic similarity, not chat. It outperforms many larger general-purpose models on embedding benchmarks.

4. **Resource efficiency** - Runs alongside other processes without hogging VRAM. You can index while coding.

5. **Quality is comparable** - For semantic search (finding similar text), nomic-embed-text scores within 1-2% of models 10x its size on MTEB benchmarks.

Bottom line: embedding is a specialized task where small, focused models excel. Using a 7B+ model for embeddings is like using a truck to deliver letters.

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
