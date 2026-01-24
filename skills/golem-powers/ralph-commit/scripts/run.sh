#!/bin/bash
# ralph-commit: Atomic test + commit + check criterion
# Usage: ./run.sh --story=US-106 --message="feat: US-106 description"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
STORY_ID=""
COMMIT_MSG=""
FILES=""
SKIP_SKILLS=false
DRY_RUN=false

for arg in "$@"; do
  case $arg in
    --story=*)
      STORY_ID="${arg#*=}"
      ;;
    --message=*)
      COMMIT_MSG="${arg#*=}"
      ;;
    --files=*)
      FILES="${arg#*=}"
      ;;
    --skip-skills)
      SKIP_SKILLS=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
  esac
done

# Validate required args
if [[ -z "$STORY_ID" ]]; then
  echo -e "${RED}Error: --story=ID required${NC}"
  exit 1
fi

if [[ -z "$COMMIT_MSG" ]]; then
  echo -e "${RED}Error: --message=MSG required${NC}"
  exit 1
fi

# Find repo root (where prd-json/ lives)
REPO_ROOT=$(pwd)
while [[ ! -d "$REPO_ROOT/prd-json" && "$REPO_ROOT" != "/" ]]; do
  REPO_ROOT=$(dirname "$REPO_ROOT")
done

if [[ ! -d "$REPO_ROOT/prd-json" ]]; then
  echo -e "${RED}Error: Cannot find prd-json/ directory${NC}"
  exit 1
fi

STORY_FILE="$REPO_ROOT/prd-json/stories/${STORY_ID}.json"

if [[ ! -f "$STORY_FILE" ]]; then
  echo -e "${RED}Error: Story file not found: $STORY_FILE${NC}"
  exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  Ralph Atomic Commit: $STORY_ID"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Step 1: Run tests
echo -e "${YELLOW}[1/3] Running tests...${NC}"

TEST_FAILED=false
FAILED_TESTS=""

# Run ralph tests
if [[ -f "$REPO_ROOT/tests/test-ralph.zsh" ]]; then
  echo "  Running test-ralph.zsh..."
  if ! "$REPO_ROOT/tests/test-ralph.zsh" > /tmp/ralph-commit-test.log 2>&1; then
    TEST_FAILED=true
    FAILED_TESTS="$FAILED_TESTS test-ralph.zsh"
  fi
fi

# Run skills tests (unless skipped)
if [[ "$SKIP_SKILLS" != "true" && -f "$REPO_ROOT/tests/test-skills.zsh" ]]; then
  echo "  Running test-skills.zsh..."
  if ! "$REPO_ROOT/tests/test-skills.zsh" > /tmp/ralph-commit-skills.log 2>&1; then
    TEST_FAILED=true
    FAILED_TESTS="$FAILED_TESTS test-skills.zsh"
  fi
fi

# Run bun tests
if [[ -d "$REPO_ROOT/bun" ]]; then
  echo "  Running bun tests..."
  if ! (cd "$REPO_ROOT/bun" && bun test > /tmp/ralph-commit-bun.log 2>&1); then
    TEST_FAILED=true
    FAILED_TESTS="$FAILED_TESTS bun-tests"
  fi
fi

# Check test results
if [[ "$TEST_FAILED" == "true" ]]; then
  echo ""
  echo -e "${RED}✗ Tests failed:${FAILED_TESTS}${NC}"
  echo ""
  echo "  Check logs:"
  echo "    /tmp/ralph-commit-test.log"
  echo "    /tmp/ralph-commit-skills.log"
  echo "    /tmp/ralph-commit-bun.log"
  echo ""
  echo -e "${YELLOW}→ Fix the failing tests, update outdated tests, or create BUG story${NC}"
  echo -e "${YELLOW}→ Commit criterion NOT checked${NC}"
  exit 1
fi

echo -e "${GREEN}✓ All tests passed${NC}"
echo ""

# Step 2: Commit
echo -e "${YELLOW}[2/3] Committing...${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would commit with message: $COMMIT_MSG"
else
  # Stage files
  if [[ -n "$FILES" ]]; then
    git add $FILES
  else
    # Auto-detect: stage prd-json and any modified files
    git add "$REPO_ROOT/prd-json/" 2>/dev/null || true
    git add -u 2>/dev/null || true
  fi

  # Commit (pre-commit hook will run)
  if ! git commit -m "$COMMIT_MSG"; then
    echo -e "${RED}✗ Commit failed (pre-commit hook?)${NC}"
    echo -e "${YELLOW}→ Commit criterion NOT checked${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Committed: $COMMIT_MSG${NC}"
fi

echo ""

# Step 3: Mark criterion as checked
echo -e "${YELLOW}[3/3] Marking commit criterion as checked...${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  [DRY RUN] Would mark commit criterion in $STORY_FILE"
else
  # Find the commit criterion (last one with "Commit" in text) and mark it checked
  # Using jq to update the JSON
  if command -v jq &> /dev/null; then
    # Find index of last criterion containing "Commit" (case insensitive)
    TEMP_FILE=$(mktemp)
    jq '
      .acceptanceCriteria |= (
        to_entries |
        map(
          if (.value.text | ascii_downcase | contains("commit")) and .value.checked == false
          then .value.checked = true
          else .
          end
        ) |
        map(.value)
      )
    ' "$STORY_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STORY_FILE"

    echo -e "${GREEN}✓ Marked commit criterion as checked in ${STORY_ID}.json${NC}"
  else
    echo -e "${YELLOW}⚠ jq not installed - please manually mark commit criterion${NC}"
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✓ Atomic commit complete: $STORY_ID${NC}"
echo "═══════════════════════════════════════════════════════════════"
