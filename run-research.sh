#!/bin/bash
#
# Self-contained codebase research - works with Gemini, Ollama, or Aider
# All context inlined - no file reference issues
#
# Usage:
#   ./run-research.sh gemini       # Use Gemini CLI (interactive)
#   ./run-research.sh ollama       # Use Ollama large (qwen3-coder, 30B)
#   ./run-research.sh ollama-small # Use Ollama small (qwen2.5-coder:7b, fast!)
#   ./run-research.sh aider        # Use Aider+Ollama (can write files!)
#

cd "$(dirname "$0")" || exit 1

MODE="${1:-gemini}"

# Build the full prompt with all context inlined
read -r -d '' SYSTEM_PROMPT << 'SYSPROMPT'
You are a senior software architect and documentation specialist.

## YOUR MISSION
Audit this codebase to find EVERY undocumented feature, command, flag, and capability. Create comprehensive documentation.

## ABOUT THIS PROJECT
This is **Ralph** (claude-golem) - an autonomous AI coding loop for Claude Code.

Core loop:
```
while stories remain:
  spawn fresh Claude → read prd-json/ → implement story → CodeRabbit review → commit
done
```

### How Claude Code Works (IMPORTANT CONTEXT)

**CLAUDE.md files** = Instructions FOR the AI (not humans)
- ~/.claude/CLAUDE.md → Global
- ./CLAUDE.md → Project-level
- Auto-loaded as system context

**Skills** = Reusable prompts in ~/.claude/commands/
```
~/.claude/commands/golem-powers/
├── prd/
│   ├── SKILL.md        ← Loaded when user types /golem-powers:prd
│   └── scripts/        ← Optional shell scripts
└── coderabbit/
    └── SKILL.md
```

**Contexts** = Composable rules referenced via @context: base, @context: tech/nextjs

### Directory Structure
```
claude-golem/
├── ralph.zsh           # Main entry - ALL COMMANDS HERE
├── lib/                # Modular zsh library - HIDDEN FEATURES HERE
├── ralph-ui/           # React Ink dashboard
├── bun/                # TypeScript story management
├── skills/golem-powers/# Skills for Claude
├── contexts/           # Shared CLAUDE.md rules
├── prompts/            # Story-type prompts (US.md, BUG.md)
└── scripts/            # Utility scripts
```

## YOUR TASK

### Phase 1: Audit Every File
For each script/module, document:
1. What it does
2. Commands/functions exposed
3. Flags/options available
4. Environment variables used
5. Undocumented features

### Phase 2: Create Output Files
Create these files with your findings (use the PREFIX provided):
- {PREFIX}-codebase-audit.md - Complete audit
- {PREFIX}-documentation-gaps.md - What's missing from README
- {PREFIX}-readme-outline.md - Proposed improved structure

## HOW TO WORK
1. Run: tree -L 2 -I node_modules (or ls -la if tree unavailable)
2. Read ralph.zsh first - find all commands and flags
3. Read each lib/*.zsh file - find helper functions
4. Read skills/golem-powers/*/SKILL.md - document each skill
5. Compare against README.md - find gaps

## OUTPUT FORMAT
Be thorough. Document EVERYTHING. Use markdown tables for clarity.

YOUR OUTPUT PREFIX: {PREFIX}
Name all output files starting with this prefix.

## RESUMING (IMPORTANT!)
Before starting, CHECK if these files already exist:
- {PREFIX}-codebase-audit.md
- {PREFIX}-documentation-gaps.md
- {PREFIX}-readme-outline.md

If they exist, READ THEM FIRST. They contain your previous work.
Then CONTINUE where you left off - don't repeat what's already documented.
If a file is incomplete, finish it. If it's complete, move to the next one.

{EXISTING_WORK}

START NOW. First check for existing files, then continue or begin fresh.
SYSPROMPT

# Set prefix based on mode
if [ "$MODE" = "ollama" ]; then
    PREFIX="ollama"
elif [ "$MODE" = "ollama-small" ]; then
    PREFIX="ollama-small"
elif [ "$MODE" = "gemini" ]; then
    PREFIX="gemini"
elif [ "$MODE" = "aider" ]; then
    PREFIX="aider"
else
    PREFIX="ai"
fi

# Replace {PREFIX} in the prompt
SYSTEM_PROMPT="${SYSTEM_PROMPT//\{PREFIX\}/$PREFIX}"

# Check for existing work and include it
EXISTING_WORK=""
for file in "${PREFIX}-codebase-audit.md" "${PREFIX}-documentation-gaps.md" "${PREFIX}-readme-outline.md"; do
    if [ -f "$file" ]; then
        echo "Found existing: $file"
        EXISTING_WORK="${EXISTING_WORK}

