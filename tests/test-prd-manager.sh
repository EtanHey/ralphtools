#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# PRD-MANAGER SCRIPT TEST SUITE
# ═══════════════════════════════════════════════════════════════════
# Tests for skills/golem-powers/prd-manager/scripts/run.sh
# Run: ./tests/test-prd-manager.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test state
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_EXPECTED_FAIL=0
CURRENT_TEST=""

# Script paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_MANAGER="$REPO_DIR/skills/golem-powers/prd-manager/scripts/run.sh"
FIXTURE_GENERATOR="$SCRIPT_DIR/fixtures/prd-manager/generate-fixtures.sh"

# ═══════════════════════════════════════════════════════════════════
# TEST FRAMEWORK
# ═══════════════════════════════════════════════════════════════════

test_start() {
    CURRENT_TEST="$1"
    printf "  %-60s " "$1"
}

test_pass() {
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local reason="${1:-assertion failed}"
    echo -e "${RED}FAIL${NC}"
    echo -e "    ${RED}└─ $reason${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_expected_fail() {
    local reason="${1:-expected failure}"
    echo -e "${YELLOW}XFAIL${NC}"
    echo -e "    ${YELLOW}└─ $reason${NC}"
    TESTS_EXPECTED_FAIL=$((TESTS_EXPECTED_FAIL + 1))
}

assert_output_contains() {
    local output="$1"
    local expected="$2"
    local message="${3:-Expected output to contain '$expected'}"

    if echo "$output" | grep -q "$expected"; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_output_not_contains() {
    local output="$1"
    local not_expected="$2"
    local message="${3:-Expected output NOT to contain '$not_expected'}"

    if ! echo "$output" | grep -q "$not_expected"; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local message="${4:-Expected $field to equal $expected}"

    local actual
    actual=$(echo "$json" | jq -r "$field")
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        test_fail "$message (got: $actual)"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# FIXTURE SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════

setup_scenario() {
    local scenario="$1"
    TEST_DIR=$(mktemp -d)

    # Run fixture generator and capture output
    local fixture_output
    fixture_output=$(bash "$FIXTURE_GENERATOR" "$TEST_DIR" "$scenario")

    # Parse output to get paths
    PRD_DIR=$(echo "$fixture_output" | grep "^PRD_DIR=" | cut -d= -f2)
    export PRD_DIR
}

teardown_scenario() {
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# Run prd-manager with PRD_DIR set
run_prd_manager() {
    PRD_DIR="$PRD_DIR" bash "$PRD_MANAGER" "$@" 2>&1 || true
}

# ═══════════════════════════════════════════════════════════════════
# LIST ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_list_pending_stories() {
    test_start "--action=list --scope=pending lists pending stories"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=list --scope=pending)

    if assert_output_contains "$output" "PENDING STORIES" "Should show PENDING header" && \
       assert_output_contains "$output" "US-002" "Should list US-002" && \
       assert_output_contains "$output" "US-003" "Should list US-003" && \
       assert_output_not_contains "$output" "US-001" "Should NOT list completed US-001"; then
        test_pass
    fi

    teardown_scenario
}

test_list_blocked_stories() {
    test_start "--action=list --scope=blocked lists blocked stories"
    setup_scenario "blocked"

    local output
    output=$(run_prd_manager --action=list --scope=blocked)

    if assert_output_contains "$output" "BLOCKED STORIES" "Should show BLOCKED header" && \
       assert_output_contains "$output" "US-001" "Should list blocked US-001"; then
        test_pass
    fi

    teardown_scenario
}

test_list_all_stories() {
    test_start "--action=list --scope=all lists all active stories"
    setup_scenario "blocked"

    local output
    output=$(run_prd_manager --action=list --scope=all)

    if assert_output_contains "$output" "US-001" "Should list blocked US-001" && \
       assert_output_contains "$output" "US-002" "Should list pending US-002"; then
        test_pass
    fi

    teardown_scenario
}

test_list_empty_pending() {
    test_start "--action=list with no pending shows empty list"
    setup_scenario "all-completed"

    local output
    output=$(run_prd_manager --action=list --scope=pending)

    # Should show header but no stories
    if assert_output_contains "$output" "PENDING STORIES" "Should show header"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# SHOW ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_show_story_details() {
    test_start "--action=show --story=US-001 displays story details"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=show --story=US-001)

    if assert_output_contains "$output" "US-001" "Should show story ID" && \
       assert_output_contains "$output" "Add login button" "Should show story title" && \
       assert_output_contains "$output" "acceptanceCriteria" "Should show criteria"; then
        test_pass
    fi

    teardown_scenario
}

