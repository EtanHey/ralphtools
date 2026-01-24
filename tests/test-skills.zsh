#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH SKILLS TEST SUITE
# ═══════════════════════════════════════════════════════════════════
# Usage: ./tests/test-skills.zsh
#
# Tests that all skills follow the correct structure and their
# scripts/workflows are functional.
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

# Skills directory - use THIS REPO's skills as the source of truth
# Structure: skills/golem-powers/{skill-name}/SKILL.md
# The symlink ~/.claude/commands/golem-powers -> skills/golem-powers is for user install
typeset -g REPO_ROOT="${0:A:h:h}"  # Parent of tests/ dir
typeset -g SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/skills/golem-powers}"

# ═══════════════════════════════════════════════════════════════════
# RESULTS TRACKING (file-based for reliable counting)
# ═══════════════════════════════════════════════════════════════════

_init_results() {
  RESULTS_FILE=$(mktemp)
  echo "0 0" > "$RESULTS_FILE"
}

_record_pass() {
  local current
  current=$(cat "$RESULTS_FILE")
  local passed=${current%% *}
  local failed=${current##* }
  passed=$((passed + 1))
  echo "$passed $failed" > "$RESULTS_FILE"
}

_record_fail() {
  local current
  current=$(cat "$RESULTS_FILE")
  local passed=${current%% *}
  local failed=${current##* }
  failed=$((failed + 1))
  echo "$passed $failed" > "$RESULTS_FILE"
}

_get_results() {
  cat "$RESULTS_FILE"
}

_cleanup_results() {
  [[ -f "$RESULTS_FILE" ]] && rm -f "$RESULTS_FILE"
}

# ═══════════════════════════════════════════════════════════════════
# TEST OUTPUT FUNCTIONS
# ═══════════════════════════════════════════════════════════════════

test_start() {
  local test_name="$1"
  CURRENT_TEST="$test_name"
  TEST_FAILED_FLAG=0
  printf "  %-55s " "$test_name"
}

test_pass() {
  if [[ $TEST_FAILED_FLAG -eq 0 ]]; then
    echo -e "${GREEN}PASS${NC}"
    _record_pass
  fi
}

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

assert_dir_exists() {
  local path="$1"
  local message="${2:-Expected directory to exist: $path}"

  if [[ -d "$path" ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

assert_executable() {
  local path="$1"
  local message="${2:-Expected file to be executable: $path}"

  if [[ -x "$path" ]]; then
    return 0
  else
    test_fail "$message"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# SKILL DISCOVERY HELPERS
# ═══════════════════════════════════════════════════════════════════

# Get list of all skills (directories with SKILL.md)
_get_directory_skills() {
  local skills=()
  for entry in "$SKILLS_DIR"/*; do
    # Resolve symlinks
    local resolved="$entry"
    if [[ -L "$entry" ]]; then
      resolved=$(readlink -f "$entry" 2>/dev/null || readlink "$entry")
    fi

    # Only consider directories with SKILL.md
    if [[ -d "$resolved" && -f "$resolved/SKILL.md" ]]; then
      skills+=("$(basename "$entry")")
    fi
  done
  echo "${skills[@]}"
}

# Get the resolved path for a skill
_get_skill_path() {
  local skill_name="$1"
  local entry="$SKILLS_DIR/$skill_name"

  if [[ -L "$entry" ]]; then
    readlink -f "$entry" 2>/dev/null || readlink "$entry"
  elif [[ -d "$entry" ]]; then
    echo "$entry"
  else
    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════════════
# STRUCTURE VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════

# Test: Each directory skill has SKILL.md
test_directory_skills_have_skill_md() {
  test_start "directory skills have SKILL.md"

  local all_passed=true
  local missing_skills=()

  for entry in "$SKILLS_DIR"/*; do
    local basename=$(basename "$entry")
    local resolved="$entry"

    if [[ -L "$entry" ]]; then
      resolved=$(readlink -f "$entry" 2>/dev/null || readlink "$entry")
    fi

    # Skip single-file skills (.md files)
    [[ "$basename" == *.md ]] && continue

    # If it's a directory, it must have SKILL.md
    if [[ -d "$resolved" ]]; then
      if [[ ! -f "$resolved/SKILL.md" ]]; then
        all_passed=false
        missing_skills+=("$basename")
      fi
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Skills missing SKILL.md: ${missing_skills[*]}"
  fi
}

# Test: SKILL.md files contain required sections
test_skill_md_has_required_sections() {
  test_start "SKILL.md contains required sections"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_skills=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local skill_md="$skill_path/SKILL.md"

    if [[ -f "$skill_md" ]]; then
      local content=$(cat "$skill_md")

      # Required for ALL skills:
      # 1. YAML frontmatter with name and description

      # Check YAML frontmatter
      if [[ ! "$content" =~ ^---.*name:.*--- ]]; then
        all_passed=false
        failing_skills+=("$skill (missing frontmatter)")
        continue
      fi

      # Required only for MULTI-ACTION skills (those with workflows/):
      # 2. Quick Actions or Quick Start section (routing table)
      if [[ -d "$skill_path/workflows" ]]; then
        if [[ ! "$content" =~ "Quick" ]]; then
          all_passed=false
          failing_skills+=("$skill (has workflows/ but missing Quick Actions/Start)")
          continue
        fi
      fi
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Skills with invalid SKILL.md: ${failing_skills[*]}"
  fi
}

# Test: Workflow files have proper structure
test_workflow_files_have_proper_structure() {
  test_start "workflow files have proper structure"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_files=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local workflows_dir="$skill_path/workflows"

    if [[ -d "$workflows_dir" ]]; then
      for workflow in "$workflows_dir"/*.md; do
        [[ -f "$workflow" ]] || continue

        local content=$(cat "$workflow")
        local filename=$(basename "$workflow")

        # Workflow files should have:
        # 1. A title (# heading) - can be after YAML frontmatter
        # 2. Some content (more than just whitespace)

        # Check for # heading anywhere in the file (after potential frontmatter)
        if [[ ! "$content" == *$'\n#'* && ! "$content" =~ ^# ]]; then
          all_passed=false
          failing_files+=("$skill/$filename (no title)")
          continue
        fi

        # Check file has meaningful content (at least 50 chars after removing whitespace)
        local content_length=${#content}
        if [[ $content_length -lt 50 ]]; then
          all_passed=false
          failing_files+=("$skill/$filename (too short)")
          continue
        fi
      done
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Invalid workflow files: ${failing_files[*]}"
  fi
}

# Test: If SKILL.md references scripts, scripts/ directory exists
test_scripts_directory_exists_when_referenced() {
  test_start "scripts/ exists when referenced"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_skills=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local skill_md="$skill_path/SKILL.md"

    if [[ -f "$skill_md" ]]; then
      local content=$(cat "$skill_md")

      # Check if SKILL.md references scripts
      if [[ "$content" =~ "scripts/" || "$content" =~ "Available Scripts" ]]; then
        # Then scripts/ directory must exist
        if [[ ! -d "$skill_path/scripts" ]]; then
          all_passed=false
          failing_skills+=("$skill")
        fi
      fi
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Skills referencing scripts but missing scripts/: ${failing_skills[*]}"
  fi
}

# Test: All scripts in scripts/ directories are executable
test_scripts_are_executable() {
  test_start "scripts are executable"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_scripts=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local scripts_dir="$skill_path/scripts"

    if [[ -d "$scripts_dir" ]]; then
      for script in "$scripts_dir"/*.sh; do
        [[ -f "$script" ]] || continue

        if [[ ! -x "$script" ]]; then
          all_passed=false
          failing_scripts+=("$skill/$(basename "$script")")
        fi
      done
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Non-executable scripts: ${failing_scripts[*]}"
  fi
}

# Test: Scripts have shebang line
test_scripts_have_shebang() {
  test_start "scripts have shebang"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_scripts=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local scripts_dir="$skill_path/scripts"

    if [[ -d "$scripts_dir" ]]; then
      for script in "$scripts_dir"/*.sh; do
        [[ -f "$script" ]] || continue

        local first_line=$(head -1 "$script")
        if [[ ! "$first_line" =~ ^#! ]]; then
          all_passed=false
          failing_scripts+=("$skill/$(basename "$script")")
        fi
      done
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Scripts missing shebang: ${failing_scripts[*]}"
  fi
}

# Test: Scripts pass basic syntax validation
test_scripts_pass_syntax_check() {
  test_start "scripts pass syntax check"

  local skills=($(_get_directory_skills))
  local all_passed=true
  local failing_scripts=()

  for skill in "${skills[@]}"; do
    local skill_path=$(_get_skill_path "$skill")
    local scripts_dir="$skill_path/scripts"

    if [[ -d "$scripts_dir" ]]; then
      for script in "$scripts_dir"/*.sh; do
        [[ -f "$script" ]] || continue

        # Use bash -n for syntax checking
        if ! bash -n "$script" 2>/dev/null; then
          all_passed=false
          failing_scripts+=("$skill/$(basename "$script")")
        fi
      done
    fi
  done

  if [[ "$all_passed" == true ]]; then
    test_pass
  else
    test_fail "Scripts with syntax errors: ${failing_scripts[*]}"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# SPECIFIC SKILL TESTS (known compliant skills)
# ═══════════════════════════════════════════════════════════════════

# Test: github skill is compliant (simple skill - just SKILL.md, no workflows/scripts)
test_github_skill_compliant() {
  test_start "github skill is compliant"

  local skill_path=$(_get_skill_path "github")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "github missing SKILL.md" || return

  # github is a simple documentation skill - it wraps git/gh CLI commands
  # No workflows or scripts needed

  test_pass
}

# Test: convex skill is compliant
test_convex_skill_compliant() {
  test_start "convex skill is compliant"

  local skill_path=$(_get_skill_path "convex")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "convex missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "convex missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "convex missing scripts/" || return

  # Must have at least one workflow
  local workflow_count=$(ls -1 "$skill_path/workflows"/*.md 2>/dev/null | wc -l | tr -d ' ')
  [[ $workflow_count -ge 1 ]] || { test_fail "convex has no workflows"; return; }

  # Must have at least one script
  local script_count=$(ls -1 "$skill_path/scripts"/*.sh 2>/dev/null | wc -l | tr -d ' ')
  [[ $script_count -ge 1 ]] || { test_fail "convex has no scripts"; return; }

  test_pass
}

# Test: 1password skill is compliant
test_1password_skill_compliant() {
  test_start "1password skill is compliant"

  local skill_path=$(_get_skill_path "1password")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "1password missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "1password missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "1password missing scripts/" || return

  test_pass
}

# Test: linear skill is compliant
test_linear_skill_compliant() {
  test_start "linear skill is compliant"

  local skill_path=$(_get_skill_path "linear")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "linear missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "linear missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "linear missing scripts/" || return

  test_pass
}

# Test: archive skill is compliant
test_archive_skill_compliant() {
  test_start "archive skill is compliant"

  local skill_path=$(_get_skill_path "archive")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "archive missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "archive missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "archive missing scripts/" || return

  test_pass
}

# Test: ralph-install skill is compliant
test_ralph_install_skill_compliant() {
  test_start "ralph-install skill is compliant"

  local skill_path=$(_get_skill_path "ralph-install")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "ralph-install missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "ralph-install missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "ralph-install missing scripts/" || return

  test_pass
}

# Test: worktrees skill is compliant (no scripts required - git commands only)
test_worktrees_skill_compliant() {
  test_start "worktrees skill is compliant"

  local skill_path=$(_get_skill_path "worktrees")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "worktrees missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "worktrees missing workflows/" || return

  # Note: worktrees skill doesn't require scripts/ - it only uses simple git commands

  test_pass
}

# Test: critique-waves skill is compliant
test_critique_waves_skill_compliant() {
  test_start "critique-waves skill is compliant"

  local skill_path=$(_get_skill_path "critique-waves")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "critique-waves missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "critique-waves missing workflows/" || return

  # Must have scripts directory
  assert_dir_exists "$skill_path/scripts" "critique-waves missing scripts/" || return

  # Must have at least one workflow
  local workflow_count=$(ls -1 "$skill_path/workflows"/*.md 2>/dev/null | wc -l | tr -d ' ')
  [[ $workflow_count -ge 1 ]] || { test_fail "critique-waves has no workflows"; return; }

  # Must have at least one script
  local script_count=$(ls -1 "$skill_path/scripts"/*.sh 2>/dev/null | wc -l | tr -d ' ')
  [[ $script_count -ge 1 ]] || { test_fail "critique-waves has no scripts"; return; }

  test_pass
}

# Test: brave skill is compliant (no scripts required - external CLI)
test_brave_skill_compliant() {
  test_start "brave skill is compliant"

  local skill_path=$(_get_skill_path "brave")

  # Must have SKILL.md
  assert_file_exists "$skill_path/SKILL.md" "brave missing SKILL.md" || return

  # Must have workflows directory
  assert_dir_exists "$skill_path/workflows" "brave missing workflows/" || return

  # Note: brave skill doesn't require scripts/ - it wraps external brave-manager CLI

  test_pass
}

# ═══════════════════════════════════════════════════════════════════
# TEST RUNNER
# ═══════════════════════════════════════════════════════════════════

run_all_tests() {
  _init_results
  trap '_cleanup_results' EXIT

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Ralph Skills Test Suite"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "Skills directory: $SKILLS_DIR"
  echo ""

  # Find all functions starting with test_
  local test_functions=()
  for func in ${(ok)functions}; do
    if [[ "$func" == test_* && "$func" != "test_start" && "$func" != "test_pass" && "$func" != "test_fail" ]]; then
      test_functions+=("$func")
    fi
  done

  # Disable ERR_EXIT for test execution
  setopt NO_ERR_EXIT

  # Run each test
  for test_func in "${test_functions[@]}"; do
    TEST_FAILED_FLAG=0
    CURRENT_TEST=""
    "$test_func" || true
  done

  # Get final counts
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

  if [[ $final_failed -gt 0 ]]; then
    exit 1
  else
    exit 0
  fi
}

# ═══════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

run_all_tests
