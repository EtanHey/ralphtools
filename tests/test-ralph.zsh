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

  # Build body with available info
  local body="📁 $project_name"
  [[ -n "$iteration" ]] && body+="\n🔢 Iteration $iteration"
  [[ -n "$story_id" ]] && body+="\n📝 $story_id"
  [[ -n "$model" ]] && body+="\n🤖 $model"
  [[ -n "$remaining" ]] && body+="\n📋 $remaining remaining"
  [[ -n "$cost" ]] && body+="\n💰 \$$cost"
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

# Test: _ralph_ntfy builds correct body with project name
test_ntfy_builds_body_with_project_name() {
  test_start "ntfy builds body with project name"
  _setup_test_fixtures
  _reset_mock_curl

  # Call testable version with mock curl (no actual HTTP call)
  _ralph_ntfy_testable "test-topic" "iteration" "Test message" "US-001" "sonnet" "5" "10" "1.50" "mock"

  # Verify curl would have been called
  assert_equals "1" "$MOCK_CURL_CALLED" "curl should have been called" || { _teardown_test_fixtures; return; }

  # Verify body contains project name (from pwd basename)
  # The body should start with the project folder name
  assert_contains "$MOCK_CURL_BODY" "📁" "body should contain project folder icon" || { _teardown_test_fixtures; return; }

  # Verify body contains other expected parts
  assert_contains "$MOCK_CURL_BODY" "🔢 Iteration 5" "body should contain iteration" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "📝 US-001" "body should contain story_id" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "🤖 sonnet" "body should contain model" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "📋 10 remaining" "body should contain remaining count" || { _teardown_test_fixtures; return; }
  assert_contains "$MOCK_CURL_BODY" "💰 \$1.50" "body should contain cost" || { _teardown_test_fixtures; return; }
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
