#!/bin/bash
#
# Self-contained codebase research - works with Gemini or Ollama
# All context inlined - no file reference issues
#
# Usage:
#   ./run-research.sh gemini    # Use Gemini CLI
#   ./run-research.sh ollama    # Use Ollama (qwen2.5-coder:14b)
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
elif [ "$MODE" = "gemini" ]; then
    PREFIX="gemini"
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

    # Check for model - prefer qwen3-coder if available
    if ollama list 2>/dev/null | grep -q "qwen3-coder"; then
        MODEL="qwen3-coder"
    else
        MODEL="qwen2.5-coder:14b"
    fi
    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
        echo "Model $MODEL not found. Pulling (this takes a while)..."
        ollama pull "$MODEL"
    fi

    echo "Launching Ollama with $MODEL..."
    echo "Output will be saved to: ${PREFIX}-output.md"
    echo ""

    # Run and capture output (tee shows it AND saves it)
    ollama run "$MODEL" "$SYSTEM_PROMPT" 2>&1 | tee "${PREFIX}-output.md"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Output saved to: ${PREFIX}-output.md"
    echo "═══════════════════════════════════════════════════════════════"

elif [ "$MODE" = "gemini" ]; then
    echo "Launching Gemini CLI..."
    echo "Tip: If you hit rate limits, wait a few seconds between commands."
    echo ""

    # Use gemini with the prompt directly
    gemini -y -p "$SYSTEM_PROMPT"

else
    echo "Usage: ./run-research.sh [gemini|ollama]"
    exit 1
fi
