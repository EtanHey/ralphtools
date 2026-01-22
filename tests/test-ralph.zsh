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
# EXAMPLE TESTS (for framework validation)
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
RALPH_ZSH="${RALPH_ZSH:-$HOME/.config/ralph/ralph.zsh}"
if [[ -f "$RALPH_ZSH" ]]; then
  source "$RALPH_ZSH" 2>/dev/null || true
fi

# Run all tests
run_all_tests