### EXISTING FILE: $file
\`\`\`
$(head -100 "$file")
\`\`\`
(truncated to first 100 lines - read full file to continue)
"
    fi
done

if [ -n "$EXISTING_WORK" ]; then
    echo ""
    echo ">>> RESUMING from previous work <<<"
    SYSTEM_PROMPT="${SYSTEM_PROMPT//\{EXISTING_WORK\}/Previous work found:$EXISTING_WORK}"
else
    SYSTEM_PROMPT="${SYSTEM_PROMPT//\{EXISTING_WORK\}/No previous work found. Starting fresh.}"
fi

echo "============================================"
echo "  Codebase Research - Mode: $MODE"
echo "  Output prefix: $PREFIX-*"
echo "============================================"
echo ""

if [ "$MODE" = "ollama" ]; then
    # Check if Ollama is running
    if ! ollama list &>/dev/null; then
        echo "Starting Ollama..."
        ollama serve &>/dev/null &
        sleep 3
    fi

    # Check for model - prefer 64k context version, then qwen3-coder
    if ollama list 2>/dev/null | grep -q "qwen3-coder-64k"; then
        MODEL="qwen3-coder-64k"
    elif ollama list 2>/dev/null | grep -q "qwen3-coder"; then
        MODEL="qwen3-coder"
    else
        MODEL="qwen2.5-coder:14b"
    fi
    MODEL_SHORT="${MODEL//:/-}"  # filename safe version

    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
        echo "Model $MODEL not found. Pulling (this takes a while)..."
        ollama pull "$MODEL"
    fi

    echo "============================================"
    echo "  Ollama Research (Large/Thorough)"
    echo "  Model: $MODEL (~20GB RAM)"
    echo "  Output: ${MODEL_SHORT}-output.md"
    echo "============================================"
    echo ""

    # Run and capture output (strip ANSI escape codes for clean file)
    ollama run "$MODEL" "$SYSTEM_PROMPT" 2>&1 | \
        python3 -c "import sys,re; [print(re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]|[\x0d]', '', line), end='') for line in sys.stdin]" | \
        tee "${MODEL_SHORT}-output.md"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Model: $MODEL"
    echo "  Output saved to: ${MODEL_SHORT}-output.md"
    echo "═══════════════════════════════════════════════════════════════"

elif [ "$MODE" = "ollama-small" ]; then
    # Small/fast Ollama model - runs alongside the big one
    MODEL="qwen2.5-coder:7b"
    MODEL_SHORT="${MODEL//:/-}"  # qwen2.5-coder-7b (filename safe)
    RUN_ID=$(date +%H%M%S)        # Unique per run (e.g., 153042)
    OUTPUT_FILE="${MODEL_SHORT}-${RUN_ID}-output.md"

    # Check if Ollama is running
    if ! ollama list &>/dev/null; then
        echo "Starting Ollama..."
        ollama serve &>/dev/null &
        sleep 3
    fi

    # Pull model if needed
    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
        echo "Model $MODEL not found. Pulling (~4GB)..."
        ollama pull "$MODEL"
    fi

    echo "============================================"
    echo "  Ollama Research (Small/Fast)"
    echo "  Model: $MODEL (~5GB RAM)"
    echo "  Run ID: $RUN_ID"
    echo "  Output: $OUTPUT_FILE"
    echo "============================================"
    echo ""

    # Run with streaming (can see progress) and clean output
    ollama run "$MODEL" "$SYSTEM_PROMPT" 2>&1 | \
        python3 -c "import sys,re; [print(re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]|[\x0d]', '', line), end='') for line in sys.stdin]" | \
        tee "$OUTPUT_FILE"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Model: $MODEL"
    echo "  Run ID: $RUN_ID"
    echo "  Output saved to: $OUTPUT_FILE"
    echo "═══════════════════════════════════════════════════════════════"

elif [ "$MODE" = "gemini" ]; then
    echo "Launching Gemini CLI..."
    echo "Tip: If you hit rate limits, wait a few seconds between commands."
    echo ""

    # Use gemini with the prompt directly
    gemini -y -p "$SYSTEM_PROMPT"

elif [ "$MODE" = "aider" ]; then
    # Check if Ollama is running
    if ! ollama list &>/dev/null; then
        echo "Starting Ollama..."
        ollama serve &>/dev/null &
        sleep 3
    fi

    # Check for model - prefer 64k context version, then qwen3-coder
    if ollama list 2>/dev/null | grep -q "qwen3-coder-64k"; then
        MODEL="ollama/qwen3-coder-64k"
    elif ollama list 2>/dev/null | grep -q "qwen3-coder"; then
        MODEL="ollama/qwen3-coder"
    else
        MODEL="ollama/qwen2.5-coder:14b"
    fi

    echo "============================================"
    echo "  Aider + Ollama Research Mode"
    echo "  Model: $MODEL"
    echo "  Output prefix: ${PREFIX}-*"
    echo "============================================"
    echo ""
    echo "Aider CAN:"
    echo "  - Read and write files directly"
    echo "  - Run shell commands (tree, grep, etc.)"
    echo "  - Create multiple output files"
    echo ""

    # Create a context file with FULL skills context (same as Claude gets)
    CONTEXT_FILE="/tmp/aider-research-context.md"
    cat > "$CONTEXT_FILE" << 'CONTEXT'
# Full Claude Context for Aider

You have access to the same skills and tools that Claude Code uses.

## Skills System

Skills are reusable prompts with optional scripts. They live in:
- `~/.claude/commands/golem-powers/` (installed)
- `./skills/golem-powers/` (source, in this repo)

Each skill has:
- `SKILL.md` - Instructions and documentation
- `scripts/` (optional) - Shell scripts you can run

### To USE a skill:
1. Read its SKILL.md to understand what it does
2. Run its scripts if it has any

### Key Skills for Research:

| Skill | Path | Purpose |
|-------|------|---------|
| github-research | `skills/golem-powers/github-research/` | Systematic repo exploration |
| context7 | `skills/golem-powers/context7/` | Library documentation lookup |
| critique-waves | `skills/golem-powers/critique-waves/` | Multi-pass verification |

### Available Scripts:
```bash
# Web search
./scripts/web-search.sh "query"

