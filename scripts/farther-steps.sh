#!/bin/bash
# farther-steps.sh - View and process deferred actions queue
# Usage: farther-steps.sh [list|pending|apply|done|add]

STEPS_FILE="$HOME/.claude/farther-steps.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure file exists
if [[ ! -f "$STEPS_FILE" ]]; then
  echo '{"steps": []}' > "$STEPS_FILE"
fi

case "${1:-list}" in
  list|ls)
    echo -e "${CYAN}=== All Farther Steps ===${NC}"
    jq -r '.steps[] | "\(.status | if . == "pending" then "⏳" elif . == "done" then "✓" else "⊘" end) [\(.priority)] \(.id): \(.reason | .[0:60])..."' "$STEPS_FILE" 2>/dev/null || echo "No steps"
    ;;

  pending|p)
    echo -e "${YELLOW}=== Pending Steps ===${NC}"
    jq -r '.steps[] | select(.status == "pending") | "
\u001b[33m[\(.priority)]\u001b[0m \(.id)
  Type: \(.type)
  Source: \(.source)
  Target: \(.target)
  Story: \(.story // "none") | Criteria: \(.criteria // "none")
  Reason: \(.reason)
"' "$STEPS_FILE" 2>/dev/null

    COUNT=$(jq '[.steps[] | select(.status == "pending")] | length' "$STEPS_FILE")
    echo -e "${CYAN}Total pending: ${COUNT}${NC}"
    ;;

  apply|a)
    STEP_ID="$2"
    if [[ -z "$STEP_ID" ]]; then
      echo -e "${RED}Usage: farther-steps.sh apply <step-id>${NC}"
      exit 1
    fi

    # Get step details
    STEP=$(jq -r ".steps[] | select(.id == \"$STEP_ID\")" "$STEPS_FILE")
    if [[ -z "$STEP" ]]; then
      echo -e "${RED}Step not found: $STEP_ID${NC}"
      exit 1
    fi

    TYPE=$(echo "$STEP" | jq -r '.type')
    SOURCE=$(echo "$STEP" | jq -r '.source' | sed "s|~|$HOME|g")
    TARGET=$(echo "$STEP" | jq -r '.target' | sed "s|~|$HOME|g")

    if [[ "$TYPE" == "sync" ]]; then
      echo -e "${BLUE}Syncing: $SOURCE -> $TARGET${NC}"

      # Create target directory if needed
      TARGET_DIR=$(dirname "$TARGET")
      mkdir -p "$TARGET_DIR"

      # Copy file
      if cp "$SOURCE" "$TARGET"; then
        echo -e "${GREEN}✓ Synced successfully${NC}"

        # Mark as done
        jq "(.steps[] | select(.id == \"$STEP_ID\")).status = \"done\"" "$STEPS_FILE" > "$STEPS_FILE.tmp" && mv "$STEPS_FILE.tmp" "$STEPS_FILE"
        echo -e "${GREEN}✓ Marked as done${NC}"
      else
        echo -e "${RED}✗ Sync failed${NC}"
        exit 1
      fi
    else
      echo -e "${YELLOW}Unknown type: $TYPE - marking as done${NC}"
      jq "(.steps[] | select(.id == \"$STEP_ID\")).status = \"done\"" "$STEPS_FILE" > "$STEPS_FILE.tmp" && mv "$STEPS_FILE.tmp" "$STEPS_FILE"
    fi
    ;;

  done|d)
    STEP_ID="$2"
    if [[ -z "$STEP_ID" ]]; then
      echo -e "${RED}Usage: farther-steps.sh done <step-id>${NC}"
      exit 1
    fi

    jq "(.steps[] | select(.id == \"$STEP_ID\")).status = \"done\"" "$STEPS_FILE" > "$STEPS_FILE.tmp" && mv "$STEPS_FILE.tmp" "$STEPS_FILE"
    echo -e "${GREEN}✓ Marked $STEP_ID as done${NC}"
    ;;

  skip|s)
    STEP_ID="$2"
    if [[ -z "$STEP_ID" ]]; then
      echo -e "${RED}Usage: farther-steps.sh skip <step-id>${NC}"
      exit 1
    fi

    jq "(.steps[] | select(.id == \"$STEP_ID\")).status = \"skipped\"" "$STEPS_FILE" > "$STEPS_FILE.tmp" && mv "$STEPS_FILE.tmp" "$STEPS_FILE"
    echo -e "${YELLOW}⊘ Marked $STEP_ID as skipped${NC}"
    ;;

  clean|c)
    echo -e "${YELLOW}Removing done/skipped steps...${NC}"
    BEFORE=$(jq '.steps | length' "$STEPS_FILE")
    jq '.steps = [.steps[] | select(.status == "pending")]' "$STEPS_FILE" > "$STEPS_FILE.tmp" && mv "$STEPS_FILE.tmp" "$STEPS_FILE"
    AFTER=$(jq '.steps | length' "$STEPS_FILE")
    echo -e "${GREEN}Removed $((BEFORE - AFTER)) steps${NC}"
    ;;

  stats)
    echo -e "${CYAN}=== Farther Steps Stats ===${NC}"
    jq -r '"Pending: \([.steps[] | select(.status == "pending")] | length)
Done: \([.steps[] | select(.status == "done")] | length)
Skipped: \([.steps[] | select(.status == "skipped")] | length)
Total: \(.steps | length)"' "$STEPS_FILE"
    ;;

  *)
    echo "farther-steps.sh - Manage deferred actions queue"
    echo ""
    echo "Usage: farther-steps.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list, ls       List all steps (default)"
    echo "  pending, p     Show pending steps with details"
    echo "  apply, a ID    Apply a sync step and mark done"
    echo "  done, d ID     Mark step as done (without applying)"
    echo "  skip, s ID     Mark step as skipped"
    echo "  clean, c       Remove done/skipped steps"
    echo "  stats          Show step statistics"
    ;;
esac
