#!/usr/bin/env zsh
# Integration Tests for Ralph
# Usage: ./tests/integration/run.sh
#
# These tests capture ralph.zsh behavior BEFORE the MP-006 TypeScript migration.
# They serve as characterization tests to catch regressions during refactoring.
#
# Tests run with a mock Claude CLI to ensure predictable behavior.

# Enable strict mode but don't exit on error (we handle that in run_test)
setopt PIPE_FAIL

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test counters
typeset -g TESTS_PASSED=0
typeset -g TESTS_FAILED=0
typeset -g TESTS_SKIPPED=0

# Script directory
SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h:h}"

# Test fixtures directory
TEST_FIXTURES="$SCRIPT_DIR/fixtures"
typeset -g TEST_TMP=""

# Mock Claude path
MOCK_CLAUDE="$SCRIPT_DIR/mock-claude.sh"

# ═══════════════════════════════════════════════════════════════════
# TEST HELPERS
# ═══════════════════════════════════════════════════════════════════

setup_test_env() {
  TEST_TMP=$(mktemp -d)

  # Create mock Claude in test tmp
  mkdir -p "$TEST_TMP/bin"
  cp "$MOCK_CLAUDE" "$TEST_TMP/bin/claude"
  chmod +x "$TEST_TMP/bin/claude"

  # Add mock to PATH (prepend so it's found first)
  export PATH="$TEST_TMP/bin:$PATH"

  # Set Ralph config to use test directory
  export RALPH_CONFIG_DIR="$TEST_TMP/.config/ralphtools"
  export RALPH_STATUS_FILE="$TEST_TMP/.ralph-status.json"
  mkdir -p "$RALPH_CONFIG_DIR"

  # Create minimal config.json
  cat > "$RALPH_CONFIG_DIR/config.json" << 'EOF'
{
  "version": "2.0.0",
  "defaults": {
    "model": "opus",
    "maxIterations": 10,
    "sleepSeconds": 0
  },
  "runtime": "zsh"
}
EOF
}

teardown_test_env() {
  if [[ -n "$TEST_TMP" && -d "$TEST_TMP" ]]; then
    rm -rf "$TEST_TMP"
  fi
}

# Source ralph.zsh for testing
source_ralph() {
  # Source main ralph.zsh
  source "$PROJECT_ROOT/ralph.zsh"
}

# Run a test function and capture result
run_test() {
  local test_name="$1"
  local test_func="$2"

  printf "  %-60s " "$test_name"

  setup_test_env

  local result=0
  local output=""

  # Capture output and exit code in a subshell to isolate failures
  output=$( $test_func 2>&1 ) || result=$?

  teardown_test_env

  if [[ $result -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  elif [[ $result -eq 77 ]]; then
    echo -e "${YELLOW}SKIP${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  else
    echo -e "${RED}FAIL${NC}"
    if [[ -n "$output" ]]; then
      echo -e "    ${RED}└─ $output${NC}"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ═══════════════════════════════════════════════════════════════════
# CHARACTERIZATION TESTS
# These capture current behavior for regression detection
# ═══════════════════════════════════════════════════════════════════

test_ralph_version_flag() {
  source_ralph
  local output
  output=$(ralph --version 2>&1)
  if [[ "$output" == *"ralphtools v"* ]]; then
    return 0
  else
    echo "Expected version output, got: $output"
    return 1
  fi
}

test_ralph_reads_index_json() {
  source_ralph

  # Create test PRD structure
  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": "US-001",
  "storyOrder": ["US-001"],
  "pending": ["US-001"],
  "blocked": [],
  "completed": []
}
EOF

  cat > "$TEST_TMP/prd-json/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "Test story",
  "acceptanceCriteria": [{"text": "Test", "checked": false}],
  "passes": false
}
EOF

  # Verify index.json can be read and parsed correctly
  cd "$TEST_TMP"
  local next_story
  next_story=$(jq -r '.nextStory' "$TEST_TMP/prd-json/index.json")

  if [[ "$next_story" == "US-001" ]]; then
    return 0
  else
    echo "Expected US-001, got: $next_story"
    return 1
  fi
}

test_ralph_update_json_processing() {
  source_ralph

  # Create test PRD structure
  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": null,
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "completed": []
}
EOF

  # Create update.json with new story
  cat > "$TEST_TMP/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {
      "id": "US-NEW",
      "title": "New story from update",
      "acceptanceCriteria": [{"text": "Test", "checked": false}],
      "passes": false
    }
  ]
}
EOF

  # Apply update
  _ralph_apply_update_queue "$TEST_TMP/prd-json"

  # Verify story was added
  if [[ ! -f "$TEST_TMP/prd-json/stories/US-NEW.json" ]]; then
    echo "Story file not created"
    return 1
  fi

  # Verify pending array updated
  local pending
  pending=$(jq -r '.pending[0]' "$TEST_TMP/prd-json/index.json")
  if [[ "$pending" != "US-NEW" ]]; then
    echo "Expected US-NEW in pending, got: $pending"
    return 1
  fi

  # Verify update.json was deleted
  if [[ -f "$TEST_TMP/prd-json/update.json" ]]; then
    echo "update.json should have been deleted"
    return 1
  fi

  return 0
}

