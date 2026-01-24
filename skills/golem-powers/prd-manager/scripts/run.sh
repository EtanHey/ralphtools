#!/bin/bash
# PRD Manager - Manage prd-json stories
set -euo pipefail

PRD_DIR="${PRD_DIR:-./prd-json}"
INDEX="$PRD_DIR/index.json"

# Parse arguments
ACTION=""
STORY=""
TEXT=""
SCOPE="pending"

while [[ $# -gt 0 ]]; do
  case $1 in
    --action=*) ACTION="${1#*=}"; shift ;;
    --story=*) STORY="${1#*=}"; shift ;;
    --text=*) TEXT="${1#*=}"; shift ;;
    --scope=*) SCOPE="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

# Helper: get stories by scope
get_stories() {
  local scope="$1"
  case "$scope" in
    pending) jq -r '.pending[]' "$INDEX" ;;
    blocked) jq -r '.blocked[]' "$INDEX" ;;
    all) jq -r '.pending[], .blocked[]' "$INDEX" ;;
  esac
}

case "$ACTION" in
  add-to-index)
    if [[ -z "$STORY" ]]; then
      echo "Error: --story required"
      exit 1
    fi

    # Check story file exists
    if [[ ! -f "$PRD_DIR/stories/${STORY}.json" ]]; then
      echo "Error: $PRD_DIR/stories/${STORY}.json not found"
      exit 1
    fi

    # Add to pending and storyOrder, update stats
    jq --arg s "$STORY" '
      .pending += [$s] |
      .storyOrder += [$s] |
      .stats.total += 1 |
      .stats.pending += 1
    ' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"

    echo "✓ Added $STORY to index"
    ;;

  add-criterion)
    if [[ -z "$TEXT" ]]; then
      echo "Error: --text required"
      exit 1
    fi

    if [[ -n "$STORY" ]]; then
      # Single story
      STORIES=("$STORY")
    else
      # Bulk by scope
      mapfile -t STORIES < <(get_stories "$SCOPE")
    fi

    updated=0
    for story in "${STORIES[@]}"; do
      file="$PRD_DIR/stories/${story}.json"
      if [[ -f "$file" ]]; then
        if ! grep -q "$TEXT" "$file" 2>/dev/null; then
          jq --arg c "$TEXT" '.acceptanceCriteria += [{"text": $c, "checked": false}]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          echo "✓ $story"
          ((updated++))
        fi
      fi
    done
    echo "Updated $updated stories"
    ;;

  list)
    echo "=== ${SCOPE^^} STORIES ==="
    get_stories "$SCOPE" | while read -r story; do
      title=$(jq -r '.title' "$PRD_DIR/stories/${story}.json" 2>/dev/null || echo "???")
      echo "  $story: $title"
    done
    ;;

  show)
    if [[ -z "$STORY" ]]; then
      echo "Error: --story required"
      exit 1
    fi
    jq '.' "$PRD_DIR/stories/${STORY}.json"
    ;;

  set-next)
    if [[ -z "$STORY" ]]; then
      echo "Error: --story required"
      exit 1
    fi
    jq --arg s "$STORY" '.nextStory = $s' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"
    echo "✓ nextStory set to $STORY"
    ;;

  stats)
    jq '.stats' "$INDEX"
    ;;

  *)
    echo "PRD Manager"
    echo ""
    echo "Actions:"
    echo "  --action=add-to-index --story=ID    Add story to index"
    echo "  --action=add-criterion --text=TEXT  Add criterion to stories"
    echo "  --action=list --scope=pending       List stories"
    echo "  --action=show --story=ID            Show story details"
    echo "  --action=set-next --story=ID        Set next story"
    echo "  --action=stats                      Show stats"
    echo ""
    echo "Scopes: pending, blocked, all"
    ;;
esac
