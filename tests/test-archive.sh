#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# ARCHIVE SCRIPTS TEST SUITE
# ═══════════════════════════════════════════════════════════════════
# Tests for skills/golem-powers/archive/scripts/
# Run: ./tests/test-archive.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test state
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Script paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_SCRIPTS="$REPO_DIR/skills/golem-powers/archive/scripts"
FIXTURE_GENERATOR="$SCRIPT_DIR/fixtures/prd-archive/generate-fixtures.sh"

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

assert_file_exists() {
    local path="$1"
    local message="${2:-File should exist: $path}"

    if [[ -f "$path" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_dir_exists() {
    local path="$1"
    local message="${2:-Directory should exist: $path}"

    if [[ -d "$path" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

assert_file_not_exists() {
    local path="$1"
    local message="${2:-File should not exist: $path}"

    if [[ ! -f "$path" ]]; then
        return 0
    else
        test_fail "$message"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# FIXTURE SETUP/TEARDOWN
# ═══════════════════════════════════════════════════════════════════

setup_fixtures() {
    TEST_DIR=$(mktemp -d)
    bash "$FIXTURE_GENERATOR" "$TEST_DIR" > /dev/null
    # Create docs.local for archive output
    mkdir -p "$TEST_DIR/docs.local/prd-archive"
}

teardown_fixtures() {
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ═══════════════════════════════════════════════════════════════════
# ARCHIVE-SNAPSHOT TESTS
# ═══════════════════════════════════════════════════════════════════

test_archive_snapshot_creates_directory() {
    test_start "archive-snapshot creates timestamped directory"
    setup_fixtures

    # Run archive-snapshot
    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/archive-snapshot.sh" > /dev/null 2>&1
    popd > /dev/null

    # Check that an archive directory was created
    local archive_count=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$archive_count" -eq 1 ]]; then
        test_pass
    else
        test_fail "Expected 1 archive directory, found $archive_count"
    fi

    teardown_fixtures
}

test_archive_snapshot_copies_index() {
    test_start "archive-snapshot copies index.json"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/archive-snapshot.sh" > /dev/null 2>&1
    popd > /dev/null

    # Find the archive directory
    local archive_dir=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | head -1)

    if assert_file_exists "$archive_dir/index.json" "index.json should be in archive"; then
        # Verify content matches
        local orig=$(cat "$TEST_DIR/prd-json/index.json" | jq -S .)
        local archived=$(cat "$archive_dir/index.json" | jq -S .)
        if [[ "$orig" == "$archived" ]]; then
            test_pass
        else
            test_fail "Archived index.json content doesn't match original"
        fi
    fi

    teardown_fixtures
}

test_archive_snapshot_copies_stories() {
    test_start "archive-snapshot copies all story files"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/archive-snapshot.sh" > /dev/null 2>&1
    popd > /dev/null

    local archive_dir=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | head -1)

    # Count stories in original and archive
    local orig_count=$(ls -1 "$TEST_DIR/prd-json/stories"/*.json 2>/dev/null | wc -l | tr -d ' ')
    local archived_count=$(ls -1 "$archive_dir/stories"/*.json 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$orig_count" -eq "$archived_count" && "$archived_count" -eq 4 ]]; then
        test_pass
    else
        test_fail "Expected 4 stories in archive, found $archived_count (original: $orig_count)"
    fi

    teardown_fixtures
}

test_archive_snapshot_copies_progress() {
    test_start "archive-snapshot copies progress.txt"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/archive-snapshot.sh" > /dev/null 2>&1
    popd > /dev/null

    local archive_dir=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | head -1)

    if assert_file_exists "$archive_dir/progress.txt" "progress.txt should be in archive"; then
        test_pass
    fi

    teardown_fixtures
}

# ═══════════════════════════════════════════════════════════════════
# CLEANUP-COMPLETED TESTS
# ═══════════════════════════════════════════════════════════════════

test_cleanup_removes_completed_stories() {
    test_start "cleanup-completed removes only passes=true stories"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    # US-001 should be removed (passes=true)
    if assert_file_not_exists "$TEST_DIR/prd-json/stories/US-001.json" "Completed story US-001 should be deleted"; then
        # US-002, US-003, BUG-001 should remain
        if assert_file_exists "$TEST_DIR/prd-json/stories/US-002.json" "Pending story US-002 should remain" &&
           assert_file_exists "$TEST_DIR/prd-json/stories/US-003.json" "Pending story US-003 should remain" &&
           assert_file_exists "$TEST_DIR/prd-json/stories/BUG-001.json" "Blocked story BUG-001 should remain"; then
            test_pass
        fi
    fi

    teardown_fixtures
}

test_cleanup_resets_completed_array() {
    test_start "cleanup resets completed array to empty"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    local completed=$(jq -r '.completed | length' "$TEST_DIR/prd-json/index.json")

    if [[ "$completed" -eq 0 ]]; then
        test_pass
    else
        test_fail "Expected completed array to be empty, but has $completed items"
    fi

    teardown_fixtures
}

test_cleanup_preserves_pending_array() {
    test_start "cleanup preserves pending stories in pending array"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    local pending=$(jq -r '.pending | join(",")' "$TEST_DIR/prd-json/index.json")

    # Should have US-002 and US-003
    if [[ "$pending" == *"US-002"* && "$pending" == *"US-003"* ]]; then
        test_pass
    else
        test_fail "Expected pending to contain US-002,US-003, got: $pending"
    fi

    teardown_fixtures
}

test_cleanup_preserves_blocked_stories() {
    test_start "cleanup preserves blocked stories"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    # Blocked array should still have BUG-001
    local blocked=$(jq -r '.blocked | join(",")' "$TEST_DIR/prd-json/index.json")

    if [[ "$blocked" == *"BUG-001"* ]]; then
        # And the story file should exist
        if assert_file_exists "$TEST_DIR/prd-json/stories/BUG-001.json" "Blocked story file should exist"; then
            test_pass
        fi
    else
        test_fail "Expected blocked to contain BUG-001, got: $blocked"
    fi

    teardown_fixtures
}

test_cleanup_updates_storyOrder() {
    test_start "cleanup updates storyOrder to only remaining stories"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    local order=$(jq -r '.storyOrder | join(",")' "$TEST_DIR/prd-json/index.json")

    # Should have US-002, US-003, BUG-001 but NOT US-001
    if [[ "$order" != *"US-001"* && "$order" == *"US-002"* && "$order" == *"US-003"* && "$order" == *"BUG-001"* ]]; then
        test_pass
    else
        test_fail "Expected storyOrder without US-001, got: $order"
    fi

    teardown_fixtures
}

test_cleanup_sets_next_story() {
    test_start "cleanup sets nextStory to first pending"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    local next=$(jq -r '.nextStory' "$TEST_DIR/prd-json/index.json")

    # Should be US-002 (first pending)
    if [[ "$next" == "US-002" ]]; then
        test_pass
    else
        test_fail "Expected nextStory to be US-002, got: $next"
    fi

    teardown_fixtures
}

test_cleanup_archives_first() {
    test_start "cleanup creates archive before deleting"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    # Check that archive was created
    local archive_count=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$archive_count" -ge 1 ]]; then
        # Check that archived index has US-001 in completed
        local archive_dir=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | head -1)
        local archived_completed=$(jq -r '.completed | join(",")' "$archive_dir/index.json")

        if [[ "$archived_completed" == *"US-001"* ]]; then
            test_pass
        else
            test_fail "Archive should have US-001 in completed, got: $archived_completed"
        fi
    else
        test_fail "No archive created"
    fi

    teardown_fixtures
}

test_cleanup_skip_archive_flag() {
    test_start "cleanup --skip-archive skips archiving"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" --skip-archive > /dev/null 2>&1
    popd > /dev/null

    # Check that NO archive was created
    local archive_count=$(ls -d "$TEST_DIR/docs.local/prd-archive"/*/ 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$archive_count" -eq 0 ]]; then
        test_pass
    else
        test_fail "Expected no archive with --skip-archive, found $archive_count"
    fi

    teardown_fixtures
}

test_cleanup_dry_run() {
    test_start "cleanup --dry-run doesn't modify files"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" --dry-run > /dev/null 2>&1
    popd > /dev/null

    # US-001 should still exist
    if assert_file_exists "$TEST_DIR/prd-json/stories/US-001.json" "US-001 should still exist after dry-run"; then
        # completed array should still have US-001
        local completed=$(jq -r '.completed | join(",")' "$TEST_DIR/prd-json/index.json")
        if [[ "$completed" == *"US-001"* ]]; then
            test_pass
        else
            test_fail "completed array was modified in dry-run"
        fi
    fi

    teardown_fixtures
}

test_cleanup_resets_progress() {
    test_start "cleanup resets progress.txt"
    setup_fixtures

    pushd "$TEST_DIR" > /dev/null
    bash "$ARCHIVE_SCRIPTS/cleanup-completed.sh" > /dev/null 2>&1
    popd > /dev/null

    if assert_file_exists "$TEST_DIR/progress.txt" "progress.txt should exist"; then
        local content=$(cat "$TEST_DIR/progress.txt")
        if [[ "$content" == *"Fresh Start"* ]]; then
            test_pass
        else
            test_fail "progress.txt should contain 'Fresh Start'"
        fi
    fi

    teardown_fixtures
}

# ═══════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Archive Scripts Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Run all tests
echo "Archive-Snapshot Tests:"
test_archive_snapshot_creates_directory
test_archive_snapshot_copies_index
test_archive_snapshot_copies_stories
test_archive_snapshot_copies_progress

echo ""
echo "Cleanup-Completed Tests:"
test_cleanup_removes_completed_stories
test_cleanup_resets_completed_array
test_cleanup_preserves_pending_array
test_cleanup_preserves_blocked_stories
test_cleanup_updates_storyOrder
test_cleanup_sets_next_story
test_cleanup_archives_first
test_cleanup_skip_archive_flag
test_cleanup_dry_run
test_cleanup_resets_progress

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
