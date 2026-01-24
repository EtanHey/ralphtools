#!/usr/bin/env bash
# prd-to-json.sh - Convert PRD.md to prd.json
# Usage: prd-to-json.sh [input.md] [output.json]
# Defaults: PRD.md -> prd.json in current directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Input/output files
INPUT_FILE="${1:-PRD.md}"
OUTPUT_FILE="${2:-prd.json}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo -e "${RED}Error: $INPUT_FILE not found${NC}"
  exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}"
  exit 1
fi

echo -e "${BLUE}Converting $INPUT_FILE -> $OUTPUT_FILE${NC}"

# Read the entire file
content=$(cat "$INPUT_FILE")

# Extract project name from title (# PRD: ...)
project_name=$(echo "$content" | grep -m1 "^# PRD:" | sed 's/^# PRD: //' | sed 's/ *$//')
if [[ -z "$project_name" ]]; then
  project_name=$(echo "$content" | grep -m1 "^# " | sed 's/^# //')
fi

# Extract working directory
working_dir=$(echo "$content" | grep -m1 "Working Directory:" | sed 's/.*Working Directory:\*\* *//' | sed 's/`//g' | sed 's/ *$//')

# Extract test URL
test_url=$(echo "$content" | grep -m1 "Test URL:" | sed 's/.*Test URL:\*\* *//' | sed 's/`//g' | sed 's/ *$//')

# Function to parse a story block
parse_story() {
  local story_block="$1"
  local story_id
  local story_title
  local story_desc=""
  local criteria_json="[]"
  local is_blocked=false
  local blocked_reason=""

  # Extract story ID and title from first line (### US-001: Title or ### V-001: Title)
  local first_line=$(echo "$story_block" | head -1)
  story_id=$(echo "$first_line" | grep -oE '(US|V)-[A-Z0-9-]+' | head -1)
  story_title=$(echo "$first_line" | sed 's/^### //' | sed "s/$story_id: //" | sed 's/ *$//')

  # Check if blocked
  if echo "$story_block" | grep -q "⏹️ BLOCKED\|⏸️ BLOCKED"; then
    is_blocked=true
    blocked_reason=$(echo "$story_block" | grep -E "BLOCKED.*:" | sed 's/.*BLOCKED[^:]*: *//' | head -1)
  fi

  # Extract description (line after **Description:** or first paragraph)
  story_desc=$(echo "$story_block" | grep -A1 "Description:" | tail -1 | sed 's/^ *//')

  # Extract acceptance criteria
  local criteria_lines=$(echo "$story_block" | grep -E "^- \[[ x]\]" || true)
  if [[ -n "$criteria_lines" ]]; then
    criteria_json="["
    local first=true
    while IFS= read -r line; do
      local checked=false
      local text
      if [[ "$line" =~ ^\-\ \[x\] ]]; then
        checked=true
      fi
      text=$(echo "$line" | sed 's/^- \[[ x]\] //' | sed 's/"/\\"/g')

      if $first; then
        first=false
      else
        criteria_json+=","
      fi
      criteria_json+="{\"text\":\"$text\",\"checked\":$checked}"
    done <<< "$criteria_lines"
    criteria_json+="]"
  fi

  # Calculate if all criteria pass
  local all_checked=true
  if echo "$criteria_json" | jq -e '.[] | select(.checked == false)' > /dev/null 2>&1; then
    all_checked=false
  fi

  # Build JSON object
  local story_json
  story_json=$(jq -n \
    --arg id "$story_id" \
    --arg title "$story_title" \
    --arg desc "$story_desc" \
    --argjson criteria "$criteria_json" \
    --argjson passes "$all_checked" \
    --argjson blocked "$is_blocked" \
    --arg blockedReason "$blocked_reason" \
    '{
      id: $id,
      title: $title,
      description: $desc,
      acceptanceCriteria: $criteria,
      priority: "medium",
      passes: $passes,
      failedAttempts: 0,
      dependsOn: []
    } + (if $blocked then {blockedBy: $blockedReason} else {} end)'
  )

  echo "$story_json"
}

