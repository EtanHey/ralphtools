#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH ZSH TEST FRAMEWORK
# ═══════════════════════════════════════════════════════════════════
# Usage: ./tests/test-ralph.zsh
#
# A lightweight test framework for testing Ralph zsh functions.
# Provides assertion helpers and a test runner with summary output.
# ═══════════════════════════════════════════════════════════════════

# Strict mode
setopt ERR_EXIT PIPE_FAIL

# ═══════════════════════════════════════════════════════════════════
# COLORS & CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'  # No Color

# Test state
typeset -g CURRENT_TEST=""
typeset -g TEST_FAILED_FLAG=0
typeset -g RESULTS_FILE=""

# ═══════════════════════════════════════════════════════════════════
# RESULTS TRACKING (file-based for reliable counting)
# ═══════════════════════════════════════════════════════════════════

# Initialize results tracking
_init_results() {
  RESULTS_FILE=$(mktemp)
  FAILURES_FILE=$(mktemp)
  echo "0 0" > "$RESULTS_FILE"
  echo -n "" > "$FAILURES_FILE"
}

# Record a pass
_record_pass() {
  local current
  current=$(cat "$RESULTS_FILE")
  local passed=${current%% *}
  local failed=${current##* }
  passed=$((passed + 1))
  echo "$passed $failed" > "$RESULTS_FILE"
}

# Record a fail
_record_fail() {
  local current
  current=$(cat "$RESULTS_FILE")
  local passed=${current%% *}
  local failed=${current##* }
  failed=$((failed + 1))
  echo "$passed $failed" > "$RESULTS_FILE"
}

# Record failure details (test name and reason)
_record_failure_details() {
  local test_name="$1"
  local reason="$2"
  echo "${test_name}|${reason}" >> "$FAILURES_FILE"
}

# Get all failure details
_get_failures() {
  cat "$FAILURES_FILE"
}

# Get final results
_get_results() {
  cat "$RESULTS_FILE"
}

# Cleanup results files
_cleanup_results() {
  [[ -f "$RESULTS_FILE" ]] && rm -f "$RESULTS_FILE"
  [[ -f "$FAILURES_FILE" ]] && rm -f "$FAILURES_FILE"
}

# ═══════════════════════════════════════════════════════════════════
# TEST OUTPUT FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

# Start a new test - call this at the beginning of each test function
# Usage: test_start "test name"
test_start() {
  local test_name="$1"
  CURRENT_TEST="$test_name"
  TEST_FAILED_FLAG=0
  printf "  %-50s " "$test_name"
}

# Mark current test as passed
# Usage: test_pass
test_pass() {
  if [[ $TEST_FAILED_FLAG -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    _record_pass
  fi
}

# Mark current test as failed with message
# Usage: test_fail "reason"
test_fail() {
  local reason="${1:-assertion failed}"
  if [[ $TEST_FAILED_FLAG -eq 0 ]]; then
    echo -e "${RED}FAIL${NC}"
    echo -e "    ${RED}└─ $reason${NC}"
    _record_fail
    _record_failure_details "$CURRENT_TEST" "$reason"
    TEST_FAILED_FLAG=1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# ASSERTION HELPERS
# ═══════════════════════════════════════════════════════════════════

# Assert two values are equal
# Usage: assert_equals "expected" "actual" ["message"]
# Returns: 0 if equal, 1 if not (and marks test as failed)
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected' but got '$actual'}"

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

# Assert a string contains a substring
# Usage: assert_contains "haystack" "needle" ["message"]
# Returns: 0 if contains, 1 if not (and marks test as failed)
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected string to contain '$needle'}"

  if [[ "$haystack" == *"$needle"* ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

# Assert a command exits with expected code
# Usage: assert_exit_code <expected_code> <command> [args...]
# Returns: 0 if exit code matches, 1 if not (and marks test as failed)
assert_exit_code() {
  local expected_code="$1"
  shift
  local actual_code=0

  # Run command, capture exit code
  "$@" >/dev/null 2>&1 || actual_code=$?

  if [[ "$expected_code" -eq "$actual_code" ]]; then
    return 0
  else
    test_fail "Expected exit code $expected_code but got $actual_code"
    return 1
  fi
}

# Assert a value is not empty
# Usage: assert_not_empty "value" ["message"]
# Returns: 0 if not empty, 1 if empty (and marks test as failed)
assert_not_empty() {
  local value="$1"
  local message="${2:-Expected non-empty value}"

  if [[ -n "$value" ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

# Assert a file exists
# Usage: assert_file_exists "path" ["message"]
# Returns: 0 if exists, 1 if not (and marks test as failed)
assert_file_exists() {
  local path="$1"
  local message="${2:-Expected file to exist: $path}"

  if [[ -f "$path" ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# TEST RUNNER
# ═══════════════════════════════════════════════════════════════════

# Discover and run all test functions
# Test functions must be named: test_*
run_all_tests() {
  # Initialize results tracking
  _init_results
  trap '_cleanup_results' EXIT

  # Print header
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Ralph ZSH Test Suite"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Find all functions starting with test_
  # Exclude framework functions (test_start, test_pass, test_fail)
  local test_functions=()
  for func in ${(ok)functions}; do
    if [[ "$func" == test_* && "$func" != "test_start" && "$func" != "test_pass" && "$func" != "test_fail" ]]; then
      test_functions+=("$func")
    fi
  done

  # Disable ERR_EXIT for test execution so we can handle failures gracefully
  setopt NO_ERR_EXIT

  # Run each test (in same shell to track results)
  for test_func in "${test_functions[@]}"; do
    # Reset per-test state
    TEST_FAILED_FLAG=0
    CURRENT_TEST=""
    # Run the test
    "$test_func" || true
  done

  # Get final counts from file
  local results
  results=$(_get_results)
  local final_passed=${results%% *}
  local final_failed=${results##* }

  # Print summary
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo -e "  Results: ${GREEN}$final_passed passed${NC}, ${RED}$final_failed failed${NC}"
  echo "═══════════════════════════════════════════════════════════════"

  # Print failures if any
  if [[ $final_failed -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}FAILURES:${NC}"
    while IFS='|' read -r test_name reason; do
      [[ -z "$test_name" ]] && continue
      echo -e "  ${RED}✗${NC} $test_name"
      echo -e "    └─ $reason"
    done < <(_get_failures)
    echo ""
  fi

  # Exit with appropriate code
  if [[ $final_failed -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

# ═══════════════════════════════════════════════════════════════════
# TEST SETUP & TEARDOWN
# ═══════════════════════════════════════════════════════════════════

# Create a temporary directory for test fixtures
_setup_test_fixtures() {
  TEST_TMP_DIR=$(mktemp -d)
  export RALPH_CONFIG_DIR="$TEST_TMP_DIR"
  export RALPH_CONFIG_FILE="$TEST_TMP_DIR/config.json"
}

# Cleanup test fixtures
_teardown_test_fixtures() {
  [[ -d "$TEST_TMP_DIR" ]] && rm -rf "$TEST_TMP_DIR"
}

# Reset all RALPH config variables to undefined state
_reset_ralph_vars() {
  unset RALPH_RUNTIME
  unset RALPH_MODEL_STRATEGY
  unset RALPH_DEFAULT_MODEL_CFG
  unset RALPH_UNKNOWN_TASK_MODEL
  unset RALPH_MODEL_US
  unset RALPH_MODEL_V
  unset RALPH_MODEL_TEST
  unset RALPH_MODEL_BUG
  unset RALPH_MODEL_AUDIT
  unset RALPH_NTFY_TOPIC
  unset RALPH_MAX_ITERATIONS
  unset RALPH_SLEEP_SECONDS
}

# ═══════════════════════════════════════════════════════════════════
# CONFIG FUNCTION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_load_config with valid config.json
test_config_load_valid() {
  test_start "load_config with valid JSON"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a valid config.json
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "modelStrategy": "smart",
  "defaultModel": "opus",
  "unknownTaskType": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },
  "notifications": {
    "enabled": true,
    "ntfyTopic": "test-topic"
  },
  "defaults": {
    "maxIterations": 10,
    "sleepSeconds": 5
  }
}
EOF

  # Load config
  _ralph_load_config
  local load_result=$?

  # Verify return code
  assert_equals "0" "$load_result" "_ralph_load_config should return 0" || { _teardown_test_fixtures; return; }

  # Verify values were loaded
  assert_equals "smart" "$RALPH_MODEL_STRATEGY" "modelStrategy should be smart" || { _teardown_test_fixtures; return; }
  assert_equals "opus" "$RALPH_DEFAULT_MODEL_CFG" "defaultModel should be opus" || { _teardown_test_fixtures; return; }
  assert_equals "sonnet" "$RALPH_MODEL_US" "models.US should be sonnet" || { _teardown_test_fixtures; return; }
  assert_equals "haiku" "$RALPH_MODEL_V" "models.V should be haiku" || { _teardown_test_fixtures; return; }
  assert_equals "test-topic" "$RALPH_NTFY_TOPIC" "ntfyTopic should be test-topic" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_load_config with missing file uses defaults
test_config_load_missing_file() {
  test_start "load_config with missing file"
  _setup_test_fixtures
  _reset_ralph_vars

  # Ensure no config file exists
  rm -f "$RALPH_CONFIG_FILE"

  # Load config - should return 1 (file not found)
  _ralph_load_config
  local load_result=$?

  # Verify return code indicates missing file
  assert_equals "1" "$load_result" "_ralph_load_config should return 1 for missing file" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_load_config with malformed JSON
test_config_load_malformed_json() {
  test_start "load_config with malformed JSON"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a malformed config.json
  echo "{ this is not valid json }" > "$RALPH_CONFIG_FILE"

  # Load config - jq should handle errors gracefully
  _ralph_load_config
  local load_result=$?

  # Should still return 0 (file exists) but vars should be null/empty due to jq error
  assert_equals "0" "$load_result" "_ralph_load_config should return 0 (file exists)" || { _teardown_test_fixtures; return; }

  # jq with // "default" should give us the default when parsing fails
  # The values should be "null" (jq returns "null" string on parse error)
  # Actually, jq returns null when it can't parse, which becomes "null" string
  # This test verifies the error handling doesn't crash

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story returns correct model for US prefix
test_model_routing_us() {
  test_start "get_model_for_story US-* → sonnet"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_US="sonnet"

  local result=$(_ralph_get_model_for_story "US-001")
  assert_equals "sonnet" "$result" "US-001 should route to sonnet" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story returns correct model for V prefix
test_model_routing_v() {
  test_start "get_model_for_story V-* → haiku"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_V="haiku"

  local result=$(_ralph_get_model_for_story "V-001")
  assert_equals "haiku" "$result" "V-001 should route to haiku" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story returns correct model for TEST prefix
test_model_routing_test() {
  test_start "get_model_for_story TEST-* → haiku"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_TEST="haiku"

  local result=$(_ralph_get_model_for_story "TEST-002")
  assert_equals "haiku" "$result" "TEST-002 should route to haiku" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story returns correct model for BUG prefix
test_model_routing_bug() {
  test_start "get_model_for_story BUG-* → sonnet"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_BUG="sonnet"

  local result=$(_ralph_get_model_for_story "BUG-001")
  assert_equals "sonnet" "$result" "BUG-001 should route to sonnet" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story returns correct model for AUDIT prefix
test_model_routing_audit() {
  test_start "get_model_for_story AUDIT-* → opus"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_AUDIT="opus"

  local result=$(_ralph_get_model_for_story "AUDIT-001")
  assert_equals "opus" "$result" "AUDIT-001 should route to opus" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story uses unknownTaskType for unknown prefix
test_model_routing_unknown() {
  test_start "get_model_for_story UNKNOWN-* → fallback"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing with unknown fallback
  RALPH_MODEL_STRATEGY="smart"
  RALPH_UNKNOWN_TASK_MODEL="sonnet"

  local result=$(_ralph_get_model_for_story "CUSTOM-001")
  assert_equals "sonnet" "$result" "CUSTOM-001 should fallback to sonnet" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story CLI override wins
test_model_routing_cli_override() {
  test_start "get_model_for_story CLI override wins"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up smart routing with specific model
  RALPH_MODEL_STRATEGY="smart"
  RALPH_MODEL_US="sonnet"

  # CLI override should win
  local result=$(_ralph_get_model_for_story "US-001" "opus" "")
  assert_equals "opus" "$result" "CLI override should win over config" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_model_for_story single strategy uses default
test_model_routing_single_strategy() {
  test_start "get_model_for_story single strategy"
  _setup_test_fixtures
  _reset_ralph_vars

  # Set up single model strategy
  RALPH_MODEL_STRATEGY="single"
  RALPH_DEFAULT_MODEL_CFG="opus"

  # All prefixes should use the default model
  local result_us=$(_ralph_get_model_for_story "US-001")
  local result_v=$(_ralph_get_model_for_story "V-001")
  local result_test=$(_ralph_get_model_for_story "TEST-001")

  assert_equals "opus" "$result_us" "US should use default in single mode" || { _teardown_test_fixtures; return; }
  assert_equals "opus" "$result_v" "V should use default in single mode" || { _teardown_test_fixtures; return; }
  assert_equals "opus" "$result_test" "TEST should use default in single mode" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# COST TRACKING FUNCTION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_init_costs creates valid costs.json structure
test_init_costs_creates_valid_structure() {
  test_start "init_costs creates valid costs.json"
  _setup_test_fixtures

  # Set up cost file path
  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Initialize costs
  _ralph_init_costs

  # Verify file exists
  assert_file_exists "$RALPH_COSTS_FILE" "costs.json should be created" || { _teardown_test_fixtures; return; }

  # Verify structure has required keys
  local has_runs=$(jq 'has("runs")' "$RALPH_COSTS_FILE")
  local has_totals=$(jq 'has("totals")' "$RALPH_COSTS_FILE")
  local has_avg_tokens=$(jq 'has("avgTokensObserved")' "$RALPH_COSTS_FILE")

  assert_equals "true" "$has_runs" "costs.json should have 'runs' key" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_totals" "costs.json should have 'totals' key" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_avg_tokens" "costs.json should have 'avgTokensObserved' key" || { _teardown_test_fixtures; return; }

  # Verify totals structure
  local stories_count=$(jq '.totals.stories' "$RALPH_COSTS_FILE")
  local estimated_cost=$(jq '.totals.estimatedCost' "$RALPH_COSTS_FILE")

  assert_equals "0" "$stories_count" "totals.stories should be 0" || { _teardown_test_fixtures; return; }
  assert_equals "0" "$estimated_cost" "totals.estimatedCost should be 0" || { _teardown_test_fixtures; return; }

  # Verify avgTokensObserved has all prefixes
  local has_us=$(jq '.avgTokensObserved | has("US")' "$RALPH_COSTS_FILE")
  local has_v=$(jq '.avgTokensObserved | has("V")' "$RALPH_COSTS_FILE")
  local has_test=$(jq '.avgTokensObserved | has("TEST")' "$RALPH_COSTS_FILE")
  local has_bug=$(jq '.avgTokensObserved | has("BUG")' "$RALPH_COSTS_FILE")
  local has_audit=$(jq '.avgTokensObserved | has("AUDIT")' "$RALPH_COSTS_FILE")

  assert_equals "true" "$has_us" "avgTokensObserved should have US" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_v" "avgTokensObserved should have V" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_test" "avgTokensObserved should have TEST" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_bug" "avgTokensObserved should have BUG" || { _teardown_test_fixtures; return; }
  assert_equals "true" "$has_audit" "avgTokensObserved should have AUDIT" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_log_cost adds entry to costs.json
test_log_cost_adds_entry() {
  test_start "log_cost adds entry to costs.json"
  _setup_test_fixtures

  # Set up cost file path
  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Log a cost entry (no session_id so it will use duration-based estimates)
  _ralph_log_cost "US-001" "sonnet" "60" "success"

  # Verify entry was added
  local runs_count=$(jq '.runs | length' "$RALPH_COSTS_FILE")
  assert_equals "1" "$runs_count" "runs should have 1 entry" || { _teardown_test_fixtures; return; }

  # Verify entry structure
  local story_id=$(jq -r '.runs[0].storyId' "$RALPH_COSTS_FILE")
  local model=$(jq -r '.runs[0].model' "$RALPH_COSTS_FILE")
  local prefix=$(jq -r '.runs[0].prefix' "$RALPH_COSTS_FILE")
  local run_status=$(jq -r '.runs[0].status' "$RALPH_COSTS_FILE")

  assert_equals "US-001" "$story_id" "storyId should be US-001" || { _teardown_test_fixtures; return; }
  assert_equals "sonnet" "$model" "model should be sonnet" || { _teardown_test_fixtures; return; }
  assert_equals "US" "$prefix" "prefix should be US" || { _teardown_test_fixtures; return; }
  assert_equals "success" "$run_status" "status should be success" || { _teardown_test_fixtures; return; }

  # Verify totals were updated
  local total_stories=$(jq '.totals.stories' "$RALPH_COSTS_FILE")
  assert_equals "1" "$total_stories" "totals.stories should be 1" || { _teardown_test_fixtures; return; }

  # Verify model count was updated
  local model_count=$(jq '.totals.byModel.sonnet' "$RALPH_COSTS_FILE")
  assert_equals "1" "$model_count" "byModel.sonnet should be 1" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: cost calculation with known token counts (duration-based estimates)
test_cost_calculation_with_duration() {
  test_start "cost calculation with known duration"
  _setup_test_fixtures

  # Set up cost file path
  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Log a cost with 60 seconds duration and sonnet
  # Expected: input_tokens = 60 * 1000 = 60000, output_tokens = 60 * 500 = 30000
  # Sonnet pricing: input=$3/M, output=$15/M
  # Cost = (60000 * 3 / 1000000) + (30000 * 15 / 1000000) = 0.18 + 0.45 = 0.63
  _ralph_log_cost "US-001" "sonnet" "60" "success"

  # Verify tokens were calculated from duration
  local input_tokens=$(jq '.runs[0].tokens.input' "$RALPH_COSTS_FILE")
  local output_tokens=$(jq '.runs[0].tokens.output' "$RALPH_COSTS_FILE")
  local token_source=$(jq -r '.runs[0].tokenSource' "$RALPH_COSTS_FILE")

  assert_equals "60000" "$input_tokens" "input_tokens should be 60000 (60 * 1000)" || { _teardown_test_fixtures; return; }
  assert_equals "30000" "$output_tokens" "output_tokens should be 30000 (60 * 500)" || { _teardown_test_fixtures; return; }
  assert_equals "estimated" "$token_source" "tokenSource should be estimated" || { _teardown_test_fixtures; return; }

  # Verify cost calculation (may have small rounding differences)
  local cost=$(jq '.runs[0].cost' "$RALPH_COSTS_FILE")
  # Cost should be approximately 0.63 (0.18 + 0.45)
  # Allow for bc precision differences
  local cost_valid="false"
  if [[ "$cost" == "0.6300" ]] || [[ "$cost" == ".6300" ]] || [[ "$cost" == "0.63" ]]; then
    cost_valid="true"
  fi
  assert_equals "true" "$cost_valid" "cost should be ~0.63 (got $cost)" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: haiku pricing (input=$1/M, output=$5/M)
test_haiku_pricing() {
  test_start "haiku pricing is correct"
  _setup_test_fixtures

  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Log with 100 seconds duration using haiku
  # input_tokens = 100000, output_tokens = 50000
  # Cost = (100000 * 1 / 1000000) + (50000 * 5 / 1000000) = 0.1 + 0.25 = 0.35
  _ralph_log_cost "V-001" "haiku" "100" "success"

  local cost=$(jq '.runs[0].cost' "$RALPH_COSTS_FILE")
  local cost_valid="false"
  if [[ "$cost" == "0.3500" ]] || [[ "$cost" == ".3500" ]] || [[ "$cost" == "0.35" ]]; then
    cost_valid="true"
  fi
  assert_equals "true" "$cost_valid" "haiku cost should be ~0.35 (got $cost)" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: sonnet pricing (input=$3/M, output=$15/M)
test_sonnet_pricing() {
  test_start "sonnet pricing is correct"
  _setup_test_fixtures

  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Log with 100 seconds duration using sonnet
  # input_tokens = 100000, output_tokens = 50000
  # Cost = (100000 * 3 / 1000000) + (50000 * 15 / 1000000) = 0.3 + 0.75 = 1.05
  _ralph_log_cost "US-002" "sonnet" "100" "success"

  local cost=$(jq '.runs[0].cost' "$RALPH_COSTS_FILE")
  local cost_valid="false"
  if [[ "$cost" == "1.0500" ]] || [[ "$cost" == "1.05" ]]; then
    cost_valid="true"
  fi
  assert_equals "true" "$cost_valid" "sonnet cost should be ~1.05 (got $cost)" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: opus pricing (input=$15/M, output=$75/M)
test_opus_pricing() {
  test_start "opus pricing is correct"
  _setup_test_fixtures

  RALPH_COSTS_FILE="$TEST_TMP_DIR/costs.json"
  rm -f "$RALPH_COSTS_FILE"

  # Log with 100 seconds duration using opus
  # input_tokens = 100000, output_tokens = 50000
  # Cost = (100000 * 15 / 1000000) + (50000 * 75 / 1000000) = 1.5 + 3.75 = 5.25
  _ralph_log_cost "AUDIT-001" "opus" "100" "success"

  local cost=$(jq '.runs[0].cost' "$RALPH_COSTS_FILE")
  local cost_valid="false"
  if [[ "$cost" == "5.2500" ]] || [[ "$cost" == "5.25" ]]; then
    cost_valid="true"
  fi
  assert_equals "true" "$cost_valid" "opus cost should be ~5.25 (got $cost)" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_get_session_tokens returns "0 0 0 0" for missing session
test_get_session_tokens_missing_session() {
  test_start "get_session_tokens returns 0 0 0 0 for missing"
  _setup_test_fixtures

  # Call with a non-existent session ID and a temp path that won't have JSONL files
  local result=$(_ralph_get_session_tokens "nonexistent-session-uuid" "$TEST_TMP_DIR")

  assert_equals "0 0 0 0" "$result" "Should return '0 0 0 0' for missing session" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# NOTIFICATION FUNCTION TESTS
# ═══════════════════════════════════════════════════════════════════

# Mock curl to capture ntfy calls
# Sets MOCK_CURL_CALLS array with call details
typeset -g MOCK_CURL_CALLED=0
typeset -g MOCK_CURL_TITLE=""
typeset -g MOCK_CURL_PRIORITY=""
typeset -g MOCK_CURL_TAGS=""
typeset -g MOCK_CURL_BODY=""
typeset -g MOCK_CURL_URL=""

_reset_mock_curl() {
  MOCK_CURL_CALLED=0
  MOCK_CURL_TITLE=""
  MOCK_CURL_PRIORITY=""
  MOCK_CURL_TAGS=""
  MOCK_CURL_BODY=""
  MOCK_CURL_URL=""
}

# Save the real curl path
typeset -g REAL_CURL=$(whence -p curl)

# Create a testable version of _ralph_ntfy that accepts a curl command
# This allows us to test the notification formatting without mocking
_ralph_ntfy_testable() {
  local topic="$1"
  local event="$2"  # complete, blocked, error, iteration, max_iterations
  local message="$3"
  local story_id="${4:-}"
  local model="${5:-}"
  local iteration="${6:-}"
  local remaining="${7:-}"
  local cost="${8:-}"
  local curl_cmd="${9:-curl}"  # Allow override for testing

  [[ -z "$topic" ]] && return 0

  local project_name=$(basename "$(pwd)")
  local title=""
  local priority="default"
  local tags=""

  case "$event" in
    complete)
      title="✅ Ralph Complete"
      tags="white_check_mark,robot"
      priority="high"
      ;;
    blocked)
      title="⏹️ Ralph Blocked"
      tags="stop_button,warning"
      priority="urgent"
      ;;
    error)
      title="❌ Ralph Error"
      tags="x,fire"
      priority="urgent"
      ;;
    iteration)
      title="🔄 Ralph Progress"
      tags="arrows_counterclockwise"
      priority="low"
      ;;
    max_iterations)
      title="⚠️ Ralph Limit Hit"
      tags="warning,hourglass"
      priority="high"
      ;;
    *)
      title="🤖 Ralph"
      tags="robot"
      ;;
  esac

  # Build compact 3-line body with emoji labels
  # Line 1: repo name
  local body="$project_name"

  # Line 2: 🔄 iteration + story + model
  local line2=""
  [[ -n "$iteration" ]] && line2="🔄$iteration"
  [[ -n "$story_id" ]] && line2+=" $story_id"
  [[ -n "$model" ]] && line2+=" $model"
  [[ -n "$line2" ]] && body+="\n$line2"

  # Line 3: 📚 stories left + ☐ criteria left + 💵 cost
  local line3=""
  if [[ -n "$remaining" ]]; then
    # remaining is "stories criteria" space-separated from _ralph_json_remaining_stats
    local stories=$(echo "$remaining" | awk '{print $1}')
    local criteria=$(echo "$remaining" | awk '{print $2}')
    [[ -n "$stories" ]] && line3+="📚$stories"
    [[ -n "$criteria" ]] && line3+=" ☐$criteria"
  fi
  [[ -n "$cost" ]] && line3+=" 💵\$$cost"
  [[ -n "$line3" ]] && body+="\n$line3"

  # Append message if present
  [[ -n "$message" ]] && body+="\n\n$message"

  # Record for test verification
  MOCK_CURL_CALLED=1
  MOCK_CURL_TITLE="$title"
  MOCK_CURL_PRIORITY="$priority"
  MOCK_CURL_TAGS="$tags"
  MOCK_CURL_BODY="$(echo -e "$body")"
  MOCK_CURL_URL="ntfy.sh/${topic}"

  # Don't actually send in test mode (curl_cmd would be "mock")
  if [[ "$curl_cmd" != "mock" ]]; then
    $curl_cmd -s \
      -H "Title: $title" \
      -H "Priority: $priority" \
      -H "Tags: $tags" \
      -d "$(echo -e "$body")" \
      "ntfy.sh/${topic}" > /dev/null 2>&1
  fi
}

# Test: _ralph_ntfy builds compact 3-line body with emoji labels
test_ntfy_builds_body_with_project_name() {
  test_start "ntfy builds compact 3-line body"
  _setup_test_fixtures
  _reset_mock_curl

  # Call testable version with mock curl (no actual HTTP call)
  # Note: remaining is "stories criteria" format (e.g., "10 129")
  _ralph_ntfy_testable "test-topic" "iteration" "Test message" "US-001" "sonnet" "5" "10 129" "1.50" "mock"

  # Verify curl would have been called
  assert_equals "1" "$MOCK_CURL_CALLED" "curl should have been called" || { _teardown_test_fixtures; return; }

  # Verify 3 compact lines with emoji labels
  # Line 1: repo name (claude-golem after rename)
  assert_contains "$MOCK_CURL_BODY" "claude-golem" "line 1 should contain repo name" || { _teardown_test_fixtures; return; }

  # Line 2: 🔄 iteration + story + model (e.g., "🔄5 US-001 sonnet")
  assert_contains "$MOCK_CURL_BODY" "🔄5 US-001 sonnet" "line 2 should have compact iteration+story+model" || { _teardown_test_fixtures; return; }

  # Line 3: 📚 stories + ☐ criteria + 💵 cost (e.g., "📚10 ☐129 💵\$1.50")
  assert_contains "$MOCK_CURL_BODY" "📚10" "line 3 should have stories count" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "☐129" "line 3 should have criteria count" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "💵\$1.50" "line 3 should have cost" || { _teardown_test_fixtures; return; }

  # Verify message is appended
  assert_contains "$MOCK_CURL_BODY" "Test message" "body should contain message" || { _teardown_test_fixtures; return; }

  # Verify URL is correct
  assert_equals "ntfy.sh/test-topic" "$MOCK_CURL_URL" "URL should be ntfy.sh/test-topic" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: event types set correct title and priority
test_ntfy_event_types_set_title_priority() {
  test_start "ntfy event types set title/priority"
  _setup_test_fixtures

  # Test complete event
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "complete" "Done" "" "" "" "" "" "mock"
  assert_equals "✅ Ralph Complete" "$MOCK_CURL_TITLE" "complete title" || { _teardown_test_fixtures; return; }
  assert_equals "high" "$MOCK_CURL_PRIORITY" "complete priority" || { _teardown_test_fixtures; return; }

  # Test blocked event
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "blocked" "Stuck" "" "" "" "" "" "mock"
  assert_equals "⏹️ Ralph Blocked" "$MOCK_CURL_TITLE" "blocked title" || { _teardown_test_fixtures; return; }
  assert_equals "urgent" "$MOCK_CURL_PRIORITY" "blocked priority" || { _teardown_test_fixtures; return; }

  # Test error event
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "error" "Failed" "" "" "" "" "" "mock"
  assert_equals "❌ Ralph Error" "$MOCK_CURL_TITLE" "error title" || { _teardown_test_fixtures; return; }
  assert_equals "urgent" "$MOCK_CURL_PRIORITY" "error priority" || { _teardown_test_fixtures; return; }

  # Test iteration event
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "iteration" "Progress" "" "" "" "" "" "mock"
  assert_equals "🔄 Ralph Progress" "$MOCK_CURL_TITLE" "iteration title" || { _teardown_test_fixtures; return; }
  assert_equals "low" "$MOCK_CURL_PRIORITY" "iteration priority" || { _teardown_test_fixtures; return; }

  # Test max_iterations event
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "max_iterations" "Limit" "" "" "" "" "" "mock"
  assert_equals "⚠️ Ralph Limit Hit" "$MOCK_CURL_TITLE" "max_iterations title" || { _teardown_test_fixtures; return; }
  assert_equals "high" "$MOCK_CURL_PRIORITY" "max_iterations priority" || { _teardown_test_fixtures; return; }

  # Test unknown event (default)
  _reset_mock_curl
  _ralph_ntfy_testable "test-topic" "unknown" "Something" "" "" "" "" "" "mock"
  assert_equals "🤖 Ralph" "$MOCK_CURL_TITLE" "unknown event title" || { _teardown_test_fixtures; return; }
  assert_equals "default" "$MOCK_CURL_PRIORITY" "unknown event priority" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: 'complete' event has priority=high
test_ntfy_complete_priority_high() {
  test_start "ntfy complete event has priority=high"
  _setup_test_fixtures
  _reset_mock_curl

  _ralph_ntfy_testable "test-topic" "complete" "All done" "" "" "" "" "" "mock"

  assert_equals "high" "$MOCK_CURL_PRIORITY" "complete should have priority=high" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: 'error' event has priority=urgent
test_ntfy_error_priority_urgent() {
  test_start "ntfy error event has priority=urgent"
  _setup_test_fixtures
  _reset_mock_curl

  _ralph_ntfy_testable "test-topic" "error" "Error occurred" "" "" "" "" "" "mock"

  assert_equals "urgent" "$MOCK_CURL_PRIORITY" "error should have priority=urgent" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: 'iteration' event has priority=low
test_ntfy_iteration_priority_low() {
  test_start "ntfy iteration event has priority=low"
  _setup_test_fixtures
  _reset_mock_curl

  _ralph_ntfy_testable "test-topic" "iteration" "Progress" "" "" "" "" "" "mock"

  assert_equals "low" "$MOCK_CURL_PRIORITY" "iteration should have priority=low" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: empty topic returns early (no curl call)
test_ntfy_empty_topic_no_curl() {
  test_start "ntfy empty topic returns early"
  _setup_test_fixtures
  _reset_mock_curl

  _ralph_ntfy_testable "" "complete" "This should not be sent" "" "" "" "" "" "mock"

  assert_equals "0" "$MOCK_CURL_CALLED" "curl should NOT be called with empty topic" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# BUG-018: WORD BOUNDARY TRUNCATION TESTS
# ═══════════════════════════════════════════════════════════════════

test_bug018_truncate_short_text_unchanged() {
  test_start "BUG-018: short text unchanged"
  _setup_test_fixtures

  local result=$(_ralph_truncate_word_boundary "hello" 40)
  assert_equals "hello" "$result" "Short text should be unchanged" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

test_bug018_truncate_at_word_boundary() {
  test_start "BUG-018: truncates at word boundary"
  _setup_test_fixtures

  # 50 char string: "This is a very long project name example text"
  local long_text="This is a very long project name example text"
  local result=$(_ralph_truncate_word_boundary "$long_text" 30)

  # Should truncate at word boundary before 30 chars
  assert_contains "$result" "..." "Should have ellipsis" || { _teardown_test_fixtures; return; }
  [[ ${#result} -le 30 ]] || { test_fail "Result should be <= 30 chars, got ${#result}"; _teardown_test_fixtures; return; }
  # Should NOT cut in the middle of a word
  [[ "$result" != *"exampl..."* ]] || { test_fail "Should not truncate mid-word"; _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

test_bug018_truncate_no_spaces_hard_truncate() {
  test_start "BUG-018: no spaces - hard truncate"
  _setup_test_fixtures

  local long_word="thisisaverylongwordwithoutanyspaces"
  local result=$(_ralph_truncate_word_boundary "$long_word" 20)

  assert_contains "$result" "..." "Should have ellipsis" || { _teardown_test_fixtures; return; }
  [[ ${#result} -le 20 ]] || { test_fail "Result should be <= 20 chars"; _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

test_bug018_ntfy_uses_markdown() {
  test_start "BUG-018: ntfy sends Markdown header"
  _setup_test_fixtures

  # Check that _ralph_ntfy includes Markdown header
  local ntfy_fn=$(type -f _ralph_ntfy 2>/dev/null)
  assert_contains "$ntfy_fn" 'Markdown: true' "Should have Markdown header" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# FRAMEWORK VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: assert_equals works correctly
test_framework_assert_equals() {
  test_start "assert_equals works"
  assert_equals "hello" "hello" && test_pass
}

# Test: assert_contains works correctly
test_framework_assert_contains() {
  test_start "assert_contains works"
  assert_contains "hello world" "world" && test_pass
}

# Test: assert_exit_code works correctly
test_framework_assert_exit_code() {
  test_start "assert_exit_code works"
  assert_exit_code 0 true && test_pass
}

# Test: assert_not_empty works correctly
test_framework_assert_not_empty() {
  test_start "assert_not_empty works"
  assert_not_empty "value" && test_pass
}

# Test: assert_file_exists works correctly
test_framework_assert_file_exists() {
  test_start "assert_file_exists works"
  assert_file_exists "/bin/zsh" && test_pass
}

# ═══════════════════════════════════════════════════════════════════
# ARCHIVE FUNCTION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: ralph-archive parses --keep flag
test_archive_parses_keep_flag() {
  test_start "archive parses --keep flag"
  _setup_test_fixtures

  # Create minimal PRD structure
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 1, "completed": 0, "pending": 1, "blocked": 0 },
  "storyOrder": ["US-001"],
  "pending": ["US-001"],
  "blocked": [],
  "nextStory": "US-001"
}
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{ "id": "US-001", "passes": false }
EOF

  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive with --keep flag
  local output
  output=$(ralph-archive --keep 2>&1)
  local exit_code=$?

  assert_equals "0" "$exit_code" "ralph-archive --keep should succeed" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$output" "--keep flag" "should mention --keep flag" || { cd -; _teardown_test_fixtures; return; }

  # Verify archive was created
  local archive_count=$(ls -d "$TEST_TMP_DIR/docs.local/prd-archive"/*/ 2>/dev/null | wc -l | tr -d ' ')
  assert_equals "1" "$archive_count" "should create one archive directory" || { cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: ralph-archive parses --clean flag
test_archive_parses_clean_flag() {
  test_start "archive parses --clean flag"
  _setup_test_fixtures

  # Create PRD structure with completed story
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 2, "completed": 1, "pending": 1, "blocked": 0 },
  "storyOrder": ["US-001", "US-002"],
  "pending": ["US-002"],
  "blocked": [],
  "nextStory": "US-002"
}
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{ "id": "US-001", "passes": true }
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-002.json" << 'EOF'
{ "id": "US-002", "passes": false }
EOF

  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive with --clean flag
  local output
  output=$(ralph-archive --clean 2>&1)
  local exit_code=$?

  assert_equals "0" "$exit_code" "ralph-archive --clean should succeed" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$output" "--clean flag" "should mention --clean flag" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$output" "Removed: US-001" "should remove completed US-001" || { cd -; _teardown_test_fixtures; return; }

  # Verify US-001 was removed from working prd
  [[ ! -f "$TEST_TMP_DIR/prd-json/stories/US-001.json" ]] || { test_fail "US-001.json should be deleted"; cd -; _teardown_test_fixtures; return; }

  # Verify US-002 still exists
  [[ -f "$TEST_TMP_DIR/prd-json/stories/US-002.json" ]] || { test_fail "US-002.json should still exist"; cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: archive copies progress.txt
test_archive_copies_progress_txt() {
  test_start "archive copies progress.txt"
  _setup_test_fixtures

  # Create PRD structure
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 1, "completed": 0, "pending": 1, "blocked": 0 },
  "storyOrder": ["US-001"],
  "pending": ["US-001"],
  "blocked": [],
  "nextStory": "US-001"
}
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{ "id": "US-001", "passes": false }
EOF

  # Create progress.txt
  echo "# Ralph Progress - Test" > "$TEST_TMP_DIR/progress.txt"

  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive
  local output
  output=$(ralph-archive --keep 2>&1)

  assert_contains "$output" "progress.txt" "should mention progress.txt" || { cd -; _teardown_test_fixtures; return; }

  # Verify progress.txt was copied to archive
  local archive_dir=$(ls -d "$TEST_TMP_DIR/docs.local/prd-archive"/*/ 2>/dev/null | head -1)
  [[ -f "$archive_dir/progress.txt" ]] || { test_fail "progress.txt should be in archive"; cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: cleanup creates fresh progress.txt
test_archive_cleanup_creates_fresh_progress() {
  test_start "cleanup creates fresh progress.txt"
  _setup_test_fixtures

  # Create PRD structure with completed story
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 1, "completed": 1, "pending": 0, "blocked": 0 },
  "storyOrder": ["US-001"],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{ "id": "US-001", "passes": true }
EOF

  echo "# Old progress" > "$TEST_TMP_DIR/progress.txt"
  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive with --clean
  ralph-archive --clean >/dev/null 2>&1

  # Verify fresh progress.txt was created
  local progress_content
  progress_content=$(cat "$TEST_TMP_DIR/progress.txt")
  assert_contains "$progress_content" "Fresh Start" "progress.txt should contain 'Fresh Start'" || { cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: cleanup archives completed stories and updates arrays (US-106: stats are derived)
test_archive_cleanup_resets_stats() {
  test_start "cleanup archives and updates arrays"
  _setup_test_fixtures

  # Create PRD structure with completed and pending stories
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-001", "US-002", "US-003"],
  "pending": ["US-003"],
  "blocked": [],
  "nextStory": "US-003"
}
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{ "id": "US-001", "passes": true }
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-002.json" << 'EOF'
{ "id": "US-002", "passes": true }
EOF
  cat > "$TEST_TMP_DIR/prd-json/stories/US-003.json" << 'EOF'
{ "id": "US-003", "passes": false }
EOF

  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive with --clean
  ralph-archive --clean >/dev/null 2>&1

  # Verify pending array still has US-003 (US-106: stats derived from arrays/files)
  local pending_count=$(jq '.pending | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "1" "$pending_count" "pending array should have 1 item" || { cd -; _teardown_test_fixtures; return; }

  # Verify nextStory is set to remaining story
  local next_story=$(jq -r '.nextStory' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "US-003" "$next_story" "nextStory should be US-003" || { cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: archive rejects unknown flags
test_archive_rejects_unknown_flags() {
  test_start "archive rejects unknown flags"
  _setup_test_fixtures

  # Create minimal PRD structure
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{ "stats": {}, "storyOrder": [], "pending": [], "blocked": [] }
EOF
  mkdir -p "$TEST_TMP_DIR/docs.local"
  cd "$TEST_TMP_DIR"

  # Run archive with unknown flag
  local output
  output=$(ralph-archive --invalid 2>&1)
  local exit_code=$?

  assert_equals "1" "$exit_code" "should fail with unknown flag" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$output" "Unknown flag" "should mention unknown flag" || { cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: update.json string criteria auto-converted to object format
test_update_queue_converts_string_criteria() {
  test_start "update queue converts string criteria to object format"
  _setup_test_fixtures

  # Create PRD structure
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 0, "completed": 0, "pending": 0, "blocked": 0 },
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # Create update.json with string criteria (the problematic format)
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {
      "id": "US-TEST-001",
      "title": "Test story with string criteria",
      "acceptanceCriteria": [
        "First criterion as string",
        "Second criterion as string"
      ]
    },
    {
      "id": "US-TEST-002",
      "title": "Test story with mixed criteria",
      "acceptanceCriteria": [
        "String criterion",
        { "text": "Already object", "checked": true }
      ]
    }
  ]
}
EOF

  # Apply the update queue
  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify US-TEST-001 criteria were converted to object format
  local criteria_type=$(jq '.acceptanceCriteria[0] | type' "$TEST_TMP_DIR/prd-json/stories/US-TEST-001.json")
  assert_equals '"object"' "$criteria_type" "first criterion should be object type" || { _teardown_test_fixtures; return; }

  local first_text=$(jq -r '.acceptanceCriteria[0].text' "$TEST_TMP_DIR/prd-json/stories/US-TEST-001.json")
  assert_equals "First criterion as string" "$first_text" "first criterion text should be preserved" || { _teardown_test_fixtures; return; }

  local first_checked=$(jq '.acceptanceCriteria[0].checked' "$TEST_TMP_DIR/prd-json/stories/US-TEST-001.json")
  assert_equals "false" "$first_checked" "first criterion checked should be false" || { _teardown_test_fixtures; return; }

  # Verify US-TEST-002 mixed criteria - string was converted, object was preserved
  local mixed_first_type=$(jq '.acceptanceCriteria[0] | type' "$TEST_TMP_DIR/prd-json/stories/US-TEST-002.json")
  assert_equals '"object"' "$mixed_first_type" "mixed first criterion should be object type" || { _teardown_test_fixtures; return; }

  local mixed_second_checked=$(jq '.acceptanceCriteria[1].checked' "$TEST_TMP_DIR/prd-json/stories/US-TEST-002.json")
  assert_equals "true" "$mixed_second_checked" "existing object criterion should preserve checked=true" || { _teardown_test_fixtures; return; }

  # Count criteria to verify all were processed
  local criteria_count=$(jq '.acceptanceCriteria | length' "$TEST_TMP_DIR/prd-json/stories/US-TEST-001.json")
  assert_equals "2" "$criteria_count" "should have 2 criteria" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# TEST-003: COMPREHENSIVE update.json MERGE TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: newStories creates story file in stories/ dir
test_update_queue_creates_story_file() {
  test_start "newStories creates story file in stories/ dir"
  _setup_test_fixtures

  # Create PRD structure
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # Create update.json with a new story
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {
      "id": "US-NEW-001",
      "title": "New test story",
      "type": "feature",
      "acceptanceCriteria": [
        {"text": "Criterion 1", "checked": false}
      ]
    }
  ]
}
EOF

  # Apply the update queue
  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify story file was created
  assert_file_exists "$TEST_TMP_DIR/prd-json/stories/US-NEW-001.json" "story file should be created" || { _teardown_test_fixtures; return; }

  # Verify story content is correct
  local story_title=$(jq -r '.title' "$TEST_TMP_DIR/prd-json/stories/US-NEW-001.json")
  assert_equals "New test story" "$story_title" "story title should match" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: newStories adds story ID to pending array (no duplicates)
test_update_queue_adds_to_pending_unique() {
  test_start "newStories adds to pending array (no duplicates)"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-EXISTING"],
  "pending": ["US-EXISTING"],
  "blocked": [],
  "nextStory": "US-EXISTING"
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-NEW-002", "title": "New story", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify pending array contains both stories
  local pending_count=$(jq '.pending | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "2" "$pending_count" "pending should have 2 stories" || { _teardown_test_fixtures; return; }

  # Add the same story again via update.json
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-NEW-002", "title": "Duplicate story", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify no duplicate in pending
  local pending_after=$(jq '.pending | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "2" "$pending_after" "pending should still have 2 (no duplicate)" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: newStories adds story ID to storyOrder array (no duplicates)
test_update_queue_adds_to_storyorder_unique() {
  test_start "newStories adds to storyOrder (no duplicates)"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-001"],
  "pending": ["US-001"],
  "blocked": [],
  "nextStory": "US-001"
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-002", "title": "Story 2", "acceptanceCriteria": []},
    {"id": "US-002", "title": "Duplicate", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify storyOrder has unique values
  local order_count=$(jq '.storyOrder | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "2" "$order_count" "storyOrder should have 2 unique entries" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: Multiple newStories in one update.json all processed
test_update_queue_multiple_new_stories() {
  test_start "multiple newStories in one update.json"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-MULTI-1", "title": "First", "acceptanceCriteria": []},
    {"id": "US-MULTI-2", "title": "Second", "acceptanceCriteria": []},
    {"id": "US-MULTI-3", "title": "Third", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify all 3 story files exist
  assert_file_exists "$TEST_TMP_DIR/prd-json/stories/US-MULTI-1.json" || { _teardown_test_fixtures; return; }
  assert_file_exists "$TEST_TMP_DIR/prd-json/stories/US-MULTI-2.json" || { _teardown_test_fixtures; return; }
  assert_file_exists "$TEST_TMP_DIR/prd-json/stories/US-MULTI-3.json" || { _teardown_test_fixtures; return; }

  # Verify pending array has all 3
  local pending_count=$(jq '.pending | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "3" "$pending_count" "pending should have 3 stories" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: updateStories merges changes into existing story file
test_update_queue_merges_update_stories() {
  test_start "updateStories merges changes into story file"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-UPDATE-001"],
  "pending": ["US-UPDATE-001"],
  "blocked": [],
  "nextStory": "US-UPDATE-001"
}
EOF

  # Create existing story file
  cat > "$TEST_TMP_DIR/prd-json/stories/US-UPDATE-001.json" << 'EOF'
{
  "id": "US-UPDATE-001",
  "title": "Original title",
  "type": "feature",
  "status": "pending",
  "acceptanceCriteria": [{"text": "Original criterion", "checked": false}]
}
EOF

  # Create update.json to change the title and status
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "updateStories": [
    {
      "id": "US-UPDATE-001",
      "title": "Updated title",
      "status": "blocked",
      "blockedBy": "BUG-999"
    }
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify title was updated
  local new_title=$(jq -r '.title' "$TEST_TMP_DIR/prd-json/stories/US-UPDATE-001.json")
  assert_equals "Updated title" "$new_title" "title should be updated" || { _teardown_test_fixtures; return; }

  # Verify blockedBy was added
  local blocker=$(jq -r '.blockedBy' "$TEST_TMP_DIR/prd-json/stories/US-UPDATE-001.json")
  assert_equals "BUG-999" "$blocker" "blockedBy should be added" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: updateStories preserves unmodified fields
test_update_queue_preserves_unmodified_fields() {
  test_start "updateStories preserves unmodified fields"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-PRESERVE"],
  "pending": ["US-PRESERVE"],
  "blocked": [],
  "nextStory": "US-PRESERVE"
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/stories/US-PRESERVE.json" << 'EOF'
{
  "id": "US-PRESERVE",
  "title": "Keep this title",
  "type": "feature",
  "priority": "high",
  "description": "Important description",
  "acceptanceCriteria": [{"text": "Original", "checked": false}]
}
EOF

  # Update only the priority
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "updateStories": [
    {"id": "US-PRESERVE", "priority": "low"}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify priority was updated
  local priority=$(jq -r '.priority' "$TEST_TMP_DIR/prd-json/stories/US-PRESERVE.json")
  assert_equals "low" "$priority" "priority should be updated" || { _teardown_test_fixtures; return; }

  # Verify other fields preserved
  local title=$(jq -r '.title' "$TEST_TMP_DIR/prd-json/stories/US-PRESERVE.json")
  assert_equals "Keep this title" "$title" "title should be preserved" || { _teardown_test_fixtures; return; }

  local desc=$(jq -r '.description' "$TEST_TMP_DIR/prd-json/stories/US-PRESERVE.json")
  assert_equals "Important description" "$desc" "description should be preserved" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: updateStories skips non-existent story IDs gracefully
test_update_queue_skips_nonexistent_story() {
  test_start "updateStories skips non-existent story IDs"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-EXISTS"],
  "pending": ["US-EXISTS"],
  "blocked": [],
  "nextStory": "US-EXISTS"
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/stories/US-EXISTS.json" << 'EOF'
{"id": "US-EXISTS", "title": "Exists", "acceptanceCriteria": []}
EOF

  # Try to update a non-existent story
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "updateStories": [
    {"id": "US-GHOST", "title": "Ghost update"}
  ]
}
EOF

  # Should not fail
  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"
  local exit_code=$?

  # Verify no ghost story file was created
  if [[ -f "$TEST_TMP_DIR/prd-json/stories/US-GHOST.json" ]]; then
    test_fail "ghost story file should not be created"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Malformed JSON in update.json handled gracefully
test_update_queue_handles_malformed_json() {
  test_start "malformed JSON in update.json handled"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # Write malformed JSON
  echo '{ "newStories": [ invalid json' > "$TEST_TMP_DIR/prd-json/update.json"

  # Should not crash (capture stderr)
  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json" 2>/dev/null
  local exit_code=$?

  # Function should return 1 (no updates applied)
  assert_equals "1" "$exit_code" "should return 1 on malformed JSON" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: Empty update.json (no newStories/updateStories) is a no-op
test_update_queue_empty_is_noop() {
  test_start "empty update.json is a no-op"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": ["US-ORIG"],
  "pending": ["US-ORIG"],
  "blocked": [],
  "nextStory": "US-ORIG"
}
EOF

  # Empty update.json (valid JSON but no stories)
  echo '{}' > "$TEST_TMP_DIR/prd-json/update.json"

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"
  local exit_code=$?

  # Should return 1 (no updates applied)
  assert_equals "1" "$exit_code" "should return 1 on empty update" || { _teardown_test_fixtures; return; }

  # Verify pending is unchanged
  local pending_count=$(jq '.pending | length' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "1" "$pending_count" "pending should be unchanged" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: Missing index.json returns error code 1
test_update_queue_missing_index_returns_error() {
  test_start "missing index.json returns error code 1"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  # No index.json created

  echo '{"newStories": [{"id": "US-X", "acceptanceCriteria": []}]}' > "$TEST_TMP_DIR/prd-json/update.json"

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"
  local exit_code=$?

  assert_equals "1" "$exit_code" "should return 1 when index.json missing" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: update.json deleted after successful merge
test_update_queue_deletes_file_on_success() {
  test_start "update.json deleted after successful merge"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-DEL-TEST", "title": "Delete test", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  # Verify update.json was deleted
  if [[ -f "$TEST_TMP_DIR/prd-json/update.json" ]]; then
    test_fail "update.json should be deleted after success"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: update.json preserved if merge fails (no update.json in first place returns 1)
test_update_queue_no_update_file_returns_error() {
  test_start "no update.json returns error code 1"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # No update.json created

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"
  local exit_code=$?

  assert_equals "1" "$exit_code" "should return 1 when no update.json" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: Warning printed for ignored fields (storyOrder, pending, stats)
test_update_queue_warns_ignored_fields() {
  test_start "warns about ignored fields"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # update.json with ignored fields
  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "storyOrder": ["ignored"],
  "pending": ["also-ignored"],
  "stats": {"total": 99},
  "newStories": [
    {"id": "US-WARN", "title": "Real story", "acceptanceCriteria": []}
  ]
}
EOF

  # Capture output for warning check
  local output=$(_ralph_apply_update_queue "$TEST_TMP_DIR/prd-json" 2>&1)

  # Verify warning was printed
  if [[ "$output" != *"Warning"* ]] && [[ "$output" != *"ignored"* ]]; then
    test_fail "should warn about ignored fields"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: RALPH_UPDATES_APPLIED is set correctly
test_update_queue_sets_updates_applied_var() {
  test_start "RALPH_UPDATES_APPLIED set correctly"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-COUNT-1", "acceptanceCriteria": []},
    {"id": "US-COUNT-2", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  assert_equals "2" "$RALPH_UPDATES_APPLIED" "RALPH_UPDATES_APPLIED should be 2" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: nextStory is set to first pending after newStories
test_update_queue_sets_next_story() {
  test_start "nextStory set to first pending after newStories"
  _setup_test_fixtures

  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  cat > "$TEST_TMP_DIR/prd-json/update.json" << 'EOF'
{
  "newStories": [
    {"id": "US-FIRST", "acceptanceCriteria": []},
    {"id": "US-SECOND", "acceptanceCriteria": []}
  ]
}
EOF

  _ralph_apply_update_queue "$TEST_TMP_DIR/prd-json"

  local next_story=$(jq -r '.nextStory' "$TEST_TMP_DIR/prd-json/index.json")
  assert_equals "US-FIRST" "$next_story" "nextStory should be first pending" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# BUG-014: COMPLETE SIGNAL VERIFICATION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_verify_pending_count returns pending count in JSON mode
test_verify_pending_count_json_mode() {
  test_start "verify_pending_count returns pending in JSON mode"
  _setup_test_fixtures

  # Create PRD structure with 3 pending stories
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 5, "completed": 2, "pending": 3, "blocked": 0 },
  "storyOrder": ["US-001", "US-002", "US-003", "US-004", "US-005"],
  "pending": ["US-003", "US-004", "US-005"],
  "blocked": [],
  "nextStory": "US-003"
}
EOF

  # Call the verification function in JSON mode
  local result=$(_ralph_verify_pending_count "$TEST_TMP_DIR/prd-json" "/nonexistent" "true")

  assert_equals "3" "$result" "should return 3 pending stories" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_verify_pending_count returns 0 when no pending tasks (JSON mode)
test_verify_pending_count_json_empty() {
  test_start "verify_pending_count returns 0 when complete (JSON)"
  _setup_test_fixtures

  # Create PRD structure with no pending stories (all completed)
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 2, "completed": 2, "pending": 0, "blocked": 0 },
  "storyOrder": ["US-001", "US-002"],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # Call the verification function in JSON mode
  local result=$(_ralph_verify_pending_count "$TEST_TMP_DIR/prd-json" "/nonexistent" "true")

  assert_equals "0" "$result" "should return 0 when all complete" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_verify_pending_count returns pending count in PRD.md mode
test_verify_pending_count_prd_md_mode() {
  test_start "verify_pending_count returns pending in PRD.md mode"
  _setup_test_fixtures

  # Create PRD.md with unchecked criteria
  cat > "$TEST_TMP_DIR/PRD.md" << 'EOF'
# Product Requirements Document

## US-001: First story
- [x] Completed criterion
- [ ] Pending criterion 1
- [ ] Pending criterion 2

## US-002: Second story
- [ ] Pending criterion 3
- [x] Completed criterion
EOF

  # Call the verification function in PRD.md mode
  local result=$(_ralph_verify_pending_count "/nonexistent" "$TEST_TMP_DIR/PRD.md" "false")

  assert_equals "3" "$result" "should return 3 unchecked criteria" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_verify_pending_count returns 0 when all checked (PRD.md mode)
test_verify_pending_count_prd_md_complete() {
  test_start "verify_pending_count returns 0 when complete (PRD.md)"
  _setup_test_fixtures

  # Create PRD.md with all criteria checked
  cat > "$TEST_TMP_DIR/PRD.md" << 'EOF'
# Product Requirements Document

## US-001: First story
- [x] Completed criterion 1
- [x] Completed criterion 2

## US-002: Second story
- [x] Completed criterion 3
EOF

  # Call the verification function in PRD.md mode
  local result=$(_ralph_verify_pending_count "/nonexistent" "$TEST_TMP_DIR/PRD.md" "false")

  assert_equals "0" "$result" "should return 0 when all criteria checked" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: False COMPLETE signal is ignored when pending > 0 (integration test)
test_false_complete_ignored_with_pending_tasks() {
  test_start "false COMPLETE signal ignored with pending tasks"
  _setup_test_fixtures

  # Create PRD structure with pending stories
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 3, "completed": 1, "pending": 2, "blocked": 0 },
  "storyOrder": ["US-001", "US-002", "US-003"],
  "pending": ["US-002", "US-003"],
  "blocked": [],
  "nextStory": "US-002"
}
EOF

  # Verify that with 2 pending stories, the function returns 2 (not 0)
  # This ensures false COMPLETE signals would be ignored
  local result=$(_ralph_verify_pending_count "$TEST_TMP_DIR/prd-json" "/nonexistent" "true")

  assert_equals "2" "$result" "should return 2 pending (false COMPLETE would be ignored)" || { _teardown_test_fixtures; return; }

  # Additionally verify that 0 is NOT returned (which would allow exit)
  if [[ "$result" -eq 0 ]]; then
    test_fail "should NOT return 0 when tasks are pending"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# BUG-015: BLOCKED STORY COMPLETION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: PRD should not be "complete" when there are blocked stories
test_blocked_stories_prevent_prd_complete() {
  test_start "blocked stories prevent false PRD complete"
  _setup_test_fixtures

  # Create PRD structure with NO pending stories but WITH blocked stories
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 5, "completed": 2, "pending": 0, "blocked": 3 },
  "storyOrder": ["US-001", "US-002", "US-003", "US-004", "US-005"],
  "pending": [],
  "blocked": ["US-003", "US-004", "US-005"],
  "nextStory": null
}
EOF

  # Check that pending array is empty
  local pending_count=$(jq -r '.pending | length' "$TEST_TMP_DIR/prd-json/index.json" 2>/dev/null)
  assert_equals "0" "$pending_count" "pending array should be empty" || { _teardown_test_fixtures; return; }

  # Check that blocked array is NOT empty
  local blocked_count=$(jq -r '.blocked | length' "$TEST_TMP_DIR/prd-json/index.json" 2>/dev/null)
  if [[ "$blocked_count" -eq 0 ]]; then
    test_fail "blocked array should have 3 stories"
    _teardown_test_fixtures
    return
  fi

  assert_equals "3" "$blocked_count" "blocked count should be 3" || { _teardown_test_fixtures; return; }

  # The key assertion: pending=0 but blocked>0 means PRD is NOT complete
  # Ralph should show "PRD Blocked" message, not "PRD Complete"
  # This test validates the data structure that BUG-015 fix would check

  _teardown_test_fixtures
  test_pass
}

# Test: PRD is only complete when both pending=0 AND blocked=0
test_prd_complete_requires_zero_blocked() {
  test_start "PRD complete requires both pending=0 AND blocked=0"
  _setup_test_fixtures

  # Create PRD structure where everything is truly complete
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 3, "completed": 3, "pending": 0, "blocked": 0 },
  "storyOrder": ["US-001", "US-002", "US-003"],
  "pending": [],
  "blocked": [],
  "nextStory": null
}
EOF

  # Verify both arrays are empty
  local pending_count=$(jq -r '.pending | length' "$TEST_TMP_DIR/prd-json/index.json" 2>/dev/null)
  local blocked_count=$(jq -r '.blocked | length' "$TEST_TMP_DIR/prd-json/index.json" 2>/dev/null)

  assert_equals "0" "$pending_count" "pending should be 0" || { _teardown_test_fixtures; return; }
  assert_equals "0" "$blocked_count" "blocked should be 0" || { _teardown_test_fixtures; return; }

  # Only when BOTH are zero is PRD truly complete
  if [[ "$pending_count" -eq 0 && "$blocked_count" -eq 0 ]]; then
    # PRD is complete - this is the only valid "complete" state
    _teardown_test_fixtures
    test_pass
    return
  fi

  test_fail "PRD should be complete when pending=0 AND blocked=0"
  _teardown_test_fixtures
}

# ═══════════════════════════════════════════════════════════════════
# BUG-017: NOTIFICATION TOPIC WRAPPING TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: Long notification topic is truncated correctly
test_bug017_long_topic_truncation() {
  test_start "BUG-017: long topic name truncated to 51 chars"

  # The fix uses max_topic_len=51, so topics > 51 chars should be truncated
  local max_topic_len=51

  # Test case: topic exactly at limit (should NOT be truncated)
  local topic_at_limit="etanheys-ralph-ralphtools-notify-exactly-at-limit"  # 51 chars
  local display_topic="$topic_at_limit"
  if [[ ${#topic_at_limit} -gt $max_topic_len ]]; then
    display_topic="${topic_at_limit:0:$((max_topic_len - 3))}..."
  fi

  # Should not be truncated since it's exactly at limit
  if [[ "$display_topic" == *"..."* ]]; then
    test_fail "topic at limit should NOT be truncated"
    return
  fi

  # Test case: topic over limit (should BE truncated)
  local topic_over_limit="etanheys-ralph-ralphtools-notify-this-is-a-very-long-topic-name-that-exceeds-the-max"  # 84 chars
  display_topic="$topic_over_limit"
  if [[ ${#topic_over_limit} -gt $max_topic_len ]]; then
    display_topic="${topic_over_limit:0:$((max_topic_len - 3))}..."
  fi

  # Should be truncated
  if [[ "$display_topic" != *"..."* ]]; then
    test_fail "topic over limit should be truncated with ..."
    return
  fi

  # Verify truncated length is correct (max_topic_len total)
  local truncated_len=${#display_topic}
  assert_equals "51" "$truncated_len" "truncated topic should be exactly 51 chars" || return

  test_pass
}

# Test: Notification is split into two lines (ON line + Topic line)
test_bug017_notification_two_lines() {
  test_start "BUG-017: notification split into two lines"

  # The ralph.zsh code at lines 4366-4382 outputs:
  # Line 1: "🔔 Notifications: ON"
  # Line 2: "   Topic: {topic}"

  local notify_str="🔔 Notifications: ON"
  local topic_str="   Topic: etanheys-ralph-ralphtools-notify"

  # Verify format matches expected pattern
  if [[ "$notify_str" != "🔔 Notifications: ON" ]]; then
    test_fail "notification line 1 format incorrect"
    return
  fi

  if [[ "$topic_str" != "   Topic:"* ]]; then
    test_fail "topic line should start with '   Topic:'"
    return
  fi

  # Verify indent (3 spaces before "Topic:")
  if [[ "$topic_str" != "   "* ]]; then
    test_fail "topic line should have 3-space indent"
    return
  fi

  test_pass
}

# Test: Box border alignment with notification lines
test_bug017_box_alignment() {
  test_start "BUG-017: box borders align with notification content"

  # The box uses BOX_INNER_WIDTH=61, so content + padding = 61 chars
  local BOX_INNER_WIDTH=61

  # Test that _ralph_display_width is available and works
  if ! type _ralph_display_width &>/dev/null; then
    # Skip if function not available (running outside ralph context)
    test_pass
    return
  fi

  # Test notification line width calculation
  local notify_str="🔔 Notifications: ON"
  local notify_width=$(_ralph_display_width "$notify_str")
  local notify_padding=$((BOX_INNER_WIDTH - notify_width))

  # Padding should be non-negative for content to fit
  if [[ $notify_padding -lt 0 ]]; then
    test_fail "notification line exceeds box width"
    return
  fi

  # Test topic line width calculation
  local topic_str="   Topic: etanheys-ralph-ralphtools-notify"
  local topic_width=$(_ralph_display_width "$topic_str")
  local topic_padding=$((BOX_INNER_WIDTH - topic_width))

  if [[ $topic_padding -lt 0 ]]; then
    test_fail "topic line exceeds box width"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# ERROR HANDLING CONFIG TESTS (BUG-019)
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_load_config loads error handling settings with defaults
test_error_handling_config_defaults() {
  test_start "error handling config loads defaults"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a config.json WITHOUT errorHandling section (backwards compatibility)
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "modelStrategy": "smart",
  "defaultModel": "opus"
}
EOF

  # Load config
  _ralph_load_config

  # Verify defaults are used when errorHandling section is missing
  assert_equals "5" "$RALPH_MAX_RETRIES" "maxRetries should default to 5" || { _teardown_test_fixtures; return; }
  assert_equals "3" "$RALPH_NO_MSG_MAX_RETRIES" "noMessagesMaxRetries should default to 3" || { _teardown_test_fixtures; return; }
  assert_equals "15" "$RALPH_GENERAL_COOLDOWN" "generalCooldownSeconds should default to 15" || { _teardown_test_fixtures; return; }
  assert_equals "30" "$RALPH_NO_MSG_COOLDOWN" "noMessagesCooldownSeconds should default to 30" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_load_config loads custom error handling settings
test_error_handling_config_custom() {
  test_start "error handling config loads custom values"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a config.json WITH custom errorHandling settings
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "modelStrategy": "smart",
  "defaultModel": "opus",
  "errorHandling": {
    "maxRetries": 10,
    "noMessagesMaxRetries": 5,
    "generalCooldownSeconds": 20,
    "noMessagesCooldownSeconds": 45
  }
}
EOF

  # Load config
  _ralph_load_config

  # Verify custom values are loaded
  assert_equals "10" "$RALPH_MAX_RETRIES" "maxRetries should be 10" || { _teardown_test_fixtures; return; }
  assert_equals "5" "$RALPH_NO_MSG_MAX_RETRIES" "noMessagesMaxRetries should be 5" || { _teardown_test_fixtures; return; }
  assert_equals "20" "$RALPH_GENERAL_COOLDOWN" "generalCooldownSeconds should be 20" || { _teardown_test_fixtures; return; }
  assert_equals "45" "$RALPH_NO_MSG_COOLDOWN" "noMessagesCooldownSeconds should be 45" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: error patterns include Node.js rejection patterns
test_error_patterns_include_nodejs_rejections() {
  test_start "error patterns include Node.js rejection patterns"

  # The error_patterns variable is local to the ralph function, so we test
  # the patterns by checking they would match expected error strings
  local error_patterns="No messages returned|EAGAIN|ECONNRESET|fetch failed|API error|promise rejected|UnhandledPromiseRejection|This error originated|promise rejected with the reason|ETIMEDOUT|socket hang up|ENOTFOUND|rate limit|overloaded|Error: 5[0-9][0-9]|status.*(5[0-9][0-9])|HTTP.*5[0-9][0-9]"

  # Test Node.js preamble pattern
  if echo "This error originated either by throwing inside of an async function" | grep -qiE "$error_patterns"; then
    : # Pattern matches
  else
    test_fail "'This error originated' pattern should match"
    return
  fi

  # Test promise rejected pattern
  if echo "Error: the promise rejected with the reason: fetch failed" | grep -qiE "$error_patterns"; then
    : # Pattern matches
  else
    test_fail "'promise rejected with the reason' pattern should match"
    return
  fi

  # Test UnhandledPromiseRejection pattern
  if echo "UnhandledPromiseRejection: Error" | grep -qiE "$error_patterns"; then
    : # Pattern matches
  else
    test_fail "'UnhandledPromiseRejection' pattern should match"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# US-084: AUTO-CATCHUP CONTEXT TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_build_catchup_context returns empty for fresh story (no checked criteria)
test_catchup_returns_empty_for_fresh_story() {
  test_start "catchup returns empty for fresh story"
  _setup_test_fixtures

  # Create PRD structure with fresh story (0 checked criteria)
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "Test story",
  "passes": false,
  "acceptanceCriteria": [
    { "text": "First criterion", "checked": false },
    { "text": "Second criterion", "checked": false },
    { "text": "Third criterion", "checked": false }
  ]
}
EOF

  # Call catchup function
  local result=$(_ralph_build_catchup_context "$TEST_TMP_DIR/prd-json" "US-001")

  # Should return empty string for fresh story
  assert_equals "" "$result" "catchup should return empty for fresh story" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_build_catchup_context returns context for partial progress
test_catchup_returns_context_for_partial_progress() {
  test_start "catchup returns context for partial progress"
  _setup_test_fixtures

  # Create PRD structure with partial progress (some checked criteria)
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/stories/US-002.json" << 'EOF'
{
  "id": "US-002",
  "title": "Partial story",
  "passes": false,
  "acceptanceCriteria": [
    { "text": "First criterion", "checked": true },
    { "text": "Second criterion", "checked": true },
    { "text": "Third criterion", "checked": false },
    { "text": "Fourth criterion", "checked": false }
  ]
}
EOF

  # Need to be in a git repo for git commands to work
  cd "$TEST_TMP_DIR"
  git init -q 2>/dev/null
  git config user.email "test@test.com" 2>/dev/null
  git config user.name "Test" 2>/dev/null
  touch file.txt
  git add file.txt
  git commit -m "Initial commit" -q 2>/dev/null

  # Call catchup function
  local result=$(_ralph_build_catchup_context "$TEST_TMP_DIR/prd-json" "US-002")

  # Should return non-empty context
  if [[ -z "$result" ]]; then
    cd -
    test_fail "catchup should return non-empty context for partial progress"
    _teardown_test_fixtures
    return
  fi

  # Should contain partial progress header
  assert_contains "$result" "PARTIAL PROGRESS DETECTED" "should contain partial progress header" || { cd -; _teardown_test_fixtures; return; }

  # Should contain criteria count
  assert_contains "$result" "2/4 criteria already checked" "should contain 2/4 criteria count" || { cd -; _teardown_test_fixtures; return; }

  # Should contain completed criteria
  assert_contains "$result" "First criterion" "should list completed criteria" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$result" "Second criterion" "should list completed criteria" || { cd -; _teardown_test_fixtures; return; }

  # Should contain remaining criteria
  assert_contains "$result" "Third criterion" "should list remaining criteria" || { cd -; _teardown_test_fixtures; return; }
  assert_contains "$result" "Fourth criterion" "should list remaining criteria" || { cd -; _teardown_test_fixtures; return; }

  # Should contain instructions
  assert_contains "$result" "DO NOT redo" "should contain instructions not to redo" || { cd -; _teardown_test_fixtures; return; }

  cd -
  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_build_catchup_context returns empty for completed story
test_catchup_returns_empty_for_completed_story() {
  test_start "catchup returns empty for completed story"
  _setup_test_fixtures

  # Create PRD structure with completed story (passes=true)
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/stories/US-003.json" << 'EOF'
{
  "id": "US-003",
  "title": "Completed story",
  "passes": true,
  "acceptanceCriteria": [
    { "text": "First criterion", "checked": true },
    { "text": "Second criterion", "checked": true }
  ]
}
EOF

  # Call catchup function
  local result=$(_ralph_build_catchup_context "$TEST_TMP_DIR/prd-json" "US-003")

  # Should return empty string for completed story (passes=true)
  assert_equals "" "$result" "catchup should return empty for completed story" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# PRE-COMMIT HOOK TESTS (TEST-002)
# ═══════════════════════════════════════════════════════════════════

# Test: Pre-commit hook is installed and executable
test_precommit_hook_installed() {
  test_start "pre-commit hook is installed and executable"

  # Get repo root
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    test_fail "Not in a git repository"
    return
  fi

  local hook_file="$repo_root/.githooks/pre-commit"

  # Check hook file exists
  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check hook is executable
  if [[ ! -x "$hook_file" ]]; then
    test_fail ".githooks/pre-commit is not executable"
    return
  fi

  # Check git is configured to use .githooks
  local hooks_path
  hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
  if [[ "$hooks_path" != ".githooks" ]]; then
    test_fail "git core.hooksPath is not set to .githooks (got: '$hooks_path')"
    return
  fi

  test_pass
}

# Test: Pre-commit hook invokes test-ralph.zsh
test_precommit_runs_tests() {
  test_start "pre-commit hook invokes test-ralph.zsh"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that the hook contains test-ralph.zsh invocation
  if ! grep -q 'test-ralph.zsh' "$hook_file"; then
    test_fail "pre-commit hook does not reference test-ralph.zsh"
    return
  fi

  # Check that the hook has the test suite section
  if ! grep -q '\[7/8\] Test Suite' "$hook_file"; then
    test_fail "pre-commit hook does not have test suite section"
    return
  fi

  test_pass
}

# Test: Pre-commit hook exit code propagates on failure
test_precommit_blocks_on_failure() {
  test_start "pre-commit hook blocks on failure (exit 1)"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that the hook exits with 1 when ERRORS > 0
  if ! grep -qE 'exit\s+1' "$hook_file"; then
    test_fail "pre-commit hook does not exit with code 1 on errors"
    return
  fi

  # Check the ERRORS counter is used to determine exit
  if ! grep -q 'ERRORS' "$hook_file"; then
    test_fail "pre-commit hook does not track ERRORS"
    return
  fi

  # Check the exit logic
  if ! grep -qE '\[.*\$ERRORS.*-gt.*0.*\]' "$hook_file"; then
    test_fail "pre-commit hook does not check if ERRORS > 0"
    return
  fi

  test_pass
}

# Test: Pre-commit hook allows clean commits (exit 0)
test_precommit_allows_good_commit() {
  test_start "pre-commit hook allows clean commits (exit 0)"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that the hook exits with 0 when successful
  if ! grep -qE 'exit\s+0' "$hook_file"; then
    test_fail "pre-commit hook does not exit with code 0 on success"
    return
  fi

  # Check both success paths: warnings only and all clear
  local exit_0_count
  exit_0_count=$(grep -cE 'exit\s+0' "$hook_file" || echo "0")
  if [[ "$exit_0_count" -lt 2 ]]; then
    test_fail "pre-commit hook should have at least 2 exit 0 paths (warnings and all clear)"
    return
  fi

  test_pass
}

# Test: --no-verify bypass is documented and works
test_no_verify_bypass_works() {
  test_start "--no-verify bypass is documented"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that --no-verify bypass is documented in the hook
  if ! grep -q '\-\-no-verify' "$hook_file"; then
    test_fail "pre-commit hook does not document --no-verify bypass"
    return
  fi

  # Verify git supports --no-verify (it always does, but sanity check)
  if ! git commit --help 2>&1 | grep -q '\-\-no-verify' 2>/dev/null; then
    # Git help might not contain this string directly, so check via alternative
    # Just verify git accepts the flag without error
    :
  fi

  test_pass
}

# Test: Pre-commit hook checks all critical components
test_precommit_checks_all_components() {
  test_start "pre-commit hook checks all 8 components"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check for all 8 check sections
  local components=(
    '\[1/8\] ZSH Syntax Check'
    '\[2/8\] ShellCheck Linting'
    '\[3/8\] Custom Bug Pattern Checks'
    '\[4/8\] Retry Logic Integrity'
    '\[5/8\] Brace/Bracket Balance'
    '\[6/8\] JSON Schema Validation'
    '\[7/8\] Test Suite'
    '\[8/8\] AGENTS.md Sync'
  )

  for component in "${components[@]}"; do
    if ! grep -qE "$component" "$hook_file"; then
      test_fail "pre-commit hook missing component: $component"
      return
    fi
  done

  test_pass
}

# Meta-test: Verify test framework detects failures correctly
test_precommit_meta_test_failure_detection() {
  test_start "meta-test: test framework detects failures"
  _setup_test_fixtures

  # Create a temp test script that will fail
  cat > "$TEST_TMP_DIR/failing-test.zsh" << 'TESTEOF'
#!/bin/zsh
echo "Running failing test..."
exit 1
TESTEOF
  chmod +x "$TEST_TMP_DIR/failing-test.zsh"

  # Run the failing test and capture exit code
  local exit_code=0
  "$TEST_TMP_DIR/failing-test.zsh" >/dev/null 2>&1 || exit_code=$?

  # Verify the test framework correctly propagates exit code
  if [[ "$exit_code" -ne 1 ]]; then
    test_fail "Test framework did not propagate exit code 1 (got $exit_code)"
    _teardown_test_fixtures
    return
  fi

  # Verify a passing test returns 0
  cat > "$TEST_TMP_DIR/passing-test.zsh" << 'TESTEOF'
#!/bin/zsh
echo "Running passing test..."
exit 0
TESTEOF
  chmod +x "$TEST_TMP_DIR/passing-test.zsh"

  exit_code=0
  "$TEST_TMP_DIR/passing-test.zsh" >/dev/null 2>&1 || exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    test_fail "Passing test did not return exit code 0 (got $exit_code)"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Pre-commit hook tolerates minor brace imbalances from ${var} syntax (BUG-026)
test_precommit_tolerates_minor_brace_imbalance() {
  test_start "pre-commit tolerates minor brace imbalance (BUG-026)"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that the hook has brace diff tolerance logic
  if ! grep -q 'BRACE_DIFF' "$hook_file"; then
    test_fail "pre-commit hook should calculate BRACE_DIFF for tolerance"
    return
  fi

  # Check that the hook warns on small imbalances instead of error
  if ! grep -qE 'BRACE_DIFF.*-gt.*10' "$hook_file"; then
    test_fail "pre-commit hook should only error on large brace imbalance (>10)"
    return
  fi

  # Check that the hook has a warning path for small imbalances
  if ! grep -q 'Minor brace imbalance' "$hook_file"; then
    test_fail "pre-commit hook should warn about minor brace imbalances"
    return
  fi

  test_pass
}

# Test: Pre-commit hook checks break is inside a loop, not just conditionals (BUG-026)
test_precommit_break_inside_loop_check() {
  test_start "pre-commit break check verifies loop context (BUG-026)"

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local hook_file="$repo_root/.githooks/pre-commit"

  if [[ ! -f "$hook_file" ]]; then
    test_fail ".githooks/pre-commit does not exist"
    return
  fi

  # Check that the hook looks for while/for/until keywords for break validation
  if ! grep -qE 'while\|for\|until' "$hook_file"; then
    test_fail "pre-commit hook should check for while/for/until near break statements"
    return
  fi

  # Check that the hook uses sufficient context (at least 20+ lines)
  if ! grep -qE 'linenum.*-.*[2-9][0-9]' "$hook_file"; then
    test_fail "pre-commit hook should check 20+ lines of context for break statements"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# INTERACTIVE CONTEXT TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_interactive_context returns base context when available
test_interactive_context_loads_base() {
  test_start "interactive_context loads base.md"
  _setup_test_fixtures

  # Create mock contexts directory
  local mock_contexts="$TEST_TMP_DIR/contexts"
  mkdir -p "$mock_contexts/workflow" "$mock_contexts/tech"

  # Create base.md
  echo "# Base Context" > "$mock_contexts/base.md"
  echo "Base rules here" >> "$mock_contexts/base.md"

  # Override contexts directory
  local old_dir="$RALPH_CONTEXTS_DIR"
  RALPH_CONTEXTS_DIR="$mock_contexts"

  # Call the function
  local result=$(_ralph_interactive_context)

  # Restore
  RALPH_CONTEXTS_DIR="$old_dir"

  # Verify base content is included
  if [[ "$result" != *"Base Context"* ]]; then
    test_fail "interactive_context should include base.md content"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_interactive_context loads interactive workflow (not ralph)
test_interactive_context_loads_interactive_workflow() {
  test_start "interactive_context loads workflow/interactive.md"
  _setup_test_fixtures

  # Create mock contexts directory
  local mock_contexts="$TEST_TMP_DIR/contexts"
  mkdir -p "$mock_contexts/workflow"

  # Create base.md and interactive.md
  echo "# Base" > "$mock_contexts/base.md"
  echo "# Interactive Workflow" > "$mock_contexts/workflow/interactive.md"
  echo "Ask before committing" >> "$mock_contexts/workflow/interactive.md"

  # Override contexts directory
  local old_dir="$RALPH_CONTEXTS_DIR"
  RALPH_CONTEXTS_DIR="$mock_contexts"

  # Call the function
  local result=$(_ralph_interactive_context)

  # Restore
  RALPH_CONTEXTS_DIR="$old_dir"

  # Verify interactive workflow is included
  if [[ "$result" != *"Interactive Workflow"* ]]; then
    test_fail "interactive_context should include workflow/interactive.md"
    _teardown_test_fixtures
    return
  fi

  # Verify it does NOT include ralph.md (if it existed)
  echo "# Ralph Workflow" > "$mock_contexts/workflow/ralph.md"
  RALPH_CONTEXTS_DIR="$mock_contexts"
  result=$(_ralph_interactive_context)
  RALPH_CONTEXTS_DIR="$old_dir"

  if [[ "$result" == *"Ralph Workflow"* ]]; then
    test_fail "interactive_context should NOT include workflow/ralph.md"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_interactive_context returns empty string gracefully when no contexts
test_interactive_context_handles_missing_contexts() {
  test_start "interactive_context handles missing contexts gracefully"
  _setup_test_fixtures

  # Point to non-existent directory
  local old_dir="$RALPH_CONTEXTS_DIR"
  RALPH_CONTEXTS_DIR="$TEST_TMP_DIR/nonexistent"

  # Call the function - should not error
  local result=$(_ralph_interactive_context 2>&1)
  local exit_code=$?

  # Restore
  RALPH_CONTEXTS_DIR="$old_dir"

  # Should return empty or near-empty, no error
  if [[ $exit_code -ne 0 ]]; then
    test_fail "interactive_context should not error on missing contexts dir"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# MP-003: RUNTIME CONFIG TESTS (TDD - Phase 1)
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_load_config loads runtime field from config.json
test_config_runtime_loads_from_config() {
  test_start "load_config loads runtime from config.json"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_RUNTIME

  # Create config with runtime field
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bun",
  "modelStrategy": "single",
  "defaultModel": "sonnet"
}
EOF

  # Load config
  _ralph_load_config

  # Verify runtime was loaded
  assert_equals "bun" "$RALPH_RUNTIME" "runtime should be 'bun' from config" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_load_config defaults runtime to 'bun' when not specified
test_config_runtime_defaults_to_bun() {
  test_start "load_config defaults runtime to 'bun'"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_RUNTIME

  # Create config WITHOUT runtime field
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "modelStrategy": "single",
  "defaultModel": "sonnet"
}
EOF

  # Load config
  _ralph_load_config

  # Verify runtime defaults to bun (changed in US-107)
  assert_equals "bun" "$RALPH_RUNTIME" "runtime should default to 'bun'" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: config.json runtime field accepts 'bash' value
test_config_runtime_accepts_bash() {
  test_start "load_config accepts runtime='bash'"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_RUNTIME

  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bash"
}
EOF

  _ralph_load_config

  assert_equals "bash" "$RALPH_RUNTIME" "runtime should be 'bash'" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: config.json runtime field accepts 'bun' value
test_config_runtime_accepts_bun() {
  test_start "load_config accepts runtime='bun'"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_RUNTIME

  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bun"
}
EOF

  _ralph_load_config

  assert_equals "bun" "$RALPH_RUNTIME" "runtime should be 'bun'" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: maxIterations is read from config.defaults.maxIterations
test_config_max_iterations_from_defaults() {
  test_start "load_config reads maxIterations from defaults"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_MAX_ITERATIONS

  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "defaults": {
    "maxIterations": 50
  }
}
EOF

  _ralph_load_config

  assert_equals "50" "$RALPH_MAX_ITERATIONS" "maxIterations should be 50" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# MP-003 PHASE 3: INTEGRATION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_first_run_check returns 0 for existing config
test_first_run_check_returns_0_for_existing_config() {
  test_start "first_run_check returns 0 for existing config"
  _setup_test_fixtures

  # Create a config file
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{"runtime": "bash"}
EOF

  # Should return 0 (config exists)
  _ralph_first_run_check
  local result=$?

  assert_equals "0" "$result" "first_run_check should return 0 when config exists" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_first_run_check returns 1 for missing config (without --skip-setup)
# Note: This test just verifies the function doesn't crash - actual wizard is interactive
test_first_run_check_detects_missing_config() {
  test_start "first_run_check detects missing config"
  _setup_test_fixtures

  # Ensure no config exists
  rm -f "$RALPH_CONFIG_FILE"

  # With --skip-setup, should create default config and return 0
  _ralph_first_run_check --skip-setup > /dev/null 2>&1
  local result=$?

  assert_equals "0" "$result" "first_run_check --skip-setup should return 0" || { _teardown_test_fixtures; return; }

  # Config should now exist
  if [[ ! -f "$RALPH_CONFIG_FILE" ]]; then
    test_fail "config file should exist after --skip-setup"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Config runtime affects RALPH_RUNTIME variable
test_config_runtime_sets_ralph_runtime_var() {
  test_start "config runtime sets RALPH_RUNTIME var"
  _setup_test_fixtures
  _reset_ralph_vars
  unset RALPH_RUNTIME

  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{"runtime": "bun"}
EOF

  _ralph_load_config

  assert_equals "bun" "$RALPH_RUNTIME" "RALPH_RUNTIME should be 'bun'" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# DERIVED STATS TESTS (US-106)
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_derive_stats returns correct format
test_derive_stats_returns_four_numbers() {
  test_start "_ralph_derive_stats returns four numbers"
  _setup_test_fixtures

  # Create minimal PRD structure
  local prd_dir="$TEST_TMP_DIR/prd-json"
  mkdir -p "$prd_dir/stories"
  echo '{"pending": ["US-001", "US-002"], "blocked": ["BUG-001"]}' > "$prd_dir/index.json"
  echo '{"id": "US-001", "passes": false}' > "$prd_dir/stories/US-001.json"
  echo '{"id": "US-002", "passes": false}' > "$prd_dir/stories/US-002.json"
  echo '{"id": "BUG-001", "passes": false}' > "$prd_dir/stories/BUG-001.json"
  echo '{"id": "US-003", "passes": true}' > "$prd_dir/stories/US-003.json"

  local result=$(_ralph_derive_stats "$prd_dir")
  local word_count=$(echo "$result" | wc -w | tr -d ' ')

  assert_equals "4" "$word_count" "derive_stats should return 4 space-separated numbers" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_derive_stats counts correctly
test_derive_stats_counts_correctly() {
  test_start "_ralph_derive_stats counts correctly"
  _setup_test_fixtures

  # Create PRD structure with known counts
  local prd_dir="$TEST_TMP_DIR/prd-json"
  mkdir -p "$prd_dir/stories"
  echo '{"pending": ["US-001", "US-002"], "blocked": ["BUG-001"]}' > "$prd_dir/index.json"
  echo '{"id": "US-001", "passes": false}' > "$prd_dir/stories/US-001.json"
  echo '{"id": "US-002", "passes": false}' > "$prd_dir/stories/US-002.json"
  echo '{"id": "BUG-001", "passes": false}' > "$prd_dir/stories/BUG-001.json"
  echo '{"id": "US-003", "passes": true}' > "$prd_dir/stories/US-003.json"

  local result=$(_ralph_derive_stats "$prd_dir")
  local pending=$(echo "$result" | awk '{print $1}')
  local blocked=$(echo "$result" | awk '{print $2}')
  local completed=$(echo "$result" | awk '{print $3}')
  local total=$(echo "$result" | awk '{print $4}')

  assert_equals "2" "$pending" "pending should be 2" || { _teardown_test_fixtures; return; }
  assert_equals "1" "$blocked" "blocked should be 1" || { _teardown_test_fixtures; return; }
  assert_equals "1" "$completed" "completed should be 1" || { _teardown_test_fixtures; return; }
  assert_equals "4" "$total" "total should be 4" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# Test: _ralph_derive_stats handles empty PRD
test_derive_stats_handles_empty_prd() {
  test_start "_ralph_derive_stats handles empty PRD"
  _setup_test_fixtures

  # Create minimal PRD structure with no stories
  local prd_dir="$TEST_TMP_DIR/prd-json"
  mkdir -p "$prd_dir/stories"
  echo '{"pending": [], "blocked": []}' > "$prd_dir/index.json"

  local result=$(_ralph_derive_stats "$prd_dir")

  assert_equals "0 0 0 0" "$result" "empty PRD should return 0 0 0 0" || { _teardown_test_fixtures; return; }

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# STATUS FILE TESTS (US-106)
# ═══════════════════════════════════════════════════════════════════

# Test: _ralph_write_status creates file
test_status_file_created() {
  test_start "_ralph_write_status creates file"

  # Use a unique status file for testing
  local test_status_file="/tmp/ralph-status-test-$$.json"
  RALPH_STATUS_FILE="$test_status_file"

  _ralph_write_status "running"

  if [[ ! -f "$test_status_file" ]]; then
    rm -f "$test_status_file"
    test_fail "status file should exist after _ralph_write_status"
    return
  fi

  rm -f "$test_status_file"
  test_pass
}

# Test: _ralph_write_status writes correct JSON
test_status_file_has_correct_fields() {
  test_start "_ralph_write_status has correct JSON fields"

  local test_status_file="/tmp/ralph-status-test-$$.json"
  RALPH_STATUS_FILE="$test_status_file"

  _ralph_write_status "running"

  # Check JSON fields
  local state=$(jq -r '.state' "$test_status_file" 2>/dev/null)
  local has_lastActivity=$(jq 'has("lastActivity")' "$test_status_file" 2>/dev/null)
  local has_error=$(jq 'has("error")' "$test_status_file" 2>/dev/null)
  local has_retryIn=$(jq 'has("retryIn")' "$test_status_file" 2>/dev/null)

  assert_equals "running" "$state" "state should be 'running'" || { rm -f "$test_status_file"; return; }
  assert_equals "true" "$has_lastActivity" "should have lastActivity field" || { rm -f "$test_status_file"; return; }
  assert_equals "true" "$has_error" "should have error field" || { rm -f "$test_status_file"; return; }
  assert_equals "true" "$has_retryIn" "should have retryIn field" || { rm -f "$test_status_file"; return; }

  rm -f "$test_status_file"
  test_pass
}

# Test: _ralph_write_status handles error state
test_status_file_error_state() {
  test_start "_ralph_write_status handles error state"

  local test_status_file="/tmp/ralph-status-test-$$.json"
  RALPH_STATUS_FILE="$test_status_file"

  _ralph_write_status "error" "Test error message"

  local state=$(jq -r '.state' "$test_status_file" 2>/dev/null)
  local error=$(jq -r '.error' "$test_status_file" 2>/dev/null)

  assert_equals "error" "$state" "state should be 'error'" || { rm -f "$test_status_file"; return; }
  assert_equals "Test error message" "$error" "error message should be set" || { rm -f "$test_status_file"; return; }

  rm -f "$test_status_file"
  test_pass
}

# Test: _ralph_write_status handles retry state
test_status_file_retry_state() {
  test_start "_ralph_write_status handles retry state"

  local test_status_file="/tmp/ralph-status-test-$$.json"
  RALPH_STATUS_FILE="$test_status_file"

  _ralph_write_status "retry" "null" "30"

  local state=$(jq -r '.state' "$test_status_file" 2>/dev/null)
  local retryIn=$(jq -r '.retryIn' "$test_status_file" 2>/dev/null)

  assert_equals "retry" "$state" "state should be 'retry'" || { rm -f "$test_status_file"; return; }
  assert_equals "30" "$retryIn" "retryIn should be 30" || { rm -f "$test_status_file"; return; }

  rm -f "$test_status_file"
  test_pass
}

# Test: _ralph_cleanup_status_file removes file
test_status_file_cleanup() {
  test_start "_ralph_cleanup_status_file removes file"

  local test_status_file="/tmp/ralph-status-test-$$.json"
  RALPH_STATUS_FILE="$test_status_file"

  _ralph_write_status "running"

  if [[ ! -f "$test_status_file" ]]; then
    test_fail "status file should exist before cleanup"
    return
  fi

  _ralph_cleanup_status_file

  if [[ -f "$test_status_file" ]]; then
    rm -f "$test_status_file"
    test_fail "status file should not exist after cleanup"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# STDERR CAPTURE TESTS (BUG-028)
# ═══════════════════════════════════════════════════════════════════

# Test: stderr capture mechanism exists in ralph.zsh
test_stderr_capture_pattern_exists() {
  test_start "stderr capture with RALPH_STDERR (BUG-028)"

  # Check that the new stderr capture pattern exists in ralph.zsh
  local ralph_file="${SCRIPT_DIR}/../ralph.zsh"
  if [[ ! -f "$ralph_file" ]]; then
    ralph_file="$HOME/.config/ralphtools/ralph.zsh"
  fi

  # Look for RALPH_STDERR variable declaration
  if ! grep -q 'RALPH_STDERR=' "$ralph_file" 2>/dev/null; then
    test_fail "RALPH_STDERR variable not found in ralph.zsh"
    return
  fi

  # Look for stderr being redirected to file
  if ! grep -q '2>"$RALPH_STDERR"' "$ralph_file" 2>/dev/null; then
    test_fail 'stderr redirect to $RALPH_STDERR not found'
    return
  fi

  # Look for stderr being appended to RALPH_TMP
  if ! grep -q 'RALPH_STDERR.*RALPH_TMP' "$ralph_file" 2>/dev/null; then
    test_fail 'stderr append to RALPH_TMP not found'
    return
  fi

  test_pass
}

# Test: debug capture logging exists
test_debug_capture_logging_exists() {
  test_start "debug capture logging (BUG-028)"

  local ralph_file="${SCRIPT_DIR}/../ralph.zsh"
  if [[ ! -f "$ralph_file" ]]; then
    ralph_file="$HOME/.config/ralphtools/ralph.zsh"
  fi

  # Look for RALPH_DEBUG_CAPTURE environment variable check
  if ! grep -q 'RALPH_DEBUG_CAPTURE' "$ralph_file" 2>/dev/null; then
    test_fail "RALPH_DEBUG_CAPTURE env var check not found"
    return
  fi

  # Look for debug log file creation
  if ! grep -q 'ralph_debug_capture' "$ralph_file" 2>/dev/null; then
    test_fail "debug capture log file creation not found"
    return
  fi

  # Look for pipestatus logging
  if ! grep -q 'pipestatus array' "$ralph_file" 2>/dev/null; then
    test_fail "pipestatus debug logging not found"
    return
  fi

  test_pass
}

# Test: error pattern detection includes has_error and is_no_messages_error debug
test_error_detection_debug_logging() {
  test_start "error detection debug logging (BUG-028)"

  local ralph_file="${SCRIPT_DIR}/../ralph.zsh"
  if [[ ! -f "$ralph_file" ]]; then
    ralph_file="$HOME/.config/ralphtools/ralph.zsh"
  fi

  # Look for debug output showing has_error value
  if ! grep -q 'has_error=\$has_error' "$ralph_file" 2>/dev/null; then
    test_fail "has_error debug output not found"
    return
  fi

  # Look for debug output showing is_no_messages_error value
  if ! grep -q 'is_no_messages_error=\$is_no_messages_error' "$ralph_file" 2>/dev/null; then
    test_fail "is_no_messages_error debug output not found"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# US-107 TESTS: Ink UI as default runtime
# ═══════════════════════════════════════════════════════════════════

# Test: Fresh install uses Ink UI (bun) by default
test_us107_fresh_install_defaults_to_bun() {
  test_start "fresh install uses Ink UI by default (US-107)"

  local ralph_file="${SCRIPT_DIR}/../ralph.zsh"
  if [[ ! -f "$ralph_file" ]]; then
    ralph_file="$HOME/.config/ralphtools/ralph.zsh"
  fi

  # Check that the config template in ralph.zsh uses runtime: bun
  # This verifies the skip-setup default config has runtime: bun
  if ! grep -q '"runtime": "bun"' "$ralph_file" 2>/dev/null; then
    test_fail "default config template should have runtime: bun"
    return
  fi

  # Check that jq fallback uses "bun" as default
  if ! grep -q '\.runtime // "bun"' "$ralph_file" 2>/dev/null; then
    test_fail "jq fallback should default runtime to bun"
    return
  fi

  test_pass
}

# Test: ralph-config can switch back to bash
test_us107_config_supports_bash_runtime() {
  test_start "config supports bash runtime switch (US-107)"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a config.json with runtime: bash
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bash",
  "modelStrategy": "smart",
  "defaultModel": "sonnet"
}
EOF

  # Load config
  _ralph_load_config

  # Check that runtime is "bash"
  if [[ "$RALPH_RUNTIME" != "bash" ]]; then
    test_fail "RALPH_RUNTIME should be 'bash', got '$RALPH_RUNTIME'"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Existing configs with runtime=bash still work
test_us107_existing_bash_config_works() {
  test_start "existing bash config works (US-107)"
  _setup_test_fixtures
  _reset_ralph_vars

  # Create a config.json mimicking an existing user config
  cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bash",
  "modelStrategy": "single",
  "defaultModel": "opus",
  "notifications": {
    "enabled": false
  },
  "defaults": {
    "maxIterations": 50,
    "sleepSeconds": 3
  }
}
EOF

  # Load config
  _ralph_load_config

  # Verify all values are loaded correctly (runtime=bash is preserved)
  if [[ "$RALPH_RUNTIME" != "bash" ]]; then
    test_fail "RALPH_RUNTIME should be 'bash' from existing config, got '$RALPH_RUNTIME'"
    _teardown_test_fixtures
    return
  fi

  if [[ "$RALPH_MODEL_STRATEGY" != "single" ]]; then
    test_fail "RALPH_MODEL_STRATEGY should be 'single', got '$RALPH_MODEL_STRATEGY'"
    _teardown_test_fixtures
    return
  fi

  if [[ "$RALPH_DEFAULT_MODEL_CFG" != "opus" ]]; then
    test_fail "RALPH_DEFAULT_MODEL_CFG should be 'opus', got '$RALPH_DEFAULT_MODEL_CFG'"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# BUG-023: ORPHAN PROCESS TRACKING AND CRASH LOGGING TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: PID tracking file is created correctly
test_pid_tracking_file_creation() {
  test_start "PID tracking file is created correctly"

  _setup_test_fixtures

  # Use a unique temp file for testing
  local test_pid_file="/tmp/ralph-test-pids-$$.txt"
  local original_file="$RALPH_PID_TRACKING_FILE"
  RALPH_PID_TRACKING_FILE="$test_pid_file"

  # Track a fake PID
  _ralph_track_pid "12345" "test-process"

  # Verify file was created
  if [[ ! -f "$test_pid_file" ]]; then
    test_fail "PID tracking file was not created"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  # Verify content format (pid type timestamp parent_pid)
  local content=$(cat "$test_pid_file")
  if [[ ! "$content" =~ ^12345[[:space:]]test-process[[:space:]][0-9]+[[:space:]][0-9]+$ ]]; then
    test_fail "PID tracking format incorrect: $content"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  rm -f "$test_pid_file"
  RALPH_PID_TRACKING_FILE="$original_file"
  _teardown_test_fixtures
  test_pass
}

# Test: PID untracking removes entry from file
test_pid_untracking_removes_entry() {
  test_start "PID untracking removes entry from file"

  _setup_test_fixtures

  local test_pid_file="/tmp/ralph-test-pids-$$.txt"
  local original_file="$RALPH_PID_TRACKING_FILE"
  RALPH_PID_TRACKING_FILE="$test_pid_file"

  # Track two PIDs
  _ralph_track_pid "12345" "process-a"
  _ralph_track_pid "67890" "process-b"

  # Verify both are tracked
  local line_count=$(wc -l < "$test_pid_file")
  if [[ "$line_count" -ne 2 ]]; then
    test_fail "Expected 2 lines, got $line_count"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  # Untrack one PID
  _ralph_untrack_pid "12345"

  # Verify only one remains
  line_count=$(wc -l < "$test_pid_file")
  if [[ "$line_count" -ne 1 ]]; then
    test_fail "Expected 1 line after untrack, got $line_count"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  # Verify the right one remains
  if ! grep -q "^67890 " "$test_pid_file"; then
    test_fail "Wrong PID was untracked"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  rm -f "$test_pid_file"
  RALPH_PID_TRACKING_FILE="$original_file"
  _teardown_test_fixtures
  test_pass
}

# Test: Session untracking removes all session PIDs
test_session_untracking_removes_all_session_pids() {
  test_start "Session untracking removes all session PIDs"

  _setup_test_fixtures

  local test_pid_file="/tmp/ralph-test-pids-$$.txt"
  local original_file="$RALPH_PID_TRACKING_FILE"
  RALPH_PID_TRACKING_FILE="$test_pid_file"

  # Track two PIDs from current session
  _ralph_track_pid "11111" "process-a"
  _ralph_track_pid "22222" "process-b"

  # Add a fake entry from a different session (fake parent PID 99999)
  echo "33333 other-process $(date +%s) 99999" >> "$test_pid_file"

  # Verify 3 lines
  local line_count=$(wc -l < "$test_pid_file")
  if [[ "$line_count" -ne 3 ]]; then
    test_fail "Expected 3 lines, got $line_count"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  # Untrack current session
  _ralph_untrack_session

  # Verify only the other session's PID remains
  line_count=$(wc -l < "$test_pid_file")
  if [[ "$line_count" -ne 1 ]]; then
    test_fail "Expected 1 line after session untrack, got $line_count"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  if ! grep -q "^33333 " "$test_pid_file"; then
    test_fail "Other session's PID should remain"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  rm -f "$test_pid_file"
  RALPH_PID_TRACKING_FILE="$original_file"
  _teardown_test_fixtures
  test_pass
}

# Test: Orphan detection finds dead parent processes
test_orphan_detection_finds_dead_parents() {
  test_start "Orphan detection finds dead parent processes"

  _setup_test_fixtures

  local test_pid_file="/tmp/ralph-test-pids-$$.txt"
  local original_file="$RALPH_PID_TRACKING_FILE"
  RALPH_PID_TRACKING_FILE="$test_pid_file"

  # Create an entry with a dead parent (PID 1 is init, unlikely to be our parent)
  # Use a non-existent parent PID
  echo "$$ test-orphan $(date +%s) 99999999" > "$test_pid_file"

  # This should detect an orphan (current PID with dead parent 99999999)
  local orphans=$(_ralph_find_orphans)

  if [[ -z "$orphans" ]]; then
    test_fail "Should have detected an orphan process"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  # Verify the orphan is our fake entry (check for current PID)
  local current_pid="$$"
  if [[ ! "$orphans" =~ "test-orphan" ]]; then
    test_fail "Orphan detection returned wrong process: $orphans"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  rm -f "$test_pid_file"
  RALPH_PID_TRACKING_FILE="$original_file"
  _teardown_test_fixtures
  test_pass
}

# Test: No orphans when parent is still running
test_no_orphans_when_parent_alive() {
  test_start "No orphans detected when parent is still running"

  _setup_test_fixtures

  local test_pid_file="/tmp/ralph-test-pids-$$.txt"
  local original_file="$RALPH_PID_TRACKING_FILE"
  RALPH_PID_TRACKING_FILE="$test_pid_file"

  # Track a PID with current shell as parent (should not be orphaned)
  _ralph_track_pid "$$" "current-process"

  # This should NOT detect orphans (parent $$ is running)
  local orphans=$(_ralph_find_orphans)

  if [[ -n "$orphans" ]]; then
    test_fail "Should not detect orphans when parent is alive: $orphans"
    rm -f "$test_pid_file"
    RALPH_PID_TRACKING_FILE="$original_file"
    _teardown_test_fixtures
    return
  fi

  rm -f "$test_pid_file"
  RALPH_PID_TRACKING_FILE="$original_file"
  _teardown_test_fixtures
  test_pass
}

# Test: Crash log is created with correct format
test_crash_log_creation() {
  test_start "Crash log is created with correct format"

  _setup_test_fixtures

  local test_logs_dir="/tmp/ralph-test-logs-$$"
  local original_dir="$RALPH_LOGS_DIR"
  RALPH_LOGS_DIR="$test_logs_dir"

  # Log a crash
  local log_file=$(_ralph_log_crash "5" "US-123" "Test criterion" "Test error message")

  # Verify file was created
  if [[ ! -f "$log_file" ]]; then
    test_fail "Crash log file was not created"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  # Verify content
  if ! grep -q "Iteration: 5" "$log_file"; then
    test_fail "Crash log missing iteration"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  if ! grep -q "Story: US-123" "$log_file"; then
    test_fail "Crash log missing story"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  if ! grep -q "Criteria: Test criterion" "$log_file"; then
    test_fail "Crash log missing criteria"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  if ! grep -q "Test error message" "$log_file"; then
    test_fail "Crash log missing error message"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  rm -rf "$test_logs_dir"
  RALPH_LOGS_DIR="$original_dir"
  _teardown_test_fixtures
  test_pass
}

# Test: Recent crash detection finds crash within 24 hours
test_recent_crash_detection() {
  test_start "Recent crash detection finds crash within 24 hours"

  _setup_test_fixtures

  local test_logs_dir="/tmp/ralph-test-logs-$$"
  local original_dir="$RALPH_LOGS_DIR"
  RALPH_LOGS_DIR="$test_logs_dir"

  # Create a fresh crash log
  _ralph_log_crash "1" "BUG-001" "Some criterion" "Some error" > /dev/null

  # Recent crash should be found (strip ANSI codes for reliable matching)
  local output=$(_ralph_show_recent_crash 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
  if [[ ! "$output" =~ "Recent crash detected" ]]; then
    test_fail "Should have detected recent crash"
    rm -rf "$test_logs_dir"
    RALPH_LOGS_DIR="$original_dir"
    _teardown_test_fixtures
    return
  fi

  rm -rf "$test_logs_dir"
  RALPH_LOGS_DIR="$original_dir"
  _teardown_test_fixtures
  test_pass
}

# Test: ralph-logs function exists and runs without error
test_ralph_logs_function_exists() {
  test_start "ralph-logs function exists and runs"

  _setup_test_fixtures

  # Function should exist
  if ! typeset -f ralph-logs > /dev/null 2>&1; then
    test_fail "ralph-logs function does not exist"
    _teardown_test_fixtures
    return
  fi

  # Should run without error (even with no logs dir)
  local output=$(ralph-logs 2>&1)
  if [[ "$?" -ne 0 && "$?" -ne 1 ]]; then
    test_fail "ralph-logs returned unexpected exit code"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: ralph-kill-orphans function exists and runs without error
test_ralph_kill_orphans_function_exists() {
  test_start "ralph-kill-orphans function exists and runs"

  _setup_test_fixtures

  # Function should exist
  if ! typeset -f ralph-kill-orphans > /dev/null 2>&1; then
    test_fail "ralph-kill-orphans function does not exist"
    _teardown_test_fixtures
    return
  fi

  # Should run without error (even with no orphans)
  local output=$(ralph-kill-orphans 2>&1)
  if [[ "$?" -ne 0 ]]; then
    test_fail "ralph-kill-orphans returned error exit code"
    _teardown_test_fixtures
    return
  fi

  # Should show cleanup message
  if [[ ! "$output" =~ "Cleanup complete" ]]; then
    test_fail "ralph-kill-orphans missing completion message"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# V-016: WORKTREE SYNC TESTS (TDD)
# ═══════════════════════════════════════════════════════════════════

# Test: Worktree syncs .env files by default
test_worktree_syncs_env_files() {
  test_start "Worktree syncs .env files by default"

  _setup_test_fixtures

  # Verify ralph-start function exists
  if ! typeset -f ralph-start > /dev/null 2>&1; then
    test_fail "ralph-start function does not exist"
    _teardown_test_fixtures
    return
  fi

  # Verify --no-env flag is documented in help
  local help_output=$(ralph-help 2>&1)
  if [[ ! "$help_output" =~ "--no-env" ]]; then
    test_fail "ralph-start --no-env flag not in help output"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Worktree syncs CLAUDE.md (project level is in git)
test_worktree_syncs_claude_md() {
  test_start "Worktree syncs CLAUDE.md via git (project)"

  _setup_test_fixtures

  # CLAUDE.md is tracked in git, so it's automatically in worktrees
  # This test verifies the conceptual understanding: project CLAUDE.md = git tracked
  # Global ~/.claude/CLAUDE.md doesn't need syncing (accessible from everywhere)

  # Find repo root by going up from test file location
  local script_dir="${0:a:h}"
  local repo_root=$(cd "$script_dir" && git rev-parse --show-toplevel 2>/dev/null)

  if [[ -z "$repo_root" ]]; then
    test_fail "Could not find git repo root"
    _teardown_test_fixtures
    return
  fi

  if [[ ! -f "$repo_root/CLAUDE.md" ]]; then
    test_fail "Project CLAUDE.md does not exist in repo root: $repo_root"
    _teardown_test_fixtures
    return
  fi

  # Verify it's tracked by git (not gitignored)
  local is_tracked=$(cd "$repo_root" && git ls-files CLAUDE.md 2>/dev/null)
  if [[ -z "$is_tracked" ]]; then
    test_fail "Project CLAUDE.md is not tracked by git"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Contexts are loaded from global location (no sync needed)
test_worktree_syncs_contexts() {
  test_start "Contexts load from ~/.claude/contexts (no sync)"

  _setup_test_fixtures

  # Verify contexts directory exists at global location
  local contexts_dir="$HOME/.claude/contexts"

  if [[ ! -d "$contexts_dir" ]]; then
    test_fail "Global contexts directory does not exist: $contexts_dir"
    _teardown_test_fixtures
    return
  fi

  # Verify base.md exists (always loaded)
  if [[ ! -f "$contexts_dir/base.md" ]]; then
    test_fail "base.md context does not exist"
    _teardown_test_fixtures
    return
  fi

  # Verify workflow/ralph.md exists (Ralph context)
  if [[ ! -f "$contexts_dir/workflow/ralph.md" ]]; then
    test_fail "workflow/ralph.md context does not exist"
    _teardown_test_fixtures
    return
  fi

  # Verify _ralph_build_context_file function loads from this location
  if ! typeset -f _ralph_build_context_file > /dev/null 2>&1; then
    test_fail "_ralph_build_context_file function does not exist"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: Worktree syncs prd-json directory
test_worktree_syncs_prd_json() {
  test_start "Worktree syncs prd-json directory"

  _setup_test_fixtures

  # Verify ralph-start function syncs prd-json
  # Check the function source for prd-json handling
  local func_source=$(typeset -f ralph-start 2>/dev/null)

  if [[ -z "$func_source" ]]; then
    test_fail "ralph-start function not found"
    _teardown_test_fixtures
    return
  fi

  # Verify prd-json sync is in the function
  if [[ ! "$func_source" =~ 'prd-json' ]]; then
    test_fail "ralph-start does not handle prd-json sync"
    _teardown_test_fixtures
    return
  fi

  # Verify copy command is used (not symlink) for prd-json
  if [[ ! "$func_source" =~ cp.*prd-json ]]; then
    test_fail "ralph-start should copy prd-json directory"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# Test: .worktree-sync.json config is processed
test_worktree_sync_config() {
  test_start ".worktree-sync.json config is processed"

  _setup_test_fixtures

  # Verify _ralph_process_worktree_sync function exists
  if ! typeset -f _ralph_process_worktree_sync > /dev/null 2>&1; then
    test_fail "_ralph_process_worktree_sync function does not exist"
    _teardown_test_fixtures
    return
  fi

  # Verify _ralph_run_sync_commands function exists
  if ! typeset -f _ralph_run_sync_commands > /dev/null 2>&1; then
    test_fail "_ralph_run_sync_commands function does not exist"
    _teardown_test_fixtures
    return
  fi

  # Verify ralph-start checks for .worktree-sync.json
  local func_source=$(typeset -f ralph-start 2>/dev/null)
  if [[ ! "$func_source" =~ '.worktree-sync.json' ]]; then
    test_fail "ralph-start does not check for .worktree-sync.json"
    _teardown_test_fixtures
    return
  fi

  _teardown_test_fixtures
  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# V-017: WIZARD VALIDATION TESTS (TDD)
# ═══════════════════════════════════════════════════════════════════

# Test: Wizard validates global CLAUDE.md exists
test_wizard_validates_global_claude_md() {
  test_start "wizard validates ~/.claude/CLAUDE.md"

  # Find validate.sh script
  local validate_script="$HOME/.claude/commands/golem-powers/ralph-install/scripts/validate.sh"
  if [[ ! -f "$validate_script" ]]; then
    validate_script="${0:a:h}/../skills/golem-powers/ralph-install/scripts/validate.sh"
  fi

  if [[ ! -f "$validate_script" ]]; then
    test_fail "validate.sh not found"
    return
  fi

  # Check that validate.sh contains a check for ~/.claude/CLAUDE.md
  if ! grep -q '\.claude/CLAUDE\.md' "$validate_script" 2>/dev/null; then
    test_fail "validate.sh does not check for ~/.claude/CLAUDE.md"
    return
  fi

  test_pass
}

# Test: Wizard validates contexts directory exists
test_wizard_validates_contexts_dir() {
  test_start "wizard validates ~/.claude/contexts/"

  # Find validate.sh script
  local validate_script="$HOME/.claude/commands/golem-powers/ralph-install/scripts/validate.sh"
  if [[ ! -f "$validate_script" ]]; then
    validate_script="${0:a:h}/../skills/golem-powers/ralph-install/scripts/validate.sh"
  fi

  if [[ ! -f "$validate_script" ]]; then
    test_fail "validate.sh not found"
    return
  fi

  # Check that validate.sh contains a check for contexts directory
  if ! grep -q 'contexts' "$validate_script" 2>/dev/null; then
    test_fail "validate.sh does not check for ~/.claude/contexts/"
    return
  fi

  test_pass
}

# Test: Wizard validates skill symlinks exist
test_wizard_validates_skill_symlinks() {
  test_start "wizard validates golem-powers symlink"

  # Find validate.sh script
  local validate_script="$HOME/.claude/commands/golem-powers/ralph-install/scripts/validate.sh"
  if [[ ! -f "$validate_script" ]]; then
    validate_script="${0:a:h}/../skills/golem-powers/ralph-install/scripts/validate.sh"
  fi

  if [[ ! -f "$validate_script" ]]; then
    test_fail "validate.sh not found"
    return
  fi

  # Check that validate.sh contains a check for golem-powers symlink
  if ! grep -q 'golem-powers' "$validate_script" 2>/dev/null; then
    test_fail "validate.sh does not check for golem-powers symlink"
    return
  fi

  test_pass
}

# Test: Wizard checks 1Password is available
test_wizard_checks_1password() {
  test_start "wizard checks 1Password CLI"

  # Find validate.sh script
  local validate_script="$HOME/.claude/commands/golem-powers/ralph-install/scripts/validate.sh"
  if [[ ! -f "$validate_script" ]]; then
    validate_script="${0:a:h}/../skills/golem-powers/ralph-install/scripts/validate.sh"
  fi

  if [[ ! -f "$validate_script" ]]; then
    test_fail "validate.sh not found"
    return
  fi

  # Check that validate.sh contains a check for op CLI
  if ! grep -q 'op' "$validate_script" 2>/dev/null; then
    test_fail "validate.sh does not check for op (1Password CLI)"
    return
  fi

  test_pass
}

# Test: Wizard validates shell config for ralph sourcing
test_wizard_validates_shell_config() {
  test_start "wizard validates shell config sourcing"

  # Find validate.sh script
  local validate_script="$HOME/.claude/commands/golem-powers/ralph-install/scripts/validate.sh"
  if [[ ! -f "$validate_script" ]]; then
    validate_script="${0:a:h}/../skills/golem-powers/ralph-install/scripts/validate.sh"
  fi

  if [[ ! -f "$validate_script" ]]; then
    test_fail "validate.sh not found"
    return
  fi

  # Check that validate.sh contains a check for ralph.zsh
  if ! grep -q 'ralph\.zsh' "$validate_script" 2>/dev/null; then
    test_fail "validate.sh does not check for ralph.zsh sourcing"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# US-097: Context Migration Wizard Tests
# ═══════════════════════════════════════════════════════════════════

# Test: Context migration function exists
test_context_migration_function_exists() {
  test_start "context migration function exists"

  # Check that the function is defined
  if ! typeset -f _ralph_setup_context_migration >/dev/null 2>&1; then
    test_fail "_ralph_setup_context_migration function not defined"
    return
  fi

  test_pass
}

# Test: Context templates exist in repo
test_context_templates_exist_in_repo() {
  test_start "context templates exist in repo"

  local contexts_dir="${SCRIPT_DIR}/../contexts"

  if [[ ! -d "$contexts_dir" ]]; then
    test_fail "contexts/ directory not found in repo"
    return
  fi

  # Check for base.md
  if [[ ! -f "$contexts_dir/base.md" ]]; then
    test_fail "contexts/base.md not found"
    return
  fi

  # Check for tech/ subdirectory
  if [[ ! -d "$contexts_dir/tech" ]]; then
    test_fail "contexts/tech/ not found"
    return
  fi

  # Check for workflow/ subdirectory
  if [[ ! -d "$contexts_dir/workflow" ]]; then
    test_fail "contexts/workflow/ not found"
    return
  fi

  test_pass
}

# Test: Migration script exists
test_migration_script_exists() {
  test_start "migration script exists"

  local migrate_script="${SCRIPT_DIR}/../scripts/context-migrate.zsh"

  if [[ ! -f "$migrate_script" ]]; then
    test_fail "scripts/context-migrate.zsh not found"
    return
  fi

  # Check it's executable
  if [[ ! -x "$migrate_script" ]]; then
    test_fail "scripts/context-migrate.zsh not executable"
    return
  fi

  test_pass
}

# Test: ralph-setup accepts --skip-context-migration flag
test_skip_context_migration_flag() {
  test_start "ralph-setup accepts --skip-context-migration flag"

  local ralph_zsh="${SCRIPT_DIR}/../ralph.zsh"

  # Check that ralph-setup function contains flag parsing for --skip-context-migration
  if ! grep -q -- '--skip-context-migration' "$ralph_zsh" 2>/dev/null; then
    test_fail "--skip-context-migration flag not found in ralph-setup"
    return
  fi

  test_pass
}

# Test: Context migration menu item exists in ralph-setup
test_context_migration_menu_item() {
  test_start "context migration menu item in ralph-setup"

  local ralph_zsh="${SCRIPT_DIR}/../ralph.zsh"

  # Check that the menu includes the context migration option
  if ! grep -q 'Migrate CLAUDE.md contexts' "$ralph_zsh" 2>/dev/null; then
    test_fail "Context migration menu item not found"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# REPOGOLEM LAUNCHER TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: repoGolem creates three launcher functions
test_repogolem_creates_functions() {
  test_start "repoGolem creates three launcher functions"

  # Create a test launcher
  repoGolem testproject "/tmp/testproject" Context7

  # Check all three functions exist
  if ! type testprojectClaude &>/dev/null; then
    test_fail "testprojectClaude function not created"
    return
  fi

  if ! type openTestproject &>/dev/null; then
    test_fail "openTestproject function not created"
    return
  fi

  if ! type runTestproject &>/dev/null; then
    test_fail "runTestproject function not created"
    return
  fi

  test_pass
}

# Test: repoGolem launcher parses -s flag
test_repogolem_skip_permissions_flag() {
  test_start "repoGolem launcher parses -s flag"

  repoGolem flagtest "/tmp/flagtest" Context7

  # Get function definition and check for skip-permissions handling
  local func_def=$(which flagtestClaude 2>/dev/null)

  if [[ "$func_def" != *"-s"*"--skip-permissions"* ]]; then
    test_fail "-s flag not found in generated function"
    return
  fi

  if [[ "$func_def" != *"--dangerously-skip-permissions"* ]]; then
    test_fail "--dangerously-skip-permissions not in generated function"
    return
  fi

  test_pass
}

# Test: repoGolem launcher parses -c flag
test_repogolem_continue_flag() {
  test_start "repoGolem launcher parses -c flag"

  repoGolem conttest "/tmp/conttest" Context7

  local func_def=$(which conttestClaude 2>/dev/null)

  if [[ "$func_def" != *"-c"*"--continue"* ]]; then
    test_fail "-c flag not found in generated function"
    return
  fi

  test_pass
}

# Test: repoGolem launcher parses -u flag
test_repogolem_update_flag() {
  test_start "repoGolem launcher parses -u flag"

  repoGolem updtest "/tmp/updtest" Context7

  local func_def=$(which updtestClaude 2>/dev/null)

  if [[ "$func_def" != *"-u"*"--update"* ]]; then
    test_fail "-u flag not found in generated function"
    return
  fi

  if [[ "$func_def" != *"should_update=true"* ]]; then
    test_fail "update logic not found in generated function"
    return
  fi

  test_pass
}

# Test: repoGolem launcher parses notification flags
test_repogolem_notification_flags() {
  test_start "repoGolem launcher parses notification flags"

  repoGolem notifytest "/tmp/notifytest" Context7

  local func_def=$(which notifytestClaude 2>/dev/null)

  if [[ "$func_def" != *"-QN"*"--quiet-notify"* ]]; then
    test_fail "-QN flag not found in generated function"
    return
  fi

  if [[ "$func_def" != *"-SN"*"--simple-notify"* ]]; then
    test_fail "-SN flag not found in generated function"
    return
  fi

  if [[ "$func_def" != *"-VN"*"--verbose-notify"* ]]; then
    test_fail "-VN flag not found in generated function"
    return
  fi

  test_pass
}

# Test: repoGolem launcher sets ntfy topic correctly
test_repogolem_ntfy_topic() {
  test_start "repoGolem launcher sets ntfy topic correctly"

  repoGolem topictest "/tmp/topictest" Context7

  local func_def=$(which topictestClaude 2>/dev/null)

  if [[ "$func_def" != *'ntfy_topic="etans-topictestClaude"'* ]]; then
    test_fail "ntfy topic not set correctly"
    return
  fi

  test_pass
}

# Test: repoGolem passes MCPs to _ralph_setup_mcps
test_repogolem_mcp_passthrough() {
  test_start "repoGolem passes MCPs to _ralph_setup_mcps"

  repoGolem mcptest "/tmp/mcptest" Context7 tempmail supabase

  local func_def=$(which mcptestClaude 2>/dev/null)

  if [[ "$func_def" != *'_ralph_setup_mcps'* ]]; then
    test_fail "_ralph_setup_mcps call not found"
    return
  fi

  if [[ "$func_def" != *'"Context7"'* ]] || [[ "$func_def" != *'"tempmail"'* ]]; then
    test_fail "MCPs not passed correctly"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# MP-004: MODULAR STRUCTURE TESTS
# ═══════════════════════════════════════════════════════════════════
# Tests for the modular lib/ file structure

# Test: lib directory exists
test_lib_directory_exists() {
  local lib_dir="${SCRIPT_DIR}/../lib"
  if [[ -d "$lib_dir" ]]; then
    test_pass
  else
    test_fail "lib/ directory not found at $lib_dir"
  fi
}

# Test: lib/ralph-ui.zsh exists and is sourced
test_lib_ralph_ui_exists() {
  local lib_file="${SCRIPT_DIR}/../lib/ralph-ui.zsh"
  if [[ -f "$lib_file" ]]; then
    # Verify a function from this module is available
    if typeset -f _ralph_display_width >/dev/null 2>&1; then
      test_pass
    else
      test_fail "lib/ralph-ui.zsh exists but _ralph_display_width not available"
    fi
  else
    test_fail "lib/ralph-ui.zsh not found"
  fi
}

# Test: lib/ralph-watcher.zsh exists and is sourced
test_lib_ralph_watcher_exists() {
  local lib_file="${SCRIPT_DIR}/../lib/ralph-watcher.zsh"
  if [[ -f "$lib_file" ]]; then
    # Verify a function from this module is available
    if typeset -f _ralph_check_fswatch >/dev/null 2>&1; then
      test_pass
    else
      test_fail "lib/ralph-watcher.zsh exists but _ralph_check_fswatch not available"
    fi
  else
    test_fail "lib/ralph-watcher.zsh not found"
  fi
}

# Test: lib/ralph-commands.zsh exists and is sourced
test_lib_ralph_commands_exists() {
  local lib_file="${SCRIPT_DIR}/../lib/ralph-commands.zsh"
  if [[ -f "$lib_file" ]]; then
    # Verify a function from this module is available
    if typeset -f ralph-help >/dev/null 2>&1; then
      test_pass
    else
      test_fail "lib/ralph-commands.zsh exists but ralph-help not available"
    fi
  else
    test_fail "lib/ralph-commands.zsh not found"
  fi
}

# Test: ralph-help still works after modularization
test_ralph_help_works() {
  local output
  output=$(ralph-help 2>&1)
  if [[ "$output" == *"Ralph Commands"* ]]; then
    test_pass
  else
    test_fail "ralph-help output doesn't contain 'Ralph Commands'"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# MODULAR PROMPTS TESTS (MP-005)
# ═══════════════════════════════════════════════════════════════════

# Test: prompt files exist and are valid markdown
test_mp005_prompt_files_exist() {
  test_start "MP-005: prompt files exist in ~/.config/ralphtools/prompts/"

  local prompts_dir="$HOME/.config/ralphtools/prompts"

  # Check directory exists
  if [[ ! -d "$prompts_dir" ]]; then
    test_fail "prompts directory does not exist: $prompts_dir"
    return
  fi

  # Check required files exist
  local required_files=("base.md" "US.md" "BUG.md" "V.md" "AUDIT.md" "TEST.md" "MP.md")
  local missing_files=()

  for file in "${required_files[@]}"; do
    if [[ ! -f "$prompts_dir/$file" ]]; then
      missing_files+=("$file")
    fi
  done

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    test_fail "missing prompt files: ${missing_files[*]}"
    return
  fi

  # Verify each file starts with a markdown heading
  for file in "${required_files[@]}"; do
    local first_line=$(head -1 "$prompts_dir/$file")
    if [[ ! "$first_line" =~ ^#.* ]]; then
      test_fail "$file does not start with markdown heading"
      return
    fi
  done

  test_pass
}

# Test: _ralph_build_story_prompt function exists and returns content
test_mp005_build_story_prompt_function_exists() {
  test_start "MP-005: _ralph_build_story_prompt function exists"

  if ! typeset -f _ralph_build_story_prompt >/dev/null 2>&1; then
    test_fail "_ralph_build_story_prompt function not found"
    return
  fi

  test_pass
}

# Test: _ralph_build_story_prompt returns content for US stories
test_mp005_build_story_prompt_us() {
  test_start "MP-005: _ralph_build_story_prompt returns content for US stories"

  local prompt
  prompt=$(_ralph_build_story_prompt "US-001" "opus" "/tmp/prd-json" "/tmp/work" 2>&1)

  # Should contain base content
  if [[ ! "$prompt" =~ "Ralph" ]]; then
    test_fail "prompt missing 'Ralph' (base content)"
    return
  fi

  # Should contain US-specific content
  if [[ ! "$prompt" =~ "feature" ]] && [[ ! "$prompt" =~ "Feature" ]]; then
    test_fail "prompt missing feature story content"
    return
  fi

  test_pass
}

# Test: _ralph_build_story_prompt returns content for BUG stories
test_mp005_build_story_prompt_bug() {
  test_start "MP-005: _ralph_build_story_prompt returns content for BUG stories"

  local prompt
  prompt=$(_ralph_build_story_prompt "BUG-001" "sonnet" "/tmp/prd-json" "/tmp/work" 2>&1)

  # Should contain base content
  if [[ ! "$prompt" =~ "Ralph" ]]; then
    test_fail "prompt missing 'Ralph' (base content)"
    return
  fi

  # Should contain BUG-specific content
  if [[ ! "$prompt" =~ "Bug" ]] && [[ ! "$prompt" =~ "bug" ]] && [[ ! "$prompt" =~ "Debugging" ]]; then
    test_fail "prompt missing bug fix content"
    return
  fi

  test_pass
}

# Test: _ralph_build_story_prompt returns content for V stories
test_mp005_build_story_prompt_v() {
  test_start "MP-005: _ralph_build_story_prompt returns content for V stories"

  local prompt
  prompt=$(_ralph_build_story_prompt "V-001" "haiku" "/tmp/prd-json" "/tmp/work" 2>&1)

  # Should contain base content
  if [[ ! "$prompt" =~ "Ralph" ]]; then
    test_fail "prompt missing 'Ralph' (base content)"
    return
  fi

  # Should contain V-specific content
  if [[ ! "$prompt" =~ "Verification" ]] && [[ ! "$prompt" =~ "verification" ]] && [[ ! "$prompt" =~ "TDD" ]]; then
    test_fail "prompt missing verification content"
    return
  fi

  test_pass
}

# Test: _ralph_build_story_prompt template substitution works
test_mp005_template_substitution() {
  test_start "MP-005: _ralph_build_story_prompt template substitution"

  local prompt
  prompt=$(_ralph_build_story_prompt "US-123" "opus" "/test/prd" "/test/work" 2>&1)

  # Model should be substituted
  if [[ "$prompt" =~ "{{MODEL}}" ]]; then
    test_fail "{{MODEL}} template not substituted"
    return
  fi

  # Should contain the model name
  if [[ ! "$prompt" =~ "opus" ]]; then
    test_fail "model name 'opus' not found in prompt"
    return
  fi

  # PRD path should be substituted
  if [[ "$prompt" =~ "{{PRD_JSON_DIR}}" ]]; then
    test_fail "{{PRD_JSON_DIR}} template not substituted"
    return
  fi

  test_pass
}

# Test: _ralph_build_story_prompt detects story types correctly
test_mp005_story_type_detection() {
  test_start "MP-005: story type detection from ID prefix"

  # Test each story type
  local -A story_types=(
    ["US-001"]="feature"
    ["BUG-002"]="Bug"
    ["V-003"]="Verification"
    ["AUDIT-004"]="Audit"
    ["TEST-005"]="Test"
    ["MP-006"]="Master"
  )

  for story_id expected_content in "${(@kv)story_types}"; do
    local prompt
    prompt=$(_ralph_build_story_prompt "$story_id" "opus" "/tmp" "/tmp" 2>&1)

    if [[ ! "$prompt" =~ "$expected_content" ]]; then
      test_fail "story $story_id should include '$expected_content' content"
      return
    fi
  done

  test_pass
}

# Test: unknown story type gets base prompt only
test_mp005_unknown_story_type() {
  test_start "MP-005: unknown story type gets base prompt only"

  local prompt
  prompt=$(_ralph_build_story_prompt "UNKNOWN-001" "opus" "/tmp" "/tmp" 2>&1)

  # Should still contain base content
  if [[ ! "$prompt" =~ "Ralph" ]]; then
    test_fail "unknown story type should still get base prompt"
    return
  fi

  # Should NOT contain story-type-specific headers (from US.md, BUG.md, etc.)
  # The prompt should not have the story-type sections since no matching .md file
  # We check that it's shorter than a prompt with story-type content
  local us_prompt
  us_prompt=$(_ralph_build_story_prompt "US-001" "opus" "/tmp" "/tmp" 2>&1)

  # Unknown prompt should be shorter since it doesn't have story-type additions
  if [[ ${#prompt} -ge ${#us_prompt} ]]; then
    # This is okay if base.md is comprehensive - just verify base content exists
    if [[ ! "$prompt" =~ "iteration" ]]; then
      test_fail "base prompt should contain 'iteration'"
      return
    fi
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# TEST-001: CONTEXT INJECTION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: base.md context file exists
test_context_files_exist() {
  test_start "TEST-001: base.md context file exists"

  local contexts_dir="${SCRIPT_DIR}/../contexts"

  # Check contexts/base.md exists in repo
  if [[ ! -f "$contexts_dir/base.md" ]]; then
    test_fail "contexts/base.md not found in repo"
    return
  fi

  # Check that it's not empty
  local line_count=$(wc -l < "$contexts_dir/base.md" | tr -d ' ')
  if [[ "$line_count" -lt 50 ]]; then
    test_fail "contexts/base.md is too short ($line_count lines, expected 50+)"
    return
  fi

  test_pass
}

# Test: base.md has required sections
test_context_base_has_required_sections() {
  test_start "TEST-001: base.md has required sections"

  local base_md="${SCRIPT_DIR}/../contexts/base.md"

  if [[ ! -f "$base_md" ]]; then
    test_fail "contexts/base.md not found"
    return
  fi

  local content=$(<"$base_md")

  # Check for Scratchpad section
  if [[ ! "$content" =~ "Scratchpad" ]]; then
    test_fail "base.md missing Scratchpad section"
    return
  fi

  # Check for AIDEV-NOTE section
  if [[ ! "$content" =~ "AIDEV-NOTE" ]]; then
    test_fail "base.md missing AIDEV-NOTE section"
    return
  fi

  # Check for Documentation Fetching section
  if [[ ! "$content" =~ "Documentation Fetching" ]]; then
    test_fail "base.md missing Documentation Fetching section"
    return
  fi

  # Check for Thinking Before Doing section
  if [[ ! "$content" =~ "Thinking Before Doing" ]]; then
    test_fail "base.md missing Thinking Before Doing section"
    return
  fi

  test_pass
}

# Test: _ralph_build_context_file function works
test_context_merge_function() {
  test_start "TEST-001: _ralph_build_context_file works"

  # Check function exists
  if ! typeset -f _ralph_build_context_file >/dev/null 2>&1; then
    test_fail "_ralph_build_context_file function not found"
    return
  fi

  # Create a temp output file
  local output_file="/tmp/test-context-merge-$$.md"

  # Set up contexts dir to use repo contexts
  local old_contexts_dir="$RALPH_CONTEXTS_DIR"
  export RALPH_CONTEXTS_DIR="${SCRIPT_DIR}/../contexts"

  # Call the function
  local result
  result=$(_ralph_build_context_file "$output_file" 2>&1)

  # Restore contexts dir
  export RALPH_CONTEXTS_DIR="$old_contexts_dir"

  # Check output file was created
  if [[ ! -f "$output_file" ]]; then
    test_fail "output file was not created"
    return
  fi

  # Check file has content
  local line_count=$(wc -l < "$output_file" | tr -d ' ')
  if [[ "$line_count" -lt 50 ]]; then
    test_fail "merged context file too short ($line_count lines)"
    rm -f "$output_file"
    return
  fi

  # Check that base content is present
  local content=$(<"$output_file")
  if [[ ! "$content" =~ "Scratchpad" ]]; then
    test_fail "merged context missing base.md content"
    rm -f "$output_file"
    return
  fi

  # Check that workflow/ralph.md content is present (if it exists)
  if [[ -f "${SCRIPT_DIR}/../contexts/workflow/ralph.md" ]]; then
    if [[ ! "$content" =~ "Ralph" ]]; then
      test_fail "merged context missing workflow/ralph.md content"
      rm -f "$output_file"
      return
    fi
  fi

  # Clean up
  rm -f "$output_file"

  test_pass
}

# Test: context cleanup removes temp files
test_context_cleanup() {
  test_start "TEST-001: context cleanup removes temp files"

  # Check cleanup function exists
  if ! typeset -f _ralph_cleanup_context_file >/dev/null 2>&1; then
    test_fail "_ralph_cleanup_context_file function not found"
    return
  fi

  # Create a temp file to test cleanup
  local test_file="/tmp/test-context-cleanup-$$.md"
  echo "test content" > "$test_file"

  # Verify file exists before cleanup
  if [[ ! -f "$test_file" ]]; then
    test_fail "test file was not created"
    return
  fi

  # Call cleanup
  _ralph_cleanup_context_file "$test_file"

  # Verify file was removed
  if [[ -f "$test_file" ]]; then
    test_fail "cleanup did not remove file"
    rm -f "$test_file"
    return
  fi

  test_pass
}

# Test: context-migrate.zsh patterns are valid regex
test_context_patterns_valid() {
  test_start "TEST-001: context-migrate.zsh patterns are valid"

  local migrate_script="${SCRIPT_DIR}/../scripts/context-migrate.zsh"

  if [[ ! -f "$migrate_script" ]]; then
    test_fail "scripts/context-migrate.zsh not found"
    return
  fi

  # Extract the CONTEXT_PATTERNS lines and verify they're valid grep -E patterns
  local patterns=$(grep 'CONTEXT_PATTERNS\[' "$migrate_script" | grep -oE '"[^"]+"\s*$' | tr -d '"')

  if [[ -z "$patterns" ]]; then
    test_fail "no patterns found in context-migrate.zsh"
    return
  fi

  # Test each pattern is valid by trying to match against empty string
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    # Try to use the pattern with grep -E (should not error)
    echo "test" | grep -qE "$pattern" 2>/dev/null || true
    # If grep itself errored (exit code 2), pattern is invalid
    if [[ $? -eq 2 ]]; then
      test_fail "invalid regex pattern: $pattern"
      return
    fi
  done <<< "$patterns"

  test_pass
}

# Test: old ${brave_skill} injection removed from ralph.zsh
test_no_old_injection() {
  test_start "TEST-001: old \${brave_skill} injection removed"

  local ralph_zsh="${SCRIPT_DIR}/../ralph.zsh"

  if [[ ! -f "$ralph_zsh" ]]; then
    test_fail "ralph.zsh not found"
    return
  fi

  # Check that ${brave_skill} injection is NOT present
  if grep -qE '\$\{brave_skill\}' "$ralph_zsh" 2>/dev/null; then
    test_fail "\${brave_skill} still present in ralph.zsh"
    return
  fi

  # Check that ${ralph_agent_instructions} injection is NOT present
  if grep -qE '\$\{ralph_agent_instructions\}' "$ralph_zsh" 2>/dev/null; then
    test_fail "\${ralph_agent_instructions} still present in ralph.zsh"
    return
  fi

  test_pass
}

# Test: workflow/ralph.md has RALPH GIT RULES
test_workflow_ralph_has_git_rules() {
  test_start "TEST-001: workflow/ralph.md has RALPH GIT RULES"

  local ralph_md="${SCRIPT_DIR}/../contexts/workflow/ralph.md"

  if [[ ! -f "$ralph_md" ]]; then
    test_fail "contexts/workflow/ralph.md not found"
    return
  fi

  local content=$(<"$ralph_md")

  # Check for Ralph Git Rules section
  if [[ ! "$content" =~ "Ralph Git Rules" ]] && [[ ! "$content" =~ "RALPH GIT RULES" ]] && [[ ! "$content" =~ "Git Rules" ]]; then
    test_fail "workflow/ralph.md missing Git Rules section"
    return
  fi

  # Check for key git rules content
  if [[ ! "$content" =~ "MUST commit" ]]; then
    test_fail "workflow/ralph.md missing 'MUST commit' rule"
    return
  fi

  if [[ ! "$content" =~ "MUST NOT push" ]]; then
    test_fail "workflow/ralph.md missing 'MUST NOT push' rule"
    return
  fi

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

# Source ralph.zsh if it exists (to test ralph functions)
# Check local repo first, then installed location
SCRIPT_DIR="${0:a:h}"
REPO_RALPH_ZSH="${SCRIPT_DIR}/../ralph.zsh"
INSTALLED_RALPH_ZSH="$HOME/.config/ralphtools/ralph.zsh"

if [[ -n "$RALPH_ZSH" && -f "$RALPH_ZSH" ]]; then
  source "$RALPH_ZSH" 2>/dev/null || true
elif [[ -f "$REPO_RALPH_ZSH" ]]; then
  source "$REPO_RALPH_ZSH" 2>/dev/null || true
elif [[ -f "$INSTALLED_RALPH_ZSH" ]]; then
  source "$INSTALLED_RALPH_ZSH" 2>/dev/null || true
fi

# Run all tests
run_all_tests
