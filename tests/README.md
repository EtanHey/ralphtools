# Ralph Test Suite

This directory contains automated tests for the Ralph tooling system.

## Running Tests

```bash
# Run all ZSH tests
./tests/test-ralph.zsh

# Run skills tests
./tests/test-skills.zsh

# Run JSON mode tests
./tests/test-json-mode.sh

# Run archive scripts tests
./tests/test-archive.sh

# Run Bun/TypeScript tests
cd bun && bun test
```

## Test Files

| File | Description |
|------|-------------|
| `test-ralph.zsh` | Main test suite for Ralph ZSH functions (~150+ tests) |
| `test-skills.zsh` | Tests for skill structure and compliance |
| `test-json-mode.sh` | Integration tests for JSON mode PRD processing |
| `test-archive.sh` | Tests for archive scripts (archive-snapshot, cleanup-completed) |

## Test Categories

### Context Injection Tests (TEST-001)

Tests for the modular context system that merges context files at runtime:

| Test | Description |
|------|-------------|
| `test_context_files_exist` | Verifies `contexts/base.md` exists in repo |
| `test_context_base_has_required_sections` | Checks base.md has Scratchpad, AIDEV-NOTE, Documentation Fetching, Thinking Before Doing |
| `test_context_merge_function` | Verifies `_ralph_build_context_file()` creates merged output |
| `test_context_cleanup` | Verifies `_ralph_cleanup_context_file()` removes temp files |
| `test_context_patterns_valid` | Validates regex patterns in `context-migrate.zsh` |
| `test_no_old_injection` | Ensures old `${brave_skill}` injection is removed |
| `test_workflow_ralph_has_git_rules` | Verifies `workflow/ralph.md` has git rules |

### Modular Prompts Tests (MP-005)

Tests for the layered prompt system:

| Test | Description |
|------|-------------|
| `test_mp005_prompt_files_exist` | Checks all prompt files exist in `~/.config/ralphtools/prompts/` |
| `test_mp005_build_story_prompt_function_exists` | Verifies function exists |
| `test_mp005_build_story_prompt_us` | Tests US story prompt generation |
| `test_mp005_build_story_prompt_bug` | Tests BUG story prompt generation |
| `test_mp005_build_story_prompt_v` | Tests V story prompt generation |
| `test_mp005_template_substitution` | Verifies template variables are substituted |
| `test_mp005_story_type_detection` | Tests story type detection from ID prefix |

### Context Migration Tests (US-097)

Tests for the context migration wizard:

| Test | Description |
|------|-------------|
| `test_context_migration_function_exists` | Verifies migration function exists |
| `test_context_templates_exist_in_repo` | Checks context templates in repo |
| `test_migration_script_exists` | Verifies migration script is executable |
| `test_skip_context_migration_flag` | Tests --skip-context-migration flag |
| `test_context_migration_menu_item` | Verifies menu item in ralph-setup |

### Worktree Sync Tests (V-016)

Tests for worktree file synchronization:

| Test | Description |
|------|-------------|
| `test_worktree_syncs_env_files` | Verifies .env file sync |
| `test_worktree_syncs_claude_md` | Verifies CLAUDE.md handling |
| `test_worktree_syncs_contexts` | Verifies context loading |
| `test_worktree_syncs_prd_json` | Verifies prd-json directory sync |
| `test_worktree_sync_config` | Verifies .worktree-sync.json processing |

### Wizard Validation Tests (V-017)

Tests for the ralph-install wizard:

| Test | Description |
|------|-------------|
| `test_wizard_validates_global_claude_md` | Checks ~/.claude/CLAUDE.md validation |
| `test_wizard_validates_contexts_dir` | Checks ~/.claude/contexts/ validation |
| `test_wizard_validates_golem_powers_symlink` | Checks symlink validation |
| `test_wizard_checks_op_cli` | Checks 1Password CLI validation |

### Update.json Merge Tests (TEST-003)

Tests for the `_ralph_apply_update_queue()` function:

| Test | Description |
|------|-------------|
| `test_apply_update_creates_story_file` | Verifies story file creation |
| `test_apply_update_adds_to_pending` | Verifies pending array update |
| `test_apply_update_adds_to_storyOrder` | Verifies storyOrder update |
| `test_apply_update_handles_duplicates` | Tests duplicate story handling |
| `test_apply_update_cleans_up` | Verifies update.json deletion |
| (and more...) | See test file for complete list |

## Pre-commit Hook Integration

All tests run automatically via the pre-commit hook (`.githooks/pre-commit`):

1. **ZSH Tests**: `tests/test-ralph.zsh` (section 7)
2. **Skills Tests**: `tests/test-skills.zsh` (section 7)
3. **Bun Tests**: `bun test` in `bun/` directory (section 7)

The hook will fail the commit if any tests fail, ensuring the context system and other functionality remains intact.

## Adding New Tests

1. Add a new function starting with `test_` to `test-ralph.zsh`
2. Use `test_start "description"` at the beginning
3. Use `test_pass` on success or `test_fail "reason"` on failure
4. Tests are auto-discovered and run by `run_all_tests()`

Example:

```zsh
test_my_new_feature() {
  test_start "My new feature works"

  # Setup
  local result=$(my_function 2>&1)

  # Assertions
  if [[ ! "$result" =~ "expected" ]]; then
    test_fail "output missing expected content"
    return
  fi

  test_pass
}
```
