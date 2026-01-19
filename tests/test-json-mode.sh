#!/usr/bin/env bash
# test-json-mode.sh - Tests for Ralph JSON mode
# Usage: ./tests/test-json-mode.sh [prd-json-dir]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test directory (use songscript as default test case)
TEST_DIR="${1:-$HOME/Desktop/Gits/songscript/prd-json}"
PASS=0
FAIL=0

# Source helper functions from ralph.zsh
RALPH_ZSH="$HOME/.config/ralph/ralph.zsh"

echo "═══════════════════════════════════════════════════════════════"
echo "  Ralph JSON Mode Tests"
echo "  Test Directory: $TEST_DIR"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Check index.json exists
test_index_exists() {
  echo -n "Test 1: index.json exists... "
  if [[ -f "$TEST_DIR/index.json" ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Test 2: Check index.json is valid JSON
test_index_valid_json() {
  echo -n "Test 2: index.json is valid JSON... "
  if jq '.' "$TEST_DIR/index.json" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Test 3: Check index.json has required fields
test_index_fields() {
  echo -n "Test 3: index.json has required fields... "
  local has_stats=$(jq -e '.stats' "$TEST_DIR/index.json" > /dev/null 2>&1 && echo "yes" || echo "no")
  local has_pending=$(jq -e '.pending' "$TEST_DIR/index.json" > /dev/null 2>&1 && echo "yes" || echo "no")
  local has_next=$(jq -e '.nextStory' "$TEST_DIR/index.json" > /dev/null 2>&1 && echo "yes" || echo "no")

  if [[ "$has_stats" == "yes" && "$has_pending" == "yes" && "$has_next" == "yes" ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} (stats: $has_stats, pending: $has_pending, nextStory: $has_next)"
    FAIL=$((FAIL + 1))
  fi
}

# Test 4: Check stories directory exists
test_stories_dir() {
  echo -n "Test 4: stories/ directory exists... "
  if [[ -d "$TEST_DIR/stories" ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Test 5: Check at least one story file exists
test_story_files() {
  echo -n "Test 5: Story files exist... "
  local count=$(ls "$TEST_DIR/stories"/*.json 2>/dev/null | wc -l)
  if [[ "$count" -gt 0 ]]; then
    echo -e "${GREEN}PASS${NC} ($count files)"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# Test 6: Check story files are valid JSON
test_stories_valid_json() {
  echo -n "Test 6: All story files are valid JSON... "
  local invalid=0
  for f in "$TEST_DIR/stories"/*.json; do
    if ! jq '.' "$f" > /dev/null 2>&1; then
      invalid=$((invalid + 1))
    fi
  done
  if [[ "$invalid" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} ($invalid invalid files)"
    FAIL=$((FAIL + 1))
  fi
}

# Test 7: Check story files have required fields
test_story_fields() {
  echo -n "Test 7: Story files have required fields... "
  local missing=0
  for f in "$TEST_DIR/stories"/*.json; do
    local has_id=$(jq 'has("id")' "$f" 2>/dev/null | grep -q "true" && echo "yes" || echo "no")
    local has_title=$(jq 'has("title")' "$f" 2>/dev/null | grep -q "true" && echo "yes" || echo "no")
    local has_criteria=$(jq 'has("acceptanceCriteria")' "$f" 2>/dev/null | grep -q "true" && echo "yes" || echo "no")
    local has_passes=$(jq 'has("passes")' "$f" 2>/dev/null | grep -q "true" && echo "yes" || echo "no")

    if [[ "$has_id" != "yes" || "$has_title" != "yes" || "$has_criteria" != "yes" || "$has_passes" != "yes" ]]; then
      missing=$((missing + 1))
    fi
  done
  if [[ "$missing" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} ($missing files missing fields)"
    FAIL=$((FAIL + 1))
  fi
}

# Test 8: Check criteria have checked field
test_criteria_checked() {
  echo -n "Test 8: Criteria have checked boolean... "
  local invalid=0
  for f in "$TEST_DIR/stories"/*.json; do
    local all_have_checked=$(jq '[.acceptanceCriteria[] | has("checked")] | all' "$f" 2>/dev/null)
    if [[ "$all_have_checked" != "true" ]]; then
      invalid=$((invalid + 1))
    fi
  done
  if [[ "$invalid" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC} ($invalid files with missing checked field)"
    FAIL=$((FAIL + 1))
  fi
}

# Test 9: Check passes field matches criteria
test_passes_consistency() {
  echo -n "Test 9: passes field is consistent with criteria... "
  local inconsistent=0
  for f in "$TEST_DIR/stories"/*.json; do
    local all_checked=$(jq '[.acceptanceCriteria[].checked] | all' "$f" 2>/dev/null)
    local passes=$(jq '.passes' "$f" 2>/dev/null)
    if [[ "$all_checked" != "$passes" ]]; then
      inconsistent=$((inconsistent + 1))
    fi
  done
  if [[ "$inconsistent" -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC} ($inconsistent files with inconsistent passes)"
    # Don't fail, just warn - some might be blocked
  fi
}

# Test 10: Check metadata.json if exists
test_metadata() {
  echo -n "Test 10: metadata.json is valid (if exists)... "
  if [[ -f "$TEST_DIR/metadata.json" ]]; then
    if jq '.' "$TEST_DIR/metadata.json" > /dev/null 2>&1; then
      echo -e "${GREEN}PASS${NC}"
      PASS=$((PASS + 1))
    else
      echo -e "${RED}FAIL${NC}"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "${YELLOW}SKIP${NC} (no metadata.json)"
  fi
}

# Run all tests
test_index_exists
test_index_valid_json
test_index_fields
test_stories_dir
test_story_files
test_stories_valid_json
test_story_fields
test_criteria_checked
test_passes_consistency
test_metadata

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