test_show_story_missing() {
    test_start "--action=show with missing story shows error"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=show --story=US-999)

    if assert_output_contains "$output" "No such file\|error\|not found" "Should show error for missing story"; then
        test_pass
    fi

    teardown_scenario
}

test_show_requires_story() {
    test_start "--action=show without --story shows error"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=show)

    if assert_output_contains "$output" "Error: --story required" "Should require --story parameter"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# STATS ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_stats_returns_counts() {
    test_start "--action=stats returns correct counts"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=stats)

    # Basic scenario has: 2 pending, 0 blocked, 2 completed, 4 total
    if assert_json_field "$output" ".pending" "2" "Should have 2 pending" && \
       assert_json_field "$output" ".blocked" "0" "Should have 0 blocked" && \
       assert_json_field "$output" ".completed" "2" "Should have 2 completed" && \
       assert_json_field "$output" ".total" "4" "Should have 4 total"; then
        test_pass
    fi

    teardown_scenario
}

test_stats_with_blocked() {
    test_start "--action=stats counts blocked correctly"
    setup_scenario "blocked"

    local output
    output=$(run_prd_manager --action=stats)

    if assert_json_field "$output" ".blocked" "1" "Should have 1 blocked"; then
        test_pass
    fi

    teardown_scenario
}

test_stats_empty_prd() {
    test_start "--action=stats with empty PRD shows zeros"
    setup_scenario "empty"

    local output
    output=$(run_prd_manager --action=stats)

    if assert_json_field "$output" ".pending" "0" "Should have 0 pending" && \
       assert_json_field "$output" ".total" "0" "Should have 0 total"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# CHECK-PROGRESS ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_check_progress_shows_next_story() {
    test_start "--action=check-progress shows next story"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=check-progress)

    if assert_output_contains "$output" "PRD PROGRESS" "Should show progress header" && \
       assert_output_contains "$output" "Next Story: US-002" "Should show next story"; then
        test_pass
    fi

    teardown_scenario
}

test_check_progress_shows_criteria() {
    test_start "--action=check-progress shows current story criteria"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=check-progress)

    # US-002 has 1/3 criteria checked
    if assert_output_contains "$output" "Criteria:" "Should show criteria section" && \
       assert_output_contains "$output" "Profile page exists" "Should show criterion text" && \
       assert_output_contains "$output" "Progress: 1/3" "Should show 1/3 progress"; then
        test_pass
    fi

    teardown_scenario
}

test_check_progress_shows_stats() {
    test_start "--action=check-progress shows derived stats"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=check-progress)

    if assert_output_contains "$output" "STATS" "Should show stats section" && \
       assert_output_contains "$output" "Pending: 2" "Should show pending count" && \
       assert_output_contains "$output" "Completed: 2" "Should show completed count"; then
        test_pass
    fi

    teardown_scenario
}

test_check_progress_complete() {
    test_start "--action=check-progress with all completed shows COMPLETE"
    setup_scenario "all-completed"

    local output
    output=$(run_prd_manager --action=check-progress)

    if assert_output_contains "$output" "Next Story: COMPLETE" "Should show COMPLETE as next story"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# ADD-CRITERION ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_add_criterion_to_story() {
    test_start "--action=add-criterion adds criterion to story"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=add-criterion --story=US-002 --text="New test criterion")

    # Verify criterion was added
    local story_content
    story_content=$(cat "$PRD_DIR/stories/US-002.json")

    if assert_output_contains "$output" "US-002" "Should confirm US-002 updated" && \
       assert_output_contains "$story_content" "New test criterion" "Story file should contain new criterion"; then
        test_pass
    fi

    teardown_scenario
}

test_add_criterion_bulk_pending() {
    test_start "--action=add-criterion --scope=pending adds to all pending"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=add-criterion --scope=pending --text="Bulk criterion")

    # Should update 2 pending stories (US-002, US-003)
    if assert_output_contains "$output" "Updated 2 stories" "Should update 2 stories"; then
        test_pass
    fi

    teardown_scenario
}

test_add_criterion_requires_text() {
    test_start "--action=add-criterion without --text shows error"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=add-criterion --story=US-002)

    if assert_output_contains "$output" "Error: --text required" "Should require --text parameter"; then
        test_pass
    fi

    teardown_scenario
}

