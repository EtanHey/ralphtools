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

    # Add to pending and storyOrder (stats are derived, US-106)
    jq --arg s "$STORY" '
      .pending += [$s] |
      .storyOrder += [$s]
    ' "$INDEX" > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"

    echo "✓ Added $STORY to index"
    ;;

  add-criterion)
    if [[ -z "$TEXT" ]]; then
      echo "Error: --text required"
      exit 1
    fi

    updated=0
    if [[ -n "$STORY" ]]; then
      # Single story
      file="$PRD_DIR/stories/${STORY}.json"
      if [[ -f "$file" ]]; then
        if ! grep -q "$TEXT" "$file" 2>/dev/null; then
          jq --arg c "$TEXT" '.acceptanceCriteria += [{"text": $c, "checked": false}]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          echo "✓ $STORY"
          updated=$((updated + 1))
        fi
      fi
    else
      # Bulk by scope - use temp file to track actual updates
      TMP_UPDATED="$(mktemp)"
      get_stories "$SCOPE" | while read -r story; do
        file="$PRD_DIR/stories/${story}.json"
        if [[ -f "$file" ]]; then
          if ! grep -q "$TEXT" "$file" 2>/dev/null; then
            jq --arg c "$TEXT" '.acceptanceCriteria += [{"text": $c, "checked": false}]' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            echo "✓ $story"
            echo "$story" >> "$TMP_UPDATED"
          fi
        fi
      done
      updated=$(wc -l < "$TMP_UPDATED" | tr -d ' ')
      rm -f "$TMP_UPDATED"
    fi
    echo "Updated $updated stories"
    ;;

  list)
    scope_upper=$(echo "$SCOPE" | tr '[:lower:]' '[:upper:]')
    echo "=== ${scope_upper} STORIES ==="
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
    # Derive stats on-the-fly (US-106)
    pending_count=$(jq '.pending | length' "$INDEX")
    blocked_count=$(jq '.blocked | length' "$INDEX")
    completed_count=0
    total_count=0
    for f in "$PRD_DIR/stories"/*.json; do
      [[ -f "$f" ]] || continue
      ((total_count++))
      if [[ "$(jq -r '.passes // false' "$f")" == "true" ]]; then
        ((completed_count++))
      fi
    done
    echo "{"
    echo "  \"pending\": $pending_count,"
    echo "  \"blocked\": $blocked_count,"
    echo "  \"completed\": $completed_count,"
    echo "  \"total\": $total_count"
    echo "}"
    ;;

  summary)
    # Show completed stories summary (US-125)
    echo "=== COMPLETED STORIES ==="
    echo ""

    # Collect completed stories data
    first_completed=""
    last_completed=""
    completed_count=0

    # Print table header
    printf "%-12s %-35s %-22s %-10s\n" "ID" "TITLE" "COMPLETED" "BY"
    printf "%-12s %-35s %-22s %-10s\n" "------------" "-----------------------------------" "----------------------" "----------"

    for f in "$PRD_DIR/stories"/*.json; do
      [[ -f "$f" ]] || continue
      passes=$(jq -r '.passes // false' "$f")
      if [[ "$passes" == "true" ]]; then
        story_id=$(jq -r '.id' "$f")
        title=$(jq -r '.title' "$f")
        completed_at=$(jq -r '.completedAt // "N/A"' "$f")
        completed_by=$(jq -r '.completedBy // "N/A"' "$f")

        # Truncate title if too long
        if [[ ${#title} -gt 35 ]]; then
          title="${title:0:32}..."
        fi

        # Format the completed_at date (show shorter format if ISO)
        if [[ "$completed_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
          # ISO format - show date and time without seconds
          completed_display="${completed_at:0:16}"
          completed_display=$(echo "$completed_display" | tr 'T' ' ')
        else
          completed_display="$completed_at"
        fi

        printf "%-12s %-35s %-22s %-10s\n" "$story_id" "$title" "$completed_display" "$completed_by"
        ((completed_count++))

        # Track time range
        if [[ "$completed_at" != "N/A" ]]; then
          if [[ -z "$first_completed" ]] || [[ "$completed_at" < "$first_completed" ]]; then
            first_completed="$completed_at"
          fi
          if [[ -z "$last_completed" ]] || [[ "$completed_at" > "$last_completed" ]]; then
            last_completed="$completed_at"
          fi
        fi
      fi
    done

    echo ""
    echo "=== SUMMARY ==="
    echo "Total Completed: $completed_count"
    if [[ -n "$first_completed" && -n "$last_completed" ]]; then
      # Format time range
      first_display="${first_completed:0:16}"
      first_display=$(echo "$first_display" | tr 'T' ' ')
      last_display="${last_completed:0:16}"
      last_display=$(echo "$last_display" | tr 'T' ' ')
      echo "Time Range: $first_display to $last_display"
    fi
    ;;

  check-progress)
    # Show current PRD progress (US-106)
    echo "=== PRD PROGRESS ==="
    echo ""

    # Get nextStory
    next=$(jq -r '.nextStory // "none"' "$INDEX")
    echo "Next Story: $next"

    # Show current story progress if story file exists
    if [[ -n "$next" && "$next" != "none" && "$next" != "COMPLETE" ]]; then
      story_file="$PRD_DIR/stories/${next}.json"
      if [[ -f "$story_file" ]]; then
        title=$(jq -r '.title' "$story_file")
        echo "Title: $title"
        echo ""

        echo "Criteria:"
        jq -r '.acceptanceCriteria[] | if .checked then "  [x] " + .text else "  [ ] " + .text end' "$story_file"
        echo ""

        # Count checked/total
        checked=$(jq '[.acceptanceCriteria[] | select(.checked)] | length' "$story_file")
        total_c=$(jq '.acceptanceCriteria | length' "$story_file")
        echo "Progress: $checked/$total_c checked"
      fi
    fi
    echo ""

    # Derive stats on-the-fly
    pending_count=$(jq '.pending | length' "$INDEX")
    blocked_count=$(jq '.blocked | length' "$INDEX")
    completed_count=0
    total_count=0
    for f in "$PRD_DIR/stories"/*.json; do
      [[ -f "$f" ]] || continue
      ((total_count++))
      if [[ "$(jq -r '.passes // false' "$f")" == "true" ]]; then
        ((completed_count++))
      fi
    done
    echo "=== STATS ==="
    echo "Pending: $pending_count"
    echo "Blocked: $blocked_count"
    echo "Completed: $completed_count"
    echo "Total: $total_count"

    # Check for status file
    status_file="/tmp/ralph-status-*.json"
    # shellcheck disable=SC2086
    if ls $status_file 1>/dev/null 2>&1; then
      echo ""
      echo "=== RALPH STATUS ==="
      # Get most recent status file
      latest=$(find /tmp -maxdepth 1 -name 'ralph-status-*.json' -exec stat -f '%m %N' {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
      if [[ -f "$latest" ]]; then
        jq '.' "$latest"
      fi
    fi
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
    echo "  --action=stats                      Show stats (derived)"
    echo "  --action=summary                    Show completed stories summary"
    echo "  --action=check-progress             Show full progress with status"
    echo ""
    echo "Scopes: pending, blocked, all"
    ;;
esac