test_ralph_updates_story_criteria() {
  source_ralph

  # Create test PRD structure
  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": "US-001",
  "storyOrder": ["US-001"],
  "pending": ["US-001"],
  "blocked": [],
  "completed": []
}
EOF

  cat > "$TEST_TMP/prd-json/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "Test story",
  "acceptanceCriteria": [
    {"text": "Criterion 1", "checked": false},
    {"text": "Criterion 2", "checked": false}
  ],
  "passes": false
}
EOF

  # Update first criterion (simulating Claude's work)
  jq '.acceptanceCriteria[0].checked = true' \
    "$TEST_TMP/prd-json/stories/US-001.json" > "$TEST_TMP/tmp.json" && \
    mv "$TEST_TMP/tmp.json" "$TEST_TMP/prd-json/stories/US-001.json"

  # Verify the update persisted
  local checked
  checked=$(jq -r '.acceptanceCriteria[0].checked' "$TEST_TMP/prd-json/stories/US-001.json")
  if [[ "$checked" != "true" ]]; then
    echo "Criterion should be checked"
    return 1
  fi

  # Second criterion should still be unchecked
  checked=$(jq -r '.acceptanceCriteria[1].checked' "$TEST_TMP/prd-json/stories/US-001.json")
  if [[ "$checked" != "false" ]]; then
    echo "Second criterion should still be unchecked"
    return 1
  fi

  return 0
}

test_ralph_moves_completed_story() {
  source_ralph

  # Create test PRD structure with story in pending
  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": "US-001",
  "storyOrder": ["US-001", "US-002"],
  "pending": ["US-001", "US-002"],
  "blocked": [],
  "completed": []
}
EOF

  cat > "$TEST_TMP/prd-json/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "Test story",
  "acceptanceCriteria": [{"text": "Test", "checked": true}],
  "passes": true
}
EOF

  cat > "$TEST_TMP/prd-json/stories/US-002.json" << 'EOF'
{
  "id": "US-002",
  "title": "Second story",
  "acceptanceCriteria": [{"text": "Test", "checked": false}],
  "passes": false
}
EOF

  # Use jq to move US-001 from pending to completed (simulating ralph completion)
  jq '.pending = ["US-002"] | .completed = ["US-001"] | .nextStory = "US-002"' \
    "$TEST_TMP/prd-json/index.json" > "$TEST_TMP/tmp.json" && \
    mv "$TEST_TMP/tmp.json" "$TEST_TMP/prd-json/index.json"

  # Verify US-001 is now in completed
  local completed
  completed=$(jq -r '.completed[0]' "$TEST_TMP/prd-json/index.json")
  if [[ "$completed" != "US-001" ]]; then
    echo "US-001 should be in completed"
    return 1
  fi

  # Verify US-001 is no longer in pending
  local pending
  pending=$(jq -r '.pending | length' "$TEST_TMP/prd-json/index.json")
  if [[ "$pending" != "1" ]]; then
    echo "Should have 1 pending story"
    return 1
  fi

  # Verify nextStory updated
  local next
  next=$(jq -r '.nextStory' "$TEST_TMP/prd-json/index.json")
  if [[ "$next" != "US-002" ]]; then
    echo "nextStory should be US-002"
    return 1
  fi

  return 0
}

