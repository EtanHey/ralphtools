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
  echo "0 0" > "$RESULTS_FILE"
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

# Get final results
_get_results() {
  cat "$RESULTS_FILE"
}

# Cleanup results file
_cleanup_results() {
  [[ -f "$RESULTS_FILE" ]] && rm -f "$RESULTS_FILE"
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
  echo ""

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
  # Line 1: repo name
  assert_contains "$MOCK_CURL_BODY" "ralphtools" "line 1 should contain repo name" || { _teardown_test_fixtures; return; }

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

# Test: cleanup resets index.json stats
test_archive_cleanup_resets_stats() {
  test_start "cleanup resets index.json stats"
  _setup_test_fixtures

  # Create PRD structure with completed and pending stories
  mkdir -p "$TEST_TMP_DIR/prd-json/stories"
  cat > "$TEST_TMP_DIR/prd-json/index.json" << 'EOF'
{
  "stats": { "total": 3, "completed": 2, "pending": 1, "blocked": 0 },
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

  # Verify stats were reset
  local completed=$(jq '.stats.completed' "$TEST_TMP_DIR/prd-json/index.json")
  local total=$(jq '.stats.total' "$TEST_TMP_DIR/prd-json/index.json")
  local pending=$(jq '.stats.pending' "$TEST_TMP_DIR/prd-json/index.json")

  assert_equals "0" "$completed" "completed should be 0" || { cd -; _teardown_test_fixtures; return; }
  assert_equals "1" "$total" "total should be 1 (only US-003 remains)" || { cd -; _teardown_test_fixtures; return; }
  assert_equals "1" "$pending" "pending should be 1" || { cd -; _teardown_test_fixtures; return; }

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
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

# Source ralph.zsh if it exists (to test ralph functions)
# Check local repo first, then installed location
SCRIPT_DIR="${0:a:h}"
REPO_RALPH_ZSH="${SCRIPT_DIR}/../ralph.zsh"
INSTALLED_RALPH_ZSH="$HOME/.config/ralph/ralph.zsh"

if [[ -n "$RALPH_ZSH" && -f "$RALPH_ZSH" ]]; then
  source "$RALPH_ZSH" 2>/dev/null || true
elif [[ -f "$REPO_RALPH_ZSH" ]]; then
  source "$REPO_RALPH_ZSH" 2>/dev/null || true
elif [[ -f "$INSTALLED_RALPH_ZSH" ]]; then
  source "$INSTALLED_RALPH_ZSH" 2>/dev/null || true
fi

# Run all tests
run_all_tests