# GitHub research (explores repos)
./skills/golem-powers/github-research/scripts/explore.sh . docs.local
./skills/golem-powers/github-research/scripts/explore-related.sh

# Context7 library docs (if configured)
# Read skills/golem-powers/context7/SKILL.md for usage
```

## Your Task

1. **Read the skills first** - Check `skills/golem-powers/` to see what tools you have
2. **Use the github-research skill** - Run its scripts to explore the codebase
3. **Create findings in docs.local/** - That's where research output goes
4. **Be thorough** - Read actual files, run actual commands, don't guess

## Related Projects to Explore

| Project | Path | Purpose |
|---------|------|---------|
| ralph-ui | `./ralph-ui/` | React Ink dashboard |
| bun | `./bun/` | TypeScript story management |
| zikaron | `~/Gits/zikaron/` | Vector embeddings (if exists) |
CONTEXT

    echo "Launching Aider..."
    echo "Type your requests, or let it work on the initial prompt."
    echo ""

    # Build read args - include skill index if it exists
    READ_ARGS=(
        --read "$CONTEXT_FILE"
        --read "CLAUDE.md"
        --read "README.md"
    )
    [ -f "$HOME/.claude/skill-index.md" ] && READ_ARGS+=(--read "$HOME/.claude/skill-index.md")
    [ -f "$HOME/.claude/skill-descriptions.md" ] && READ_ARGS+=(--read "$HOME/.claude/skill-descriptions.md")

    # Write message to temp file (avoids quoting issues with long prompts)
    MSG_FILE="/tmp/aider-research-message.txt"
    cat > "$MSG_FILE" << 'AIDERMSG'
Research this codebase using the skills available.

STEP 1: Run this command to see available skills:
ls skills/golem-powers/

STEP 2: Read the github-research skill:
cat skills/golem-powers/github-research/SKILL.md

STEP 3: Run the exploration scripts:
./skills/golem-powers/github-research/scripts/explore.sh . docs.local
./skills/golem-powers/github-research/scripts/explore-related.sh

STEP 4: Read the generated files in docs.local/ and create your analysis:
- docs.local/aider-codebase-audit.md - All commands and features found
- docs.local/aider-config-issues.md - Any issues found
- docs.local/aider-readme-improvements.md - README gaps
- docs.local/aider-proposed-readme.md - Write a FULL improved README

IMPORTANT: Actually READ files and RUN commands. Don't guess.
AIDERMSG

    # Run Aider with Ollama backend (git enabled for research, no auto-commits)
    aider \
        --model "$MODEL" \
        --no-auto-commits \
        --yes-always \
        --no-stream \
        --no-show-model-warnings \
        --no-show-release-notes \
        "${READ_ARGS[@]}" \
        --message-file "$MSG_FILE"

else
    echo "Usage: ./run-research.sh [gemini|ollama|ollama-small|aider]"
    echo ""
    echo "Modes:"
    echo "  gemini       - Gemini CLI (interactive)"
    echo "  ollama       - Ollama large (qwen3-coder 30B, slow, thorough)"
    echo "  ollama-small - Ollama small (qwen2.5-coder 7B, fast!)"
    echo "  aider        - Aider + Ollama (can write files)"
    exit 1
fi
