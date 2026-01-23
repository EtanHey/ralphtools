#!/usr/bin/env zsh
#
# Install AGENTS.md sync hooks for a project
# Sets up pre-commit hook to auto-sync AGENTS.md to all AI tool files.
#
# Usage: install-hooks.sh [project-path]
#   project-path: Path to the project root (default: current directory)
#
# This script:
#   1. Creates/updates .githooks/pre-commit to call sync-agents.sh
#   2. Configures git to use the .githooks directory
#   3. Makes the hook executable
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get the directory where this script lives (ralph scripts dir)
SCRIPT_DIR="${0:A:h}"
SYNC_SCRIPT="$SCRIPT_DIR/sync-agents.sh"

# Project directory (default: current directory)
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="${PROJECT_DIR:A}"  # Resolve to absolute path

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BLUE}  🔧 Installing AGENTS.md Sync Hooks${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
# VALIDATE PROJECT
# ═══════════════════════════════════════════════════════════════

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "${RED}Error: Directory not found: $PROJECT_DIR${NC}"
  exit 1
fi

cd "$PROJECT_DIR"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "${RED}Error: Not a git repository: $PROJECT_DIR${NC}"
  exit 1
fi

echo "${YELLOW}Project:${NC} $PROJECT_DIR"
echo ""

# ═══════════════════════════════════════════════════════════════
# CREATE .githooks DIRECTORY
# ═══════════════════════════════════════════════════════════════

HOOKS_DIR="$PROJECT_DIR/.githooks"
if [[ ! -d "$HOOKS_DIR" ]]; then
  mkdir -p "$HOOKS_DIR"
  echo "  ${GREEN}Created:${NC} .githooks/"
fi

# ═══════════════════════════════════════════════════════════════
# CREATE/UPDATE PRE-COMMIT HOOK
# ═══════════════════════════════════════════════════════════════

PRE_COMMIT="$HOOKS_DIR/pre-commit"
HOOK_MARKER="# AGENTS.md sync hook"

# Check if hook already exists
if [[ -f "$PRE_COMMIT" ]]; then
  # Check if our hook is already installed
  if grep -q "$HOOK_MARKER" "$PRE_COMMIT"; then
    echo "  ${GREEN}✓${NC} AGENTS.md sync hook already installed"
  else
    # Append our hook to existing pre-commit
    echo "" >> "$PRE_COMMIT"
    cat >> "$PRE_COMMIT" << 'HOOK_END'

# ═══════════════════════════════════════════════════════════════
# AGENTS.md sync hook
# Syncs AGENTS.md to CLAUDE.md, .cursorrules, .windsurfrules,
# and .github/copilot-instructions.md when AGENTS.md is modified.
# ═══════════════════════════════════════════════════════════════

# Check if AGENTS.md is staged for this commit
if git diff --cached --name-only | grep -q '^AGENTS\.md$'; then
  echo ""
  echo "${YELLOW}[AGENTS.md Sync]${NC}"

  # Find sync-agents.sh (check common locations)
  SYNC_SCRIPT=""
  if [[ -f "$HOME/.config/ralphtools/scripts/sync-agents.sh" ]]; then
    SYNC_SCRIPT="$HOME/.config/ralphtools/scripts/sync-agents.sh"
  elif [[ -f "$(git rev-parse --show-toplevel)/scripts/sync-agents.sh" ]]; then
    SYNC_SCRIPT="$(git rev-parse --show-toplevel)/scripts/sync-agents.sh"
  fi

  if [[ -n "$SYNC_SCRIPT" && -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT"
  else
    echo "  ${YELLOW}Warning: sync-agents.sh not found or not executable${NC}"
    echo "  ${YELLOW}AGENTS.md changes will not be synced to other files${NC}"
  fi
fi
HOOK_END
    echo "  ${GREEN}✓${NC} Added AGENTS.md sync to existing pre-commit hook"
  fi
else
  # Create new pre-commit hook
  cat > "$PRE_COMMIT" << 'HOOK_START'
#!/usr/bin/env zsh
#
# Pre-commit hook with AGENTS.md sync
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════
# AGENTS.md sync hook
# Syncs AGENTS.md to CLAUDE.md, .cursorrules, .windsurfrules,
# and .github/copilot-instructions.md when AGENTS.md is modified.
# ═══════════════════════════════════════════════════════════════

# Check if AGENTS.md is staged for this commit
if git diff --cached --name-only | grep -q '^AGENTS\.md$'; then
  echo ""
  echo "${YELLOW}[AGENTS.md Sync]${NC}"

  # Find sync-agents.sh (check common locations)
  SYNC_SCRIPT=""
  if [[ -f "$HOME/.config/ralphtools/scripts/sync-agents.sh" ]]; then
    SYNC_SCRIPT="$HOME/.config/ralphtools/scripts/sync-agents.sh"
  elif [[ -f "$(git rev-parse --show-toplevel)/scripts/sync-agents.sh" ]]; then
    SYNC_SCRIPT="$(git rev-parse --show-toplevel)/scripts/sync-agents.sh"
  fi

  if [[ -n "$SYNC_SCRIPT" && -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT"
  else
    echo "  ${YELLOW}Warning: sync-agents.sh not found or not executable${NC}"
    echo "  ${YELLOW}AGENTS.md changes will not be synced to other files${NC}"
  fi
fi
HOOK_START
  echo "  ${GREEN}Created:${NC} .githooks/pre-commit"
fi

# Make hook executable
chmod +x "$PRE_COMMIT"
echo "  ${GREEN}✓${NC} Made pre-commit hook executable"

# ═══════════════════════════════════════════════════════════════
# CONFIGURE GIT
# ═══════════════════════════════════════════════════════════════

echo ""
echo "${YELLOW}Configuring git...${NC}"
git config core.hooksPath .githooks
echo "  ${GREEN}✓${NC} Set core.hooksPath to .githooks"

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}  ✓ AGENTS.md sync hooks installed!${NC}"
echo ""
echo "  When you commit changes to AGENTS.md, it will automatically sync to:"
echo "    • ${CYAN}CLAUDE.md${NC} (Claude Code)"
echo "    • ${CYAN}.cursorrules${NC} (Cursor IDE)"
echo "    • ${CYAN}.windsurfrules${NC} (Windsurf IDE)"
echo "    • ${CYAN}.github/copilot-instructions.md${NC} (GitHub Copilot)"
echo ""
echo "  All synced files will be auto-staged with your commit."
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
