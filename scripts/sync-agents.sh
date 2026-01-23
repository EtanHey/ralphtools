#!/usr/bin/env zsh
#
# Sync AGENTS.md to all AI tool-specific files
# One source of truth, auto-distributed.
#
# Usage: ./scripts/sync-agents.sh [--dry-run] [path-to-agents.md]
#
# Syncs to:
#   - CLAUDE.md
#   - .cursorrules
#   - .windsurfrules
#   - .github/copilot-instructions.md
#
# This script is typically called from the pre-commit hook
# when AGENTS.md is modified.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
AGENTS_FILE=""
REPO_DIR=""

# ═══════════════════════════════════════════════════════════════
# ARGUMENT PARSING
# ═══════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    *)
      AGENTS_FILE="$1"
      shift
      ;;
  esac
done

# ═══════════════════════════════════════════════════════════════
# FIND AGENTS.MD
# ═══════════════════════════════════════════════════════════════

# If no file specified, try to find AGENTS.md in the repo root
if [[ -z "$AGENTS_FILE" ]]; then
  # Try to find repo root via git
  REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [[ -n "$REPO_DIR" ]]; then
    AGENTS_FILE="$REPO_DIR/AGENTS.md"
  else
    echo "${RED}Error: Not in a git repository and no AGENTS.md path provided${NC}"
    exit 1
  fi
else
  # Get repo root from the provided file's directory
  AGENTS_DIR=$(dirname "$AGENTS_FILE")
  REPO_DIR=$(cd "$AGENTS_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "$AGENTS_DIR")
fi

if [[ ! -f "$AGENTS_FILE" ]]; then
  echo "${YELLOW}Warning: AGENTS.md not found at $AGENTS_FILE${NC}"
  echo "${YELLOW}Skipping sync - no source file${NC}"
  exit 0
fi

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BLUE}  📄 Syncing AGENTS.md${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "${YELLOW}[DRY RUN] No files will be modified${NC}"
  echo ""
fi

SYNCED_COUNT=0
STAGED_FILES=()

# ═══════════════════════════════════════════════════════════════
# SYNC FUNCTION
# ═══════════════════════════════════════════════════════════════

sync_file() {
  local target="$1"
  local description="$2"
  local needs_dir="${3:-false}"

  # Handle directory creation for paths like .github/copilot-instructions.md
  local target_dir=$(dirname "$target")
  if [[ "$needs_dir" == "true" && ! -d "$target_dir" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  ${YELLOW}Would create:${NC} $target_dir/"
    else
      mkdir -p "$target_dir"
      echo "  ${GREEN}Created:${NC} $target_dir/"
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  ${YELLOW}Would sync:${NC} $description → $target"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
  else
    cp "$AGENTS_FILE" "$target"
    echo "  ${GREEN}Synced:${NC} $description → $target"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
    STAGED_FILES+=("$target")
  fi
}

# ═══════════════════════════════════════════════════════════════
# SYNC TO ALL TARGETS
# ═══════════════════════════════════════════════════════════════

echo "${YELLOW}Source:${NC} $AGENTS_FILE"
echo ""

# 1. CLAUDE.md (Claude Code)
sync_file "$REPO_DIR/CLAUDE.md" "CLAUDE.md"

# 2. .cursorrules (Cursor IDE)
sync_file "$REPO_DIR/.cursorrules" ".cursorrules"

# 3. .windsurfrules (Windsurf IDE)
sync_file "$REPO_DIR/.windsurfrules" ".windsurfrules"

# 4. .github/copilot-instructions.md (GitHub Copilot)
sync_file "$REPO_DIR/.github/copilot-instructions.md" ".github/copilot-instructions.md" true

echo ""

# ═══════════════════════════════════════════════════════════════
# AUTO-STAGE SYNCED FILES
# ═══════════════════════════════════════════════════════════════

if [[ "$DRY_RUN" != "true" && ${#STAGED_FILES[@]} -gt 0 ]]; then
  echo "${YELLOW}Staging synced files...${NC}"
  for file in "${STAGED_FILES[@]}"; do
    git add "$file"
    echo "  ${GREEN}Staged:${NC} $file"
  done
  echo ""
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "${GREEN}  ✓ Would sync $SYNCED_COUNT file(s)${NC}"
else
  echo "${GREEN}  ✓ Synced $SYNCED_COUNT file(s) from AGENTS.md${NC}"
fi
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