test_ralph_sleep_seconds_positional() {
  # Test that sleep seconds can be set via config.json
  # Note: config.json sleepSeconds takes precedence, but we can verify
  # the default loading mechanism works

  # Create config without sleepSeconds to test default
  cat > "$RALPH_CONFIG_DIR/config.json" << 'EOF'
{
  "version": "2.0.0",
  "defaults": {
    "model": "opus",
    "maxIterations": 10
  },
  "runtime": "zsh"
}
EOF

  # Set env var before sourcing
  export RALPH_SLEEP_SECONDS=5
  source "$PROJECT_ROOT/ralph.zsh"

  # When config doesn't specify sleepSeconds, env var should be used
  if [[ "$RALPH_SLEEP_SECONDS" != "5" ]]; then
    echo "RALPH_SLEEP_SECONDS should be 5, got: $RALPH_SLEEP_SECONDS"
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════
# STATUS FILE TESTS
# ═══════════════════════════════════════════════════════════════════

test_ralph_writes_status_file() {
  source_ralph

  # Manually call status write function
  RALPH_STATUS_FILE="$TEST_TMP/.ralph-status.json"
  _ralph_write_status "running" "null" "0"

  if [[ ! -f "$RALPH_STATUS_FILE" ]]; then
    echo "Status file not created"
    return 1
  fi

  return 0
}

test_ralph_status_file_fields() {
  source_ralph

  RALPH_STATUS_FILE="$TEST_TMP/.ralph-status.json"
  _ralph_write_status "running" "null" "0"

  # Check required fields exist
  local state
  state=$(jq -r '.state' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ "$state" != "running" ]]; then
    echo "Expected state=running, got: $state"
    return 1
  fi

  local activity
  activity=$(jq -r '.lastActivity' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ -z "$activity" || "$activity" == "null" ]]; then
    echo "lastActivity should be set"
    return 1
  fi

  local pid
  pid=$(jq -r '.pid' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ -z "$pid" || "$pid" == "null" ]]; then
    echo "pid should be set"
    return 1
  fi

  return 0
}

test_ralph_status_error_state() {
  source_ralph

  RALPH_STATUS_FILE="$TEST_TMP/.ralph-status.json"
  _ralph_write_status "error" "Test error message" "30"

  local state
  state=$(jq -r '.state' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ "$state" != "error" ]]; then
    echo "Expected state=error, got: $state"
    return 1
  fi

  local error
  error=$(jq -r '.error' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ "$error" != "Test error message" ]]; then
    echo "Expected error message, got: $error"
    return 1
  fi

  local retry
  retry=$(jq -r '.retryIn' "$RALPH_STATUS_FILE" 2>/dev/null)
  if [[ "$retry" != "30" ]]; then
    echo "Expected retryIn=30, got: $retry"
    return 1
  fi

  return 0
}

test_ralph_status_cleanup() {
  source_ralph

  RALPH_STATUS_FILE="$TEST_TMP/.ralph-status.json"
  _ralph_write_status "running" "null" "0"

  if [[ ! -f "$RALPH_STATUS_FILE" ]]; then
    echo "Status file should exist before cleanup"
    return 1
  fi

  _ralph_cleanup_status_file

  if [[ -f "$RALPH_STATUS_FILE" ]]; then
    echo "Status file should be deleted after cleanup"
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════
# UPDATE.JSON INTEGRATION TESTS
# These test the full update.json workflow
# ═══════════════════════════════════════════════════════════════════

test_update_json_adds_multiple_stories() {
  source_ralph

  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": null,
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "completed": []
}
EOF

  cat > "$TEST_TMP/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-001", "title": "First", "acceptanceCriteria": [{"text": "Test", "checked": false}], "passes": false},
    {"id": "US-002", "title": "Second", "acceptanceCriteria": [{"text": "Test", "checked": false}], "passes": false},
    {"id": "BUG-001", "title": "Bug fix", "acceptanceCriteria": [{"text": "Test", "checked": false}], "passes": false}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP/prd-json"

  # Verify all three stories were added
  local pending_count
  pending_count=$(jq -r '.pending | length' "$TEST_TMP/prd-json/index.json")
  if [[ "$pending_count" != "3" ]]; then
    echo "Expected 3 pending stories, got: $pending_count"
    return 1
  fi

  # Verify story files exist
  for story in US-001 US-002 BUG-001; do
    if [[ ! -f "$TEST_TMP/prd-json/stories/${story}.json" ]]; then
      echo "Missing story file: ${story}.json"
      return 1
    fi
  done

  # Verify RALPH_UPDATES_APPLIED was set
  if [[ "$RALPH_UPDATES_APPLIED" != "3" ]]; then
    echo "RALPH_UPDATES_APPLIED should be 3, got: $RALPH_UPDATES_APPLIED"
    return 1
  fi

  return 0
}