test_add_criterion_idempotent() {
    test_start "--action=add-criterion is idempotent (no duplicates)"
    setup_scenario "basic"

    # Add criterion twice
    run_prd_manager --action=add-criterion --story=US-002 --text="Unique criterion" > /dev/null
    local output
    output=$(run_prd_manager --action=add-criterion --story=US-002 --text="Unique criterion")

    # Second run should not add duplicate, so 0 updated
    if assert_output_contains "$output" "Updated 0 stories" "Should not duplicate criterion"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# ADD-TO-INDEX ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_add_to_index() {
    test_start "--action=add-to-index adds story to index"
    setup_scenario "basic"

    # Create a new story file first
    cat > "$PRD_DIR/stories/US-099.json" << 'EOF'
{
  "id": "US-099",
  "title": "New story",
  "acceptanceCriteria": [{"text": "Test", "checked": false}],
  "passes": false
}
EOF

    local output
    output=$(run_prd_manager --action=add-to-index --story=US-099)

    # Verify it was added
    local index
    index=$(cat "$PRD_DIR/index.json")

    if assert_output_contains "$output" "Added US-099" "Should confirm story added" && \
       assert_output_contains "$index" "US-099" "Index should contain US-099"; then
        test_pass
    fi

    teardown_scenario
}

test_add_to_index_missing_file() {
    test_start "--action=add-to-index with missing story file shows error"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=add-to-index --story=US-MISSING)

    if assert_output_contains "$output" "not found\|Error" "Should show error for missing file"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# SET-NEXT ACTION TESTS
# ═══════════════════════════════════════════════════════════════════

test_set_next_story() {
    test_start "--action=set-next updates nextStory"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=set-next --story=US-003)

    # Verify nextStory was updated
    local index
    index=$(cat "$PRD_DIR/index.json")

    if assert_output_contains "$output" "nextStory set to US-003" "Should confirm next story set" && \
       assert_json_field "$index" ".nextStory" "US-003" "Index should have US-003 as nextStory"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# SUMMARY ACTION TESTS (EXPECTED TO FAIL - NOT IMPLEMENTED)
# ═══════════════════════════════════════════════════════════════════

test_summary_action() {
    test_start "--action=summary shows completed stories (NOT IMPLEMENTED)"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager --action=summary)

    # Summary action is not implemented yet - this test should fail
    # Looking for output that shows completed stories with their titles
    if echo "$output" | grep -q "COMPLETED STORIES\|Summary\|US-001.*Add login button"; then
        test_pass
    else
        test_expected_fail "action=summary not yet implemented (US-125)"
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# HELP/USAGE TESTS
# ═══════════════════════════════════════════════════════════════════

test_no_action_shows_help() {
    test_start "no arguments shows help"
    setup_scenario "basic"

    local output
    output=$(run_prd_manager)

    if assert_output_contains "$output" "PRD Manager" "Should show PRD Manager header" && \
       assert_output_contains "$output" "Actions:" "Should show actions list"; then
        test_pass
    fi

    teardown_scenario
}

# ═══════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  PRD-Manager Script Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check script exists
if [[ ! -f "$PRD_MANAGER" ]]; then
    echo -e "${RED}ERROR: PRD Manager script not found at $PRD_MANAGER${NC}"
    exit 1
fi

# Check fixture generator exists
if [[ ! -f "$FIXTURE_GENERATOR" ]]; then
    echo -e "${RED}ERROR: Fixture generator not found at $FIXTURE_GENERATOR${NC}"
    exit 1
fi

# Run all tests
echo "List Action Tests:"
test_list_pending_stories
test_list_blocked_stories
test_list_all_stories
test_list_empty_pending

echo ""
echo "Show Action Tests:"
test_show_story_details
test_show_story_missing
test_show_requires_story

echo ""
echo "Stats Action Tests:"
test_stats_returns_counts
test_stats_with_blocked
test_stats_empty_prd

echo ""
echo "Check-Progress Action Tests:"
test_check_progress_shows_next_story
test_check_progress_shows_criteria
test_check_progress_shows_stats
test_check_progress_complete

echo ""
echo "Add-Criterion Action Tests:"
test_add_criterion_to_story
test_add_criterion_bulk_pending
test_add_criterion_requires_text
test_add_criterion_idempotent

echo ""
echo "Add-To-Index Action Tests:"
test_add_to_index
test_add_to_index_missing_file

echo ""
echo "Set-Next Action Tests:"
test_set_next_story

echo ""
echo "Summary Action Tests (Expected to Fail):"
test_summary_action

echo ""
echo "Help/Usage Tests:"
test_no_action_shows_help

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}, ${YELLOW}$TESTS_EXPECTED_FAIL expected failures${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