# Extract all story blocks
# Stories start with ### US-* or ### V-*
extract_stories() {
  local type="$1"  # "US" or "V"
  local stories="[]"

  # Use awk to extract story blocks
  local story_blocks
  story_blocks=$(awk -v type="$type" '
    /^### '"$type"'-[A-Z0-9-]+:/ {
      if (block != "") print block;
      block = $0;
      next
    }
    /^### / {
      if (block != "") print block;
      block = "";
      next
    }
    /^---$/ {
      if (block != "") print block;
      block = "";
      next
    }
    block != "" { block = block "\n" $0 }
    END { if (block != "") print block }
  ' "$INPUT_FILE" | grep -v "^$" || true)

  if [[ -n "$story_blocks" ]]; then
    local first=true
    stories="["

    # Process each story block (separated by double newlines from awk)
    while IFS= read -r block; do
      if [[ -z "$block" ]]; then continue; fi

      local story_json
      story_json=$(parse_story "$block")

      if [[ -n "$story_json" ]]; then
        if $first; then
          first=false
        else
          stories+=","
        fi
        stories+="$story_json"
      fi
    done < <(echo "$story_blocks" | awk 'BEGIN{RS="### "} NR>1 {print "### "$0}')

    stories+="]"
  fi

  echo "$stories"
}

# Extract iteration rules
extract_rules() {
  local rules="[]"
  local rule_lines
  rule_lines=$(echo "$content" | awk '/## 🚨 ITERATION RULES/,/^---$/' | grep -E "^[0-9]+\." | sed 's/^[0-9]*\. \*\*//' | sed 's/\*\*:.*//' || true)

  if [[ -n "$rule_lines" ]]; then
    rules=$(echo "$rule_lines" | jq -R -s 'split("\n") | map(select(length > 0))')
  fi

  echo "$rules"
}

# Main JSON construction
echo -e "${YELLOW}Extracting stories...${NC}"

user_stories=$(extract_stories "US")
verification_stories=$(extract_stories "V")
iteration_rules=$(extract_rules)

# Count stories
us_count=$(echo "$user_stories" | jq 'length')
v_count=$(echo "$verification_stories" | jq 'length')
completed=$(echo "$user_stories" | jq '[.[] | select(.passes == true)] | length')
blocked=$(echo "$user_stories" | jq '[.[] | select(.blockedBy != null)] | length')

echo -e "${GREEN}Found: $us_count user stories, $v_count verification stories${NC}"
echo -e "${GREEN}Completed: $completed, Blocked: $blocked${NC}"

# Build final JSON
final_json=$(jq -n \
  --arg projectName "$project_name" \
  --arg workingDir "$working_dir" \
  --arg testUrl "$test_url" \
  --argjson userStories "$user_stories" \
  --argjson verificationStories "$verification_stories" \
  --argjson iterationRules "$iteration_rules" \
  '{
    "$schema": "https://ralph.dev/schemas/prd.schema.json",
    projectName: $projectName,
    workingDirectory: $workingDir,
    metadata: {
      testUrl: $testUrl,
      viewport: "desktop",
      createdAt: (now | strftime("%Y-%m-%d")),
      updatedAt: (now | strftime("%Y-%m-%d"))
    },
    iterationRules: $iterationRules,
    userStories: $userStories,
    verificationStories: $verificationStories,
    blockedStories: [],
    completedStories: [],
    nonGoals: [],
    technicalNotes: {}
  }'
)

# Separate blocked stories
final_json=$(echo "$final_json" | jq '
  .blockedStories = [.userStories[] | select(.blockedBy != null)] |
  .userStories = [.userStories[] | select(.blockedBy == null)]
')

# Write output
echo "$final_json" | jq '.' > "$OUTPUT_FILE"

echo -e "${GREEN}✅ Converted to $OUTPUT_FILE${NC}"
echo -e "${BLUE}Schema: prd.schema.json${NC}"

# Validate with schema if ajv is available
if command -v ajv &> /dev/null; then
  schema_path="$HOME/.config/ralphtools/schemas/prd.schema.json"
  if [[ -f "$schema_path" ]]; then
    echo -e "${YELLOW}Validating against schema...${NC}"
    if ajv validate -s "$schema_path" -d "$OUTPUT_FILE" 2>/dev/null; then
      echo -e "${GREEN}✅ Schema validation passed${NC}"
    else
      echo -e "${YELLOW}⚠️ Schema validation failed (non-critical)${NC}"
    fi
  fi
fi