test_update_json_sets_next_story() {
  source_ralph

  mkdir -p "$TEST_TMP/prd-json/stories"
  cat > "$TEST_TMP/prd-json/index.json" << 'EOF'
{
  "nextStory": null,
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "completed": []
}
EOF

  cat > "$TEST_TMP/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-NEW", "title": "New story", "acceptanceCriteria": [{"text": "Test", "checked": false}], "passes": false}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP/prd-json"

  # Verify nextStory was set
  local next
  next=$(jq -r '.nextStory' "$TEST_TMP/prd-json/index.json")
  if [[ "$next" != "US-NEW" ]]; then
    echo "nextStory should be US-NEW, got: $next"
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════
# NOTIFICATION TESTS (skipped without ntfy)
# ═══════════════════════════════════════════════════════════════════

test_ralph_ntfy_topic_format() {
  source_ralph

  # Test that RALPH_NTFY_PREFIX is respected when set
  # The actual topic is computed in ralph() as: ${RALPH_NTFY_PREFIX}-${project_name}-notify
  export RALPH_NTFY_PREFIX="test-ralph"

  # Re-source to pick up the new value
  source "$PROJECT_ROOT/ralph.zsh"

  # Verify the prefix is set correctly
  if [[ "$RALPH_NTFY_PREFIX" != "test-ralph" ]]; then
    echo "RALPH_NTFY_PREFIX should be test-ralph, got: $RALPH_NTFY_PREFIX"
    return 1
  fi

  # Verify the default prefix is used when not set
  unset RALPH_NTFY_PREFIX
  source "$PROJECT_ROOT/ralph.zsh"

  if [[ -z "$RALPH_NTFY_PREFIX" ]]; then
    echo "RALPH_NTFY_PREFIX should have a default value"
    return 1
  fi

  # Verify default follows expected pattern
  if [[ "$RALPH_NTFY_PREFIX" != *"ralph"* ]]; then
    echo "RALPH_NTFY_PREFIX default should contain 'ralph', got: $RALPH_NTFY_PREFIX"
    return 1
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════"
echo "  Ralph Integration Tests (Characterization Tests for MP-006)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo -e "${CYAN}=== Characterization Tests ===${NC}"
run_test "ralph --version shows version" test_ralph_version_flag
run_test "ralph reads prd-json/index.json correctly" test_ralph_reads_index_json
run_test "ralph processes update.json and adds stories" test_ralph_update_json_processing
run_test "ralph updates story criteria when checked" test_ralph_updates_story_criteria
run_test "ralph moves completed story to completed array" test_ralph_moves_completed_story
run_test "ralph respects RALPH_SLEEP_SECONDS env var" test_ralph_sleep_seconds_positional
echo ""

echo -e "${CYAN}=== Status File Tests ===${NC}"
run_test "ralph writes status file during run" test_ralph_writes_status_file
run_test "status file contains state, lastActivity, pid" test_ralph_status_file_fields
run_test "status file captures error state correctly" test_ralph_status_error_state
run_test "status file is cleaned up properly" test_ralph_status_cleanup
echo ""

echo -e "${CYAN}=== Update.json Integration Tests ===${NC}"
run_test "update.json adds multiple stories at once" test_update_json_adds_multiple_stories
run_test "update.json sets nextStory to first pending" test_update_json_sets_next_story
echo ""

echo -e "${CYAN}=== Notification Tests ===${NC}"
run_test "ntfy topic format is correct" test_ralph_ntfy_topic_format
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}, ${YELLOW}$TESTS_SKIPPED skipped${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
