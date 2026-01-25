#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH - Autonomous Coding Loop (Original Concept)
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph [app] [max_iterations] [sleep_seconds] [-QN] [-c] [-S]
# Examples:
#   ralph 30 5 -QN         # Classic mode: ./prd-json/, current branch
#   ralph expo 300         # App mode: apps/expo/prd-json/, feat/expo-work branch
#   ralph public 300 -QN   # App mode with notifications
#   ralph 100 -S           # Run with Sonnet model (faster, cheaper)
#   ralph 50 -c            # Run with compact output (less verbose)
#
# Options:
#   app  : Optional app name - uses apps/{app}/prd-json/
#   -QN  : Enable quiet notifications via ntfy app
#   -c, --compact : Compact output mode (less vertical whitespace)
#   -d, --debug   : Debug output mode (more verbose)
#   --no-live    : Disable live progress bar updates (fswatch)
#   --ui-ink     : Use React Ink UI dashboard (default, requires bun)
#   --ui-bash    : Force traditional zsh-based UI (fallback)
#   (no flag) : No notifications, Opus model, Ink UI (default)
#
# Model Flags:
#   -O   : Opus (Claude, default)
#   -S   : Sonnet (Claude, faster)
#
# Deprecated Flags (use smart routing via config.json instead):
#   -H   : Haiku (DEPRECATED - use smart routing)
#   -K   : Kiro CLI (DEPRECATED - use smart routing)
#   -G   : Gemini CLI (DEPRECATED - use smart routing)
#
# Smart Model Routing (Recommended):
#   Configure models in config.json via `ralph-setup`. Story prefixes
#   auto-select models: US→Sonnet, V→Haiku, BUG→Sonnet, etc.
#
# App Mode:
#   - PRD: apps/{app}/prd-json/
#   - Branch: feat/{app}-work (creates if needed)
#   - Notifications: {project}-{app} topic
#   - Multiple can run simultaneously on different branches
#
# Prerequisites:
# 1. Create prd-json/ with user stories (use /golem-powers:prd skill)
# 2. Each story should be small (completable in one context window)
# 3. Run `ralph` from project root
#
# This is the ORIGINAL Ralph concept - a bash loop spawning FRESH
# Claude instances. Unlike the plugin, each iteration gets clean context.
# Output streams in REAL-TIME so you can watch Claude work.
# ═══════════════════════════════════════════════════════════════════

# Read version from centralized VERSION file
RALPH_VERSION_FILE="${0:A:h}/VERSION"
if [[ -f "$RALPH_VERSION_FILE" ]]; then
  RALPH_VERSION=$(head -1 "$RALPH_VERSION_FILE")
else
  RALPH_VERSION="0.0.0"  # Fallback if VERSION file missing
fi

# ═══════════════════════════════════════════════════════════════════
# CHANGELOG (loaded from VERSION file)
# Format: VERSION|feature1|feature2|...
# ═══════════════════════════════════════════════════════════════════
declare -A RALPH_CHANGELOG
if [[ -f "$RALPH_VERSION_FILE" ]]; then
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Parse VERSION|features format
    local ver="${line%%|*}"
    local features="${line#*|}"
    [[ "$ver" != "$line" ]] && RALPH_CHANGELOG[$ver]="$features"
  done < "$RALPH_VERSION_FILE"
fi

# ═══════════════════════════════════════════════════════════════════
# WHAT'S NEW (shown once per version upgrade)
# ═══════════════════════════════════════════════════════════════════
_ralph_show_whatsnew() {
  local last_version_file="$RALPH_CONFIG_DIR/.ralph_last_version"
  local last_version=""

  [[ -f "$last_version_file" ]] && last_version=$(cat "$last_version_file" 2>/dev/null)

  # Skip if same version
  [[ "$last_version" == "$RALPH_VERSION" ]] && return 0

  # Show what's new (current version only)
  _ralph_show_changelog_version "$RALPH_VERSION"

  # Save current version
  echo "$RALPH_VERSION" > "$last_version_file"
}

# Helper function to display a specific version's changelog
_ralph_show_changelog_version() {
  local version="$1"
  local changes="${RALPH_CHANGELOG[$version]:-Updated to v${version}}"

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🆕 Ralph v${version}                                          │"
  echo "├─────────────────────────────────────────────────────────────┤"

  # Parse pipe-separated changes and display each as a bullet point
  # Split on pipes and iterate
  local change
  while [[ -n "$changes" ]]; do
    # Extract first change (before first pipe)
    change="${changes%%\|*}"
    # Trim leading/trailing whitespace
    change="${change#"${change%%[![:space:]]*}"}"
    change="${change%"${change##*[![:space:]]}"}"
    # Print with formatting using display width
    local display_width=$(_ralph_display_width "$change")
    local padding=$((57 - (display_width - ${#change})))
    printf "│  • %-${padding}s │\n" "$change"
    # Remove processed change from string
    [[ "$changes" == *"|"* ]] && changes="${changes#*\|}" || changes=""
  done

  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""
}

# Helper function to calculate display width of a string
# Strips ANSI escape codes, counts emojis as width 2, regular ASCII as width 1
# Usage: _ralph_display_width "string with emojis 🚀" → returns display width
_ralph_display_width() {
  local str="$1"

  # Strip ANSI escape codes (colors, bold, etc.) - they have zero display width
  # Pattern matches: ESC[ followed by any number of digits/semicolons, ending with a letter
  local clean_str=$(echo "$str" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')

  # Strip Unicode variation selectors (U+FE0F = ️) - zero display width but counted in ${#str}
  clean_str=$(echo "$clean_str" | sed 's/️//g')

  local width=${#clean_str}  # Start with basic character count

  # Count known emojis that are width 2 (display width extends)
  # Each emoji found adds 1 to width (since it's counted as 1 in ${#str} but displayed as 2)
  local emoji_count=0
  for emoji in 🚀 📋 🆕 💰 ⏱ 🔄 📚 💵 🏁 🎯 ✨ 🆘 🔴 🟢 🟡 ⚡ ❌ ✅ 🛑 🔥 🔕 🔔 📂 📱 📊 📖 🧠; do
    emoji_count=$((emoji_count + $(echo "$clean_str" | grep -o "$emoji" | wc -l)))
  done
  width=$((width + emoji_count))

  echo "$width"
}

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
# Source local config if it exists (for personal overrides)
RALPH_CONFIG_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}"
[[ -f "$RALPH_CONFIG_DIR/ralph-config.local" ]] && source "$RALPH_CONFIG_DIR/ralph-config.local"

# Defaults (can be overridden in ralph-config.local or environment)
# Notification topic configuration:
#   RALPH_NTFY_PREFIX: Base prefix for Ralph topics (default: "etanheys-ralph")
#   RALPH_NTFY_TOPIC: Ralph's topic, defaults to "{prefix}-{project}-notify" format
#   CLAUDE_NTFY_TOPIC: Claude's topic (default: "etanheys-ralphclaude-notify") - separate from Ralph
RALPH_NTFY_PREFIX="${RALPH_NTFY_PREFIX:-etanheys-ralph}"
# Note: RALPH_NTFY_TOPIC will be set per-project in ralph() function
RALPH_NTFY_TOPIC="${RALPH_NTFY_TOPIC:-}"
CLAUDE_NTFY_TOPIC="${CLAUDE_NTFY_TOPIC:-etanheys-ralphclaude-notify}"
RALPH_DEFAULT_MODEL="${RALPH_DEFAULT_MODEL:-opus}"
RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-10}"
RALPH_SLEEP_SECONDS="${RALPH_SLEEP_SECONDS:-2}"
RALPH_VALID_APPS="${RALPH_VALID_APPS:-frontend backend mobile expo public admin}"
RALPH_CONFIG_FILE="${RALPH_CONFIG_DIR}/config.json"

# ═══════════════════════════════════════════════════════════════════
# SOURCE MODULAR LIB FILES
# ═══════════════════════════════════════════════════════════════════
# Ralph is split into modular files in lib/ for maintainability.
# Order matters: base modules must be sourced before dependent ones.
RALPH_LIB_DIR="${0:A:h}/lib"
if [[ -d "$RALPH_LIB_DIR" ]]; then
  # Source modules in dependency order
  [[ -f "$RALPH_LIB_DIR/ralph-ui.zsh" ]] && source "$RALPH_LIB_DIR/ralph-ui.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-watcher.zsh" ]] && source "$RALPH_LIB_DIR/ralph-watcher.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-commands.zsh" ]] && source "$RALPH_LIB_DIR/ralph-commands.zsh"
  # Note: Additional modules will be added as extraction continues
  # [[ -f "$RALPH_LIB_DIR/ralph-models.zsh" ]] && source "$RALPH_LIB_DIR/ralph-models.zsh"
  # [[ -f "$RALPH_LIB_DIR/ralph-registry.zsh" ]] && source "$RALPH_LIB_DIR/ralph-registry.zsh"
  # [[ -f "$RALPH_LIB_DIR/ralph-worktrees.zsh" ]] && source "$RALPH_LIB_DIR/ralph-worktrees.zsh"
  # [[ -f "$RALPH_LIB_DIR/ralph-secrets.zsh" ]] && source "$RALPH_LIB_DIR/ralph-secrets.zsh"
  # [[ -f "$RALPH_LIB_DIR/ralph-setup.zsh" ]] && source "$RALPH_LIB_DIR/ralph-setup.zsh"
fi
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# GUM DEPENDENCY CHECK
# ═══════════════════════════════════════════════════════════════════

# Check if gum is installed for interactive CLI prompts
# Returns: 0 if gum available, 1 if not
_ralph_check_gum() {
  if command -v gum >/dev/null 2>&1; then
    return 0
  else
    echo "For interactive setup, install gum: brew install gum"
    return 1
  fi
}

# Set RALPH_HAS_GUM on source (0 = has gum, 1 = no gum)
if command -v gum >/dev/null 2>&1; then
  RALPH_HAS_GUM=0
else
  RALPH_HAS_GUM=1
fi

# ═══════════════════════════════════════════════════════════════════
# SEMANTIC COLOR HELPERS
# ═══════════════════════════════════════════════════════════════════
# Global color constants (ANSI escape codes)
RALPH_COLOR_RESET='\033[0m'
RALPH_COLOR_BOLD='\033[1m'
RALPH_COLOR_RED='\033[0;31m'
RALPH_COLOR_GREEN='\033[0;32m'
RALPH_COLOR_YELLOW='\033[1;33m'
RALPH_COLOR_BLUE='\033[0;34m'
RALPH_COLOR_MAGENTA='\033[0;35m'
RALPH_COLOR_CYAN='\033[0;36m'
RALPH_COLOR_GOLD='\033[0;33m'
RALPH_COLOR_PURPLE='\033[0;35m'
RALPH_COLOR_GRAY='\033[0;90m'

# Color a story ID by its type prefix
# Usage: _ralph_color_story_id "US-001" → colored string
_ralph_color_story_id() {
  local story_id="$1"
  local prefix="${story_id%%-*}"
  local color=""

  case "$prefix" in
    US)    color="$RALPH_COLOR_BLUE" ;;
    V)     color="$RALPH_COLOR_PURPLE" ;;
    TEST)  color="$RALPH_COLOR_YELLOW" ;;
    BUG)   color="$RALPH_COLOR_RED" ;;
    AUDIT) color="$RALPH_COLOR_MAGENTA" ;;
    MP)    color="$RALPH_COLOR_CYAN" ;;
    *)     color="$RALPH_COLOR_RESET" ;;
  esac

  echo -e "${color}${story_id}${RALPH_COLOR_RESET}"
}

# Color a model name semantically
# Usage: _ralph_color_model "opus" → colored string
_ralph_color_model() {
  local model="$1"
  local color=""

  case "$model" in
    opus)   color="$RALPH_COLOR_GOLD" ;;
    sonnet) color="$RALPH_COLOR_CYAN" ;;
    haiku)  color="$RALPH_COLOR_GREEN" ;;
    *)      color="$RALPH_COLOR_RESET" ;;
  esac

  echo -e "${color}${model}${RALPH_COLOR_RESET}"
}

# Color a cost value based on thresholds
# Usage: _ralph_color_cost "1.50" → colored "$1.50"
_ralph_color_cost() {
  local cost_str="$1"
  # Remove $ prefix if present for comparison
  local cost_val="${cost_str#\$}"
  local color=""

  # Compare as float: green <$0.50, yellow <$2, red >=$2
  if (( $(echo "$cost_val < 0.50" | bc -l 2>/dev/null || echo "0") )); then
    color="$RALPH_COLOR_GREEN"
  elif (( $(echo "$cost_val < 2.00" | bc -l 2>/dev/null || echo "0") )); then
    color="$RALPH_COLOR_YELLOW"
  else
    color="$RALPH_COLOR_RED"
  fi

  # Output with $ prefix
  echo -e "${color}\$${cost_val}${RALPH_COLOR_RESET}"
}

# Success message in green
# Usage: _ralph_success "All tests passed"
_ralph_success() {
  echo -e "${RALPH_COLOR_GREEN}$1${RALPH_COLOR_RESET}"
}

# Error message in red
# Usage: _ralph_error "Build failed"
_ralph_error() {
  echo -e "${RALPH_COLOR_RED}$1${RALPH_COLOR_RESET}"
}

# Warning message in yellow
# Usage: _ralph_warning "Deprecated API usage"
_ralph_warning() {
  echo -e "${RALPH_COLOR_YELLOW}$1${RALPH_COLOR_RESET}"
}

# Bold/bright text for emphasis
# Usage: _ralph_bold "ITERATION 5"
_ralph_bold() {
  echo -e "${RALPH_COLOR_BOLD}$1${RALPH_COLOR_RESET}"
}

# ═══════════════════════════════════════════════════════════════════
# PROGRESS BAR HELPERS
# ═══════════════════════════════════════════════════════════════════

# Get color for progress bar based on percentage
# Usage: _ralph_progress_color 75 → color code
_ralph_progress_color() {
  local percent="$1"
  if (( percent >= 75 )); then
    echo "$RALPH_COLOR_GREEN"
  elif (( percent >= 50 )); then
    echo "$RALPH_COLOR_YELLOW"
  else
    echo "$RALPH_COLOR_RED"
  fi
}

# Generate a progress bar with filled/empty blocks
# Usage: _ralph_progress_bar 4 6 10 → [████░░░░░░] 4/6
# Args: current, total, bar_width (optional, default 10)
_ralph_progress_bar() {
  local current="$1"
  local total="$2"
  local width="${3:-10}"

  # Handle edge cases
  (( total <= 0 )) && total=1
  (( current < 0 )) && current=0
  (( current > total )) && current=$total

  # Calculate percentage and filled blocks (cap at 100%)
  local percent=$((current * 100 / total))
  (( percent > 100 )) && percent=100
  local filled=$((current * width / total))
  local empty=$((width - filled))

  # Get color based on percentage
  local color=$(_ralph_progress_color $percent)

  # Build the bar using Unicode blocks
  local bar=""
  for ((j=0; j<filled; j++)); do bar+="█"; done
  for ((j=0; j<empty; j++)); do bar+="░"; done

  echo -e "${color}[${bar}]${RALPH_COLOR_RESET} ${current}/${total}"
}

# Iteration progress bar: shows X/MAX iterations
# Usage: _ralph_iteration_progress 3 10 → [███░░░░░░░] 3/10
_ralph_iteration_progress() {
  local current="$1"
  local max="$2"
  _ralph_progress_bar "$current" "$max" 10
}

# Story progress bar: shows completed/total stories
# Usage: _ralph_story_progress 20 30 → [██████░░░░] 20/30
_ralph_story_progress() {
  local completed="$1"
  local total="$2"
  _ralph_progress_bar "$completed" "$total" 10
}

# Criteria progress bar: shows checked/total criteria for current story
# Usage: _ralph_criteria_progress 4 6 → [██████░░░░] 4/6
_ralph_criteria_progress() {
  local checked="$1"
  local total="$2"
  _ralph_progress_bar "$checked" "$total" 10
}

# Get current story's criteria progress (checked/total)
# Usage: _ralph_get_story_criteria_progress "US-001" "/path/to/prd-json"
# Returns: "checked total" space-separated
_ralph_get_story_criteria_progress() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local story_id="$1"
  local json_dir="$2"
  local story_file="$json_dir/stories/${story_id}.json"

  if [[ ! -f "$story_file" ]]; then
    echo "0 0"
    return
  fi

  local total=$(jq '[.acceptanceCriteria[]] | length' "$story_file" 2>/dev/null || echo 0)
  local checked=$(jq '[.acceptanceCriteria[] | select(.checked == true)] | length' "$story_file" 2>/dev/null || echo 0)

  echo "$checked $total"
}

# Get total criteria across ALL stories in PRD
# Usage: _ralph_get_total_criteria "/path/to/prd-json"
# Returns: "checked total" space-separated
_ralph_get_total_criteria() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local json_dir="$1"
  local stories_dir="$json_dir/stories"

  if [[ ! -d "$stories_dir" ]]; then
    echo "0 0"
    return
  fi

  local total=0
  local checked=0

  for story_file in "$stories_dir"/*.json; do
    [[ -f "$story_file" ]] || continue
    local t=$(jq '[.acceptanceCriteria[]] | length' "$story_file" 2>/dev/null || echo 0)
    local c=$(jq '[.acceptanceCriteria[] | select(.checked == true)] | length' "$story_file" 2>/dev/null || echo 0)
    total=$((total + t))
    checked=$((checked + c))
  done

  echo "$checked $total"
}

# Derive stats on-the-fly from index.json arrays and story files (US-106)
# Usage: _ralph_derive_stats "/path/to/prd-json"
# Returns: "pending blocked completed total" space-separated
# Counts: pending array length, blocked array length, stories with passes:true
_ralph_derive_stats() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local json_dir="$1"
  local index_file="$json_dir/index.json"
  local stories_dir="$json_dir/stories"

  if [[ ! -f "$index_file" ]]; then
    echo "0 0 0 0"
    return
  fi

  # Get pending and blocked from arrays
  local pending=$(jq -r '.pending | length' "$index_file" 2>/dev/null || echo 0)
  local blocked=$(jq -r '.blocked | length' "$index_file" 2>/dev/null || echo 0)

  # Count completed stories (passes: true)
  local completed=0
  local total=0

  if [[ -d "$stories_dir" ]]; then
    for story_file in "$stories_dir"/*.json(N); do
      [[ -f "$story_file" ]] || continue
      total=$((total + 1))
      local passes=$(jq -r '.passes // false' "$story_file" 2>/dev/null)
      [[ "$passes" == "true" ]] && completed=$((completed + 1))
    done
  fi

  echo "$pending $blocked $completed $total"
}

# Write status file for UI tools to watch (US-106)
# Usage: _ralph_write_status "state" ["error_message"] ["retry_seconds"]
# States: running, cr_review, error, retry
# Status file: /tmp/ralph-status-$$.json
_ralph_write_status() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local state="${1:-running}"
  local error_msg="${2:-null}"
  local retry_seconds="${3:-0}"

  # Create status file path with PID
  RALPH_STATUS_FILE="${RALPH_STATUS_FILE:-/tmp/ralph-status-$$.json}"

  local timestamp=$(date +%s)

  # Build JSON with proper escaping
  if [[ "$error_msg" != "null" ]]; then
    error_msg="\"$(echo "$error_msg" | sed 's/"/\\"/g')\""
  fi

  cat > "$RALPH_STATUS_FILE" << EOF
{
  "state": "$state",
  "lastActivity": $timestamp,
  "error": $error_msg,
  "retryIn": $retry_seconds,
  "pid": $$
}
EOF
}

# Clean up status file (called from cleanup_ralph trap)
_ralph_cleanup_status_file() {
  if [[ -n "$RALPH_STATUS_FILE" && -f "$RALPH_STATUS_FILE" ]]; then
    rm -f "$RALPH_STATUS_FILE"
  fi
}

# Verify actual pending count before trusting Claude's COMPLETE signal (BUG-014)
# Usage: _ralph_verify_pending_count "/path/to/prd-json" "/path/to/PRD.md" "true|false"
# Args:
#   $1 - JSON dir path (for json mode)
#   $2 - PRD.md path (for markdown mode)
#   $3 - use_json_mode (true/false)
# Returns: pending count (0 = actually complete, >0 = still tasks pending)
_ralph_verify_pending_count() {
  local json_dir="$1"
  local prd_path="$2"
  local use_json="$3"
  local actual_pending=0

  if [[ "$use_json" == "true" ]]; then
    # JSON mode: check pending array in index.json
    actual_pending=$(jq -r '.pending | length' "$json_dir/index.json" 2>/dev/null)
    [[ -z "$actual_pending" ]] && actual_pending=0
  else
    # PRD.md mode: count unchecked acceptance criteria (- [ ])
    # grep -c returns 0 count with exit code 1 when no matches, so capture output only
    actual_pending=$(grep -c '^\s*- \[ \]' "$prd_path" 2>/dev/null) || actual_pending=0
  fi

  echo "$actual_pending"
}

# ═══════════════════════════════════════════════════════════════════
# CODERABBIT PRE-COMMIT CHECK
# ═══════════════════════════════════════════════════════════════════
# Free AI code review before committing. Catches issues early.
# Configure: coderabbit.enabled, coderabbit.repos[] in registry

# Global CodeRabbit state
RALPH_CODERABBIT_ENABLED="${RALPH_CODERABBIT_ENABLED:-true}"
RALPH_CODERABBIT_ALLOWED_REPOS="${RALPH_CODERABBIT_ALLOWED_REPOS:-}"

# Check if CodeRabbit should run for current repo
# Returns: 0 if should run, 1 if should skip
_ralph_coderabbit_should_run() {
  # Check if globally disabled
  if [[ "$RALPH_CODERABBIT_ENABLED" != "true" ]]; then
    return 1
  fi

  # Check if cr CLI exists
  if ! command -v cr >/dev/null 2>&1; then
    return 1
  fi

  # Check if current repo is in allowed list
  local current_repo
  current_repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")

  # If allowed repos not set, skip (opt-in)
  if [[ -z "$RALPH_CODERABBIT_ALLOWED_REPOS" ]]; then
    return 1
  fi

  # Check if * (all repos allowed) or specific repo in list
  if [[ "$RALPH_CODERABBIT_ALLOWED_REPOS" == "*" ]]; then
    return 0
  fi

  # Check comma-separated list
  local IFS=','
  local repo
  for repo in $RALPH_CODERABBIT_ALLOWED_REPOS; do
    # Trim whitespace
    repo="${repo#"${repo%%[![:space:]]*}"}"
    repo="${repo%"${repo##*[![:space:]]}"}"
    if [[ "$repo" == "$current_repo" ]]; then
      return 0
    fi
  done

  return 1
}

# Run CodeRabbit review on uncommitted changes
# Usage: _ralph_coderabbit_review
# Returns: 0 if no issues, 1 if issues found (output in RALPH_CODERABBIT_OUTPUT)
# Exit codes:
#   0 - No issues found (or CodeRabbit skipped)
#   1 - Issues found, stored in RALPH_CODERABBIT_OUTPUT
#   2 - CodeRabbit failed to run
_ralph_coderabbit_review() {
  setopt localoptions noxtrace

  RALPH_CODERABBIT_OUTPUT=""

  # Check if we should run
  if ! _ralph_coderabbit_should_run; then
    return 0
  fi

  local CYAN='\033[0;36m'
  local YELLOW='\033[0;33m'
  local GREEN='\033[0;32m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo "${CYAN}🐰 Running CodeRabbit pre-commit review...${NC}"

  # Update status file: cr_review (US-106)
  _ralph_write_status "cr_review"

  # Run cr review with --prompt-only for AI-parseable output
  # --type uncommitted reviews staged and unstaged changes
  local cr_output
  cr_output=$(cr review --prompt-only --type uncommitted 2>&1)
  local cr_exit=$?

  # Check if cr failed to run
  if [[ $cr_exit -ne 0 ]]; then
    echo "${YELLOW}⚠️  CodeRabbit review failed (exit $cr_exit). Continuing without review.${NC}"
    return 0
  fi

  # Check for issues in output
  # Look for: Type: potential_issue OR severity markers (CRITICAL, HIGH, MEDIUM)
  local issue_count=0
  # First try the --prompt-only format (Type: potential_issue)
  if echo "$cr_output" | grep -qE '^Type: potential_issue'; then
    issue_count=$(echo "$cr_output" | grep -cE '^Type: potential_issue')
  # Fallback to severity markers if present
  elif echo "$cr_output" | grep -qiE '\b(CRITICAL|HIGH|MEDIUM)\b.*:'; then
    issue_count=$(echo "$cr_output" | grep -ciE '\b(CRITICAL|HIGH|MEDIUM)\b.*:')
  fi

  if [[ $issue_count -gt 0 ]]; then
    echo "${YELLOW}⚠️  CodeRabbit found $issue_count issue(s)${NC}"
    RALPH_CODERABBIT_OUTPUT="$cr_output"
    return 1
  fi

  echo "${GREEN}✓ CodeRabbit review passed${NC}"
  return 0
}

# Get CodeRabbit configuration from registry
# Sets RALPH_CODERABBIT_ENABLED and RALPH_CODERABBIT_ALLOWED_REPOS from registry
_ralph_load_coderabbit_config() {
  if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
    local cr_enabled cr_repos
    cr_enabled=$(jq -r '.coderabbit.enabled // "true"' "$RALPH_REGISTRY_FILE" 2>/dev/null)
    cr_repos=$(jq -r '.coderabbit.repos // [] | join(",")' "$RALPH_REGISTRY_FILE" 2>/dev/null)

    RALPH_CODERABBIT_ENABLED="${cr_enabled:-true}"
    RALPH_CODERABBIT_ALLOWED_REPOS="${cr_repos:-}"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# LIVE FILE WATCHER (fswatch/inotifywait)
# ═══════════════════════════════════════════════════════════════════
# Provides real-time progress updates without terminal flashing.
# Uses ANSI cursor positioning to update only changed characters.

# Global watcher state
RALPH_WATCHER_PID=""
RALPH_WATCHER_FIFO=""
RALPH_LIVE_ENABLED=true
RALPH_LAST_UPDATE_TIME=0
RALPH_DEBOUNCE_MS=500
RALPH_CRITERIA_ROW=0      # Row where criteria progress bar was drawn
RALPH_STORIES_ROW=0       # Row where stories progress bar was drawn

# Check for file watcher availability
# Returns: 0 if fswatch (macOS) or inotifywait (Linux) available, 1 if not
_ralph_check_fswatch() {
  if command -v fswatch >/dev/null 2>&1; then
    echo "fswatch"
    return 0
  elif command -v inotifywait >/dev/null 2>&1; then
    echo "inotifywait"
    return 0
  else
    return 1
  fi
}

# DEBUG OUTPUT - guard with RALPH_DEBUG_LIVE
# Debug logging for live updates system (enable with RALPH_DEBUG_LIVE=true)
_ralph_debug_live() {
  [[ "$RALPH_DEBUG_LIVE" == "true" ]] && echo "[LIVE-DEBUG] $(date '+%H:%M:%S') $*" >> /tmp/ralph-live-debug.log
}

# Start file watcher in background
# Usage: _ralph_start_watcher "/path/to/prd-json"
# Sets RALPH_WATCHER_PID and RALPH_WATCHER_FIFO
_ralph_start_watcher() {
  local json_dir="$1"
  local stories_dir="$json_dir/stories"
  local index_file="$json_dir/index.json"

  # Don't start if live updates disabled
  [[ "$RALPH_LIVE_ENABLED" != "true" ]] && return 1

  # Check for watcher tool
  local watcher_tool
  watcher_tool=$(_ralph_check_fswatch) || {
    # Log once and continue without live updates
    echo -e "${RALPH_COLOR_GRAY}ℹ️  Live updates disabled (install fswatch: brew install fswatch)${RALPH_COLOR_RESET}"
    RALPH_LIVE_ENABLED=false
    return 1
  }

  _ralph_debug_live "start_watcher: tool=$watcher_tool, stories_dir=$stories_dir"

  # Create FIFO for communication and PID file for cleanup
  RALPH_WATCHER_FIFO="/tmp/ralph_watcher_$$_fifo"
  RALPH_WATCHER_PIDFILE="/tmp/ralph_watcher_$$_pid"
  mkfifo "$RALPH_WATCHER_FIFO" 2>/dev/null || {
    _ralph_debug_live "start_watcher: FAILED to create FIFO"
    RALPH_LIVE_ENABLED=false
    return 1
  }

  _ralph_debug_live "start_watcher: FIFO created at $RALPH_WATCHER_FIFO"

  # Start watcher in background based on platform
  # Disable job control to suppress [N] PID and "suspended (tty output)" messages
  setopt LOCAL_OPTIONS NO_MONITOR NO_NOTIFY

  # Store paths/files for use in subshell
  local fifo="$RALPH_WATCHER_FIFO"
  local pidfile="$RALPH_WATCHER_PIDFILE"

  if [[ "$watcher_tool" == "fswatch" ]]; then
    # macOS: fswatch with batch mode, watch stories dir and index.json
    # Detach stdin from TTY to prevent "suspended (tty output)" messages
    # Use process substitution to capture fswatch PID
    {
      # Start fswatch and save its PID to file
      coproc fswatch -0 --batch-marker=EOF "$stories_dir" "$index_file" 2>/dev/null
      echo $! > "$pidfile"
      # Read from fswatch's output
      while IFS= read -r -d '' file <&p; do
        if [[ "$file" == "EOF" ]]; then
          continue
        fi
        # Write changed filename to FIFO (non-blocking)
        echo "$file" > "$fifo" 2>/dev/null &
      done
    } </dev/null >/dev/null 2>&1 &
    RALPH_WATCHER_PID=$!
    disown $RALPH_WATCHER_PID 2>/dev/null
    _ralph_track_pid "$RALPH_WATCHER_PID" "fswatch-wrapper"
  else
    # Linux: inotifywait
    # Detach stdin from TTY to prevent "suspended (tty output)" messages
    {
      coproc inotifywait -m -e modify,create "$stories_dir" "$index_file" --format '%w%f' 2>/dev/null
      echo $! > "$pidfile"
      while read -r file <&p; do
        echo "$file" > "$fifo" 2>/dev/null &
      done
    } </dev/null >/dev/null 2>&1 &
    RALPH_WATCHER_PID=$!
    disown $RALPH_WATCHER_PID 2>/dev/null
    _ralph_track_pid "$RALPH_WATCHER_PID" "inotifywait-wrapper"
  fi

  _ralph_debug_live "start_watcher: SUCCESS, PID=$RALPH_WATCHER_PID"
  return 0
}

# Stop file watcher and cleanup
_ralph_stop_watcher() {
  # Suppress job control messages during cleanup
  setopt LOCAL_OPTIONS NO_MONITOR NO_NOTIFY

  # Kill the actual fswatch/inotifywait process using saved PID
  if [[ -n "$RALPH_WATCHER_PIDFILE" && -f "$RALPH_WATCHER_PIDFILE" ]]; then
    local watcher_pid
    watcher_pid=$(<"$RALPH_WATCHER_PIDFILE")
    if [[ -n "$watcher_pid" ]]; then
      kill "$watcher_pid" 2>/dev/null
      _ralph_untrack_pid "$watcher_pid"
    fi
    rm -f "$RALPH_WATCHER_PIDFILE"
    RALPH_WATCHER_PIDFILE=""
  fi

  # Kill the wrapper shell
  if [[ -n "$RALPH_WATCHER_PID" ]]; then
    _ralph_untrack_pid "$RALPH_WATCHER_PID"
    kill "$RALPH_WATCHER_PID" 2>/dev/null
    # Brief wait for cleanup
    sleep 0.1
    RALPH_WATCHER_PID=""
  fi

  if [[ -n "$RALPH_WATCHER_FIFO" && -p "$RALPH_WATCHER_FIFO" ]]; then
    rm -f "$RALPH_WATCHER_FIFO"
    RALPH_WATCHER_FIFO=""
  fi
}

# Poll for file changes (non-blocking)
# Usage: changed_file=$(_ralph_poll_updates)
# Returns: filename if changed, empty if no updates
_ralph_poll_updates() {
  [[ -z "$RALPH_WATCHER_FIFO" || ! -p "$RALPH_WATCHER_FIFO" ]] && return 1

  # Non-blocking read from FIFO with timeout
  local changed_file=""
  if read -t 0.1 changed_file < "$RALPH_WATCHER_FIFO" 2>/dev/null; then
    echo "$changed_file"
    return 0
  fi
  return 1
}

# Get current terminal row (for cursor positioning)
# Usage: row=$(_ralph_get_cursor_row)
_ralph_get_cursor_row() {
  local row col
  # Save cursor, request position, read response, restore
  IFS=';' read -sdR -p $'\E[6n' row col 2>/dev/null
  echo "${row#*[}"
}

# Update progress bar in-place without flashing
# Usage: _ralph_update_progress_inplace row "new_bar_content"
# Uses ANSI escape codes to position cursor and overwrite
_ralph_update_progress_inplace() {
  local row="$1"
  local content="$2"
  local col="${3:-4}"  # Default column offset (after "║  ")

  [[ "$row" -le 0 ]] && return 1

  # Save cursor, move to position, write content, restore cursor
  # \e[s = save cursor, \e[{row};{col}H = move, \e[u = restore
  printf '\e[s\e[%d;%dH%s\e[u' "$row" "$col" "$content"
}

# Update criteria progress bar for current story
# Usage: _ralph_update_criteria_display "US-031" "/path/to/prd-json"
_ralph_update_criteria_display() {
  local story_id="$1"
  local json_dir="$2"

  [[ "$RALPH_CRITERIA_ROW" -le 0 ]] && return 1

  _ralph_update_criteria_display_at_row "$story_id" "$json_dir" "$RALPH_CRITERIA_ROW"
}

# Update criteria progress bar at explicit row position (used by background polling loop)
# Usage: _ralph_update_criteria_display_at_row "US-031" "/path/to/prd-json" row
_ralph_update_criteria_display_at_row() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local story_id="$1"
  local json_dir="$2"
  local row="$3"

  [[ "$row" -le 0 ]] && return 1

  # Get updated criteria progress
  local criteria_stats=$(_ralph_get_story_criteria_progress "$story_id" "$json_dir")
  local criteria_checked=$(echo "$criteria_stats" | awk '{print $1}')
  local criteria_total=$(echo "$criteria_stats" | awk '{print $2}')

  [[ "$criteria_total" -le 0 ]] && return 0

  _ralph_debug_live "update_criteria: story=$story_id, checked=$criteria_checked/$criteria_total, row=$row"

  # Build new progress bar (no leading text, just bar + numbers)
  local criteria_bar=$(_ralph_criteria_progress "$criteria_checked" "$criteria_total")

  # Update in-place (col 16 is where the bar starts after "║  ☐ Criteria:  ")
  _ralph_update_progress_inplace "$row" "$criteria_bar" 16
}

# Update stories progress bar when index.json changes
# Usage: _ralph_update_stories_display "/path/to/prd-json"
_ralph_update_stories_display() {
  local json_dir="$1"

  [[ "$RALPH_STORIES_ROW" -le 0 ]] && return 1

  _ralph_update_stories_display_at_row "$json_dir" "$RALPH_STORIES_ROW"
}

# Update stories progress bar at explicit row position (used by background polling loop)
# Usage: _ralph_update_stories_display_at_row "/path/to/prd-json" row
_ralph_update_stories_display_at_row() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local json_dir="$1"
  local row="$2"

  [[ "$row" -le 0 ]] && return 1

  # Derive stats on-the-fly (US-106)
  local derived_stats=$(_ralph_derive_stats "$json_dir")
  local story_completed=$(echo "$derived_stats" | awk '{print $3}')
  local story_total=$(echo "$derived_stats" | awk '{print $4}')

  [[ "$story_total" -le 0 ]] && return 0

  _ralph_debug_live "update_stories: completed=$story_completed/$story_total, row=$row"

  # Build new progress bar
  local story_bar=$(_ralph_story_progress "$story_completed" "$story_total")

  # Update in-place (col 16 is where the bar starts after "║  📚 Stories:  ")
  _ralph_update_progress_inplace "$row" "$story_bar" 16
}

# Handle file change event (called from poll loop)
# Usage: _ralph_handle_file_change "/path/to/file" "US-031" "/path/to/prd-json"
_ralph_handle_file_change() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local changed_file="$1"
  local current_story="$2"
  local json_dir="$3"

  local filename=$(basename "$changed_file")

  if [[ "$filename" == "${current_story}.json" ]]; then
    # Current story file changed - update criteria bar
    _ralph_update_criteria_display "$current_story" "$json_dir"
  elif [[ "$filename" == "index.json" ]]; then
    # Index changed - update stories bar
    _ralph_update_stories_display "$json_dir"
  fi
}

# Handle file change event with explicit row positions (used by background polling loop)
# Usage: _ralph_handle_file_change_with_rows "/path/to/file" "US-031" "/path/to/prd-json" criteria_row stories_row
_ralph_handle_file_change_with_rows() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local changed_file="$1"
  local current_story="$2"
  local json_dir="$3"
  local criteria_row="$4"
  local stories_row="$5"

  local filename=$(basename "$changed_file")

  if [[ "$filename" == "${current_story}.json" ]]; then
    # Current story file changed - update criteria bar
    _ralph_update_criteria_display_at_row "$current_story" "$json_dir" "$criteria_row"
  elif [[ "$filename" == "index.json" ]]; then
    # Index changed - update stories bar
    _ralph_update_stories_display_at_row "$json_dir" "$stories_row"
  fi
}

# Store row positions when drawing the iteration header
# This must be called AFTER drawing the box, while cursor is still in position
# Usage: _ralph_store_progress_rows $criteria_row $stories_row
_ralph_store_progress_rows() {
  RALPH_CRITERIA_ROW="${1:-0}"
  RALPH_STORIES_ROW="${2:-0}"
}

# Global for polling loop PID
RALPH_POLLING_PID=""

# Start background polling loop during Claude execution
# This runs in parallel with the Claude command to handle file change events
# Usage: _ralph_start_polling_loop "US-031" "/path/to/prd-json" criteria_row stories_row
_ralph_start_polling_loop() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local current_story="$1"
  local json_dir="$2"
  local criteria_row="${3:-0}"
  local stories_row="${4:-0}"

  _ralph_debug_live "start_polling_loop: story=$current_story, criteria_row=$criteria_row, stories_row=$stories_row"

  # Don't start if live updates disabled or watcher not running
  [[ "$RALPH_LIVE_ENABLED" != "true" ]] && { _ralph_debug_live "start_polling_loop: SKIPPED - live updates disabled"; return 1; }
  [[ -z "$RALPH_WATCHER_FIFO" || ! -p "$RALPH_WATCHER_FIFO" ]] && { _ralph_debug_live "start_polling_loop: SKIPPED - no FIFO"; return 1; }

  # Don't start if row positions not set (nothing to update)
  if [[ "$criteria_row" -le 0 && "$stories_row" -le 0 ]]; then
    _ralph_debug_live "start_polling_loop: SKIPPED - no row positions set"
    return 1
  fi

  # Suppress job control messages
  setopt LOCAL_OPTIONS NO_MONITOR NO_NOTIFY noxtrace

  # Capture the FIFO path for the subshell
  local fifo_path="$RALPH_WATCHER_FIFO"

  # Start polling loop in background
  # Pass row positions as local variables so subshell has correct values
  {
    # Use local copies of row positions (subshell doesn't see parent's globals)
    local local_criteria_row="$criteria_row"
    local local_stories_row="$stories_row"

    _ralph_debug_live "polling_loop: STARTED in subshell, criteria_row=$local_criteria_row, stories_row=$local_stories_row"

    while true; do
      # Non-blocking read with short timeout
      local changed_file=""
      if read -t 0.2 changed_file < "$fifo_path" 2>/dev/null; then
        if [[ -n "$changed_file" ]]; then
          _ralph_debug_live "polling_loop: file changed: $changed_file"
          # Handle the file change with row positions
          _ralph_handle_file_change_with_rows "$changed_file" "$current_story" "$json_dir" "$local_criteria_row" "$local_stories_row"
        fi
      fi
      # Small sleep to prevent CPU spinning
      sleep 0.1
    done
  } &
  RALPH_POLLING_PID=$!
  disown $RALPH_POLLING_PID 2>/dev/null
  _ralph_track_pid "$RALPH_POLLING_PID" "polling-loop"

  _ralph_debug_live "start_polling_loop: SUCCESS, PID=$RALPH_POLLING_PID"
  return 0
}

# Stop background polling loop
_ralph_stop_polling_loop() {
  # Suppress job control messages
  setopt LOCAL_OPTIONS NO_MONITOR NO_NOTIFY

  if [[ -n "$RALPH_POLLING_PID" ]]; then
    _ralph_untrack_pid "$RALPH_POLLING_PID"
    kill "$RALPH_POLLING_PID" 2>/dev/null
    # Brief wait for cleanup
    sleep 0.1
    RALPH_POLLING_PID=""
  fi
}

# ═══════════════════════════════════════════════════════════════════
# ORPHAN PROCESS TRACKING AND CLEANUP
# ═══════════════════════════════════════════════════════════════════
# Tracks Ralph child processes in a persistent file so orphans can be
# detected and cleaned up after hard crashes (Ctrl+C during infinite loop,
# terminal reset, etc.) when the normal cleanup trap doesn't run.

# Global PID tracking file (persists across sessions)
RALPH_PID_TRACKING_FILE="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}/ralph-pids.txt"
RALPH_LOGS_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}/logs"

# Register a child process PID for tracking
# Usage: _ralph_track_pid <pid> <type>
# Example: _ralph_track_pid $RALPH_WATCHER_PID "fswatch"
_ralph_track_pid() {
  local pid="$1"
  local type="$2"
  local timestamp=$(date +%s)

  [[ -z "$pid" || "$pid" == "0" ]] && return 1

  mkdir -p "$(dirname "$RALPH_PID_TRACKING_FILE")"

  # Append PID with type and timestamp
  echo "$pid $type $timestamp $$" >> "$RALPH_PID_TRACKING_FILE"
}

# Unregister a PID (called during normal cleanup)
# Usage: _ralph_untrack_pid <pid>
_ralph_untrack_pid() {
  local pid="$1"

  [[ -z "$pid" || ! -f "$RALPH_PID_TRACKING_FILE" ]] && return 0

  # Remove line with this PID (first field)
  local tmp="${RALPH_PID_TRACKING_FILE}.tmp"
  grep -v "^$pid " "$RALPH_PID_TRACKING_FILE" > "$tmp" 2>/dev/null
  mv "$tmp" "$RALPH_PID_TRACKING_FILE" 2>/dev/null

  # Remove file if empty
  if [[ ! -s "$RALPH_PID_TRACKING_FILE" ]]; then
    rm -f "$RALPH_PID_TRACKING_FILE"
  fi
}

# Unregister all PIDs from current session (parent PID)
# Usage: _ralph_untrack_session
_ralph_untrack_session() {
  [[ ! -f "$RALPH_PID_TRACKING_FILE" ]] && return 0

  # Remove all lines belonging to current session (4th field = $$)
  local tmp="${RALPH_PID_TRACKING_FILE}.tmp"
  grep -v " $$\$" "$RALPH_PID_TRACKING_FILE" > "$tmp" 2>/dev/null
  mv "$tmp" "$RALPH_PID_TRACKING_FILE" 2>/dev/null

  # Remove file if empty
  if [[ ! -s "$RALPH_PID_TRACKING_FILE" ]]; then
    rm -f "$RALPH_PID_TRACKING_FILE"
  fi
}

# Check for orphan processes from previous Ralph runs
# Returns: 0 if orphans found, 1 if none
# Outputs: list of orphan PIDs and their types
_ralph_find_orphans() {
  [[ ! -f "$RALPH_PID_TRACKING_FILE" ]] && return 1

  local found_orphans=false
  local orphan_list=""

  while read -r pid type timestamp parent_pid; do
    [[ -z "$pid" ]] && continue

    # Check if parent process (Ralph session) is still running
    if ! kill -0 "$parent_pid" 2>/dev/null; then
      # Parent is dead - check if child is still running
      if kill -0 "$pid" 2>/dev/null; then
        found_orphans=true
        orphan_list+="$pid $type $timestamp $parent_pid\n"
      fi
    fi
  done < "$RALPH_PID_TRACKING_FILE"

  if [[ "$found_orphans" == "true" ]]; then
    echo -e "$orphan_list"
    return 0
  fi

  return 1
}

# Kill orphan processes and clean up tracking file
# Usage: _ralph_kill_orphans [--quiet]
_ralph_kill_orphans() {
  local quiet=false
  [[ "$1" == "--quiet" ]] && quiet=true

  local orphans=$(_ralph_find_orphans)

  if [[ -z "$orphans" ]]; then
    [[ "$quiet" == "false" ]] && echo "No orphan processes found."
    return 0
  fi

  local killed=0

  while read -r pid type timestamp parent_pid; do
    [[ -z "$pid" ]] && continue

    if kill -0 "$pid" 2>/dev/null; then
      if [[ "$quiet" == "false" ]]; then
        local age=$(( $(date +%s) - timestamp ))
        echo "  Killing orphan: PID $pid ($type, age: ${age}s)"
      fi
      kill "$pid" 2>/dev/null
      ((killed++))
    fi

    # Remove from tracking file
    _ralph_untrack_pid "$pid"
  done <<< "$orphans"

  [[ "$quiet" == "false" ]] && echo "Killed $killed orphan process(es)."

  return 0
}

# Check for orphans at startup and offer to kill them
# Usage: _ralph_check_orphans_at_startup
_ralph_check_orphans_at_startup() {
  local orphans=$(_ralph_find_orphans)

  if [[ -z "$orphans" ]]; then
    return 0
  fi

  local count=$(echo -e "$orphans" | grep -c '^[0-9]')

  echo ""
  echo "${RALPH_COLOR_YELLOW:-\033[1;33m}⚠️  Found $count orphan process(es) from previous Ralph run(s):${RALPH_COLOR_RESET:-\033[0m}"

  while read -r pid type timestamp parent_pid; do
    [[ -z "$pid" ]] && continue
    local age=$(( $(date +%s) - timestamp ))
    local age_str
    if (( age < 60 )); then
      age_str="${age}s"
    elif (( age < 3600 )); then
      age_str="$(( age / 60 ))m"
    else
      age_str="$(( age / 3600 ))h"
    fi
    echo "   PID $pid ($type, age: $age_str)"
  done <<< "$orphans"

  echo ""

  # Offer to kill orphans
  if [[ -t 0 ]]; then
    # Interactive terminal - ask user
    echo -n "Kill these orphan processes? [Y/n] "
    read -r response
    if [[ "$response" != "n" && "$response" != "N" ]]; then
      _ralph_kill_orphans --quiet
      echo "${RALPH_COLOR_GREEN:-\033[0;32m}✓ Orphan processes killed${RALPH_COLOR_RESET:-\033[0m}"
    fi
  else
    # Non-interactive - auto-kill orphans
    echo "Auto-killing orphans (non-interactive mode)..."
    _ralph_kill_orphans --quiet
    echo "${RALPH_COLOR_GREEN:-\033[0;32m}✓ Orphan processes killed${RALPH_COLOR_RESET:-\033[0m}"
  fi

  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# CRASH LOGGING
# ═══════════════════════════════════════════════════════════════════
# Logs crash information to ~/.config/ralphtools/logs/ for debugging
# when Ralph exits unexpectedly.

# Log crash information
# Usage: _ralph_log_crash <iteration> <story_id> <criteria> <error_message>
_ralph_log_crash() {
  local iteration="${1:-unknown}"
  local story_id="${2:-unknown}"
  local criteria="${3:-unknown}"
  local error_message="${4:-unknown}"
  local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')

  mkdir -p "$RALPH_LOGS_DIR"

  local log_file="$RALPH_LOGS_DIR/crash-$timestamp.log"

  {
    echo "# Ralph Crash Log"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Working Dir: $(pwd)"
    echo ""
    echo "## State at Crash"
    echo "Iteration: $iteration"
    echo "Story: $story_id"
    echo "Criteria: $criteria"
    echo ""
    echo "## Error"
    echo "$error_message"
    echo ""
    echo "## Recent Git"
    git log -3 --oneline 2>/dev/null || echo "(git log unavailable)"
    echo ""
    echo "## Environment"
    echo "RALPH_VERSION: $RALPH_VERSION"
    echo "Shell: $SHELL"
    echo "Terminal: ${TERM:-unknown}"
  } > "$log_file"

  echo "$log_file"
}

# Show recent crash info on startup if available
# Usage: _ralph_show_recent_crash
_ralph_show_recent_crash() {
  [[ ! -d "$RALPH_LOGS_DIR" ]] && return 1

  # Find most recent crash log (within last 24 hours)
  local recent_crash=$(find "$RALPH_LOGS_DIR" -name "crash-*.log" -mtime -1 2>/dev/null | sort -r | head -1)

  [[ -z "$recent_crash" ]] && return 1

  local crash_time=$(basename "$recent_crash" | sed 's/crash-//; s/\.log$//' | tr '_' ' ')
  local crash_story=$(grep "^Story:" "$recent_crash" 2>/dev/null | head -1 | cut -d' ' -f2)
  local crash_error=$(grep -A1 "^## Error" "$recent_crash" 2>/dev/null | tail -1)

  echo ""
  echo "${RALPH_COLOR_YELLOW:-\033[1;33m}⚠️  Recent crash detected:${RALPH_COLOR_RESET:-\033[0m}"
  echo "   Time: $crash_time"
  [[ -n "$crash_story" && "$crash_story" != "unknown" ]] && echo "   Story: $crash_story"
  [[ -n "$crash_error" && ${#crash_error} -lt 100 ]] && echo "   Error: $crash_error"
  echo "   Log: $recent_crash"
  echo "   Run ${RALPH_COLOR_CYAN:-\033[0;36m}ralph-logs${RALPH_COLOR_RESET:-\033[0m} to view full details"
  echo ""

  return 0
}

# List recent crash logs
# Usage: ralph-logs [count]
ralph-logs() {
  local count="${1:-5}"

  if [[ ! -d "$RALPH_LOGS_DIR" ]]; then
    echo "No logs directory found at $RALPH_LOGS_DIR"
    return 1
  fi

  local logs=($(find "$RALPH_LOGS_DIR" -name "crash-*.log" 2>/dev/null | sort -r | head -"$count"))

  if [[ ${#logs[@]} -eq 0 ]]; then
    echo "No crash logs found."
    return 0
  fi

  echo ""
  echo "${RALPH_COLOR_CYAN:-\033[0;36m}Recent Ralph Crash Logs:${RALPH_COLOR_RESET:-\033[0m}"
  echo ""

  for log in "${logs[@]}"; do
    local timestamp=$(basename "$log" | sed 's/crash-//; s/\.log$//' | tr '_' ' ')
    local story=$(grep "^Story:" "$log" 2>/dev/null | head -1 | cut -d' ' -f2)
    echo "  📄 $timestamp"
    [[ -n "$story" && "$story" != "unknown" ]] && echo "     Story: $story"
    echo "     Path: $log"
    echo ""
  done

  echo "To view a log: ${RALPH_COLOR_GRAY:-\033[0;90m}cat <path>${RALPH_COLOR_RESET:-\033[0m}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# ralph-session - Show current Ralph session state and data locations
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph-session [--paths]
#   --paths : Show all data file paths
#
# Data locations:
#   /tmp/ralph-status-$$.json    - Current session status (state, lastActivity, error)
#   /tmp/ralph_output_$$.txt     - Current session Claude output
#   ~/.config/ralphtools/logs/   - Crash logs (persistent)
#   ./progress.txt               - Story progress (persistent, per-repo)
#   ./prd-json/                  - Story definitions (persistent, per-repo)
# ═══════════════════════════════════════════════════════════════════
ralph-session() {
  local show_paths=false
  [[ "$1" == "--paths" ]] && show_paths=true

  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "${CYAN}═══ Ralph Status ═══${NC}"
  echo ""

  # Find running Ralph sessions
  local status_files=(/tmp/ralph-status-*.json(N))

  if [[ ${#status_files[@]} -eq 0 ]]; then
    echo "${YELLOW}No active Ralph sessions found${NC}"
  else
    for sf in "${status_files[@]}"; do
      local pid=$(basename "$sf" | sed 's/ralph-status-//; s/.json//')
      local state=$(jq -r '.state // "unknown"' "$sf" 2>/dev/null)
      local last=$(jq -r '.lastActivity // 0' "$sf" 2>/dev/null)
      local error=$(jq -r '.error // null' "$sf" 2>/dev/null)
      local now=$(date +%s)
      local age=$((now - last))

      # Check if process is alive
      if ps -p "$pid" &>/dev/null; then
        echo "${GREEN}● Session $pid: $state${NC} (active ${age}s ago)"
      else
        echo "${RED}○ Session $pid: $state${NC} (dead, ${age}s stale)"
      fi

      [[ "$error" != "null" && -n "$error" ]] && echo "  Error: $error"

      # Show last output (BUG-029: show last 5-10 lines for debugging)
      local output_file="/tmp/ralph_output_${pid}.txt"
      if [[ -f "$output_file" ]]; then
        local lines=$(wc -l < "$output_file" 2>/dev/null | tr -d ' ')
        local bytes=$(wc -c < "$output_file" 2>/dev/null | tr -d ' ')
        echo "  Output: $output_file ($lines lines, $bytes bytes)"
        if [[ "$lines" -gt 0 ]]; then
          echo ""
          echo "  ${YELLOW}Last 10 lines:${NC}"
          # Filter out ANSI escape codes and show last 10 lines, indented
          tail -10 "$output_file" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^/    /'
        fi
      fi
      echo ""
    done
  fi

  # Show progress.txt location if in a repo
  if [[ -f "./progress.txt" ]]; then
    local last_story=$(grep "^Story:" ./progress.txt 2>/dev/null | tail -1 | cut -d: -f2 | xargs)
    local last_status=$(grep "^Status:" ./progress.txt 2>/dev/null | tail -1 | cut -d: -f2 | xargs)
    echo "${CYAN}Progress file:${NC} ./progress.txt"
    echo "  Last story: $last_story - $last_status"
    echo ""
  fi

  # Show paths if requested
  if $show_paths; then
    echo "${CYAN}═══ Data Locations ═══${NC}"
    echo ""
    echo "  ${YELLOW}Session (temporary):${NC}"
    echo "    /tmp/ralph-status-\$\$.json  - State, lastActivity, error, retryIn"
    echo "    /tmp/ralph_output_\$\$.txt   - Claude output for current iteration"
    echo ""
    echo "  ${YELLOW}Persistent:${NC}"
    echo "    ~/.config/ralphtools/logs/  - Crash logs"
    echo "    ./progress.txt              - Story progress (per-repo)"
    echo "    ./prd-json/                 - Story definitions (per-repo)"
    echo "    ./prd-json/index.json       - Story order, pending, completed"
    echo ""
  fi
}

# Kill all Ralph-related orphan processes
# Usage: ralph-kill-orphans [--all]
#   --all : Also kill processes by name pattern (fswatch, bun ui) even if not tracked
ralph-kill-orphans() {
  local kill_all=false
  [[ "$1" == "--all" ]] && kill_all=true

  echo ""
  echo "${RALPH_COLOR_CYAN:-\033[0;36m}Ralph Orphan Process Cleanup${RALPH_COLOR_RESET:-\033[0m}"
  echo ""

  # First, kill tracked orphans
  local orphans=$(_ralph_find_orphans)

  if [[ -n "$orphans" ]]; then
    echo "Tracked orphan processes:"
    _ralph_kill_orphans
    echo ""
  else
    echo "No tracked orphan processes found."
  fi

  # If --all flag, also look for Ralph-related processes by name
  if [[ "$kill_all" == "true" ]]; then
    echo ""
    echo "Searching for untracked Ralph-related processes..."

    # Look for common Ralph child processes
    local untracked_count=0

    # fswatch watching prd-json or stories
    local fswatch_pids=$(pgrep -f "fswatch.*prd-json\|fswatch.*stories" 2>/dev/null)
    if [[ -n "$fswatch_pids" ]]; then
      for pid in $fswatch_pids; do
        echo "  Killing untracked fswatch: PID $pid"
        kill "$pid" 2>/dev/null
        ((untracked_count++))
      done
    fi

    # bun processes in ralph-ui directory
    local bun_pids=$(pgrep -f "bun.*ralph-ui" 2>/dev/null)
    if [[ -n "$bun_pids" ]]; then
      for pid in $bun_pids; do
        echo "  Killing untracked bun (ralph-ui): PID $pid"
        kill "$pid" 2>/dev/null
        ((untracked_count++))
      done
    fi

    if [[ $untracked_count -eq 0 ]]; then
      echo "  No untracked Ralph processes found."
    else
      echo "  Killed $untracked_count untracked process(es)."
    fi
  fi

  # Clean up stale entries from tracking file
  if [[ -f "$RALPH_PID_TRACKING_FILE" ]]; then
    local stale_count=0
    local tmp="${RALPH_PID_TRACKING_FILE}.tmp"
    > "$tmp"

    while read -r pid type timestamp parent_pid; do
      [[ -z "$pid" ]] && continue
      # Only keep entries for still-running processes
      if kill -0 "$pid" 2>/dev/null; then
        echo "$pid $type $timestamp $parent_pid" >> "$tmp"
      else
        ((stale_count++))
      fi
    done < "$RALPH_PID_TRACKING_FILE"

    mv "$tmp" "$RALPH_PID_TRACKING_FILE"

    if [[ $stale_count -gt 0 ]]; then
      echo ""
      echo "Cleaned up $stale_count stale tracking entries."
    fi

    # Remove file if empty
    if [[ ! -s "$RALPH_PID_TRACKING_FILE" ]]; then
      rm -f "$RALPH_PID_TRACKING_FILE"
    fi
  fi

  echo ""
  echo "${RALPH_COLOR_GREEN:-\033[0;32m}✓ Cleanup complete${RALPH_COLOR_RESET:-\033[0m}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# COLOR SCHEMES
# ═══════════════════════════════════════════════════════════════════

# Define color schemes as JSON-like structure
# Each scheme defines colors for: success, error, warning, info, story types (US/V/BUG/TEST/AUDIT), models, costs
declare -A COLOR_SCHEMES=(
  [default]='{"success":"32","error":"31","warning":"33","info":"36","US":"34","V":"35","BUG":"31","TEST":"33","AUDIT":"35","opus":"33","sonnet":"36","haiku":"32","cost_low":"32","cost_med":"33","cost_high":"31"}'
  [dark]='{"success":"92","error":"91","warning":"93","info":"96","US":"94","V":"95","BUG":"91","TEST":"93","AUDIT":"95","opus":"33","sonnet":"96","haiku":"92","cost_low":"92","cost_med":"93","cost_high":"91"}'
  [light]='{"success":"32","error":"31","warning":"33","info":"36","US":"34","V":"35","BUG":"31","TEST":"33","AUDIT":"35","opus":"33","sonnet":"36","haiku":"32","cost_low":"32","cost_med":"33","cost_high":"31"}'
  [minimal]='{"success":"32","error":"31","warning":"0","info":"0","US":"0","V":"0","BUG":"0","TEST":"0","AUDIT":"0","opus":"0","sonnet":"0","haiku":"0","cost_low":"32","cost_med":"0","cost_high":"31"}'
  [none]='{"success":"0","error":"0","warning":"0","info":"0","US":"0","V":"0","BUG":"0","TEST":"0","AUDIT":"0","opus":"0","sonnet":"0","haiku":"0","cost_low":"0","cost_med":"0","cost_high":"0"}'
)

# Initialize colors from a scheme
# Usage: _ralph_init_colors "default"
_ralph_init_colors() {
  local scheme="${1:-default}"
  local scheme_json="${COLOR_SCHEMES[$scheme]:-${COLOR_SCHEMES[default]}}"

  # Check NO_COLOR environment variable
  if [[ -n "$NO_COLOR" ]]; then
    scheme_json="${COLOR_SCHEMES[none]}"
  fi

  # Parse JSON-like structure and set color variables
  # Build full ANSI sequences from color codes: \033[{code}m
  local code

  code=$(jq -r '.success' <<< "$scheme_json" 2>/dev/null || echo "32")
  RALPH_COLOR_SUCCESS=$'\033['"${code}m"
  code=$(jq -r '.error' <<< "$scheme_json" 2>/dev/null || echo "31")
  RALPH_COLOR_ERROR=$'\033['"${code}m"
  code=$(jq -r '.warning' <<< "$scheme_json" 2>/dev/null || echo "33")
  RALPH_COLOR_WARNING=$'\033['"${code}m"
  code=$(jq -r '.info' <<< "$scheme_json" 2>/dev/null || echo "36")
  RALPH_COLOR_INFO=$'\033['"${code}m"

  # Update story type colors
  code=$(jq -r '.US' <<< "$scheme_json" 2>/dev/null || echo "34")
  RALPH_COLOR_BLUE=$'\033['"${code}m"
  code=$(jq -r '.V' <<< "$scheme_json" 2>/dev/null || echo "35")
  RALPH_COLOR_PURPLE=$'\033['"${code}m"
  code=$(jq -r '.BUG' <<< "$scheme_json" 2>/dev/null || echo "31")
  RALPH_COLOR_RED=$'\033['"${code}m"
  code=$(jq -r '.TEST' <<< "$scheme_json" 2>/dev/null || echo "33")
  RALPH_COLOR_YELLOW=$'\033['"${code}m"
  code=$(jq -r '.AUDIT' <<< "$scheme_json" 2>/dev/null || echo "35")
  RALPH_COLOR_MAGENTA=$'\033['"${code}m"

  # Update model colors
  code=$(jq -r '.opus' <<< "$scheme_json" 2>/dev/null || echo "33")
  RALPH_COLOR_GOLD=$'\033['"${code}m"
  code=$(jq -r '.sonnet' <<< "$scheme_json" 2>/dev/null || echo "36")
  RALPH_COLOR_CYAN=$'\033['"${code}m"
  code=$(jq -r '.haiku' <<< "$scheme_json" 2>/dev/null || echo "32")
  RALPH_COLOR_GREEN=$'\033['"${code}m"

  # Store cost thresholds for dynamic coloring
  code=$(jq -r '.cost_low' <<< "$scheme_json" 2>/dev/null || echo "32")
  RALPH_COST_COLOR_LOW=$'\033['"${code}m"
  code=$(jq -r '.cost_med' <<< "$scheme_json" 2>/dev/null || echo "33")
  RALPH_COST_COLOR_MED=$'\033['"${code}m"
  code=$(jq -r '.cost_high' <<< "$scheme_json" 2>/dev/null || echo "31")
  RALPH_COST_COLOR_HIGH=$'\033['"${code}m"
}

# ═══════════════════════════════════════════════════════════════════
# ELAPSED TIME & STATUS HELPERS
# ═══════════════════════════════════════════════════════════════════

# Format elapsed time from seconds to human-readable (e.g., "12m 34s")
# Usage: _ralph_format_elapsed 754 → "12m 34s"
_ralph_format_elapsed() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local seconds="$1"
  local hours=$((seconds / 3600))
  local mins=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  if [[ $hours -gt 0 ]]; then
    printf "%dh %dm %ds" $hours $mins $secs
  elif [[ $mins -gt 0 ]]; then
    printf "%dm %ds" $mins $secs
  else
    printf "%ds" $secs
  fi
}

# ═══════════════════════════════════════════════════════════════════
# REACT INK UI INTEGRATION
# ═══════════════════════════════════════════════════════════════════

# Usage: _ralph_show_ink_ui $mode $prd_path $iteration $model $start_time $ntfy_topic
# Modes: startup, iteration, live
_ralph_show_ink_ui() {
  local mode="$1"
  local prd_path="$2"
  local iteration="${3:-1}"
  local model="${4:-sonnet}"
  local start_time="${5:-$(date +%s)}"
  local ntfy_topic="${6:-}"

  # Check if bun is available
  if ! command -v bun &>/dev/null; then
    echo -e "${RALPH_COLOR_YELLOW}[WARN] bun not found, falling back to shell UI${RALPH_COLOR_RESET}"
    return 1
  fi

  # Check if UI file exists
  if [[ ! -f "$RALPH_UI_PATH" ]]; then
    echo -e "${RALPH_COLOR_YELLOW}[WARN] React Ink UI not found at $RALPH_UI_PATH, falling back to shell UI${RALPH_COLOR_RESET}"
    return 1
  fi

  # Convert start_time to milliseconds for JavaScript
  local start_time_ms=$((start_time * 1000))

  # Build command with optional ntfy topic
  local cmd=(bun "$RALPH_UI_PATH" --mode="$mode" --prd-path="$prd_path" --iteration="$iteration" --model="$model" --start-time="$start_time_ms")
  [[ -n "$ntfy_topic" ]] && cmd+=(--ntfy-topic="$ntfy_topic")

  # Run the React Ink UI
  "${cmd[@]}"

  return $?
}

# ═══════════════════════════════════════════════════════════════════

# Show compact between-iterations status (4-5 lines max)
# Usage: _ralph_show_iteration_status $json_dir $start_time $i $MAX $current_story $model $compact
_ralph_show_iteration_status() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local json_dir="$1"
  local start_time="$2"
  local iteration="$3"
  local max_iter="$4"
  local story="$5"
  local model="$6"
  local compact="$7"
  local pause_enabled="$8"
  local verbose_enabled="$9"
  local has_gum="${10}"

  # Calculate elapsed time
  local now=$(date +%s)
  local elapsed=$((now - start_time))
  local elapsed_str=$(_ralph_format_elapsed $elapsed)

  # Derive stats on-the-fly (US-106)
  local derived_stats=$(_ralph_derive_stats "$json_dir")
  local pending=$(echo "$derived_stats" | awk '{print $1}')
  local completed=$(echo "$derived_stats" | awk '{print $3}')
  local total=$(echo "$derived_stats" | awk '{print $4}')
  local percent=0
  [[ "$total" -gt 0 ]] && percent=$((completed * 100 / total))
  # Cap percentage at 100% (defensive guard)
  (( percent > 100 )) && percent=100

  # Get cumulative cost
  local cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")

  # Build progress bar (10 chars)
  local bar_filled=$((percent * 10 / 100))
  local bar_empty=$((10 - bar_filled))
  local progress_bar=""
  for ((j=0; j<bar_filled; j++)); do progress_bar+="█"; done
  for ((j=0; j<bar_empty; j++)); do progress_bar+="░"; done

  # Color the story and model
  local colored_story=$(_ralph_color_story_id "$story")
  local colored_model=$(_ralph_color_model "$model")
  local colored_cost=$(_ralph_color_cost "$cost")

  if [[ "$compact" == "true" ]]; then
    # Compact: 2 lines
    echo ""
    echo -e "── ${progress_bar} ${completed}/${total} (${percent}%) │ ⏱ ${elapsed_str} │ 💰 ${colored_cost} ──"
  else
    # Normal: 4-5 lines with full info
    # Box is 65 chars wide, inner content area is 61 chars (between │  and │)
    local BOX_INNER_WIDTH=61
    echo ""
    echo "┌───────────────────────────────────────────────────────────────┐"
    local progress_str="${progress_bar} ${completed}/${total} (${percent}%)"
    local progress_width=$(_ralph_display_width "$progress_str")
    local progress_padding=$((BOX_INNER_WIDTH - progress_width))
    echo -e "│  ${progress_str}$(printf '%*s' $progress_padding '')│"
    local story_model_str="📖 ${colored_story} │ 🧠 ${colored_model} │ 🔄 ${iteration}/${max_iter}"
    local story_model_width=$(_ralph_display_width "$story_model_str")
    local story_model_padding=$((BOX_INNER_WIDTH - story_model_width))
    echo -e "│  ${story_model_str}$(printf '%*s' $story_model_padding '')│"
    local elapsed_cost_str="⏱ ${elapsed_str} │ 💰 ${colored_cost}"
    local elapsed_cost_width=$(_ralph_display_width "$elapsed_cost_str")
    local elapsed_cost_padding=$((BOX_INNER_WIDTH - elapsed_cost_width))
    echo -e "│  ${elapsed_cost_str}$(printf '%*s' $elapsed_cost_padding '')│"

    # Show keybind hints if gum available
    if [[ "$has_gum" -eq 0 ]]; then
      local hints="[v]erbose "
      [[ "$verbose_enabled" == "true" ]] && hints+="✓ " || hints+="  "
      hints+="[p]ause "
      [[ "$pause_enabled" == "true" ]] && hints+="✓ " || hints+="  "
      hints+="[s]kip [q]uit"
      local hints_width=$(_ralph_display_width "$hints")
      local hints_padding=$((BOX_INNER_WIDTH - hints_width))
      echo -e "│  ${RALPH_COLOR_GRAY}${hints}${RALPH_COLOR_RESET}$(printf '%*s' $hints_padding '')│"
    fi
    echo "└───────────────────────────────────────────────────────────────┘"
  fi
}

# Check for keyboard input (non-blocking) and handle controls
# Usage: _ralph_check_keyboard pause_var verbose_var skip_var quit_var
# Returns: sets variables by name reference
_ralph_check_keyboard() {
  local -n pause_ref="$1"
  local -n verbose_ref="$2"
  local -n skip_ref="$3"
  local -n quit_ref="$4"

  # Only works with gum installed
  [[ $RALPH_HAS_GUM -ne 0 ]] && return

  # Non-blocking read with timeout
  local key=""
  if read -t 0.1 -k 1 key 2>/dev/null; then
    case "$key" in
      v|V)
        if [[ "$verbose_ref" == "true" ]]; then
          verbose_ref="false"
          echo -e "\n${RALPH_COLOR_GRAY}[verbose mode OFF]${RALPH_COLOR_RESET}"
        else
          verbose_ref="true"
          echo -e "\n${RALPH_COLOR_GREEN}[verbose mode ON]${RALPH_COLOR_RESET}"
        fi
        ;;
      p|P)
        if [[ "$pause_ref" == "true" ]]; then
          pause_ref="false"
          echo -e "\n${RALPH_COLOR_GRAY}[pause after iteration OFF]${RALPH_COLOR_RESET}"
        else
          pause_ref="true"
          echo -e "\n${RALPH_COLOR_YELLOW}[will pause after this iteration]${RALPH_COLOR_RESET}"
        fi
        ;;
      s|S)
        skip_ref="true"
        echo -e "\n${RALPH_COLOR_YELLOW}[skipping current story...]${RALPH_COLOR_RESET}"
        ;;
      q|Q)
        quit_ref="true"
        echo -e "\n${RALPH_COLOR_YELLOW}[will quit after current iteration completes]${RALPH_COLOR_RESET}"
        ;;
    esac
  fi
}

# Wait for user to press a key when paused
# Usage: _ralph_wait_for_resume
_ralph_wait_for_resume() {
  echo ""
  echo -e "${RALPH_COLOR_YELLOW}⏸️  PAUSED - Press any key to continue, or [q] to quit...${RALPH_COLOR_RESET}"
  local key=""
  read -k 1 key
  if [[ "$key" == "q" || "$key" == "Q" ]]; then
    return 1  # Signal to quit
  fi
  echo ""
  return 0
}

# ═══════════════════════════════════════════════════════════════════
# INTERACTIVE CONFIGURATION
# ═══════════════════════════════════════════════════════════════════

# Interactive config setup using gum (or fallback prompts)
# Usage: ralph-config
ralph-config() {
  local config_file="$RALPH_CONFIG_DIR/config.json"

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🛠️  Ralph Configuration Setup                              │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Ensure config directory exists
  mkdir -p "$RALPH_CONFIG_DIR"

  local runtime="bun"
  local max_iterations="100"
  local model_strategy=""
  local default_model=""
  local notifications_enabled=""
  local ntfy_topic=""
  local max_retries="5"
  local no_msg_max_retries="3"
  local general_cooldown="15"
  local no_msg_cooldown="30"

  # Check if gum is available
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # ═══════════════════════════════════════════════════════════
    # GUM-BASED INTERACTIVE PROMPTS
    # ═══════════════════════════════════════════════════════════

    echo "🏃 Runtime Preference"
    echo "   bun  = Modern React Ink UI (recommended, requires bun)"
    echo "   bash = Traditional zsh-based UI (fallback)"
    echo ""
    runtime=$(gum choose "bun (Recommended)" "bash")
    # Extract just the runtime name (remove "(Recommended)" suffix)
    runtime="${runtime%% *}"
    echo "   Selected: $runtime"
    echo ""

    echo "🔢 Max Iterations"
    echo "   How many iterations before Ralph pauses? (default: 100)"
    echo ""
    local max_iter_input=$(gum input --placeholder "100")
    [[ -z "$max_iter_input" ]] && max_iter_input="100"
    max_iterations="$max_iter_input"
    echo "   Selected: $max_iterations"
    echo ""

    echo "📊 Model Strategy"
    echo "   smart  = Different models for different task types"
    echo "   single = One model for everything"
    echo ""
    model_strategy=$(gum choose "smart" "single")
    echo "   Selected: $model_strategy"
    echo ""

    echo "🤖 Default Model"
    echo "   opus   = Most capable, slowest, most expensive"
    echo "   sonnet = Balanced capability and cost"
    echo "   haiku  = Fastest, cheapest, good for simple tasks"
    echo ""
    default_model=$(gum choose "opus" "sonnet" "haiku")
    echo "   Selected: $default_model"
    echo ""

    echo "🔔 Notifications"
    if gum confirm "Enable ntfy notifications?"; then
      notifications_enabled="true"
      echo ""
      local topic_mode=$(gum choose "Per-project topics (recommended)" "Fixed topic")
      if [[ "$topic_mode" == "Per-project topics (recommended)" ]]; then
        ntfy_topic=""  # Empty = per-project mode
        echo "   📬 Topic: Per-project (etans-ralph-{project})"
      else
        echo "📬 Enter your fixed ntfy topic name:"
        ntfy_topic=$(gum input --placeholder "ralph-notifications")
        [[ -z "$ntfy_topic" ]] && ntfy_topic="ralph-notifications"
        echo "   📬 Topic: $ntfy_topic (fixed)"
      fi
    else
      notifications_enabled="false"
      ntfy_topic=""
    fi

    echo ""
    echo "⚙️  Error Handling"
    echo "   Configure retry behavior for API errors"
    echo ""
    if gum confirm "Customize error handling? (defaults recommended)"; then
      echo ""
      echo "   Max retries for general errors (default: 5):"
      local max_retries_input=$(gum input --placeholder "5")
      [[ -z "$max_retries_input" ]] && max_retries_input="5"
      max_retries="$max_retries_input"
      echo "   Selected: $max_retries"
      echo ""
      echo "   Max retries for 'No messages returned' error (default: 3):"
      local no_msg_retries_input=$(gum input --placeholder "3")
      [[ -z "$no_msg_retries_input" ]] && no_msg_retries_input="3"
      no_msg_max_retries="$no_msg_retries_input"
      echo "   Selected: $no_msg_max_retries"
      echo ""
      echo "   General cooldown (seconds) (default: 15):"
      local general_cd_input=$(gum input --placeholder "15")
      [[ -z "$general_cd_input" ]] && general_cd_input="15"
      general_cooldown="$general_cd_input"
      echo "   Selected: $general_cooldown"
      echo ""
      echo "   'No messages' cooldown (seconds) (default: 30):"
      local no_msg_cd_input=$(gum input --placeholder "30")
      [[ -z "$no_msg_cd_input" ]] && no_msg_cd_input="30"
      no_msg_cooldown="$no_msg_cd_input"
      echo "   Selected: $no_msg_cooldown"
    else
      max_retries="5"
      no_msg_max_retries="3"
      general_cooldown="15"
      no_msg_cooldown="30"
      echo "   Using defaults: maxRetries=5, noMessagesMaxRetries=3, cooldowns=15s/30s"
    fi

  else
    # ═══════════════════════════════════════════════════════════
    # FALLBACK: Simple read prompts
    # ═══════════════════════════════════════════════════════════
    echo "ℹ️  (Install gum for a better experience: brew install gum)"
    echo ""

    echo "🏃 Runtime Preference"
    echo "   1) bun  = Modern React Ink UI (recommended, requires bun)"
    echo "   2) bash = Traditional zsh-based UI (fallback)"
    echo -n "   Choose [1/2]: "
    read runtime_choice
    case "$runtime_choice" in
      2|bash) runtime="bash" ;;
      *)      runtime="bun" ;;
    esac
    echo "   Selected: $runtime"
    echo ""

    echo "🔢 Max Iterations"
    echo -n "   How many iterations before Ralph pauses? [100]: "
    read max_iter_input
    [[ -z "$max_iter_input" ]] && max_iter_input="100"
    max_iterations="$max_iter_input"
    echo "   Selected: $max_iterations"
    echo ""

    echo "📊 Model Strategy"
    echo "   1) smart  = Different models for different task types"
    echo "   2) single = One model for everything"
    echo -n "   Choose [1/2]: "
    read strategy_choice
    case "$strategy_choice" in
      1|smart)  model_strategy="smart" ;;
      *)        model_strategy="single" ;;
    esac
    echo "   Selected: $model_strategy"
    echo ""

    echo "🤖 Default Model"
    echo "   1) opus   = Most capable, slowest, most expensive"
    echo "   2) sonnet = Balanced capability and cost"
    echo "   3) haiku  = Fastest, cheapest, good for simple tasks"
    echo -n "   Choose [1/2/3]: "
    read model_choice
    case "$model_choice" in
      1|opus)   default_model="opus" ;;
      3|haiku)  default_model="haiku" ;;
      *)        default_model="sonnet" ;;
    esac
    echo "   Selected: $default_model"
    echo ""

    echo "🔔 Notifications"
    echo -n "   Enable ntfy notifications? [y/N]: "
    read notify_choice
    case "$notify_choice" in
      [Yy]*)
        notifications_enabled="true"
        echo "   Topic mode:"
        echo "   1) Per-project (recommended) - etans-ralph-{project}"
        echo "   2) Fixed topic"
        echo -n "   Choose [1/2]: "
        read topic_mode_choice
        case "$topic_mode_choice" in
          2)
            echo -n "   Enter ntfy topic [ralph-notifications]: "
            read ntfy_topic
            [[ -z "$ntfy_topic" ]] && ntfy_topic="ralph-notifications"
            echo "   📬 Topic: $ntfy_topic (fixed)"
            ;;
          *)
            ntfy_topic=""  # Empty = per-project mode
            echo "   📬 Topic: Per-project (etans-ralph-{project})"
            ;;
        esac
        ;;
      *)
        notifications_enabled="false"
        ntfy_topic=""
        ;;
    esac

    echo ""
    echo "⚙️  Error Handling"
    echo -n "   Customize error handling? [y/N]: "
    read error_handling_choice
    case "$error_handling_choice" in
      [Yy]*)
        echo -n "   Max retries for general errors [5]: "
        read max_retries_input
        [[ -n "$max_retries_input" ]] && max_retries="$max_retries_input"
        echo "   Selected: $max_retries"
        echo -n "   Max retries for 'No messages returned' [3]: "
        read no_msg_input
        [[ -n "$no_msg_input" ]] && no_msg_max_retries="$no_msg_input"
        echo "   Selected: $no_msg_max_retries"
        echo -n "   General cooldown (seconds) [15]: "
        read general_cd_input
        [[ -n "$general_cd_input" ]] && general_cooldown="$general_cd_input"
        echo "   Selected: $general_cooldown"
        echo -n "   'No messages' cooldown (seconds) [30]: "
        read no_msg_cd_input
        [[ -n "$no_msg_cd_input" ]] && no_msg_cooldown="$no_msg_cd_input"
        echo "   Selected: $no_msg_cooldown"
        ;;
      *)
        echo "   Using defaults: maxRetries=5, noMessagesMaxRetries=3, cooldowns=15s/30s"
        ;;
    esac
  fi

  echo ""

  # ═══════════════════════════════════════════════════════════
  # Save config to JSON
  # ═══════════════════════════════════════════════════════════

  # Build smart model mappings based on default model
  local us_model="$default_model"
  local v_model="haiku"
  local test_model="haiku"
  local bug_model="$default_model"
  local audit_model="opus"

  # If smart mode, use sensible defaults
  if [[ "$model_strategy" == "smart" ]]; then
    us_model="sonnet"
    bug_model="sonnet"
  fi

  cat > "$config_file" << EOF
{
  "runtime": "$runtime",
  "modelStrategy": "$model_strategy",
  "defaultModel": "$default_model",
  "unknownTaskType": "$default_model",
  "models": {
    "US": "$us_model",
    "V": "$v_model",
    "TEST": "$test_model",
    "BUG": "$bug_model",
    "AUDIT": "$audit_model"
  },
  "notifications": {
    "enabled": $notifications_enabled,
    "ntfyTopic": "$ntfy_topic"
  },
  "defaults": {
    "maxIterations": $max_iterations,
    "sleepSeconds": $RALPH_SLEEP_SECONDS
  },
  "errorHandling": {
    "maxRetries": $max_retries,
    "noMessagesMaxRetries": $no_msg_max_retries,
    "generalCooldownSeconds": $general_cooldown,
    "noMessagesCooldownSeconds": $no_msg_cooldown
  }
}
EOF

  echo "✅ Configuration saved to $config_file"
  echo ""

  # Reload config
  _ralph_load_config

  echo "📋 Current settings:"
  _ralph_show_routing
  if [[ "$notifications_enabled" == "true" ]]; then
    echo "🔔 Notifications: enabled → $ntfy_topic"
  else
    echo "🔔 Notifications: disabled"
  fi
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# FIRST-RUN DETECTION
# ═══════════════════════════════════════════════════════════════════

# Check if config.json exists and prompt for setup if missing
# Usage: _ralph_first_run_check [--skip-setup|-y]
# Returns: 0 if config exists or was created, 1 if user cancelled
_ralph_first_run_check() {
  local skip_setup=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-setup|-y)
        skip_setup=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  # If config exists, nothing to do
  if [[ -f "$RALPH_CONFIG_FILE" ]]; then
    return 0
  fi

  # Config missing - first run detected
  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  👋 Welcome to Ralph!                                       │"
  echo "│                                                             │"
  echo "│  No configuration found. Let's set things up.               │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  if [[ "$skip_setup" == "true" ]]; then
    # Create minimal config with defaults
    echo "⏩ Using default configuration (--skip-setup)"
    echo ""
    mkdir -p "$RALPH_CONFIG_DIR"
    cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bun",
  "modelStrategy": "smart",
  "defaultModel": "sonnet",
  "unknownTaskType": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },
  "notifications": {
    "enabled": false,
    "ntfyTopic": ""
  },
  "defaults": {
    "maxIterations": 100,
    "sleepSeconds": 2
  },
  "errorHandling": {
    "maxRetries": 5,
    "noMessagesMaxRetries": 3,
    "generalCooldownSeconds": 15,
    "noMessagesCooldownSeconds": 30
  }
}
EOF
    echo "✅ Default configuration saved to $RALPH_CONFIG_FILE"
    echo ""
    # Reload config
    _ralph_load_config
    return 0
  fi

  # Interactive setup prompt
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # GUM mode - use confirm
    if gum confirm "Run interactive setup?"; then
      ralph-config
      return 0
    else
      echo ""
      echo "You can run 'ralph-config' later to configure Ralph."
      echo "Creating minimal config with defaults..."
      echo ""
      mkdir -p "$RALPH_CONFIG_DIR"
      cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bun",
  "modelStrategy": "smart",
  "defaultModel": "sonnet",
  "unknownTaskType": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },
  "notifications": {
    "enabled": false,
    "ntfyTopic": ""
  },
  "defaults": {
    "maxIterations": 100,
    "sleepSeconds": 2
  },
  "errorHandling": {
    "maxRetries": 5,
    "noMessagesMaxRetries": 3,
    "generalCooldownSeconds": 15,
    "noMessagesCooldownSeconds": 30
  }
}
EOF
      echo "✅ Default configuration saved to $RALPH_CONFIG_FILE"
      echo ""
      _ralph_load_config
      return 0
    fi
  else
    # Fallback mode - use read
    echo "Options:"
    echo "  1) Run interactive setup (recommended)"
    echo "  2) Use defaults (skip setup)"
    echo ""
    echo -n "Choose [1/2]: "
    read setup_choice
    case "$setup_choice" in
      1)
        ralph-config
        return 0
        ;;
      *)
        echo ""
        echo "Creating minimal config with defaults..."
        echo ""
        mkdir -p "$RALPH_CONFIG_DIR"
        cat > "$RALPH_CONFIG_FILE" << 'EOF'
{
  "runtime": "bun",
  "modelStrategy": "smart",
  "defaultModel": "sonnet",
  "unknownTaskType": "sonnet",
  "models": {
    "US": "sonnet",
    "V": "haiku",
    "TEST": "haiku",
    "BUG": "sonnet",
    "AUDIT": "opus"
  },
  "notifications": {
    "enabled": false,
    "ntfyTopic": ""
  },
  "defaults": {
    "maxIterations": 100,
    "sleepSeconds": 2
  },
  "errorHandling": {
    "maxRetries": 5,
    "noMessagesMaxRetries": 3,
    "generalCooldownSeconds": 15,
    "noMessagesCooldownSeconds": 30
  }
}
EOF
        echo "✅ Default configuration saved to $RALPH_CONFIG_FILE"
        echo ""
        _ralph_load_config
        return 0
        ;;
    esac
  fi
}

# ═══════════════════════════════════════════════════════════════════
# SMART MODEL ROUTING
# ═══════════════════════════════════════════════════════════════════

# Load config from config.json
_ralph_load_config() {
  if [[ -f "$RALPH_CONFIG_FILE" ]]; then
    # Export config values as environment variables for easy access
    # Runtime: bash or bun (default: bun)
    RALPH_RUNTIME=$(jq -r '.runtime // "bun"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    RALPH_MODEL_STRATEGY=$(jq -r '.modelStrategy // "single"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_DEFAULT_MODEL_CFG=$(jq -r '.defaultModel // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_UNKNOWN_TASK_MODEL=$(jq -r '.unknownTaskType // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load model mappings for smart routing
    RALPH_MODEL_US=$(jq -r '.models.US // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_V=$(jq -r '.models.V // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_TEST=$(jq -r '.models.TEST // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_BUG=$(jq -r '.models.BUG // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_AUDIT=$(jq -r '.models.AUDIT // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_MP=$(jq -r '.models.MP // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load notification settings
    local notify_enabled=$(jq -r '.notifications.enabled // false' "$RALPH_CONFIG_FILE" 2>/dev/null)
    if [[ "$notify_enabled" == "true" ]]; then
      local config_topic=$(jq -r '.notifications.ntfyTopic // ""' "$RALPH_CONFIG_FILE" 2>/dev/null)
      # Empty string or "auto" means use per-project topics (don't set RALPH_NTFY_TOPIC)
      # Any other value is an explicit override
      if [[ -n "$config_topic" && "$config_topic" != "auto" && "$config_topic" != "null" ]]; then
        RALPH_NTFY_TOPIC="$config_topic"
      fi
    fi

    # Load defaults
    local max_iter=$(jq -r '.defaults.maxIterations // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    local sleep_sec=$(jq -r '.defaults.sleepSeconds // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    [[ -n "$max_iter" && "$max_iter" != "null" ]] && RALPH_MAX_ITERATIONS="$max_iter"
    [[ -n "$sleep_sec" && "$sleep_sec" != "null" ]] && RALPH_SLEEP_SECONDS="$sleep_sec"

    # Load parallel verification settings
    RALPH_PARALLEL_VERIFICATION=$(jq -r '.parallelVerification // false' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_PARALLEL_AGENTS=$(jq -r '.parallelAgents // 2' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load error handling settings (with defaults for backwards compatibility)
    RALPH_MAX_RETRIES=$(jq -r '.errorHandling.maxRetries // 5' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_NO_MSG_MAX_RETRIES=$(jq -r '.errorHandling.noMessagesMaxRetries // 3' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_GENERAL_COOLDOWN=$(jq -r '.errorHandling.generalCooldownSeconds // 15' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_NO_MSG_COOLDOWN=$(jq -r '.errorHandling.noMessagesCooldownSeconds // 30' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load color scheme setting
    RALPH_COLOR_SCHEME=$(jq -r '.colorScheme // "default"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Check if custom scheme is provided
    local custom_scheme=$(jq -r '.customColorScheme // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    if [[ -n "$custom_scheme" && "$custom_scheme" != "null" ]]; then
      COLOR_SCHEMES[custom]="$custom_scheme"
      RALPH_COLOR_SCHEME="custom"
    fi

    # Load context loading settings
    local contexts_dir=$(jq -r '.contexts.directory // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    [[ -n "$contexts_dir" && "$contexts_dir" != "null" ]] && RALPH_CONTEXTS_DIR="$contexts_dir"

    # Load additional contexts to append (space-separated list)
    local additional_contexts=$(jq -r '.contexts.additional // [] | join(" ")' "$RALPH_CONFIG_FILE" 2>/dev/null)
    [[ -n "$additional_contexts" && "$additional_contexts" != "null" ]] && RALPH_ADDITIONAL_CONTEXTS="$additional_contexts"

    return 0
  fi
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# REGISTRY - Centralized Project/MCP Configuration
# ═══════════════════════════════════════════════════════════════════

RALPH_REGISTRY_FILE="${RALPH_CONFIG_DIR}/registry.json"

# Load CodeRabbit configuration from registry
_ralph_load_coderabbit_config

# Migrate existing configs to registry.json
# Sources: projects.json, shared-project-mcps.json, repo-claude-v2.zsh
# Usage: _ralph_migrate_to_registry [--force]
_ralph_migrate_to_registry() {
  setopt localoptions noxtrace  # Suppress debug output

  local force=false
  [[ "$1" == "--force" ]] && force=true

  local old_projects="$HOME/.config/ralphtools/projects.json"
  local shared_mcps="$HOME/.claude/shared-project-mcps.json"
  local repo_claude_v2="$HOME/.config/ralphtools/repo-claude-v2.zsh"
  local registry="$RALPH_REGISTRY_FILE"

  # Check if registry already exists
  if [[ -f "$registry" ]] && ! $force; then
    echo "Registry already exists at $registry"
    echo "Use --force to recreate from source configs"
    return 0
  fi

  # Initialize result variables
  local projects_json="{}"
  local global_mcps="{}"
  local mcp_definitions="{}"
  local has_sources=false

  echo "Migrating to registry.json..."

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 1: repo-claude-v2.zsh (REPO_CONFIGS_V2, SUPABASE_TOKENS, LINEAR_TOKENS)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$repo_claude_v2" ]]; then
    has_sources=true
    echo "  📦 Found repo-claude-v2.zsh"

    # Source the file to get associative arrays
    # Create a subshell to avoid polluting current environment
    local v2_data
    v2_data=$(zsh -c "
      source '$repo_claude_v2' 2>/dev/null

      # Output MCP_UNIVERSAL as JSON
      echo '===MCP_UNIVERSAL==='
      for key val in \"\${(@kv)MCP_UNIVERSAL}\"; do
        # val can be JSON or command string
        if [[ \"\$val\" == '{'* ]]; then
          printf '%s\t%s\n' \"\$key\" \"\$val\"
        else
          # Convert command string to JSON (e.g., '--transport http figma ...')
          printf '%s\t{\"transport\": \"command\", \"value\": \"%s\"}\n' \"\$key\" \"\$val\"
        fi
      done

      # Output REPO_CONFIGS_V2 as JSON
      echo '===REPO_CONFIGS_V2==='
      for key val in \"\${(@kv)REPO_CONFIGS_V2}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done

      # Output SUPABASE_TOKENS
      echo '===SUPABASE_TOKENS==='
      for key val in \"\${(@kv)SUPABASE_TOKENS}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done

      # Output LINEAR_TOKENS
      echo '===LINEAR_TOKENS==='
      for key val in \"\${(@kv)LINEAR_TOKENS}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done
    " 2>/dev/null)

    # Parse MCP_UNIVERSAL into mcpDefinitions
    local in_section=""
    local mcp_u_count=0
    local proj_count=0
    local sb_tokens=""
    local linear_tokens=""
    local repo_configs=""

    while IFS= read -r line; do
      case "$line" in
        "===MCP_UNIVERSAL===") in_section="mcp_universal" ;;
        "===REPO_CONFIGS_V2===") in_section="repo_configs" ;;
        "===SUPABASE_TOKENS===") in_section="supabase" ;;
        "===LINEAR_TOKENS===") in_section="linear" ;;
        *)
          [[ -z "$line" ]] && continue
          case "$in_section" in
            mcp_universal)
              local key="${line%%	*}"
              local val="${line#*	}"
              if [[ "$val" == '{'* ]]; then
                mcp_definitions=$(echo "$mcp_definitions" | jq --arg k "$key" --argjson v "$val" '.[$k] = $v')
                ((mcp_u_count++))
              fi
              ;;
            repo_configs)
              repo_configs+="$line"$'\n'
              ;;
            supabase)
              sb_tokens+="$line"$'\n'
              ;;
            linear)
              linear_tokens+="$line"$'\n'
              ;;
          esac
          ;;
      esac
    done <<< "$v2_data"

    echo "    ✓ Imported $mcp_u_count MCP definitions from MCP_UNIVERSAL"

    # Parse REPO_CONFIGS_V2 into projects
    # Format: "key|name|path|mcps_light|mcps_full"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local key="${line%%	*}"
      local config="${line#*	}"

      # Parse pipe-delimited config
      local proj_key=$(echo "$config" | cut -d'|' -f1)
      local proj_name=$(echo "$config" | cut -d'|' -f2)
      local proj_path=$(echo "$config" | cut -d'|' -f3)
      local mcps_light=$(echo "$config" | cut -d'|' -f4)
      local mcps_full=$(echo "$config" | cut -d'|' -f5)

      # Expand $HOME in path
      proj_path="${proj_path/\$HOME/$HOME}"

      # Convert comma-separated MCPs to JSON array
      local mcps_array="[]"
      if [[ -n "$mcps_full" ]]; then
        mcps_array=$(echo "$mcps_full" | tr ',' '\n' | jq -R . | jq -s .)
      fi

      # Build project entry
      local proj_entry=$(jq -n \
        --arg path "$proj_path" \
        --arg name "$proj_name" \
        --argjson mcps "$mcps_array" \
        --arg light "$mcps_light" \
        '{
          path: $path,
          displayName: $name,
          mcps: $mcps,
          mcpsLight: ($light | split(",") | map(select(. != ""))),
          secrets: {},
          created: (now | todate)
        }' 2>/dev/null)

      projects_json=$(echo "$projects_json" | jq --arg k "$proj_key" --argjson v "$proj_entry" '.[$k] = $v')
      ((proj_count++))
    done <<< "$repo_configs"

    echo "    ✓ Imported $proj_count projects from REPO_CONFIGS_V2"

    # Add SUPABASE_TOKENS to project secrets
    local sb_count=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local proj="${line%%	*}"
      local token="${line#*	}"

      # Add to project's secrets if project exists
      if echo "$projects_json" | jq -e --arg p "$proj" '.[$p]' >/dev/null 2>&1; then
        projects_json=$(echo "$projects_json" | jq --arg p "$proj" --arg t "$token" \
          '.[$p].secrets.SUPABASE_ACCESS_TOKEN = $t')
        ((sb_count++))
      fi
    done <<< "$sb_tokens"

    [[ $sb_count -gt 0 ]] && echo "    ✓ Added $sb_count Supabase tokens to project secrets"

    # Add LINEAR_TOKENS to project secrets
    local linear_count=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local proj="${line%%	*}"
      local token="${line#*	}"

      # Add to project's secrets if project exists
      if echo "$projects_json" | jq -e --arg p "$proj" '.[$p]' >/dev/null 2>&1; then
        projects_json=$(echo "$projects_json" | jq --arg p "$proj" --arg t "$token" \
          '.[$p].secrets.LINEAR_API_TOKEN = $t')
        ((linear_count++))
      fi
    done <<< "$linear_tokens"

    [[ $linear_count -gt 0 ]] && echo "    ✓ Added $linear_count Linear tokens to project secrets"
  fi

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 2: projects.json (legacy format)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$old_projects" ]]; then
    has_sources=true
    echo "  📦 Found projects.json"

    # Convert projects array to object format, merge with existing
    local legacy_projects
    legacy_projects=$(jq -r '
      .projects // [] | map({(.name): {path: .path, mcps: (.mcps // []), secrets: {}, created: .created}}) | add // {}
    ' "$old_projects" 2>/dev/null)

    if [[ -n "$legacy_projects" && "$legacy_projects" != "null" ]]; then
      # Merge with priority to existing (from repo-claude-v2.zsh)
      projects_json=$(echo "$projects_json" "$legacy_projects" | jq -s '.[1] * .[0]')
      echo "    ✓ Merged projects from projects.json"
    fi
  fi

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 3: shared-project-mcps.json (global MCPs)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$shared_mcps" ]]; then
    has_sources=true
    echo "  📦 Found shared-project-mcps.json"

    local shared_mcp_servers
    shared_mcp_servers=$(jq '.mcpServers // {}' "$shared_mcps" 2>/dev/null)

    if [[ -n "$shared_mcp_servers" && "$shared_mcp_servers" != "null" ]]; then
      global_mcps="$shared_mcp_servers"
      local mcp_count=$(echo "$global_mcps" | jq 'keys | length')
      echo "    ✓ Imported $mcp_count global MCPs"
    fi
  fi

  # ═══════════════════════════════════════════════════════════════
  # CREATE REGISTRY
  # ═══════════════════════════════════════════════════════════════
  if ! $has_sources; then
    echo "  ⚠️  No source configs found. Creating minimal registry."
  fi

  mkdir -p "$RALPH_CONFIG_DIR"
  jq -n \
    --arg version "1.0.0" \
    --argjson global_mcps "$global_mcps" \
    --argjson projects "$projects_json" \
    --argjson mcp_defs "$mcp_definitions" \
    '{
      version: $version,
      global: {
        mcps: $global_mcps
      },
      projects: $projects,
      mcpDefinitions: $mcp_defs
    }' > "$registry"

  local total_projects=$(echo "$projects_json" | jq 'keys | length')
  local total_mcps=$(echo "$mcp_definitions" | jq 'keys | length')

  echo ""
  echo "  ✅ Registry created at $registry"
  echo "     Projects: $total_projects | MCP Definitions: $total_mcps"
  return 0
}

# Load registry into memory (cached)
# Usage: _ralph_load_registry
_ralph_load_registry() {
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "Registry not found. Run '_ralph_migrate_to_registry' to initialize." >&2
    return 1
  fi
  cat "$RALPH_REGISTRY_FILE"
}

# Get project config by path (auto-detects current project)
# Usage: _ralph_get_project_config [path]
_ralph_get_project_config() {
  local search_path="${1:-$(pwd)}"
  search_path="${search_path:A}"  # Resolve to absolute

  local registry=$(_ralph_load_registry) || return 1

  # Find project matching this path
  echo "$registry" | jq -r --arg path "$search_path" '
    .projects | to_entries[] |
    select(($path | startswith(.value.path | gsub("~"; env.HOME) | gsub("^~"; env.HOME)))) |
    {name: .key, config: .value}
  ' | head -1
}

# Get project name from current directory
# Usage: _ralph_current_project
_ralph_current_project() {
  local config=$(_ralph_get_project_config)
  [[ -n "$config" ]] && echo "$config" | jq -r '.name'
}

# Build MCP config for a project (merges global + project MCPs)
# Usage: _ralph_build_mcp_config [project_name]
_ralph_build_mcp_config() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Get global MCPs
  local global_mcps=$(echo "$registry" | jq '.global.mcps // {}')

  # Get project-specific MCPs
  local project_mcps=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].mcps // [] | .[]
  ')

  # Get MCP definitions and build final config
  local mcp_defs=$(echo "$registry" | jq '.mcpDefinitions // {}')
  local project_secrets=$(echo "$registry" | jq --arg proj "$project_name" '
    .projects[$proj].secrets // {}
  ')

  # Merge: global + (project MCPs resolved from definitions)
  local result="$global_mcps"

  for mcp in ${(f)project_mcps}; do
    local mcp_def=$(echo "$mcp_defs" | jq --arg m "$mcp" '.[$m] // empty')

    # Handle special MCPs that require project-specific tokens
    if [[ -z "$mcp_def" ]]; then
      case "$mcp" in
        linear)
          # Build linear MCP config using project's LINEAR_API_TOKEN
          local linear_token=$(echo "$project_secrets" | jq -r '.LINEAR_API_TOKEN // empty')
          if [[ -n "$linear_token" && "$linear_token" != "null" ]]; then
            mcp_def=$(jq -n --arg token "$linear_token" '{
              "command": "npx",
              "args": ["-y", "@tacticlaunch/mcp-linear"],
              "env": {"LINEAR_API_TOKEN": $token}
            }')
          fi
          ;;
        supabase)
          # Build supabase MCP config using project's SUPABASE_ACCESS_TOKEN
          local supabase_token=$(echo "$project_secrets" | jq -r '.SUPABASE_ACCESS_TOKEN // empty')
          if [[ -n "$supabase_token" && "$supabase_token" != "null" ]]; then
            mcp_def=$(jq -n --arg token "$supabase_token" '{
              "command": "npx",
              "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", $token]
            }')
          fi
          ;;
      esac
    fi

    if [[ -n "$mcp_def" ]]; then
      result=$(echo "$result" | jq --arg m "$mcp" --argjson def "$mcp_def" '.[$m] = $def')
    fi
  done

  echo "{\"mcpServers\": $result}"
}

# Inject secrets from 1Password into environment
# Usage: _ralph_inject_secrets [project_name]
_ralph_inject_secrets() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Check if op CLI is available
  if ! command -v op &> /dev/null; then
    return 0  # No 1Password, skip silently
  fi

  # Get project secrets (op:// references)
  local secrets=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Resolve each secret via op
  local resolved=()
  for secret in ${(f)secrets}; do
    local key="${secret%%=*}"
    local op_ref="${secret#*=}"

    if [[ "$op_ref" == op://* ]]; then
      local value=$(op read "$op_ref" 2>/dev/null)
      if [[ -n "$value" ]]; then
        resolved+=("$key=$value")
      fi
    else
      resolved+=("$key=$op_ref")  # Plain value, not op://
    fi
  done

  # Export resolved secrets
  for kv in "${resolved[@]}"; do
    export "${kv%%=*}=${kv#*=}"
  done
}

# Generate .env.1password file with op:// references for 1Password Environments
# Usage: _ralph_generate_env_1password [project_name] [output_path]
# This is used with 'op run --env-file' for secure secret injection
_ralph_generate_env_1password() {
  local project_name="${1:-$(_ralph_current_project)}"
  local output_path="${2:-/tmp/ralph-${project_name}.env.1password}"
  local registry=$(_ralph_load_registry) || return 1

  # Get project secrets (op:// references)
  local secrets=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Also get global MCP secrets if any
  local global_secrets=$(echo "$registry" | jq -r '
    .global.mcps // {} | to_entries[] |
    .value.secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Write .env.1password file
  # Format: KEY=op://vault/item/field (already in registry)
  {
    echo "# Generated by Ralph for 1Password Environments"
    echo "# Use with: op run --env-file $output_path -- command"
    echo "# Project: $project_name"
    echo ""

    # Write project secrets
    if [[ -n "$secrets" ]]; then
      echo "# Project Secrets"
      echo "$secrets"
      echo ""
    fi

    # Write global secrets
    if [[ -n "$global_secrets" ]]; then
      echo "# Global MCP Secrets"
      echo "$global_secrets"
    fi
  } > "$output_path"

  echo "$output_path"
}

# Run parallel verification for V-* stories
# Spawns multiple agents with different viewport/focus prompts
# Usage: _ralph_run_parallel_verification "V-001" "/path/to/prd-json" "prompt_text"
_ralph_run_parallel_verification() {
  local story_id="$1"
  local prd_json_dir="$2"
  local base_prompt="$3"
  local num_agents="${RALPH_PARALLEL_AGENTS:-2}"

  # Temp directory for parallel agent results
  local temp_dir="/tmp/ralph_parallel_${story_id}_$$"
  mkdir -p "$temp_dir"

  local pids=()
  local agent_prompts=()

  # Define agent-specific prompts based on focus area
  # Agent 1: Desktop viewport (1920x1080)
  agent_prompts[1]="VIEWPORT FOCUS: Desktop (1920x1080). Verify all acceptance criteria at desktop resolution. Check layout, spacing, and interactions at full width.\n\n$base_prompt"

  # Agent 2: Mobile viewport (375x812)
  agent_prompts[2]="VIEWPORT FOCUS: Mobile (375x812 iPhone X). Verify all acceptance criteria at mobile resolution. Check responsive behavior, touch targets, and mobile-specific issues.\n\n$base_prompt"

  # Agent 3: Accessibility focus (if parallelAgents >= 3)
  agent_prompts[3]="ACCESSIBILITY FOCUS: Verify keyboard navigation, screen reader compatibility, color contrast, and ARIA labels. Check all acceptance criteria with accessibility in mind.\n\n$base_prompt"

  echo "  🔀 Running parallel verification with $num_agents agents..."

  # Spawn agents in parallel
  for ((agent=1; agent<=num_agents && agent<=3; agent++)); do
    local agent_prompt="${agent_prompts[$agent]}"
    local agent_output="$temp_dir/agent_${agent}.txt"

    (
      claude --chrome --dangerously-skip-permissions --model haiku \
        -p "$agent_prompt" > "$agent_output" 2>&1
    ) &
    pids+=($!)
    echo "    📍 Agent $agent spawned (PID: ${pids[-1]})"
  done

  # Wait for all agents to complete
  echo "  ⏳ Waiting for all agents to complete..."
  local failed_pids=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed_pids++))
    fi
  done

  # Aggregate results using dedicated function
  _ralph_aggregate_parallel_results "$temp_dir" "$num_agents" "$story_id" "$prd_json_dir"
  local result=$?

  # Cleanup temp directory
  rm -rf "$temp_dir"

  return $result
}

# Aggregate results from parallel verification agents
# Reads temp files, collects pass/fail status and failure reasons, logs to progress.txt
# Usage: _ralph_aggregate_parallel_results "/tmp/dir" num_agents "V-001" "/path/to/prd-json"
_ralph_aggregate_parallel_results() {
  local temp_dir="$1"
  local num_agents="$2"
  local story_id="$3"
  local prd_json_dir="$4"
  local progress_file="$prd_json_dir/../progress.txt"

  echo "  📊 Aggregating parallel agent results..."

  local all_pass=true
  local agent_results=()
  local failure_reasons=()

  # Read results from each agent's temp file
  for ((agent=1; agent<=num_agents && agent<=3; agent++)); do
    local agent_output="$temp_dir/agent_${agent}.txt"

    if [[ -f "$agent_output" ]]; then
      if grep -q "<promise>COMPLETE</promise>" "$agent_output" 2>/dev/null; then
        echo "    ✅ Agent $agent: PASSED"
        agent_results+=("Agent $agent: PASSED")
      else
        echo "    ❌ Agent $agent: FAILED"
        agent_results+=("Agent $agent: FAILED")
        all_pass=false

        # Extract failure reason (look for BLOCKED or error messages)
        local reason=""
        if grep -q "BLOCKED" "$agent_output" 2>/dev/null; then
          reason=$(grep -o "BLOCKED:.*" "$agent_output" | head -1)
        elif grep -q "Error:" "$agent_output" 2>/dev/null; then
          reason=$(grep -o "Error:.*" "$agent_output" | head -1)
        else
          reason="No completion promise found"
        fi
        failure_reasons+=("Agent $agent: $reason")
      fi
    else
      echo "    ⚠️ Agent $agent: No output file"
      agent_results+=("Agent $agent: NO OUTPUT")
      all_pass=false
      failure_reasons+=("Agent $agent: Output file missing")
    fi
  done

  # Log which agents passed/failed to progress.txt
  if [[ -f "$progress_file" ]]; then
    echo "" >> "$progress_file"
    echo "### Parallel Verification Results for $story_id" >> "$progress_file"
    echo "- Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "$progress_file"
    echo "- Agents: $num_agents" >> "$progress_file"
    for result in "${agent_results[@]}"; do
      echo "  - $result" >> "$progress_file"
    done
    if [[ ${#failure_reasons[@]} -gt 0 ]]; then
      echo "- Failure Reasons:" >> "$progress_file"
      for reason in "${failure_reasons[@]}"; do
        echo "  - $reason" >> "$progress_file"
      done
    fi
  fi

  if $all_pass; then
    echo "  ✅ All parallel verification agents passed"
    return 0
  else
    echo "  ❌ Some parallel verification agents failed"
    # Display collected failure reasons
    if [[ ${#failure_reasons[@]} -gt 0 ]]; then
      echo "  Failure reasons:"
      for reason in "${failure_reasons[@]}"; do
        echo "    - $reason"
      done
    fi
    return 1
  fi
}

# Get model for a story based on smart routing
# Usage: _ralph_get_model_for_story "US-001" [cli_primary] [cli_verify] [prd_json_dir]
# Returns: model name (haiku, sonnet, opus, gemini, kiro)
_ralph_get_model_for_story() {
  local story_id="$1"
  local cli_primary="$2"   # CLI override for primary model
  local cli_verify="$3"    # CLI override for verify model
  local prd_json_dir="$4"  # Optional: prd-json dir for story-level override

  # Extract prefix (everything before the dash and number)
  local prefix="${story_id%%-*}"

  # Story JSON "model" field wins first (for sensitive stories like 1Password)
  if [[ -n "$prd_json_dir" && -f "$prd_json_dir/stories/${story_id}.json" ]]; then
    local story_model=$(jq -r '.model // empty' "$prd_json_dir/stories/${story_id}.json" 2>/dev/null)
    if [[ -n "$story_model" ]]; then
      echo "$story_model"
      return
    fi
  fi

  # CLI flags win if specified
  if [[ -n "$cli_primary" || -n "$cli_verify" ]]; then
    case "$prefix" in
      V)
        echo "${cli_verify:-${cli_primary:-haiku}}"
        ;;
      *)
        echo "${cli_primary:-opus}"
        ;;
    esac
    return
  fi

  # No CLI override - use config-based routing
  if [[ "$RALPH_MODEL_STRATEGY" == "smart" ]]; then
    case "$prefix" in
      US)
        echo "${RALPH_MODEL_US:-sonnet}"
        ;;
      V)
        echo "${RALPH_MODEL_V:-haiku}"
        ;;
      TEST)
        echo "${RALPH_MODEL_TEST:-haiku}"
        ;;
      BUG)
        echo "${RALPH_MODEL_BUG:-sonnet}"
        ;;
      AUDIT)
        echo "${RALPH_MODEL_AUDIT:-opus}"
        ;;
      MP)
        echo "${RALPH_MODEL_MP:-opus}"
        ;;
      *)
        # Unknown prefix - use fallback
        echo "${RALPH_UNKNOWN_TASK_MODEL:-sonnet}"
        ;;
    esac
  else
    # Single model strategy - use default for everything
    echo "${RALPH_DEFAULT_MODEL_CFG:-opus}"
  fi
}

# Show current routing config
_ralph_show_routing() {
  local strategy="${RALPH_MODEL_STRATEGY:-single}"

  if [[ "$strategy" == "smart" ]]; then
    echo "🧠 Smart Model Routing:"
    echo -e "   $(_ralph_color_story_id "US")   → $(_ralph_color_model "${RALPH_MODEL_US:-sonnet}")"
    echo -e "   $(_ralph_color_story_id "V")    → $(_ralph_color_model "${RALPH_MODEL_V:-haiku}")"
    echo -e "   $(_ralph_color_story_id "TEST") → $(_ralph_color_model "${RALPH_MODEL_TEST:-haiku}")"
    echo -e "   $(_ralph_color_story_id "BUG")  → $(_ralph_color_model "${RALPH_MODEL_BUG:-sonnet}")"
    echo -e "   $(_ralph_color_story_id "AUDIT")→ $(_ralph_color_model "${RALPH_MODEL_AUDIT:-opus}")"
    echo -e "   $(_ralph_color_story_id "MP")   → $(_ralph_color_model "${RALPH_MODEL_MP:-opus}")"
    echo -e "   ???  → $(_ralph_color_model "${RALPH_UNKNOWN_TASK_MODEL:-sonnet}")"
  else
    echo -e "🧠 Single Model: $(_ralph_color_model "${RALPH_DEFAULT_MODEL_CFG:-opus}")"
  fi
}

# Load config on source
_ralph_load_config

# Initialize color scheme
_ralph_init_colors "${RALPH_COLOR_SCHEME:-default}"

# ═══════════════════════════════════════════════════════════════════
# COST TRACKING
# ═══════════════════════════════════════════════════════════════════

RALPH_COSTS_FILE="${RALPH_CONFIG_DIR}/costs.json"

# Initialize costs.json if it doesn't exist
_ralph_init_costs() {
  if [[ ! -f "$RALPH_COSTS_FILE" ]]; then
    cat > "$RALPH_COSTS_FILE" << 'EOF'
{
  "runs": [],
  "totals": {
    "stories": 0,
    "estimatedCost": 0,
    "byModel": {}
  },
  "avgTokensObserved": {
    "US": { "input": 0, "output": 0, "samples": 0 },
    "V": { "input": 0, "output": 0, "samples": 0 },
    "TEST": { "input": 0, "output": 0, "samples": 0 },
    "BUG": { "input": 0, "output": 0, "samples": 0 },
    "AUDIT": { "input": 0, "output": 0, "samples": 0 }
  }
}
EOF
  fi
}

# Get token usage from Claude's JSONL for a specific session
# Usage: _ralph_get_session_tokens "session-uuid"
# Returns: "input_tokens output_tokens cache_create cache_read" (space-separated)
_ralph_get_session_tokens() {
  local session_id="$1"
  local project_path="${2:-$(pwd)}"

  # Convert project path to Claude's project directory format
  # e.g., /Users/foo/project -> -Users-foo-project
  local claude_project=$(echo "$project_path" | tr '/' '-')
  local jsonl_dir="$HOME/.claude/projects/$claude_project"

  if [[ ! -d "$jsonl_dir" ]]; then
    echo "0 0 0 0"
    return
  fi

  # Stream through JSONL files, filter by session, sum tokens
  cat "$jsonl_dir"/*.jsonl 2>/dev/null | \
    grep "$session_id" | grep '"usage"' | \
    jq -r '.message.usage | "\(.input_tokens // 0) \(.output_tokens // 0) \(.cache_creation_input_tokens // 0) \(.cache_read_input_tokens // 0)"' 2>/dev/null | \
    awk '{input+=$1; output+=$2; cache_create+=$3; cache_read+=$4} END {print input, output, cache_create, cache_read}'
}

# Log a story completion with cost data
# Usage: _ralph_log_cost "US-001" "sonnet" "180" "success" [session_id]
_ralph_log_cost() {
  local story_id="$1"
  local model="$2"
  local duration_seconds="$3"
  local run_status="$4"  # success, blocked, error
  local session_id="$5"  # Optional: Claude session UUID for real token tracking

  # Skip cost logging for Kiro - it uses credits, not trackable tokens
  if [[ "$model" == "kiro" ]]; then
    echo "  💰 Cost: (Kiro uses credits - see kiro.dev dashboard)"
    return
  fi

  _ralph_init_costs

  local prefix="${story_id%%-*}"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Get pricing from config (or use defaults) - per million tokens
  local input_price=3   # Default sonnet input price per M tokens
  local output_price=15 # Default sonnet output price per M tokens
  local cache_create_price=3.75  # Cache creation price (Sonnet)
  local cache_read_price=0.30    # Cache read price (Sonnet)

  case "$model" in
    haiku)   input_price=1;   output_price=5; cache_create_price=1.25; cache_read_price=0.10 ;;
    sonnet)  input_price=3;   output_price=15; cache_create_price=3.75; cache_read_price=0.30 ;;
    opus)    input_price=15;  output_price=75; cache_create_price=18.75; cache_read_price=1.50 ;;
    gemini*) input_price=0.075; output_price=0.30; cache_create_price=0; cache_read_price=0 ;;
    kiro)    input_price=0;   output_price=0; cache_create_price=0; cache_read_price=0 ;;  # Credit-based
  esac

  local input_tokens=0 output_tokens=0 cache_create=0 cache_read=0
  local token_source="estimated"

  # Try to get real tokens from session if session_id provided
  if [[ -n "$session_id" ]]; then
    local token_data=$(_ralph_get_session_tokens "$session_id")
    input_tokens=$(echo "$token_data" | awk '{print $1}')
    output_tokens=$(echo "$token_data" | awk '{print $2}')
    cache_create=$(echo "$token_data" | awk '{print $3}')
    cache_read=$(echo "$token_data" | awk '{print $4}')

    if [[ "$input_tokens" -gt 0 ]] || [[ "$output_tokens" -gt 0 ]]; then
      token_source="actual"
    fi
  fi

  # Fall back to duration-based estimates if no real data
  if [[ "$token_source" == "estimated" ]]; then
    input_tokens=$((duration_seconds * 1000))   # ~1K input tokens/sec
    output_tokens=$((duration_seconds * 500))   # ~500 output tokens/sec
  fi

  # Calculate cost (tokens / 1M * price)
  local cost=$(echo "scale=4; \
    ($input_tokens * $input_price / 1000000) + \
    ($output_tokens * $output_price / 1000000) + \
    ($cache_create * $cache_create_price / 1000000) + \
    ($cache_read * $cache_read_price / 1000000)" | bc 2>/dev/null || echo "0")

  # Update costs.json
  local tmp_file=$(mktemp)
  jq --arg id "$story_id" \
     --arg model "$model" \
     --arg prefix "$prefix" \
     --arg ts "$timestamp" \
     --arg status "$run_status" \
     --arg src "$token_source" \
     --arg sid "${session_id:-}" \
     --argjson duration "$duration_seconds" \
     --argjson input "$input_tokens" \
     --argjson output "$output_tokens" \
     --argjson cache_c "$cache_create" \
     --argjson cache_r "$cache_read" \
     --argjson cost "${cost:-0}" \
     '.runs += [{
       "storyId": $id,
       "model": $model,
       "prefix": $prefix,
       "timestamp": $ts,
       "status": $status,
       "durationSeconds": $duration,
       "tokens": { "input": $input, "output": $output, "cacheCreate": $cache_c, "cacheRead": $cache_r },
       "tokenSource": $src,
       "sessionId": (if $sid == "" then null else $sid end),
       "cost": ($cost | tonumber)
     }] |
     .totals.stories += 1 |
     .totals.cost += ($cost | tonumber) |
     .totals.byModel[$model] = ((.totals.byModel[$model] // 0) + 1) |
     # Update rolling averages only for actual token data
     if $src == "actual" then
       .avgTokensObserved[$prefix] = (
         (.avgTokensObserved[$prefix] // {"input": 0, "output": 0, "samples": 0}) |
         {
           "input": (((.input * .samples) + $input) / (.samples + 1)),
           "output": (((.output * .samples) + $output) / (.samples + 1)),
           "samples": (.samples + 1)
         }
       )
     else . end' \
     "$RALPH_COSTS_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$RALPH_COSTS_FILE"

  # Print iteration cost summary
  if [[ "$token_source" == "actual" ]]; then
    echo "  💰 Cost: \$$(printf '%.4f' $cost) (${input_tokens}↓ ${output_tokens}↑ ${cache_read}📖)"
  fi
}

# Show cost summary
ralph-costs() {
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BOLD='\033[1m'
  local GRAY='\033[0;90m'
  local NC='\033[0m'

  _ralph_init_costs

  echo ""
  echo "${CYAN}${BOLD}💰 Ralph Cost Tracking${NC}"
  echo ""

  if [[ ! -f "$RALPH_COSTS_FILE" ]]; then
    echo "${YELLOW}No cost data yet. Run some stories first.${NC}"
    return
  fi

  local total_stories=$(jq -r '.totals.stories // 0' "$RALPH_COSTS_FILE")
  local total_cost=$(jq -r '.totals.cost // .totals.estimatedCost // 0' "$RALPH_COSTS_FILE")
  local actual_count=$(jq -r '[.runs[] | select(.tokenSource == "actual")] | length' "$RALPH_COSTS_FILE" 2>/dev/null || echo "0")

  echo "${BOLD}Total Stories:${NC} $total_stories"
  local formatted_cost=$(printf '%.2f' $total_cost)
  echo -e "${BOLD}Total Cost:${NC} $(_ralph_color_cost "$formatted_cost")"
  echo "${GRAY}($actual_count with actual token data, rest estimated)${NC}"
  echo ""

  echo "${CYAN}By Model:${NC}"
  jq -r '.totals.byModel | to_entries[] | "   \(.key): \(.value) stories"' "$RALPH_COSTS_FILE" 2>/dev/null

  echo ""
  echo "${CYAN}Recent Runs (last 10):${NC}"
  jq -r '.runs | .[-10:] | reverse | .[] |
    "   \(.timestamp | split("T")[0]) \(.storyId) [\(.model)] $\(.cost // .estimatedCost | . * 100 | floor / 100) \(if .tokenSource == "actual" then "✓" else "~" end)"' \
    "$RALPH_COSTS_FILE" 2>/dev/null

  echo ""
  echo "${GRAY}✓ = actual tokens, ~ = estimated${NC}"
  echo "${GRAY}Data: $RALPH_COSTS_FILE${NC}"
  echo "${GRAY}Reset: rm $RALPH_COSTS_FILE${NC}"
}

# ═══════════════════════════════════════════════════════════════════
# NTFY NOTIFICATIONS
# ═══════════════════════════════════════════════════════════════════

# Truncate text at word boundary with ellipsis
# Usage: _ralph_truncate_word_boundary "text" max_length
# Returns truncated text with ... if longer than max_length
_ralph_truncate_word_boundary() {
  setopt localoptions noxtrace
  local text="$1"
  local max_len="${2:-40}"

  # If text fits, return as-is
  [[ ${#text} -le $max_len ]] && echo "$text" && return

  # Find last space within max_len (leaving room for ...)
  local truncate_at=$((max_len - 3))
  local last_space=$(echo "${text:0:$truncate_at}" | grep -o ' [^ ]*$' | head -1)

  if [[ -n "$last_space" ]]; then
    # Truncate at last word boundary
    local space_pos=$((truncate_at - ${#last_space} + 1))
    echo "${text:0:$space_pos}..."
  else
    # No space found, hard truncate at max_len - 3
    echo "${text:0:$truncate_at}..."
  fi
}

# Send compact ntfy notification with emoji labels
# Usage: _ralph_ntfy "topic" "event_type" "story_id" "model" "iteration" "remaining_stats" "cost"
# remaining_stats should be "stories criteria" space-separated (from _ralph_json_remaining_stats)
# Body format (3 lines):
#   Line 1: repo name (e.g. 'ralphtools')
#   Line 2: 🔄iteration story_id model (e.g. '🔄5 TEST-004 haiku')
#   Line 3: 📚stories ☐criteria 💵cost (e.g. '📚26 ☐129 💵$0.28')
_ralph_ntfy() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local topic="$1"
  local event="$2"  # complete, blocked, error, iteration, max_iterations
  local story_id="${3:-}"
  local model="${4:-}"
  local iteration="${5:-}"
  local remaining="${6:-}"
  local cost="${7:-}"

  [[ -z "$topic" ]] && return 0

  local project_name=$(basename "$(pwd)")
  local title=""
  local priority="default"
  local tags=""

  case "$event" in
    complete)
      title="[Ralph] ✅ Complete"
      tags="white_check_mark,robot"
      priority="high"
      ;;
    blocked)
      title="[Ralph] ⏹️ Blocked"
      tags="stop_button,warning"
      priority="urgent"
      ;;
    error)
      title="[Ralph] ❌ Error"
      tags="x,fire"
      priority="urgent"
      ;;
    iteration)
      title="[Ralph] 🔄 Progress"
      tags="arrows_counterclockwise"
      priority="low"
      ;;
    max_iterations)
      title="[Ralph] ⚠️ Limit Hit"
      tags="warning,hourglass"
      priority="high"
      ;;
    *)
      title="[Ralph] 🤖"
      tags="robot"
      ;;
  esac

  # Build compact 3-line body with emoji labels
  # Line 1: repo name (truncate long names at word boundary, max 40 chars)
  local body=$(_ralph_truncate_word_boundary "$project_name" 40)

  # Line 2: 🔄 iteration + story + model (truncate story_id if very long)
  local line2=""
  [[ -n "$iteration" ]] && line2="🔄$iteration"
  if [[ -n "$story_id" ]]; then
    # Truncate story_id at word boundary if > 25 chars
    local truncated_story=$(_ralph_truncate_word_boundary "$story_id" 25)
    line2+=" $truncated_story"
  fi
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

  # Send with ntfy headers for rich notification
  # Use Markdown format for better rendering in web/desktop apps
  curl -s \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Markdown: true" \
    -d "$(echo -e "$body")" \
    "ntfy.sh/${topic}" > /dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════
# CONTEXT LOADING HELPERS
# ═══════════════════════════════════════════════════════════════════

# Context directory for modular context files
RALPH_CONTEXTS_DIR="${RALPH_CONTEXTS_DIR:-$HOME/.claude/contexts}"

# Script directory (for finding ralph-ui and other assets)
# Use ${0:A:h} to resolve symlinks (capital A = absolute path resolving symlinks)
# Always compute fresh - don't preserve stale values from previous sources
RALPH_SCRIPT_DIR="${0:A:h}"

# React Ink UI path for dashboard display (relative to script dir)
RALPH_UI_PATH="${RALPH_SCRIPT_DIR}/ralph-ui/src/index.tsx"

# Detect project technology stack for loading appropriate tech contexts
# Returns: space-separated list of tech contexts (e.g., "nextjs supabase")
_ralph_detect_tech_stack() {
  local tech_stack=""
  local project_dir="${1:-$(pwd)}"

  # Check for Next.js
  if [[ -f "$project_dir/next.config.js" ]] || [[ -f "$project_dir/next.config.mjs" ]] || [[ -f "$project_dir/next.config.ts" ]]; then
    tech_stack="$tech_stack nextjs"
  fi

  # Check for Convex
  if [[ -f "$project_dir/convex.json" ]] || [[ -d "$project_dir/convex" ]]; then
    tech_stack="$tech_stack convex"
  fi

  # Check for Supabase
  if [[ -d "$project_dir/supabase" ]] || grep -q "supabase" "$project_dir/package.json" 2>/dev/null; then
    tech_stack="$tech_stack supabase"
  fi

  # Check for React Native / Expo
  if [[ -f "$project_dir/app.json" ]] && grep -q "expo" "$project_dir/app.json" 2>/dev/null; then
    tech_stack="$tech_stack react-native"
  elif grep -q "react-native" "$project_dir/package.json" 2>/dev/null; then
    tech_stack="$tech_stack react-native"
  fi

  # Trim leading space
  echo "${tech_stack## }"
}

# Build a merged context file from modular context files
# Usage: _ralph_build_context_file [output_file]
# Returns: path to generated context file
_ralph_build_context_file() {
  setopt localoptions noxtrace  # Prevent context content leaking to terminal (BUG-025)
  local output_file="${1:-/tmp/ralph-context-$$.md}"
  local contexts_dir="$RALPH_CONTEXTS_DIR"

  # Kill any stale processes holding the file from previous crashed runs
  if [[ -f "$output_file" ]]; then
    local stale_pids=$(lsof -t "$output_file" 2>/dev/null)
    if [[ -n "$stale_pids" ]]; then
      kill $stale_pids 2>/dev/null
      sleep 0.1  # Brief wait for process cleanup
    fi
    rm -f "$output_file"
  fi

  # Build context in memory first, then write once (avoids orphaned cat processes)
  local context_content=""

  # Always load base.md first (core Ralph rules)
  if [[ -f "$contexts_dir/base.md" ]]; then
    context_content+="$(<"$contexts_dir/base.md")"
    context_content+=$'\n---\n'
  fi

  # Load workflow/ralph.md (Ralph-specific instructions)
  if [[ -f "$contexts_dir/workflow/ralph.md" ]]; then
    context_content+="$(<"$contexts_dir/workflow/ralph.md")"
    context_content+=$'\n---\n'
  fi

  # Detect and load tech-specific contexts
  local tech_stack=$(_ralph_detect_tech_stack)
  for tech in $tech_stack; do
    if [[ -f "$contexts_dir/tech/${tech}.md" ]]; then
      context_content+="$(<"$contexts_dir/tech/${tech}.md")"
      context_content+=$'\n---\n'
    fi
  done

  # Load additional contexts from config if specified
  if [[ -n "$RALPH_ADDITIONAL_CONTEXTS" ]]; then
    for ctx in $RALPH_ADDITIONAL_CONTEXTS; do
      local ctx_file="$contexts_dir/$ctx"
      if [[ -f "$ctx_file" ]]; then
        context_content+="$(<"$ctx_file")"
        context_content+=$'\n---\n'
      fi
    done
  fi

  # Write all content at once (single operation, no subprocess)
  print -r -- "$context_content" > "$output_file"

  echo "$output_file"
}

# Clean up generated context files
# Usage: _ralph_cleanup_context_file [context_file]
_ralph_cleanup_context_file() {
  local context_file="$1"
  if [[ -n "$context_file" ]]; then
    # Kill any stale processes holding the file (from interrupted runs)
    if [[ -f "$context_file" ]]; then
      local stale_pids=$(lsof -t "$context_file" 2>/dev/null)
      if [[ -n "$stale_pids" ]]; then
        kill $stale_pids 2>/dev/null
      fi
      rm -f "$context_file"
    fi
  fi
}

# Build context for interactive (non-Ralph) Claude sessions
# Used by generated launcher functions ({name}Claude)
# Returns context string (not file path) for --append-system-prompt
# Usage: local ctx=$(_ralph_interactive_context)
_ralph_interactive_context() {
  local contexts_dir="${RALPH_CONTEXTS_DIR:-$HOME/.claude/contexts}"
  local context=""

  # 1. Base context (always)
  if [[ -f "$contexts_dir/base.md" ]]; then
    context+="$(<"$contexts_dir/base.md")"
    context+=$'\n---\n'
  fi

  # 2. Interactive workflow (NOT ralph workflow)
  if [[ -f "$contexts_dir/workflow/interactive.md" ]]; then
    context+="$(<"$contexts_dir/workflow/interactive.md")"
    context+=$'\n---\n'
  fi

  # 3. Auto-detect tech stack and load relevant contexts
  local detected_tech
  detected_tech=$(_ralph_detect_tech_stack 2>/dev/null)
  for tech in ${=detected_tech}; do
    if [[ -f "$contexts_dir/tech/${tech}.md" ]]; then
      context+="$(<"$contexts_dir/tech/${tech}.md")"
      context+=$'\n---\n'
    fi
  done

  # Return context string (caller uses with --append-system-prompt)
  print -r -- "$context"
}

# ═══════════════════════════════════════════════════════════════════
# JSON MODE HELPERS
# ═══════════════════════════════════════════════════════════════════

# Get next incomplete story from prd-json/
_ralph_json_next_story() {
  local json_dir="$1"
  local index_file="$json_dir/index.json"

  if [[ ! -f "$index_file" ]]; then
    echo ""
    return 1
  fi

  # Get pending stories from index.json
  local next_id=$(jq -r '.pending[0] // empty' "$index_file" 2>/dev/null)

  if [[ -z "$next_id" ]]; then
    echo ""
    return 1
  fi

  echo "$next_id"
}

# Get story details from JSON file
_ralph_json_get_story() {
  local json_dir="$1"
  local story_id="$2"
  local story_file="$json_dir/stories/${story_id}.json"

  if [[ ! -f "$story_file" ]]; then
    echo ""
    return 1
  fi

  cat "$story_file"
}

# Mark story criteria as checked in JSON
_ralph_json_check_criterion() {
  local json_dir="$1"
  local story_id="$2"
  local criterion_index="$3"
  local story_file="$json_dir/stories/${story_id}.json"

  if [[ ! -f "$story_file" ]]; then
    return 1
  fi

  # Update the specific criterion
  local tmp_file=$(mktemp)
  jq ".acceptanceCriteria[$criterion_index].checked = true" "$story_file" > "$tmp_file"
  mv "$tmp_file" "$story_file"

  # Check if all criteria are now checked
  local all_checked=$(jq '[.acceptanceCriteria[].checked] | all' "$story_file")
  if [[ "$all_checked" == "true" ]]; then
    jq '.passes = true' "$story_file" > "$tmp_file"
    mv "$tmp_file" "$story_file"
  fi
}

# Mark entire story as complete
_ralph_json_complete_story() {
  local json_dir="$1"
  local story_id="$2"
  local story_file="$json_dir/stories/${story_id}.json"
  local index_file="$json_dir/index.json"

  if [[ ! -f "$story_file" ]]; then
    return 1
  fi

  # Mark all criteria as checked and story as passing, with completion timestamp
  local tmp_file=$(mktemp)
  local completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg ts "$completed_at" '.acceptanceCriteria = [.acceptanceCriteria[] | .checked = true] | .passes = true | .completedAt = $ts' "$story_file" > "$tmp_file"
  mv "$tmp_file" "$story_file"

  # Update index.json - remove from pending (stats are derived, US-106)
  if [[ -f "$index_file" ]]; then
    jq --arg id "$story_id" '.pending = [.pending[] | select(. != $id)] | .nextStory = (.pending[0] // "COMPLETE")' "$index_file" > "$tmp_file"
    mv "$tmp_file" "$index_file"
  fi
}

# Convert acceptanceCriteria from string array to object array format
# Input: JSON story via stdin
# Output: JSON story with criteria converted to {text, checked} objects
_ralph_normalize_criteria() {
  jq '
    if .acceptanceCriteria then
      .acceptanceCriteria = [
        .acceptanceCriteria[] |
        if type == "string" then
          { text: ., checked: false }
        else
          .
        end
      ]
    else
      .
    end
  '
}

# Build catchup context for partial story progress (US-084)
# Args: json_dir story_id
# Returns: Catchup context string if partial progress, empty string otherwise
_ralph_build_catchup_context() {
  setopt localoptions noxtrace
  local json_dir="$1"
  local story_id="$2"
  local story_file="$json_dir/stories/${story_id}.json"

  [[ -f "$story_file" ]] || return 1

  # Check if story has partial progress
  local total_criteria=$(jq '[.acceptanceCriteria[]] | length' "$story_file" 2>/dev/null || echo 0)
  local checked_criteria=$(jq '[.acceptanceCriteria[] | select(.checked == true)] | length' "$story_file" 2>/dev/null || echo 0)
  local passes=$(jq -r '.passes // false' "$story_file" 2>/dev/null)

  # No catchup needed if: no checked criteria OR story already passes
  if [[ "$checked_criteria" -eq 0 || "$passes" == "true" ]]; then
    echo ""
    return 0
  fi

  # Has partial progress - build catchup context
  local catchup_context="
## ⚠️ PARTIAL PROGRESS DETECTED - AUTO-CATCHUP

This story has **$checked_criteria/$total_criteria criteria already checked** from a previous iteration.

### Previous Iteration Changes"

  # Add git diff from last commit
  local files_changed=$(git diff HEAD~1 --name-only 2>/dev/null | head -20)
  if [[ -n "$files_changed" ]]; then
    catchup_context+="
\`\`\`
Files changed in last commit:
$files_changed
\`\`\`"
  fi

  # Add last commit info
  local last_commit=$(git log -1 --oneline 2>/dev/null)
  if [[ -n "$last_commit" ]]; then
    catchup_context+="
Last commit: \`$last_commit\`"
  fi

  # Add criteria status breakdown
  catchup_context+="

### Criteria Status"

  # Get checked criteria
  local checked_list=$(jq -r '.acceptanceCriteria[] | select(.checked == true) | "✅ " + .text' "$story_file" 2>/dev/null)
  if [[ -n "$checked_list" ]]; then
    catchup_context+="
**Completed (DO NOT REDO):**
$checked_list"
  fi

  # Get unchecked criteria
  local unchecked_list=$(jq -r '.acceptanceCriteria[] | select(.checked == false) | "⬜ " + .text' "$story_file" 2>/dev/null)
  if [[ -n "$unchecked_list" ]]; then
    catchup_context+="

**Remaining (FOCUS ON THESE):**
$unchecked_list"
  fi

  catchup_context+="

### Instructions
1. **Review the changes** from the previous iteration above
2. **DO NOT redo** already-checked criteria
3. **Continue from where the previous iteration left off**
4. Focus on the remaining unchecked criteria
"

  echo "$catchup_context"
}

# Apply queued updates from update.json (allows external processes to queue changes)
# Returns 0 if updates were applied, 1 if no updates
# Sets RALPH_UPDATES_APPLIED to the count of new stories added
_ralph_apply_update_queue() {
  local json_dir="$1"
  local update_file="$json_dir/update.json"
  local index_file="$json_dir/index.json"
  local stories_dir="$json_dir/stories"

  RALPH_UPDATES_APPLIED=0

  # Exit early if no update.json
  [[ -f "$update_file" ]] || return 1
  [[ -f "$index_file" ]] || return 1

  # Warn about ignored fields in update.json
  local ignored_fields=$(jq -r 'keys[] | select(. != "newStories" and . != "updateStories")' "$update_file" 2>/dev/null)
  if [[ -n "$ignored_fields" ]]; then
    echo "${RALPH_COLOR_YELLOW}⚠ Warning: update.json has ignored fields: $(echo $ignored_fields | tr '\n' ', ')${RALPH_COLOR_RESET}"
    echo "${RALPH_COLOR_YELLOW}  Only 'newStories' and 'updateStories' are processed${RALPH_COLOR_RESET}"
  fi

  local tmp_file=$(mktemp)
  local new_stories_count=0
  local update_stories_count=0

  # 1. Process newStories - create story files and add to pending
  # Supports two formats:
  #   - String IDs: ["MP-004", "US-005"] - story files must already exist
  #   - Full objects: [{id: "MP-004", title: "...", ...}] - creates story files
  local new_stories=$(jq -c '.newStories // [] | .[]' "$update_file" 2>/dev/null)
  if [[ -n "$new_stories" ]]; then
    echo "$new_stories" | while IFS= read -r story; do
      local story_id
      local story_file

      # Check if it's a string (just ID) or object (full story)
      if [[ "$story" =~ ^\" ]]; then
        # String format: "MP-004" - strip quotes
        story_id=$(echo "$story" | jq -r '.')
        story_file="$stories_dir/${story_id}.json"

        # Story file must already exist for string format
        if [[ ! -f "$story_file" ]]; then
          echo "${RALPH_COLOR_YELLOW}  ⚠ Skipping $story_id: story file not found${RALPH_COLOR_RESET}"
          continue
        fi
      else
        # Object format: {id: "MP-004", ...} - extract ID and create file
        story_id=$(echo "$story" | jq -r '.id')
        story_file="$stories_dir/${story_id}.json"

        # Create the story file (normalize string criteria to object format)
        echo "$story" | _ralph_normalize_criteria > "$story_file"
      fi

      # Add to pending array and storyOrder in index.json
      jq --arg id "$story_id" '
        .pending = (.pending + [$id] | unique) |
        .storyOrder = (.storyOrder + [$id] | unique)
      ' "$index_file" > "$tmp_file" && mv "$tmp_file" "$index_file"

      new_stories_count=$((new_stories_count + 1))
    done
    # Re-count after the while loop (subshell isolation)
    new_stories_count=$(jq '.newStories | length' "$update_file" 2>/dev/null || echo 0)
  fi

  # 2. Process updateStories - apply changes to existing story files
  local update_stories=$(jq -c '.updateStories // [] | .[]' "$update_file" 2>/dev/null)
  if [[ -n "$update_stories" ]]; then
    echo "$update_stories" | while IFS= read -r update; do
      local story_id=$(echo "$update" | jq -r '.id')
      local story_file="$stories_dir/${story_id}.json"

      [[ -f "$story_file" ]] || continue

      # Merge the update into the existing story file (normalize string criteria to object format)
      jq -s '.[0] * .[1]' "$story_file" <(echo "$update") | _ralph_normalize_criteria > "$tmp_file" && mv "$tmp_file" "$story_file"
      update_stories_count=$((update_stories_count + 1))
    done
    # Re-count after the while loop (subshell isolation)
    update_stories_count=$(jq '.updateStories | length' "$update_file" 2>/dev/null || echo 0)
  fi

  # 3. Update nextStory after any changes (stats are derived on-the-fly, US-106)
  if [[ $new_stories_count -gt 0 ]] || [[ $update_stories_count -gt 0 ]]; then
    # Update nextStory in index.json
    jq '.nextStory = (.pending[0] // null)' "$index_file" > "$tmp_file" && mv "$tmp_file" "$index_file"

    # Clear newStories from index.json (they've been processed)
    jq '.newStories = []' "$index_file" > "$tmp_file" && mv "$tmp_file" "$index_file"
  fi

  # 4. Delete update.json after successful processing
  rm -f "$update_file"

  # Set global for caller to use
  RALPH_UPDATES_APPLIED=$new_stories_count

  # Return success if we applied anything
  if [[ $new_stories_count -gt 0 ]] || [[ $update_stories_count -gt 0 ]]; then
    return 0
  fi
  return 1
}

# Auto-unblock stories whose blockers are now complete
_ralph_auto_unblock() {
  local json_dir="$1"
  local index_file="$json_dir/index.json"
  local stories_dir="$json_dir/stories"

  [[ -f "$index_file" ]] || return 0

  # Get blocked stories
  local blocked_stories=$(jq -r '.blocked[]? // empty' "$index_file" 2>/dev/null)
  [[ -z "$blocked_stories" ]] && return 0

  local unblocked_any=false

  for story_id in $blocked_stories; do
    local story_file="$stories_dir/${story_id}.json"
    [[ -f "$story_file" ]] || continue

    # Get the blocker story ID
    local blocker_id=$(jq -r '.blockedBy // empty' "$story_file" 2>/dev/null)
    [[ -z "$blocker_id" ]] && continue

    # Check if blocker is complete
    local blocker_file="$stories_dir/${blocker_id}.json"
    if [[ -f "$blocker_file" ]]; then
      local blocker_passes=$(jq -r '.passes // false' "$blocker_file" 2>/dev/null)
      if [[ "$blocker_passes" == "true" ]]; then
        # Unblock: remove blockedBy from story
        jq 'del(.blockedBy)' "$story_file" > "${story_file}.tmp" && mv "${story_file}.tmp" "$story_file"

        # Move from blocked to pending in index (stats are derived, US-106)
        jq --arg id "$story_id" '
          .blocked = [.blocked[] | select(. != $id)] |
          .pending = (.pending + [$id])
        ' "$index_file" > "${index_file}.tmp" && mv "${index_file}.tmp" "$index_file"

        echo "  🔓 Auto-unblocked $story_id (blocker $blocker_id is complete)"
        unblocked_any=true
      fi
    fi
  done
}

# Get count of remaining stories AND criteria
_ralph_json_remaining_count() {
  local json_dir="$1"
  local index_file="$json_dir/index.json"

  if [[ ! -f "$index_file" ]]; then
    echo "0 stories (0 criteria)"
    return
  fi

  # Derive pending count from array (US-106)
  local stories=$(jq -r '.pending | length' "$index_file")

  # Count total unchecked criteria across all pending stories using while read
  local criteria=0
  while IFS= read -r story_id; do
    local story_file="$json_dir/stories/${story_id}.json"
    if [[ -f "$story_file" ]]; then
      local unchecked=$(jq '[.acceptanceCriteria[] | select(.checked == false)] | length' "$story_file" 2>/dev/null || echo 0)
      criteria=$((criteria + unchecked))
    fi
  done < <(jq -r '.pending[]' "$index_file" 2>/dev/null)

  echo "$stories stories ($criteria criteria)"
}

# Get remaining stats as space-separated numbers: "stories criteria"
_ralph_json_remaining_stats() {
  setopt localoptions noxtrace  # Prevent debug output leaking to terminal
  local json_dir="$1"
  local index_file="$json_dir/index.json"

  if [[ ! -f "$index_file" ]]; then
    echo "0 0"
    return
  fi

  # Derive pending count from array (US-106)
  local stories=$(jq -r '.pending | length' "$index_file")

  # Count total unchecked criteria across all pending stories using while read
  local criteria=0
  while IFS= read -r story_id; do
    local story_file="$json_dir/stories/${story_id}.json"
    if [[ -f "$story_file" ]]; then
      local unchecked=$(jq '[.acceptanceCriteria[] | select(.checked == false)] | length' "$story_file" 2>/dev/null || echo 0)
      criteria=$((criteria + unchecked))
    fi
  done < <(jq -r '.pending[]' "$index_file" 2>/dev/null)

  echo "$stories $criteria"
}

# ═══════════════════════════════════════════════════════════════════

function ralph() {
  # Disable xtrace in case user's shell has it enabled (prevents debug output leakage)
  setopt localoptions noxtrace

  # Clean up stale context files from ANY previous crashed session (not just current PID)
  # This fixes the bug where $$ gives current PID but stale files have old PID
  for stale_file in /tmp/ralph-context-*.md(N); do
    local stale_pids=$(lsof -t "$stale_file" 2>/dev/null)
    if [[ -n "$stale_pids" ]]; then
      kill $stale_pids 2>/dev/null
      sleep 0.1
    fi
    rm -f "$stale_file"
  done

  local MAX=$RALPH_MAX_ITERATIONS
  local SLEEP=$RALPH_SLEEP_SECONDS
  local notify_enabled=false
  local primary_model=""     # First model flag: for US-*/BUG-* stories
  local verify_model=""      # Second model flag: for V-* stories (defaults to haiku)
  local RALPH_TMP="/tmp/ralph_output_$$.txt"
  local REPO_ROOT=$(pwd)
  local PRD_PATH="$REPO_ROOT/PRD.md"
  local PRD_JSON_DIR="$REPO_ROOT/prd-json"
  local use_json_mode=false
  local project_key="ralph"
  # Default ntfy topic: etanheys-ralph-<project>-notify (per-project topics)
  local project_name=$(basename "$(pwd)")
  local ntfy_topic="${RALPH_NTFY_TOPIC:-${RALPH_NTFY_PREFIX}-${project_name}-notify}"
  local app_mode=""
  local target_branch=""
  local original_branch=""
  local skip_setup=false     # Skip interactive setup, use defaults
  local compact_mode=false   # Compact output mode (less verbose)
  local debug_mode=false     # Debug output mode (more verbose)
  local live_updates=true    # Live progress bar updates via file watching
  local use_ink_ui=false     # Use React Ink UI for dashboard display
  local force_bash_ui=false  # Force bash UI (override config.runtime)

  # Interactive control variables (gum-enabled features)
  local ralph_start_time=$(date +%s)  # Track when ralph started
  local pause_enabled=false           # Pause after current iteration
  local verbose_enabled=true          # Show full claude output (default on)
  local skip_story=false              # Skip current story
  local quit_requested=false          # Graceful quit after iteration

  # Valid app names for app-specific mode (parsed from space-separated config)
  local valid_apps=(${=RALPH_VALID_APPS})

  # Check for version flag first (exits immediately)
  case "$1" in
    --version|-v)
      echo "ralphtools v${RALPH_VERSION}"
      return 0
      ;;
  esac

  # Parse arguments - check for app name first
  local args_to_parse=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -QN|--quiet-notify)
        notify_enabled=true
        shift
        ;;
      --skip-setup|-y)
        skip_setup=true
        shift
        ;;
      --compact|-c)
        compact_mode=true
        shift
        ;;
      --debug|-d)
        debug_mode=true
        shift
        ;;
      --no-live)
        live_updates=false
        shift
        ;;
      --ui-ink)
        use_ink_ui=true
        shift
        ;;
      --ui-bash)
        use_ink_ui=false
        force_bash_ui=true
        shift
        ;;
      -O|--opus)
        if [[ -z "$primary_model" ]]; then
          primary_model="opus"
        else
          verify_model="opus"
        fi
        shift
        ;;
      -S|--sonnet)
        if [[ -z "$primary_model" ]]; then
          primary_model="sonnet"
        else
          verify_model="sonnet"
        fi
        shift
        ;;
      -H|--haiku)
        if [[ -z "$primary_model" ]]; then
          primary_model="haiku"
        else
          verify_model="haiku"
        fi
        shift
        ;;
      -K|--kiro)
        if [[ -z "$primary_model" ]]; then
          primary_model="kiro"
        else
          verify_model="kiro"
        fi
        shift
        ;;
      -G*|--gemini*)
        local g_model="gemini"
        if [[ "$1" == -G-* ]]; then
          g_model="${1#-G-}"
        elif [[ "$1" == --gemini=* ]]; then
          g_model="${1#--gemini=}"
        fi
        
        if [[ -z "$primary_model" ]]; then
          primary_model="$g_model"
        else
          verify_model="$g_model"
        fi
        shift
        ;;
      *)
        # Check if it's a valid app name
        if [[ " ${valid_apps[*]} " =~ " $1 " ]]; then
          # App-specific mode
          app_mode="$1"
          PRD_PATH="$REPO_ROOT/apps/$app_mode/PRD.md"
          target_branch="feat/${app_mode}-work"
          # ntfy_topic already set to project-based default, app mode doesn't change it
          # (same project = same Ralph topic, different projects = different topics)
          shift
        elif [[ "$1" =~ ^[0-9]+$ ]]; then
          # Positional args: numbers for MAX/SLEEP
          if [[ "$MAX" -eq "$RALPH_MAX_ITERATIONS" ]]; then
            MAX="$1"
          else
            SLEEP="$1"
          fi
          shift
        else
          shift
        fi
        ;;
    esac
  done

  # First-run check - prompt for setup if config missing
  if [[ "$skip_setup" == "true" ]]; then
    _ralph_first_run_check --skip-setup
  else
    _ralph_first_run_check
  fi

  # Set UI mode from config.runtime (unless --ui-ink or --ui-bash was passed explicitly)
  if [[ "$force_bash_ui" != "true" && "$use_ink_ui" != "true" && "$RALPH_RUNTIME" == "bun" ]]; then
    use_ink_ui=true
  fi

  # If app mode, handle branch switching
  if [[ -n "$app_mode" ]]; then
    original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    echo "🔀 App mode: $app_mode"
    echo "   PRD: apps/$app_mode/PRD.md"
    echo "   Branch: $target_branch"
    echo ""

    # Check if target branch exists
    if git show-ref --verify --quiet "refs/heads/$target_branch" 2>/dev/null; then
      # Branch exists, switch to it
      echo "📍 Switching to existing branch: $target_branch"
      git checkout "$target_branch" || {
        echo "❌ Failed to switch to $target_branch"
        return 1
      }
    else
      # Create new branch from current
      echo "🌱 Creating new branch: $target_branch"
      git checkout -b "$target_branch" || {
        echo "❌ Failed to create $target_branch"
        return 1
      }
    fi
    echo ""
  fi

  # Remove ALL notification configs to prevent per-iteration notifications
  (setopt NULL_GLOB; rm -f /tmp/.claude_notify_config_*.json) 2>/dev/null

  # Check for JSON mode (prd-json/ directory with index.json)
  if [[ -n "$app_mode" ]]; then
    PRD_JSON_DIR="$REPO_ROOT/apps/$app_mode/prd-json"
  fi

  if [[ -f "$PRD_JSON_DIR/index.json" ]]; then
    use_json_mode=true
    echo "📋 JSON mode detected: $PRD_JSON_DIR"
  fi

  if [[ "$use_json_mode" != "true" ]] && [[ ! -f "$PRD_PATH" ]]; then
    echo "❌ No PRD.md or prd-json/ found in current directory"
    echo ""
    echo "Create one first:"
    echo "  1. Run 'claude' and use '/golem-powers:prd' to generate a PRD"
    echo "  2. Or manually create PRD.md with user stories"
    echo ""
    echo "PRD.md format:"
    echo "  **Working Directory:** \`apps/public\`"
    echo "  ### US-001: Task Name"
    echo "  - [ ] Acceptance criterion 1"
    echo "  - [ ] Acceptance criterion 2"
    return 1
  fi

  # Check for uncommitted changes - prevent starting on dirty working tree
  echo "🔍 Checking git status..."
  local git_status=$(git status --porcelain 2>/dev/null)
  if [[ -n "$git_status" ]]; then
    echo "❌ Uncommitted changes detected! Ralph requires a clean working tree."
    echo ""
    echo "Modified/untracked files:"
    git status --short
    echo ""
    echo "Options:"
    echo "  1. Commit your changes: git add -A && git commit -m 'WIP'"
    echo "  2. Stash your changes: git stash"
    echo "  3. Discard changes: git checkout -- . && git clean -fd"
    echo ""
    read -q "REPLY?Override and continue anyway? (y/n) "
    echo ""
    if [[ "$REPLY" != "y" ]]; then
      return 1
    fi
    echo "⚠️  Continuing with dirty working tree..."
  else
    echo "  ✓ Working tree is clean"
  fi

  # Parse Working Directory from PRD.md and cd to it
  local working_dir=$(grep '^\*\*Working Directory:\*\*' "$PRD_PATH" 2>/dev/null | sed 's/.*`\([^`]*\)`.*/\1/')
  if [[ -n "$working_dir" ]]; then
    if [[ -d "$working_dir" ]]; then
      echo "📁 Changing to working directory: $working_dir"
      cd "$working_dir" || { echo "❌ Failed to cd to $working_dir"; return 1; }
    else
      echo "❌ Working directory not found: $working_dir"
      return 1
    fi
  fi

  # Check required MCPs
  echo "🔍 Checking required tools..."
  local mcp_list=$(claude mcp list 2>/dev/null)

  # Check Context7 MCP (for documentation lookups)
  if echo "$mcp_list" | grep -q "Context7.*Connected"; then
    echo "  ✓ Context7 MCP connected (docs lookup)"
  else
    echo "  ⚠️  Context7 MCP not connected (docs lookup will be unavailable)"
  fi

  # Check if browser verification tasks exist in PRD
  if grep -q "verify.*browser\|verify.*visually\|Figma" "$PRD_PATH" 2>/dev/null; then
    # Check browser MCPs - both complement each other
    if echo "$mcp_list" | grep -q "browser-tools.*Connected"; then
      echo "  ✓ browser-tools MCP connected (console, network, audits)"
    else
      echo "  ⚠️  browser-tools MCP not connected"
    fi

    # claude-in-chrome connects via Chrome extension (may not show in mcp list)
    echo "  ℹ️  claude-in-chrome: Ensure Chrome extension is running for full browser control"

    # Check figma MCP if Figma comparison needed
    if grep -q "Figma" "$PRD_PATH" 2>/dev/null; then
      if echo "$mcp_list" | grep -q "figma.*Connected"; then
        echo "  ✓ Figma MCP connected (design comparison)"
      else
        echo "  ⚠️  Figma MCP not connected (design comparison unavailable)"
      fi
    fi

    # Check if dev server is likely running
    if curl -s --max-time 2 http://localhost:3000 > /dev/null 2>&1; then
      echo "  ✓ Dev server responding on localhost:3000"
    else
      echo "  ⚠️  Dev server not detected on localhost:3000"
      echo "     Start it with 'bun dev' in another terminal for browser verification"
      echo ""
      read -q "REPLY?Continue anyway? (y/n) "
      echo ""
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        return 1
      fi
    fi
  fi
  echo ""

  # Detect current project and 1Password availability for secret injection
  local ralph_project_name=""
  local ralph_use_op=false
  local ralph_env_1password_file=""
  local ralph_mcp_config_file=""

  # Try to detect project from registry
  ralph_project_name=$(_ralph_current_project 2>/dev/null)

  # Check if op CLI is available, user is signed in, and environments are configured
  if command -v op &> /dev/null; then
    if op account list &> /dev/null; then
      # CLI is installed and signed in - now check if environments are configured
      if _ralph_check_op_environments "."; then
        ralph_use_op=true
        echo "🔐 1Password: Available (secrets via 1Password Environments)"
      else
        echo "🔐 1Password: CLI available (environments not configured)"
        echo "   Run 'ralph-setup' → Configure 1Password Environments"
      fi
    else
      echo "🔐 1Password: CLI available but not signed in"
    fi
  else
    echo "🔐 1Password: Not installed (using environment variables)"
  fi

  # Build MCP config from registry if project detected
  local ralph_project_mcps=""
  if [[ -n "$ralph_project_name" ]]; then
    echo "📦 Project: $ralph_project_name"

    # Build MCP config and write to temp file
    local mcp_config=$(_ralph_build_mcp_config "$ralph_project_name" 2>/dev/null)
    if [[ -n "$mcp_config" && "$mcp_config" != '{"mcpServers": {}}' ]]; then
      ralph_mcp_config_file="/tmp/ralph-mcp-config-$$.json"
      echo "$mcp_config" > "$ralph_mcp_config_file"

      # Extract MCP names for display
      ralph_project_mcps=$(echo "$mcp_config" | jq -r '.mcpServers | keys | join(", ")' 2>/dev/null)
      if [[ -n "$ralph_project_mcps" ]]; then
        echo "🔌 MCPs: $ralph_project_mcps"
      fi
    fi
  fi
  echo ""

  # Create progress.txt if it doesn't exist
  if [[ ! -f "progress.txt" ]]; then
    echo "# Progress Log" > progress.txt
    echo "" >> progress.txt
    echo "## Learnings" >> progress.txt
    echo "(Patterns discovered during implementation)" >> progress.txt
    echo "" >> progress.txt
    echo "---" >> progress.txt
  fi

  # Check for orphan processes from previous crashed Ralph sessions
  _ralph_check_orphans_at_startup

  # Show recent crash info if available
  _ralph_show_recent_crash

  # Global variable for context file cleanup (accessible from trap)
  RALPH_CONTEXT_FILE="/tmp/ralph-context-$$.md"

  # Cleanup on exit (and switch back to original branch in app mode)
  cleanup_ralph() {
    # Stop file watcher if running
    _ralph_stop_watcher

    # Stop polling loop if running
    _ralph_stop_polling_loop

    # Stop Ink UI if running
    if [[ -n "$RALPH_INK_UI_PID" ]]; then
      _ralph_untrack_pid "$RALPH_INK_UI_PID"
      kill "$RALPH_INK_UI_PID" 2>/dev/null
      RALPH_INK_UI_PID=""
    fi

    # Untrack all PIDs from this session (prevents orphan false positives)
    _ralph_untrack_session

    rm -f "$RALPH_TMP"
    # Clean up temp 1Password environment files
    [[ -n "$ralph_env_1password_file" ]] && rm -f "$ralph_env_1password_file"
    [[ -n "$ralph_mcp_config_file" ]] && rm -f "$ralph_mcp_config_file"
    # Clean up context file and kill any processes holding it
    if [[ -n "$RALPH_CONTEXT_FILE" && -f "$RALPH_CONTEXT_FILE" ]]; then
      # Kill any stale processes holding the file open
      local stale_pids=$(lsof -t "$RALPH_CONTEXT_FILE" 2>/dev/null)
      if [[ -n "$stale_pids" ]]; then
        kill $stale_pids 2>/dev/null
      fi
      rm -f "$RALPH_CONTEXT_FILE"
    fi
    # Clean up status file (US-106)
    _ralph_cleanup_status_file
    if [[ -n "$app_mode" && -n "$original_branch" ]]; then
      echo ""
      echo "🔙 Returning to original branch: $original_branch"
      git checkout "$original_branch" 2>/dev/null
    fi
  }
  trap cleanup_ralph EXIT

  # Initialize live updates if enabled and JSON mode
  if [[ "$live_updates" == "true" ]]; then
    RALPH_LIVE_ENABLED=true
  else
    RALPH_LIVE_ENABLED=false
  fi

  # Show React Ink UI for startup (renders once, exits)
  # Note: True live mode with persistent background TUI not yet supported (see research/07-live-ink-ui)
  if [[ "$use_ink_ui" == "true" ]]; then
    if _ralph_show_ink_ui "startup" "$PRD_JSON_DIR" "1" "${primary_model:-sonnet}" "$(date +%s)" "$ntfy_topic"; then
      : # Ink UI succeeded
    else
      # Ink UI failed, fall through to shell UI
      use_ink_ui=false
    fi
  fi

  # Shell-based startup display (if not using Ink UI)
  if [[ "$use_ink_ui" != "true" && "$compact_mode" == "true" ]]; then
    # Compact mode: single-line startup
    local project_name=$(basename "$(pwd)")
    # Derive stats on-the-fly (US-106)
    local derived_stats=$(_ralph_derive_stats "$PRD_JSON_DIR")
    local pending=$(echo "$derived_stats" | awk '{print $1}')
    local completed=$(echo "$derived_stats" | awk '{print $3}')
    local criteria_stats=$(_ralph_get_total_criteria "$PRD_JSON_DIR")
    local crit_done=$(echo "$criteria_stats" | cut -d' ' -f1)
    local crit_total=$(echo "$criteria_stats" | cut -d' ' -f2)
    echo ""
    echo "🚀 Ralph v${RALPH_VERSION} │ ${project_name} │ ${completed}/${pending}+${completed} stories │ ${crit_done}/${crit_total} criteria │ max ${MAX} iters"
  elif [[ "$use_ink_ui" != "true" ]]; then
    # Normal mode: full startup banner (shell-based)
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    local title_str="🚀 RALPH v${RALPH_VERSION}"
    local title_width=$(_ralph_display_width "$title_str")
    local title_padding=$((61 - title_width))
    echo "║  ${title_str}$(printf '%*s' $title_padding '')║"
    echo "╠───────────────────────────────────────────────────────────────╣"
    local pwd_str="📂 $(pwd | head -c 50)"
    local pwd_width=$(_ralph_display_width "$pwd_str")
    local pwd_padding=$((61 - pwd_width))
    echo "║  ${pwd_str}$(printf '%*s' $pwd_padding '')║"
    if [[ -n "$app_mode" ]]; then
      local app_str="📱 App: $app_mode (branch: $target_branch)"
      local app_width=$(_ralph_display_width "$app_str")
      local app_padding=$((61 - app_width))
      echo "║  ${app_str}$(printf '%*s' $app_padding '')║"
    fi
    local max_str="🔄 Max iterations: $MAX"
    local max_width=$(_ralph_display_width "$max_str")
    local max_padding=$((61 - max_width))
    echo "║  ${max_str}$(printf '%*s' $max_padding '')║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Show routing config (smart vs single)
    if [[ -z "$primary_model" && -z "$verify_model" ]]; then
      # No CLI override - show config-based routing
      _ralph_show_routing
    fi
    # Count and display based on mode (BOX_INNER_WIDTH=61 to match header)
    local BOX_INNER_WIDTH=61
    echo "┌───────────────────────────────────────────────────────────────┐"
    if [[ "$use_json_mode" == "true" ]]; then
      # Derive stats on-the-fly (US-106)
      local derived_stats=$(_ralph_derive_stats "$PRD_JSON_DIR")
      local pending=$(echo "$derived_stats" | awk '{print $1}')
      local blocked=$(echo "$derived_stats" | awk '{print $2}')
      local completed=$(echo "$derived_stats" | awk '{print $3}')
      local status_str="📋 Stories: $pending pending │ $completed completed │ $blocked blocked"
      local status_width=$(_ralph_display_width "$status_str")
      local status_padding=$((BOX_INNER_WIDTH - status_width))
      echo "│  ${status_str}$(printf '%*s' $status_padding '')│"
      # Show total criteria across all stories with progress bar (BUG-017)
      local criteria_stats=$(_ralph_get_total_criteria "$PRD_JSON_DIR")
      local criteria_checked=$(echo "$criteria_stats" | cut -d' ' -f1)
      local criteria_total=$(echo "$criteria_stats" | cut -d' ' -f2)
      # Build a wider progress bar (15 chars) for startup display
      local percent=0
      [[ "$criteria_total" -gt 0 ]] && percent=$((criteria_checked * 100 / criteria_total))
      local bar_filled=$((percent * 15 / 100))
      local bar_empty=$((15 - bar_filled))
      local criteria_bar=""
      for ((j=0; j<bar_filled; j++)); do criteria_bar+="█"; done
      for ((j=0; j<bar_empty; j++)); do criteria_bar+="░"; done
      local criteria_str="📝 Criteria: [${criteria_bar}] $criteria_checked/$criteria_total"
      local criteria_width=$(_ralph_display_width "$criteria_str")
      local criteria_padding=$((BOX_INNER_WIDTH - criteria_width))
      echo "│  ${criteria_str}$(printf '%*s' $criteria_padding '')│"
    else
      local task_count=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
      local task_str="📋 Tasks remaining: $task_count"
      local task_width=$(_ralph_display_width "$task_str")
      local task_padding=$((BOX_INNER_WIDTH - task_width))
      echo "│  ${task_str}$(printf '%*s' $task_padding '')│"
    fi
    if $notify_enabled; then
      # BUG-017: Split notification into two lines for better readability
      # Line 1: Notification status
      local notify_str="🔔 Notifications: ON"
      local notify_width=$(_ralph_display_width "$notify_str")
      local notify_padding=$((BOX_INNER_WIDTH - notify_width))
      echo "│  ${notify_str}$(printf '%*s' $notify_padding '')│"
      # Line 2: Topic (with indent)
      # "   Topic: " = 10 display chars, max topic length = 61 - 10 = 51 chars
      local max_topic_len=51
      local display_topic="$ntfy_topic"
      if [[ ${#ntfy_topic} -gt $max_topic_len ]]; then
        display_topic="${ntfy_topic:0:$((max_topic_len - 3))}..."
      fi
      local topic_str="   Topic: $display_topic"
      local topic_width=$(_ralph_display_width "$topic_str")
      local topic_padding=$((BOX_INNER_WIDTH - topic_width))
      echo "│  ${topic_str}$(printf '%*s' $topic_padding '')│"
    else
      local notify_off_str="🔕 Notifications: OFF"
      local notify_off_width=$(_ralph_display_width "$notify_off_str")
      local notify_off_padding=$((BOX_INNER_WIDTH - notify_off_width))
      echo "│  ${notify_off_str}$(printf '%*s' $notify_off_padding '')│"
    fi
    echo "└───────────────────────────────────────────────────────────────┘"
    echo ""
  fi

  # Start file watcher for live updates (JSON mode only)
  if [[ "$use_json_mode" == "true" && "$RALPH_LIVE_ENABLED" == "true" ]]; then
    _ralph_start_watcher "$PRD_JSON_DIR"
  fi

  for ((i=1; i<=$MAX; i++)); do
    # Check for update.json at START of each iteration (hot-reload)
    if [[ "$use_json_mode" == "true" ]]; then
      if _ralph_apply_update_queue "$PRD_JSON_DIR"; then
        if [[ $RALPH_UPDATES_APPLIED -gt 0 ]]; then
          local story_word="stories"
          [[ $RALPH_UPDATES_APPLIED -eq 1 ]] && story_word="story"
          echo "  📥 Applied $RALPH_UPDATES_APPLIED new $story_word from update.json"
        fi
      fi
      _ralph_auto_unblock "$PRD_JSON_DIR"
    fi

    # Determine current story and model to use
    local current_story=""
    local effective_model=""

    if [[ "$use_json_mode" == "true" ]]; then
      current_story=$(_ralph_json_next_story "$PRD_JSON_DIR")

      # BUG-005: Check if PRD is complete (no more pending stories)
      # BUG-015: Also check blocked count - only complete if pending=0 AND blocked=0
      if [[ -z "$current_story" ]]; then
        local pending_count=$(jq -r '.pending | length' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        local blocked_count=$(jq -r '.blocked | length' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        [[ -z "$blocked_count" ]] && blocked_count=0

        if [[ "$pending_count" -eq 0 || -z "$pending_count" ]]; then
          local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
          local elapsed_time=$(($(date +%s) - ralph_start_time))
          local elapsed_formatted=$(_ralph_format_duration "$elapsed_time" 2>/dev/null || echo "${elapsed_time}s")

          _ralph_stop_watcher 2>/dev/null

          # BUG-015: Check if there are blocked stories
          if [[ "$blocked_count" -gt 0 ]]; then
            # PRD is blocked - pending=0 but blocked>0
            local story_word="stories"
            [[ "$blocked_count" -eq 1 ]] && story_word="story"

            if [[ "$compact_mode" == "true" ]]; then
              echo ""
              echo -e "⚠️  $(_ralph_warning "PRD BLOCKED!") $blocked_count $story_word need manual intervention │ $elapsed_formatted │ $(_ralph_color_cost "$total_cost")"
            else
              local BOX_INNER_WIDTH=61
              echo ""
              echo -e "${RALPH_COLOR_YELLOW}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
              local blocked_str="⚠️  PRD Blocked: $blocked_count $story_word need manual intervention"
              local blocked_width=$(_ralph_display_width "$blocked_str")
              local blocked_padding=$((BOX_INNER_WIDTH - blocked_width))
              echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${blocked_str}$(printf '%*s' $blocked_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
              echo -e "${RALPH_COLOR_YELLOW}╠───────────────────────────────────────────────────────────────╣${RALPH_COLOR_RESET}"
              local time_str="⏱️  Total time: $elapsed_formatted"
              local time_width=$(_ralph_display_width "$time_str")
              local time_padding=$((BOX_INNER_WIDTH - time_width))
              echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${time_str}$(printf '%*s' $time_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
              local cost_str="💰 Total cost: \$$total_cost"
              local cost_width=$(_ralph_display_width "$cost_str")
              local cost_padding=$((BOX_INNER_WIDTH - cost_width))
              echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${cost_str}$(printf '%*s' $cost_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
              local iter_str="🔄 Iterations: $((i - 1))"
              local iter_width=$(_ralph_display_width "$iter_str")
              local iter_padding=$((BOX_INNER_WIDTH - iter_width))
              echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${iter_str}$(printf '%*s' $iter_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
              echo -e "${RALPH_COLOR_YELLOW}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
            fi

            # Send notification if enabled
            if $notify_enabled; then
              _ralph_ntfy "$ntfy_topic" "blocked" "" "" "$((i - 1))" "0 $blocked_count" "$total_cost"
            fi

            rm -f "$RALPH_TMP"
            return 0
          fi

          # PRD is complete - pending=0 AND blocked=0
          # Derive stats on-the-fly (US-106)
          local derived_stats=$(_ralph_derive_stats "$PRD_JSON_DIR")
          local total_stories=$(echo "$derived_stats" | awk '{print $4}')

          if [[ "$compact_mode" == "true" ]]; then
            echo ""
            echo -e "✅ $(_ralph_success "PRD COMPLETE!") All $total_stories stories finished │ $elapsed_formatted │ $(_ralph_color_cost "$total_cost")"
          else
            local BOX_INNER_WIDTH=61
            echo ""
            echo -e "${RALPH_COLOR_GREEN}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
            local complete_str="✅ PRD Complete! All $total_stories stories finished."
            local complete_width=$(_ralph_display_width "$complete_str")
            local complete_padding=$((BOX_INNER_WIDTH - complete_width))
            echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ${complete_str}$(printf '%*s' $complete_padding '')${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
            echo -e "${RALPH_COLOR_GREEN}╠───────────────────────────────────────────────────────────────╣${RALPH_COLOR_RESET}"
            local time_str="⏱️  Total time: $elapsed_formatted"
            local time_width=$(_ralph_display_width "$time_str")
            local time_padding=$((BOX_INNER_WIDTH - time_width))
            echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ${time_str}$(printf '%*s' $time_padding '')${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
            local cost_str="💰 Total cost: \$$total_cost"
            local cost_width=$(_ralph_display_width "$cost_str")
            local cost_padding=$((BOX_INNER_WIDTH - cost_width))
            echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ${cost_str}$(printf '%*s' $cost_padding '')${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
            local iter_str="🔄 Iterations: $((i - 1))"
            local iter_width=$(_ralph_display_width "$iter_str")
            local iter_padding=$((BOX_INNER_WIDTH - iter_width))
            echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ${iter_str}$(printf '%*s' $iter_padding '')${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
            echo -e "${RALPH_COLOR_GREEN}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
          fi

          # Send notification if enabled
          if $notify_enabled; then
            _ralph_ntfy "$ntfy_topic" "complete" "" "" "$((i - 1))" "0 0" "$total_cost"
          fi

          rm -f "$RALPH_TMP"
          return 0
        fi
      fi
    fi

    # Determine effective model using smart routing
    local routed_model=$(_ralph_get_model_for_story "$current_story" "$primary_model" "$verify_model" "$PRD_JSON_DIR")
    effective_model="$routed_model"

    # Track iteration start time for cost logging
    local iteration_start_time=$(date +%s)

    if [[ "$compact_mode" == "true" ]]; then
      # Compact mode: single-line iteration header
      local colored_story=$(_ralph_color_story_id "$current_story")
      local colored_model=$(_ralph_color_model "$effective_model")
      echo ""
      echo -e "── [$i/$MAX] ${colored_story} (${colored_model}) $(date '+%H:%M:%S') ──"
    else
      # Normal mode: full iteration header
      echo ""
      echo "╔═══════════════════════════════════════════════════════════════╗"
      local iter_title="🔄 ITERATION $i of $MAX"
      local iter_title_width=$(_ralph_display_width "$iter_title")
      local iter_title_padding=$((61 - iter_title_width))
      echo -e "║  $(_ralph_bold "$iter_title")$(printf '%*s' $iter_title_padding '')║"
      echo "╠───────────────────────────────────────────────────────────────╣"
      local time_str="⏱️  $(date '+%H:%M:%S')"
      local time_width=$(_ralph_display_width "$time_str")
      local time_padding=$((61 - time_width))
      echo "║  ${time_str}$(printf '%*s' $time_padding '')║"
      # Show iteration progress bar
      local iter_progress=$(_ralph_iteration_progress "$i" "$MAX")
      local iter_str="📊 Iteration: ${iter_progress}"
      local iter_width=$(_ralph_display_width "$iter_str")
      local iter_padding=$((61 - iter_width))
      echo -e "║  ${iter_str}$(printf '%*s' $iter_padding '')║"
      # Track line offsets for live updates (lines from bottom of header box)
      local criteria_line_offset=0
      local stories_line_offset=0

      if [[ -n "$current_story" ]]; then
        local colored_story=$(_ralph_color_story_id "$current_story")
        local story_str="📖 Story: ${current_story}"
        local story_width=$(_ralph_display_width "$story_str")
        local story_padding=$((61 - story_width))
        echo -e "║  📖 Story: ${colored_story}$(printf '%*s' $story_padding '')║"
        # Show criteria progress for current story (JSON mode only)
        if [[ "$use_json_mode" == "true" ]]; then
          local criteria_stats=$(_ralph_get_story_criteria_progress "$current_story" "$PRD_JSON_DIR")
          local criteria_checked=$(echo "$criteria_stats" | awk '{print $1}')
          local criteria_total=$(echo "$criteria_stats" | awk '{print $2}')
          if [[ "$criteria_total" -gt 0 ]]; then
            local criteria_bar=$(_ralph_criteria_progress "$criteria_checked" "$criteria_total")
            local criteria_str="☐ Criteria:  ${criteria_bar}"
            local criteria_width=$(_ralph_display_width "$criteria_str")
            local criteria_padding=$((61 - criteria_width))
            echo -e "║  ${criteria_str}$(printf '%*s' $criteria_padding '')║"
            # Criteria line is 4 lines from bottom (model + stories + closing + blank)
            criteria_line_offset=4
          fi
        fi
      fi
      local colored_model=$(_ralph_color_model "$effective_model")
      local model_str="🧠 Model: ${effective_model}"
      local model_width=$(_ralph_display_width "$model_str")
      local model_padding=$((61 - model_width))
      echo -e "║  🧠 Model: ${colored_model}$(printf '%*s' $model_padding '')║"
      # Show story progress (JSON mode only)
      if [[ "$use_json_mode" == "true" ]]; then
        # Derive stats on-the-fly (US-106)
        local derived_stats=$(_ralph_derive_stats "$PRD_JSON_DIR")
        local story_completed=$(echo "$derived_stats" | awk '{print $3}')
        local story_total=$(echo "$derived_stats" | awk '{print $4}')
        local story_bar=$(_ralph_story_progress "$story_completed" "$story_total")
        local stories_str="📚 Stories:  ${story_bar}"
        local stories_width=$(_ralph_display_width "$stories_str")
        local stories_padding=$((61 - stories_width))
        echo -e "║  ${stories_str}$(printf '%*s' $stories_padding '')║"
        # Stories line is 2 lines from bottom (closing + blank)
        stories_line_offset=2
      fi
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""

      # Store row positions for live updates (relative to current cursor)
      # We use negative offsets since we're counting backwards from current position
      if [[ "$RALPH_LIVE_ENABLED" == "true" && "$use_json_mode" == "true" ]]; then
        # Get current cursor row using ANSI escape sequence
        local current_row
        if current_row=$(_ralph_get_cursor_row 2>/dev/null); then
          [[ "$criteria_line_offset" -gt 0 ]] && RALPH_CRITERIA_ROW=$((current_row - criteria_line_offset))
          [[ "$stories_line_offset" -gt 0 ]] && RALPH_STORIES_ROW=$((current_row - stories_line_offset))
        fi
      fi
    fi

    # Retry logic for transient API errors like "No messages returned"
    # Use config values (loaded from config.json) with fallback defaults
    local max_retries="${RALPH_MAX_RETRIES:-5}"
    local retry_count=0
    local no_messages_retry_count=0
    local no_messages_max_retries="${RALPH_NO_MSG_MAX_RETRIES:-3}"
    local general_cooldown="${RALPH_GENERAL_COOLDOWN:-15}"
    local no_msg_cooldown="${RALPH_NO_MSG_COOLDOWN:-30}"
    local claude_success=false

    while [[ "$retry_count" -lt "$max_retries" ]]; do
      # Build CLI command as array (safer than string concatenation)
      # V-* stories ALWAYS use Claude Haiku for browser verification
      local -a cli_cmd_arr
      local prompt_flag="-p"  # Claude uses -p, Kiro uses positional arg

      # Determine which model to use based on story type
      # Priority: 1) story JSON "model" field, 2) prefix-based routing
      local active_model=""
      local story_model=""
      if [[ "$use_json_mode" == "true" ]]; then
        story_model=$(jq -r '.model // empty' "$PRD_JSON_DIR/stories/${current_story}.json" 2>/dev/null)
      fi

      if [[ -n "$story_model" ]]; then
        # Story-level override (for sensitive work: 1Password, MCP, env, keys)
        active_model="$story_model"
      elif [[ "$current_story" == V-* ]]; then
        # V-* verification story: use verify_model (default haiku)
        active_model="${verify_model:-haiku}"
      else
        # US-*/BUG-* story: use primary_model (default opus)
        active_model="${primary_model:-opus}"
      fi

      # Build CLI command based on active model
      # Generate session UUID for Claude cost tracking
      local iteration_session_id=$(uuidgen | tr '[:upper:]' '[:lower:]')

      case "$active_model" in
        kiro)
          # Default Kiro (Auto router - cheapest)
          cli_cmd_arr=(kiro-cli chat --trust-all-tools --no-interactive)
          prompt_flag=""  # Kiro takes prompt as positional argument
          iteration_session_id=""  # Kiro doesn't use session IDs
          ;;
        kiro-haiku)
          cli_cmd_arr=(kiro-cli chat --trust-all-tools --no-interactive --model claude-haiku4)
          prompt_flag=""
          iteration_session_id=""
          ;;
        kiro-sonnet)
          cli_cmd_arr=(kiro-cli chat --trust-all-tools --no-interactive --model claude-sonnet4)
          prompt_flag=""
          iteration_session_id=""
          ;;
        kiro-opus)
          cli_cmd_arr=(kiro-cli chat --trust-all-tools --no-interactive --model claude-opus4-5)
          prompt_flag=""
          iteration_session_id=""
          ;;
        gemini*)
          cli_cmd_arr=(gemini -y)
          if [[ "$active_model" != "gemini" ]]; then
            cli_cmd_arr+=(--model "$active_model")
          elif [[ -n "$RALPH_GEMINI_MODEL" ]]; then
            cli_cmd_arr+=(--model "$RALPH_GEMINI_MODEL")
          fi
          prompt_flag=""  # Gemini takes prompt as positional argument
          iteration_session_id=""  # Gemini doesn't use session IDs
          ;;
        haiku|sonnet)
          # BUG-029 FIX: --print outputs to stdout (pipeable), interactive mode writes to TTY (not pipeable)
          # Browser automation is added via --mcp-config when project needs it
          cli_cmd_arr=(claude --print --dangerously-skip-permissions --model "$active_model" --session-id "$iteration_session_id")
          ;;
        *)
          # Default: Claude Opus
          # BUG-029 FIX: --print outputs to stdout (pipeable), interactive mode writes to TTY (not pipeable)
          cli_cmd_arr=(claude --print --dangerously-skip-permissions --session-id "$iteration_session_id")
          ;;
      esac

      # Add --mcp-config if MCP config file exists (project-specific MCPs from registry)
      if [[ -n "$ralph_mcp_config_file" && -f "$ralph_mcp_config_file" ]]; then
        cli_cmd_arr+=(--mcp-config "$ralph_mcp_config_file")
      fi

      # Inject secrets from registry before running Claude
      if [[ -n "$ralph_project_name" ]]; then
        _ralph_inject_secrets "$ralph_project_name" 2>/dev/null
      fi

      # Wrap CLI command with 'op run --env-file' if 1Password is available
      # This injects secrets from the .env.1password file into the environment
      if [[ "$ralph_use_op" == "true" && -n "$ralph_project_name" ]]; then
        # Generate temp .env.1password file for this iteration
        ralph_env_1password_file=$(_ralph_generate_env_1password "$ralph_project_name" "/tmp/ralph-${ralph_project_name}-$$.env.1password")
        if [[ -f "$ralph_env_1password_file" ]]; then
          # Prepend 'op run --env-file' to the command array
          cli_cmd_arr=(op run --env-file "$ralph_env_1password_file" -- "${cli_cmd_arr[@]}")
        fi
      fi

      # Build modular context file for --append-system-prompt (Claude only)
      # Uses global RALPH_CONTEXT_FILE so cleanup trap can access it
      if [[ "$active_model" == "haiku" || "$active_model" == "sonnet" || "$active_model" == "opus" || -z "$active_model" ]]; then
        _ralph_build_context_file "$RALPH_CONTEXT_FILE" >/dev/null
        if [[ -f "$RALPH_CONTEXT_FILE" ]]; then
          # Read context file and add to CLI as --append-system-prompt
          # Use $(<file) syntax and noxtrace to prevent content leaking to terminal (BUG-025)
          # CRITICAL: The array assignment MUST be inside noxtrace block to prevent $context_content expansion leak
          {
            setopt localoptions noxtrace
            local context_content
            context_content=$(<"$RALPH_CONTEXT_FILE")
            cli_cmd_arr+=(--append-system-prompt "$context_content")
          }
        fi
      fi

      # Build the prompt based on JSON vs Markdown mode
      local ralph_prompt=""

      if [[ "$use_json_mode" == "true" ]]; then
        # JSON MODE PROMPT
        # Note: Git rules, skills, and agent instructions now loaded via --append-system-prompt from context files
        ralph_prompt="You are Ralph, an autonomous coding agent. Do exactly ONE task per iteration.

## Model Information
You are running on model: **${active_model}**

## Meta-Learnings
Read docs.local/ralph-meta-learnings.md if it exists - contains critical patterns about avoiding loops and state management.

## File Access (CRITICAL)
If \`read_file\` or \`write_file\` fail due to \"ignored by configured ignore patterns\", you MUST use shell commands to access them:
- To read: \`run_shell_command(\"cat <path>\")\`
- To write: \`run_shell_command(\"printf '...content...' > <path>\")\`
Always prioritize standard tools, but use shell as a fallback for \`progress.txt\` and \`prd-json/\` files.

## Paths (JSON MODE)
- PRD Index: $PRD_JSON_DIR/index.json
- Stories: $PRD_JSON_DIR/stories/*.json
- Working Dir: $(pwd)

## Steps (JSON MODE)
1. Read prd-json/index.json - find nextStory field for the story to work on
2. Read prd-json/stories/{nextStory}.json - get acceptanceCriteria
3. Read progress.txt - check Learnings section for patterns
4. Check if story has blockedBy field (see Blocked Task Rules below)
5. If blocked: move to next in pending array
6. If actionable: work through acceptance criteria ONE BY ONE

## INCREMENTAL CRITERION CHECKING (CRITICAL)
As you complete EACH acceptance criterion:
1. Immediately update the story JSON: set that criterion's checked=true
2. Do NOT wait until all criteria are done
3. This allows live progress tracking via 'ralph-live'
4. After updating the JSON, continue to the next criterion

Example workflow:
- Complete criterion 1 → Edit JSON, set checked=true for criterion 1
- Complete criterion 2 → Edit JSON, set checked=true for criterion 2
- ...continue until all done
- When ALL checked=true → set passes=true

## Final Steps
7. Run typecheck to verify all code changes
8. If 'verify in browser': take a screenshot (see Browser Rules below)
9. Update prd-json/index.json:
   - Remove story from pending array
   - Update stats.completed and stats.pending counts
   - Set nextStory to first remaining pending item
10. Commit prd-json/ AND progress.txt together
11. Verify commit succeeded before ending iteration"
      else
        # MARKDOWN MODE PROMPT (legacy)
        ralph_prompt="You are Ralph, an autonomous coding agent. Do exactly ONE task per iteration.

${private_skills}

## Model Information
You are running on model: **${active_model}**

## Meta-Learnings
Read docs.local/ralph-meta-learnings.md if it exists - contains critical patterns about avoiding loops and state management.

## Paths
- PRD: $PRD_PATH
- Working Dir: $(pwd)

## Steps
1. Read PRD.md - find first incomplete task (marked [ ])
2. Read progress.txt - check Learnings section for patterns from previous iterations
3. Check if task is BLOCKED (see Blocked Task Rules below)
4. If blocked: mark it, move to next task
5. If actionable: implement that ONE task only
6. Run typecheck to verify
7. If 'verify in browser': take a screenshot (see Browser Rules below)
8. **CRITICAL**: Update PRD.md checkboxes ([ ] → [x]) for completed acceptance criteria
9. **CRITICAL**: Commit PRD.md AND progress.txt together (Iteration Summary MUST include model name)
10. Verify commit succeeded before ending iteration"
      fi

      # Build browser/MCP rules (only for models with browser MCPs - Claude/Gemini, not Kiro)
      local browser_rules=""
      if [[ "$active_model" != "kiro" ]]; then
        browser_rules="
## Browser Rules (IMPORTANT)

**🚨 CHECK TABS FIRST - BEFORE ANY BROWSER WORK 🚨**

At the START of any iteration that needs browser verification:
1. Call \`mcp__claude-in-chrome__tabs_context_mcp\` IMMEDIATELY
2. **If tabs exist:** Report \"✓ Browser tabs available (desktop: tabId X, mobile: tabId Y)\" and proceed
3. **If NO tabs / error / extension not connected:**
   - Report: \"⚠️ Browser tabs not available. Need user to open Chrome with extension.\"
   - Mark the browser verification step as BLOCKED
   - Continue with non-browser parts of the story
   - Do NOT keep retrying - the user will open tabs and run Ralph again

**Expected Setup (user provides this):**
- Tab 1: Desktop viewport (1440px+)
- Tab 2: Mobile viewport (375px)
- Chrome extension: Claude-in-Chrome running

**When tabs ARE available:**
1. CHOOSE the correct tab (desktop or mobile based on what you're testing)
2. Navigate to the test URL if needed
3. Take screenshot with: mcp__claude-in-chrome__computer action='screenshot' tabId=<chosen_tab_id>
4. Describe what you see in the screenshot

**Click rules:**
- ALWAYS use action='left_click' - NEVER 'right_click'
- Use ref='ref_X' from read_page, or coordinate=\[x,y\] from screenshot
- ALWAYS include tabId parameter

**Do NOT:**
- Create new tabs (reuse existing ones)
- Resize window or change viewport - NEVER
- Open DevTools
- Right-click anything
- Keep retrying if tabs aren't available
"
      fi

      # Start background polling for live progress updates
      # Pass row positions so the background subshell has correct values
      if [[ "$use_json_mode" == "true" && "$RALPH_LIVE_ENABLED" == "true" ]]; then
        _ralph_start_polling_loop "$current_story" "$PRD_JSON_DIR" "$RALPH_CRITERIA_ROW" "$RALPH_STORIES_ROW"
      fi

      # Update status file: running (US-106)
      _ralph_write_status "running"

      # Run CLI with output capture (tee for checking promises)
      # Note: Claude uses -p flag, Kiro uses positional argument (${prompt_flag:+...} expands only if non-empty)
      # NODE_OPTIONS: Force unhandled promise rejections to become exceptions (properly captured by pipe)
      #
      # BUG-028 FIX: Capture stderr separately to ensure error messages like "No messages returned"
      # are captured even if they're written to stderr before the 2>&1 redirect takes effect.
      # This uses a separate file for stderr, then appends it to RALPH_TMP.
      local RALPH_STDERR="/tmp/ralph_stderr_$$.txt"
      rm -f "$RALPH_STDERR" 2>/dev/null

      # Execute with stderr going to separate file, stdout to RALPH_TMP (via tee or cat)
      # The { cmd 2>file; } pattern ensures stderr is captured to file before any redirects
      { NODE_OPTIONS="--unhandled-rejections=strict" "${cli_cmd_arr[@]}" ${prompt_flag:+$prompt_flag} "${ralph_prompt}

## Dev Server Rules (CRITICAL)

**START DEV SERVER YOURSELF if needed for browser verification:**
1. Check if dev server is running: \`curl -s http://localhost:3001\`
2. If NOT running, start it: \`bun run dev\` (run in background)
3. Wait 5 seconds for startup, then verify it's up
4. Only proceed with browser verification after dev server is confirmed running

**INFRASTRUCTURE BLOCKERS = END ITERATION IMMEDIATELY:**
If you hit a blocker that affects ALL remaining stories (like no dev server and you can't start it):
1. Mark the CURRENT story as blocked
2. Do NOT skip to the next story
3. END the iteration immediately
4. The next iteration will retry with fresh context

This prevents wasting one iteration marking ALL stories as blocked.

## Blocked Task Rules (CRITICAL - Prevents Infinite Loops)

**FIRST: Try to fix the blocker yourself!**
- Dev server not running? Start it with \`bun run dev\`
- Browser tabs not available? Check mcp__claude-in-chrome__tabs_context_mcp
- Use available MCPs: Figma, Linear, Supabase, browser-tools, Context7

A task is BLOCKED only when you CANNOT fix it yourself:
- Figma: node not found, permission denied, MCP timeout
- Linear: API error, missing permissions
- Manual device testing (needs iOS/Android simulator - no MCP for this)
- User decision required (ambiguous requirements)
- External API unavailable
- Dev server fails to start after trying
- 1Password auth timeout (see below)

**1Password/Biometric Auth Timeout:**
If \`op\` commands fail with "authorization timeout" or similar auth errors:
1. Retry up to 3 times with 30 second waits between attempts
2. After 3 failed attempts, mark story as BLOCKED with reason: "1Password authentication timeout - user not present"
3. Do NOT keep retrying indefinitely - user may be AFK
4. Detection: check stderr for "authorization timeout", "biometric", "Touch ID", or exit code from op commands

**When you find a BLOCKED task:**
1. In the story JSON, set blockedBy field: \`\"blockedBy\": \"[specific reason]\"\`
2. Add note to progress.txt: \"[STORY-ID] BLOCKED: [reason].\"
3. If it's an INFRASTRUCTURE blocker (affects all stories): END ITERATION NOW
4. If it's a STORY-SPECIFIC blocker: move to next story
5. Commit the blocker note

**When ALL remaining tasks are BLOCKED:**
1. List all blocked stories and their blockers in progress.txt
2. Output: \`<promise>ALL_BLOCKED</promise>\`
3. This stops the Ralph loop so the user can address blockers

**Do NOT:**
- Skip through ALL stories marking them blocked for the same infrastructure issue
- Keep retrying a blocked task iteration after iteration
- Output the same \"all tasks blocked\" message without the ALL_BLOCKED promise
- Wait for external resources that won't appear

${browser_rules}

## Completion Rules (CRITICAL)

**🚨 YOU DIE AFTER THIS ITERATION 🚨**
The next Ralph is a FRESH instance with NO MEMORY of your work. The ONLY way the next Ralph knows what you did is by reading the PRD state and git commits.

**If you complete work but DON'T update the PRD state:**
→ Next Ralph sees incomplete task
→ Next Ralph thinks work is incomplete
→ Next Ralph re-does the EXACT SAME STORY
→ Infinite loop forever

**If typecheck PASSES (JSON mode):**
1. **UPDATE story JSON**: Set checked=true for completed criteria, passes=true if all done, AND add completedAt with ISO timestamp AND completedBy with the model name (e.g. \"completedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"completedBy\": \"${active_model}\")
2. **UPDATE index.json**: Remove from pending, update stats, set nextStory
3. **UPDATE progress.txt**: Add iteration summary (include CodeRabbit results if run)
4. **CODERABBIT** (if enabled): Run \`cr review --prompt-only --type uncommitted\` before commit
   - If CRITICAL/HIGH/MEDIUM issues found: fix them, then re-run CodeRabbit
   - Only proceed to commit when CodeRabbit passes (or use --skip-coderabbit flag)
   - Log CodeRabbit results in progress.txt
5. **COMMIT**: git add prd-json/ progress.txt && git commit -m \"feat: [story-id] [description]\"
6. **VERIFY**: git log -1 (confirm commit succeeded)
7. If commit fails, STOP and report error

**If typecheck FAILS:**
- Do NOT mark complete
- Do NOT commit
- Append failure to progress.txt
- Create blocker story (US-NNN-A) if infrastructure issue

**Remember:** Git commits = audit trail. PRD state = what next Ralph sees.

## Progress Format

## Iteration - [Task Name]
- Model: ${active_model}
- What was done
- Learnings for next iteration
---


## Iteration Summary (REQUIRED)

At the end of EVERY iteration, provide an expressive summary:
- \"I completed [story ID] which was about [what it accomplished/changed]\"
- \"Next I think I should work on \[next story ID\] which is \[what it will do\]. I'm planning to \[specific actions X, Y, Z\]\"
- Be descriptive and conversational about what you did and what's next, not just checkboxes

**NEVER OUTPUT TASK COUNTS** - No 'remaining=N', no 'X stories left', no task counts at all. The Ralph script displays this automatically. Just describe what you did.

## End Condition

After completing task, check PRD state:
- ALL stories have passes=true (or pending array empty): output <promise>COMPLETE</promise>
- ALL remaining stories are blocked: output <promise>ALL_BLOCKED</promise>
- Some stories still pending: end response (next iteration continues)" 2>"$RALPH_STDERR"; } | if [[ "$verbose_enabled" == "true" ]]; then tee "$RALPH_TMP"; else cat > "$RALPH_TMP"; fi

      # BUG-028: Append stderr to RALPH_TMP so error patterns are detected
      # This ensures "No messages returned" and other errors written to stderr are captured
      if [[ -s "$RALPH_STDERR" ]]; then
        echo "" >> "$RALPH_TMP"
        echo "─── STDERR OUTPUT ───────────────────────────────────────────" >> "$RALPH_TMP"
        cat "$RALPH_STDERR" >> "$RALPH_TMP"
        # Also show stderr to user if verbose mode or if debug capture enabled
        if [[ "$verbose_enabled" == "true" ]] || [[ "${RALPH_DEBUG_CAPTURE:-false}" == "true" ]]; then
          echo ""
          echo "  ⚠️  STDERR captured:"
          cat "$RALPH_STDERR" | sed 's/^/       /'
        fi
      fi
      rm -f "$RALPH_STDERR" 2>/dev/null

      # Stop background polling loop now that Claude has finished
      _ralph_stop_polling_loop

      # Clean up context file generated for this iteration
      _ralph_cleanup_context_file "$RALPH_CONTEXT_FILE"

      # Capture exit code of Claude (pipestatus[1] in zsh gets first command in pipe)
      # Note: zsh uses lowercase 'pipestatus' and 1-indexed arrays
      local exit_code=${pipestatus[1]:-999}

      # DEBUG LOGGING (BUG-028): Diagnose No messages returned capture issues
      # These logs help identify if stderr is being captured and what exit codes we're seeing
      if [[ "${RALPH_DEBUG_CAPTURE:-false}" == "true" ]]; then
        local debug_log="/tmp/ralph_debug_capture_$(date +%Y%m%d_%H%M%S).log"
        {
          echo "═══════════════════════════════════════════════════════════════"
          echo "RALPH DEBUG: Capture Diagnostics - $(date)"
          echo "═══════════════════════════════════════════════════════════════"
          echo ""
          echo "─── EXIT CODE INFO ──────────────────────────────────────────"
          echo "pipestatus array: ${pipestatus[*]}"
          echo "exit_code (pipestatus[1]): $exit_code"
          echo ""
          echo "─── RALPH_TMP FILE INFO ─────────────────────────────────────"
          echo "RALPH_TMP path: $RALPH_TMP"
          if [[ -f "$RALPH_TMP" ]]; then
            echo "File exists: YES"
            echo "File size: $(wc -c < "$RALPH_TMP") bytes"
            echo "Line count: $(wc -l < "$RALPH_TMP")"
            echo ""
            echo "─── FIRST 5 LINES OF RALPH_TMP ─────────────────────────────"
            head -5 "$RALPH_TMP" 2>/dev/null || echo "(failed to read)"
            echo ""
            echo "─── LAST 10 LINES OF RALPH_TMP ────────────────────────────"
            tail -10 "$RALPH_TMP" 2>/dev/null || echo "(failed to read)"
          else
            echo "File exists: NO - this is a problem!"
          fi
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
        } > "$debug_log"
        echo "  📋 DEBUG: Capture diagnostics written to $debug_log"
      fi

      # Check for Ctrl+C (exit code 130 = SIGINT)
      if [[ "$exit_code" -eq 130 ]]; then
        echo ""
        echo "🛑 Ralph stopped."
        rm -f "$RALPH_TMP"
        return 130
      fi

      # Check for transient API errors (in output OR non-zero exit)
      # IMPORTANT: Only check LAST 10 lines to avoid false positives from prose text
      # Patterns must be specific to actual errors, not mentions in summaries
      local error_patterns="No messages returned|EAGAIN|ECONNRESET|fetch failed|API error|promise rejected|UnhandledPromiseRejection|This error originated|promise rejected with the reason|ETIMEDOUT|socket hang up|ENOTFOUND|rate limit|overloaded|Error: 5[0-9][0-9]|status.*(5[0-9][0-9])|HTTP.*5[0-9][0-9]"
      local has_error=false

      # Check first 5 AND last 10 lines for error patterns (avoids false positives from prose)
      # Promise rejections often appear at the start, API errors at the end
      if [[ -f "$RALPH_TMP" ]]; then
        if head -5 "$RALPH_TMP" 2>/dev/null | grep -qiE "$error_patterns"; then
          has_error=true
        elif tail -10 "$RALPH_TMP" 2>/dev/null | grep -qiE "$error_patterns"; then
          has_error=true
        fi
      fi

      # Also treat non-zero exit, empty exit code, or empty output as error
      if [[ -z "$exit_code" ]] || [[ "$exit_code" -ne 0 ]] || [[ ! -s "$RALPH_TMP" ]]; then
        has_error=true
      fi

      # SPECIFIC HANDLING: "No messages returned" Claude CLI error
      # This error requires longer cooldown (30s) and has separate retry limit (3)
      local is_no_messages_error=false
      if [[ -f "$RALPH_TMP" ]]; then
        if grep -qiE "No messages returned" "$RALPH_TMP" 2>/dev/null; then
          is_no_messages_error=true
        fi
      fi

      # DEBUG LOGGING (BUG-028): Show error detection results
      if [[ "${RALPH_DEBUG_CAPTURE:-false}" == "true" ]]; then
        echo "  📋 DEBUG: has_error=$has_error, is_no_messages_error=$is_no_messages_error"
        if [[ -f "$RALPH_TMP" ]]; then
          local found_patterns=$(grep -iE "$error_patterns" "$RALPH_TMP" 2>/dev/null | head -3)
          if [[ -n "$found_patterns" ]]; then
            echo "  📋 DEBUG: Matched error patterns:"
            echo "$found_patterns" | sed 's/^/       /'
          fi
        fi
      fi

      if $is_no_messages_error; then
        no_messages_retry_count=$((no_messages_retry_count + 1))

        # Log error with timestamp to dedicated error log
        local no_msg_error_log="/tmp/ralph_no_messages_$(date +%Y%m%d_%H%M%S).log"
        {
          echo "═══════════════════════════════════════════════════════════════"
          echo "RALPH 'No messages returned' ERROR - $(date)"
          echo "═══════════════════════════════════════════════════════════════"
          echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          echo "Iteration: $i"
          echo "Story: $current_story"
          echo "Model: $active_model"
          echo "Session ID: $iteration_session_id"
          echo "Retry count (this error): $no_messages_retry_count / $no_messages_max_retries"
          echo "Exit code: $exit_code"
          echo ""
          echo "─── Last 30 lines of output ───────────────────────────────────"
          tail -30 "$RALPH_TMP" 2>/dev/null
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
        } > "$no_msg_error_log"

        if [[ "$no_messages_retry_count" -lt "$no_messages_max_retries" ]]; then
          echo ""
          echo -e "  ⚠️  $(_ralph_warning "'No messages returned' error detected") - Retry $no_messages_retry_count/$no_messages_max_retries"
          echo "  📝 Error log: $no_msg_error_log"
          echo "  🔄 Generating fresh session ID for retry..."
          echo "  ⏳ Waiting ${no_msg_cooldown} seconds (API cooldown)..."
          # Update status file: retry (US-106)
          _ralph_write_status "retry" "null" "$no_msg_cooldown"
          sleep "$no_msg_cooldown"
          # Fresh session ID will be generated at the start of the next loop iteration
          continue
        else
          # Max retries exhausted for this specific error - skip this story
          echo ""
          echo -e "  ❌ $(_ralph_error "'No messages returned' persisted") after $no_messages_max_retries retries."
          echo "  📝 Full error log: $no_msg_error_log"
          echo -e "  ⏭️  $(_ralph_warning "Skipping story") '$current_story' and continuing to next..."

          # Update status file: error (US-106)
          _ralph_write_status "error" "No messages returned after $no_messages_max_retries retries"

          # Send ntfy notification for persistent failure
          if $notify_enabled; then
            local skip_stats
            if [[ "$use_json_mode" == "true" ]]; then
              skip_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)
            else
              skip_stats="? ?"
            fi
            local skip_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
            _ralph_ntfy "$ntfy_topic" "error" "$current_story" "$routed_model" "$i" "$skip_stats" "$skip_cost"
          fi

          # Mark as failed but continue to next iteration (next story)
          break
        fi
      fi

      if $has_error; then
        retry_count=$((retry_count + 1))

        # Log detailed error info for debugging
        local error_log="/tmp/ralph_error_$(date +%Y%m%d_%H%M%S).log"
        {
          echo "═══════════════════════════════════════════════════════════════"
          echo "RALPH ERROR LOG - $(date)"
          echo "═══════════════════════════════════════════════════════════════"
          echo "Iteration: $i"
          echo "Exit code: $exit_code"
          echo "Retry count: $retry_count / $max_retries"
          echo "Working dir: $(pwd)"
          echo "Current story: $(_ralph_json_next_story "$PRD_JSON_DIR" 2>/dev/null || echo "unknown")"
          echo ""
          echo "─── Last 30 lines of output ───────────────────────────────────"
          [[ -f "$RALPH_TMP" ]] && tail -30 "$RALPH_TMP"
          echo ""
          echo "─── Error patterns searched ────────────────────────────────────"
          echo "$error_patterns"
          echo ""
          echo "─── Pattern matches found ──────────────────────────────────────"
          [[ -f "$RALPH_TMP" ]] && grep -iE "$error_patterns" "$RALPH_TMP" 2>/dev/null || echo "(none)"
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
        } > "$error_log"

        if [[ "$retry_count" -lt "$max_retries" ]]; then
          echo ""
          echo -e "  ⚠️  $(_ralph_warning "Error detected") (exit code: $exit_code) - Retrying ($retry_count/$max_retries)..."
          echo "  📝 Error log: $error_log"
          [[ -f "$RALPH_TMP" ]] && tail -3 "$RALPH_TMP" 2>/dev/null | head -2
          echo "  ⏳ Waiting ${general_cooldown} seconds before retry..."
          # Update status file: retry (US-106)
          _ralph_write_status "retry" "null" "$general_cooldown"
          sleep "$general_cooldown"
          continue
        else
          echo ""
          echo -e "  ❌ $(_ralph_error "Error persisted") after $max_retries retries. $(_ralph_warning "Skipping iteration.")"
          echo "  📝 Full error log: $error_log"
          # Update status file: error (US-106)
          _ralph_write_status "error" "Error persisted after $max_retries retries"

          # Log crash for debugging (BUG-023)
          local crash_criteria="unknown"
          [[ -f "$PRD_JSON_DIR/stories/${current_story}.json" ]] && \
            crash_criteria=$(jq -r '.acceptanceCriteria | map(select(.checked == false) | .text) | first // "unknown"' "$PRD_JSON_DIR/stories/${current_story}.json" 2>/dev/null)
          local crash_error=$(tail -5 "$RALPH_TMP" 2>/dev/null | head -3 | tr '\n' ' ')
          local crash_log=$(_ralph_log_crash "$i" "$current_story" "$crash_criteria" "$crash_error")
          echo "  📋 Crash log: $crash_log"

          if $notify_enabled; then
            local error_stats
            if [[ "$use_json_mode" == "true" ]]; then
              error_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)
            else
              error_stats="? ?"
            fi
            local error_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
            _ralph_ntfy "$ntfy_topic" "error" "$current_story" "$routed_model" "$i" "$error_stats" "$error_cost"
          fi
          break  # Only break after exhausting retries
        fi
      else
        claude_success=true
        break  # Success - break out of retry loop
      fi
    done

    echo ""

    # Log cost data for this iteration (with session ID for real token tracking)
    local iteration_end_time=$(date +%s)
    local iteration_duration=$((iteration_end_time - iteration_start_time))
    if [[ -n "$current_story" && "$claude_success" == "true" ]]; then
      # Small delay to ensure JSONL is flushed before reading
      sleep 1
      _ralph_log_cost "$current_story" "$routed_model" "$iteration_duration" "success" "$iteration_session_id"
    fi

    # Check if all tasks complete (search anywhere in output, not just on own line)
    # BUG-014: Verify pending count before trusting Claude's COMPLETE signal
    # Claude sometimes falsely signals COMPLETE after just one story. We verify by
    # calling _ralph_verify_pending_count() which checks:
    # - JSON mode: the pending array length in index.json
    # - PRD.md mode: count of unchecked "- [ ]" boxes
    # Only exit if we confirm zero pending tasks. Otherwise warn and continue.
    if grep -q "<promise>COMPLETE</promise>" "$RALPH_TMP" 2>/dev/null; then
      local actual_pending
      actual_pending=$(_ralph_verify_pending_count "$PRD_JSON_DIR" "$PRD_PATH" "$use_json_mode")

      if [[ "$actual_pending" -gt 0 ]]; then
        # Claude said COMPLETE but there are still pending stories - ignore and continue
        echo ""
        echo -e "  ⚠️  $(_ralph_warning "Claude signaled COMPLETE but $actual_pending tasks still pending - ignoring false signal")"
      else
        # Actually complete
        local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
        if [[ "$compact_mode" == "true" ]]; then
          # Compact mode: single line with cost
          echo ""
          echo -e "✅ $(_ralph_success "COMPLETE") after $i iterations │ $(_ralph_color_cost "$total_cost")"
        else
          # Normal mode: full box
          echo ""
          echo -e "${RALPH_COLOR_GREEN}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
          echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ✅ $(_ralph_success "ALL TASKS COMPLETE") after $(_ralph_bold "$i") iterations!                    ${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
          echo -e "${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}  ⏱️  $(date '+%H:%M:%S')                                        ${RALPH_COLOR_GREEN}║${RALPH_COLOR_RESET}"
          echo -e "${RALPH_COLOR_GREEN}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
        fi
        # Send notification if enabled
        if $notify_enabled; then
          _ralph_ntfy "$ntfy_topic" "complete" "" "" "$i" "0 0" "$total_cost"
        fi
        rm -f "$RALPH_TMP"
        return 0
      fi
    fi

    # Check if all remaining tasks are blocked (search anywhere in output, not just on own line)
    if grep -q "<promise>ALL_BLOCKED</promise>" "$RALPH_TMP" 2>/dev/null; then
      local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
      if [[ "$compact_mode" == "true" ]]; then
        # Compact mode: single line with cost
        echo ""
        echo -e "⏹️  $(_ralph_warning "ALL BLOCKED") after $i iterations │ $(_ralph_color_cost "$total_cost")"
      else
        # Normal mode: full box
        echo ""
        echo -e "${RALPH_COLOR_YELLOW}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ⏹️  $(_ralph_warning "ALL REMAINING TASKS BLOCKED") after $(_ralph_bold "$i") iterations          ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ⏱️  $(date '+%H:%M:%S')                                        ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}╠───────────────────────────────────────────────────────────────╣${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  Review PRD.md for stories marked ⏹️ BLOCKED                   ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  Address blockers (Figma access, Linear issues, etc.)         ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  Then run 'ralph' again to continue                           ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
        echo -e "${RALPH_COLOR_YELLOW}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
      fi
      # Send notification if enabled
      if $notify_enabled; then
        local blocked_stats
        if [[ "$use_json_mode" == "true" ]]; then
          blocked_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)
        else
          blocked_stats="? ?"
        fi
        _ralph_ntfy "$ntfy_topic" "blocked" "User action needed" "$current_story" "" "$i" "$blocked_stats" "$total_cost"
      fi
      rm -f "$RALPH_TMP"
      return 2  # Different exit code for blocked vs complete
    fi

    # Note: update.json is checked at START of next iteration (hot-reload)

    # Show enhanced between-iterations status (with progress bar, elapsed time, cost)
    local remaining_stats
    if [[ "$use_json_mode" == "true" ]]; then
      remaining_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)

      # Use React Ink UI if enabled, otherwise fall back to shell UI
      if [[ "$use_ink_ui" == "true" ]]; then
        if ! _ralph_show_ink_ui "iteration" "$PRD_JSON_DIR" "$i" "$routed_model" "$ralph_start_time" "$ntfy_topic"; then
          # Ink UI failed, fall back to shell UI
          _ralph_show_iteration_status "$PRD_JSON_DIR" "$ralph_start_time" "$i" "$MAX" "$current_story" "$routed_model" "$compact_mode" "$pause_enabled" "$verbose_enabled" "$RALPH_HAS_GUM"
        fi
      else
        # Use the shell-based status display
        _ralph_show_iteration_status "$PRD_JSON_DIR" "$ralph_start_time" "$i" "$MAX" "$current_story" "$routed_model" "$compact_mode" "$pause_enabled" "$verbose_enabled" "$RALPH_HAS_GUM"
      fi
    else
      remaining_stats="? ?"
      local remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo "?")
      if [[ "$compact_mode" == "true" ]]; then
        echo "── 📋 ${remaining} remaining │ ⏳ ${SLEEP}s ──"
      else
        # Box is 65 chars wide, inner content area is 61 chars
        local BOX_INNER_WIDTH=61
        echo "┌───────────────────────────────────────────────────────────────┐"
        local remaining_str="📋 Remaining: $remaining"
        local remaining_width=$(_ralph_display_width "$remaining_str")
        local remaining_padding=$((BOX_INNER_WIDTH - remaining_width))
        echo "│  ${remaining_str}$(printf '%*s' $remaining_padding '')│"
        local pause_str="⏳ Pausing ${SLEEP}s before next iteration..."
        local pause_width=$(_ralph_display_width "$pause_str")
        local pause_padding=$((BOX_INNER_WIDTH - pause_width))
        echo "│  ${pause_str}$(printf '%*s' $pause_padding '')│"
        echo "└───────────────────────────────────────────────────────────────┘"
      fi
    fi

    # Per-iteration notification if enabled
    if $notify_enabled; then
      local iter_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
      _ralph_ntfy "$ntfy_topic" "iteration" "$current_story" "$routed_model" "$i" "$remaining_stats" "$iter_cost"
    fi

    # Handle pause if enabled (pause BEFORE sleep, not during Claude)
    if [[ "$pause_enabled" == "true" ]]; then
      if ! _ralph_wait_for_resume; then
        # User pressed q during pause
        quit_requested=true
      fi
      pause_enabled=false  # Reset after pausing
    fi

    # Check for graceful quit request
    if [[ "$quit_requested" == "true" ]]; then
      local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
      echo ""
      echo -e "${RALPH_COLOR_YELLOW}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
      echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  🛑 QUIT REQUESTED after $(_ralph_bold "$i") iterations                      ${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
      echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  💰 Total cost: $(_ralph_color_cost "$total_cost")$(printf '%*s' $((44 - ${#total_cost})) '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
      echo -e "${RALPH_COLOR_YELLOW}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
      rm -f "$RALPH_TMP"
      return 0
    fi

    sleep $SLEEP

    # Reset skip flag for next iteration
    skip_story=false
  done

  # Apply queued updates, auto-unblock, and count remaining for final message
  if [[ "$use_json_mode" == "true" ]]; then
    if _ralph_apply_update_queue "$PRD_JSON_DIR"; then
      if [[ $RALPH_UPDATES_APPLIED -gt 0 ]]; then
        local story_word="stories"
        [[ $RALPH_UPDATES_APPLIED -eq 1 ]] && story_word="story"
        echo "  📥 Applied $RALPH_UPDATES_APPLIED new $story_word from update.json"
      fi
    fi
    _ralph_auto_unblock "$PRD_JSON_DIR"
  fi
  local final_remaining
  local final_remaining_stats
  if [[ "$use_json_mode" == "true" ]]; then
    final_remaining=$(_ralph_json_remaining_count "$PRD_JSON_DIR" 2>/dev/null)
    final_remaining_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)
  else
    final_remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
    final_remaining_stats="? ?"
  fi
  local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
  if [[ "$compact_mode" == "true" ]]; then
    # Compact mode: single line with cost
    echo ""
    echo -e "⚠️  $(_ralph_warning "MAX ITERATIONS") ($MAX) │ ${final_remaining} remaining │ $(_ralph_color_cost "$total_cost")"
  else
    # Normal mode: full box (65 chars wide, inner content area is 61 chars)
    local BOX_INNER_WIDTH=61
    echo ""
    echo -e "${RALPH_COLOR_YELLOW}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
    local max_iter_str=$(_ralph_warning "REACHED MAX ITERATIONS")
    local max_iter_label="⚠️  ${max_iter_str} ($(_ralph_bold "$MAX"))"
    local max_iter_width=$(_ralph_display_width "$max_iter_label")
    local max_iter_padding=$((BOX_INNER_WIDTH - max_iter_width))
    echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${max_iter_label}$(printf '%*s' $max_iter_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
    local remaining_str="📋 Remaining: $final_remaining"
    local remaining_width=$(_ralph_display_width "$remaining_str")
    local remaining_padding=$((BOX_INNER_WIDTH - remaining_width))
    echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${remaining_str}$(printf '%*s' $remaining_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
    # Show story progress bar (JSON mode only)
    if [[ "$use_json_mode" == "true" ]]; then
      # Derive stats on-the-fly (US-106)
      local final_derived_stats=$(_ralph_derive_stats "$PRD_JSON_DIR")
      local final_completed=$(echo "$final_derived_stats" | awk '{print $3}')
      local final_total=$(echo "$final_derived_stats" | awk '{print $4}')
      local final_story_bar=$(_ralph_story_progress "$final_completed" "$final_total")
      local story_str="📚 Stories:  ${final_story_bar}"
      local story_width=$(_ralph_display_width "$story_str")
      local story_padding=$((BOX_INNER_WIDTH - story_width))
      echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ${story_str}$(printf '%*s' $story_padding '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
    fi
    echo -e "${RALPH_COLOR_YELLOW}╚═══════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
  fi
  # Send notification if enabled
  if $notify_enabled; then
    _ralph_ntfy "$ntfy_topic" "max_iterations" "" "" "$MAX" "$final_remaining_stats" "$total_cost"
  fi
  rm -f "$RALPH_TMP"
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# Ralph Helper Commands
# ═══════════════════════════════════════════════════════════════════

# ralph-stop - Stop any running Ralph loops
function ralph-stop() {
  local YELLOW='\033[1;33m'
  local GREEN='\033[0;32m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo "${YELLOW}🛑 Stopping Ralph processes...${NC}"

  local count=$(pgrep -f "claude --dangerously-skip-permissions" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$count" -eq 0 ]]; then
    echo "${GREEN}✓ No Ralph processes running${NC}"
    return 0
  fi

  pkill -f "claude --dangerously-skip-permissions" 2>/dev/null
  sleep 1

  local remaining=$(pgrep -f "claude --dangerously-skip-permissions" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$remaining" -eq 0 ]]; then
    echo "${GREEN}✓ Stopped $count Ralph process(es)${NC}"
  else
    echo "${RED}⚠ $remaining process(es) still running. Try: pkill -9 -f 'claude'${NC}"
  fi
}

# ralph-help - Show all Ralph commands
function ralph-help() {
  local CYAN='\033[0;36m'
  local BOLD='\033[1m'
  local GRAY='\033[0;90m'
  local GREEN='\033[0;32m'
  local NC='\033[0m'

  echo ""
  echo "${CYAN}${BOLD}Ralph Commands${NC}"
  echo ""
  echo "  ${BOLD}ralph [N] [sleep]${NC}     Run N iterations (default 10)"
  echo "  ${BOLD}ralph <app> N${NC}         Run on apps/<app>/ with auto branch"
  echo ""
  echo "  ${BOLD}ralph-init [app]${NC}      Create PRD JSON structure (prd-json/)"
  echo "  ${BOLD}ralph-archive [app]${NC}   Archive completed stories to docs.local/"
  echo "  ${BOLD}ralph-status${NC}          Show PRD progress, blocked stories, next story"
  echo "  ${BOLD}ralph-live [N]${NC}        Live refreshing status (default: 3s)"
  echo "  ${BOLD}ralph-learnings${NC}       Manage learnings in docs.local/learnings/"
  echo "  ${BOLD}ralph-watch${NC}           Live tail of current Ralph output"
  echo "  ${BOLD}ralph-stop${NC}            Kill all running Ralph processes"
  echo ""
  echo "${GREEN}Session Isolation:${NC}"
  echo "  ${BOLD}ralph-start${NC}           Create worktree for isolated Ralph session"
  echo "    ${GRAY}--install${NC}           Run package manager install in worktree"
  echo "    ${GRAY}--dev${NC}               Start dev server in background after setup"
  echo "    ${GRAY}--symlink-deps${NC}      Symlink node_modules (faster than install)"
  echo "    ${GRAY}--1password${NC}         Use 1Password injection (.env.template)"
  echo "    ${GRAY}--no-env${NC}            Skip copying .env files"
  echo "  ${BOLD}ralph-cleanup${NC}         Merge changes and remove worktree"
  echo ""
  echo "${GREEN}Maintenance:${NC}"
  echo "  ${BOLD}ralph-kill-orphans${NC}    Kill orphan processes from crashed sessions"
  echo "    ${GRAY}--all${NC}               Also kill untracked Ralph processes"
  echo "  ${BOLD}ralph-logs [N]${NC}        Show N recent crash logs (default: 5)"
  echo ""
  echo "${GRAY}Flags:${NC}"
  echo "  ${BOLD}-QN${NC}                   Enable ntfy notifications"
  echo "  ${BOLD}--compact, -c${NC}         Compact output mode (less verbose)"
  echo "  ${BOLD}--debug, -d${NC}           Debug output mode (more verbose)"
  echo "  ${BOLD}--ui-ink${NC}              Use React Ink UI dashboard (default, requires bun)"
  echo "  ${BOLD}--ui-bash${NC}             Force traditional zsh-based UI (fallback)"
  echo ""
  echo "${GREEN}Model Flags:${NC}"
  echo "  ${BOLD}-O${NC}                    Opus (Claude, default)"
  echo "  ${BOLD}-S${NC}                    Sonnet (Claude, faster)"
  echo ""
  echo "${GRAY}Deprecated Flags (use smart routing instead):${NC}"
  echo "  ${GRAY}-H                    Haiku (use config.json)${NC}"
  echo "  ${GRAY}-K                    Kiro CLI (use config.json)${NC}"
  echo "  ${GRAY}-G                    Gemini CLI (use config.json)${NC}"
  echo ""
  echo "${GREEN}Smart Model Routing:${NC}"
  echo "  Configure via ralph-setup or config.json. Story prefixes"
  echo "  auto-select models: US→Sonnet, V→Haiku, BUG→Sonnet, etc."
  echo ""
  echo "${GREEN}Color Schemes:${NC}"
  echo "  Set in config.json via 'colorScheme' field:"
  echo "  - default  Bright colors (recommended)"
  echo "  - dark     High-contrast bright colors"
  echo "  - light    Muted colors for terminals with light backgrounds"
  echo "  - minimal  Only errors (red) and success (green)"
  echo "  - none     Disable all colors (for CI/logs)"
  echo "  - custom   Define custom colors in config.json"
  echo ""
  echo "  NO_COLOR env var automatically disables colors"
  echo ""
  echo "${GREEN}JSON Mode:${NC}"
  echo "  Ralph auto-detects prd-json/ folder for JSON mode."
  echo "  Falls back to PRD.md if prd-json/ not found."
  echo ""
  echo "${GREEN}Info:${NC}"
  echo "  ${BOLD}ralph-costs${NC}            Show cost tracking summary"
  echo "  ${BOLD}ralph-whatsnew${NC}         Show what's new in current version"
  echo "  ${BOLD}ralph --version${NC}        Show Ralph version"
  echo ""
}

# ralph-whatsnew - Show changelog (current version by default, --all for full history)
function ralph-whatsnew() {
  local show_all=false

  # Parse arguments
  [[ "$1" == "--all" ]] && show_all=true

  if $show_all; then
    # Show all versions from newest to oldest
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  📜 Ralph Version History                                   │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""

    # Display each version (manually ordered from newest to oldest)
    for version in "1.3.0" "1.2.0" "1.1.0" "1.0.0"; do
      _ralph_show_changelog_version "$version"
    done
  else
    # Show only current version
    _ralph_show_changelog_version "$RALPH_VERSION"
  fi
}

# ralph-watch - Live tail of current Ralph iteration output
function ralph-watch() {
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local RED='\033[0;31m'
  local GRAY='\033[0;90m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  # Find the most recent ralph output file
  local ralph_files=$(ls -t /tmp/ralph_output_*.txt 2>/dev/null | head -5)

  if [[ -z "$ralph_files" ]]; then
    echo "${YELLOW}No Ralph output files found in /tmp/${NC}"
    echo "${GRAY}Start a Ralph loop first: ralph 10${NC}"
    return 1
  fi

  # Show available files
  echo "${CYAN}${BOLD}📺 Ralph Watch${NC}"
  echo ""

  local has_running=false
  local latest_running=""

  echo "${GRAY}Available output files:${NC}"
  local i=1
  echo "$ralph_files" | while read -r file; do
    [[ -z "$file" ]] && continue
    local pid=$(basename "$file" | sed 's/ralph_output_//' | sed 's/.txt//')
    local size=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
    local size_human="$(( size / 1024 ))KB"
    [[ "$size" -lt 1024 ]] && size_human="${size}B"
    local modified=$(stat -f "%Sm" -t "%H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1)
    local status_str=""
    if ps -p "$pid" > /dev/null 2>&1; then
      status_str="${GREEN}● RUNNING${NC}"
    else
      status_str="${GRAY}○ finished${NC}"
    fi
    echo "   ${BOLD}[$i]${NC} PID $pid  $status_str  ${GRAY}${size_human}  $modified${NC}"
    i=$((i + 1))
  done
  echo ""

  # Check if any Ralph is currently running (look for tee writing to ralph output)
  local running_pid=$(pgrep -f "tee /tmp/ralph_output" 2>/dev/null | head -1)
  local latest=$(echo "$ralph_files" | head -1)
  local latest_pid=$(basename "$latest" | sed 's/ralph_output_//' | sed 's/.txt//')
  local latest_size=$(wc -c < "$latest" 2>/dev/null | tr -d ' ')

  if [[ -z "$running_pid" ]]; then
    echo "${YELLOW}⚠ No Ralph process currently running${NC}"
    echo ""
    if [[ "$latest_size" -gt 0 ]]; then
      echo "${GRAY}Last output (final 30 lines):${NC}"
      echo "${CYAN}─────────────────────────────────────────────────────────────${NC}"
      tail -30 "$latest"
    else
      echo "${GRAY}Output file is empty${NC}"
    fi
    return 0
  fi

  echo "${GREEN}✓ Ralph is running (PID: $running_pid)${NC}"
  echo "${CYAN}Watching:${NC} $latest"
  echo "${GRAY}Press Ctrl+C to stop${NC}"
  echo ""
  echo "${CYAN}─────────────────────────────────────────────────────────────${NC}"

  # Tail the file with follow
  tail -f "$latest" 2>/dev/null
}

# ralph-init [app] - Create PRD from template for an app
function ralph-init() {
  local app="$1"
  local prd_dir

  # Help text
  if [[ "$app" == "-h" || "$app" == "--help" ]]; then
    echo "Usage: ralph-init [app]"
    echo ""
    echo "Create a PRD JSON structure."
    echo "  No args:     Creates prd-json/ in current directory"
    echo "  With app:    Creates apps/<app>/prd-json/"
    echo ""
    echo "Example: ralph-init frontend"
    return 0
  fi

  # Validate app name
  if [[ -n "$app" && "$app" =~ ^- ]]; then
    echo "❌ Invalid app name: $app"
    echo "   App names cannot start with a dash"
    return 1
  fi

  if [[ -n "$app" ]]; then
    prd_dir="apps/$app/prd-json"
    mkdir -p "apps/$app"
  else
    prd_dir="prd-json"
  fi

  if [[ -d "$prd_dir" ]]; then
    echo "❌ PRD already exists: $prd_dir"
    read -q "REPLY?Overwrite? (y/n) "
    echo ""
    if [[ "$REPLY" != "y" ]]; then
      return 1
    fi
  fi

  # Create directory structure
  mkdir -p "$prd_dir/stories"

  # Create index.json
  cat > "$prd_dir/index.json" << EOF
{
  "\$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectName": "[Project Name]",
  "workingDirectory": ".",
  "stats": {
    "total": 2,
    "completed": 0,
    "pending": 2,
    "blocked": 0
  },
  "nextStory": "US-001",
  "storyOrder": ["US-001", "V-001"],
  "blocked": [],
  "pending": ["US-001", "V-001"]
}
EOF

  # Create sample story
  cat > "$prd_dir/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "[Story Title]",
  "description": "[What this story accomplishes]",
  "acceptanceCriteria": [
    {"text": "First criterion", "checked": false},
    {"text": "Second criterion", "checked": false},
    {"text": "Typecheck passes", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
EOF

  # Create sample verification story
  cat > "$prd_dir/stories/V-001.json" << 'EOF'
{
  "id": "V-001",
  "title": "Verify US-001",
  "description": "Visual verification that US-001 works correctly",
  "acceptanceCriteria": [
    {"text": "Take screenshot of feature", "checked": false},
    {"text": "Verify expected behavior", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
EOF

  # Create progress.txt
  cat > "progress.txt" << 'EOF'
# Progress Log

## Learnings
(Mark with [DONE] when promoted to CLAUDE.md)

---

## Current Iteration
(Continue from here)
EOF

  echo "✅ Created PRD JSON structure: $prd_dir/"
  echo "   ├── index.json"
  echo "   └── stories/"
  echo "       ├── US-001.json"
  echo "       └── V-001.json"
  echo ""
  echo "   Edit the JSON files to add your user stories"
}

# ═══════════════════════════════════════════════════════════════════
# WORKTREE-BASED SESSION ISOLATION
# ═══════════════════════════════════════════════════════════════════
# Ralph pollutes Claude /resume history. Running in a git worktree gives
# Ralph its own separate Claude session (sessions stored per-directory).
#
# Workflow:
#   1. ralph-start        → creates worktree, outputs cd + ralph command
#   2. (user runs ralph in worktree)
#   3. ralph-cleanup      → merges changes, removes worktree
# ═══════════════════════════════════════════════════════════════════

# ralph-start - Create a worktree for Ralph session isolation
# Usage: ralph-start [flags] [args to pass to ralph]
# Flags:
#   --install           Run package manager install in worktree
#   --dev               Start dev server in background after setup
#   --symlink-deps      Symlink node_modules instead of installing (faster)
#   --no-env            Skip copying .env files
#   --1password         Use 1Password injection (op run --env-file=.env.template)
# Creates worktree at ~/worktrees/<repo>/ralph-session
function ralph-start() {
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local RED='\033[0;31m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  # Parse flags
  local do_install=false
  local do_dev=false
  local symlink_deps=false
  local skip_env=false
  local use_1password=false
  local ralph_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)
        do_install=true
        shift
        ;;
      --dev)
        do_dev=true
        shift
        ;;
      --symlink-deps)
        symlink_deps=true
        shift
        ;;
      --no-env)
        skip_env=true
        shift
        ;;
      --1password)
        use_1password=true
        shift
        ;;
      *)
        ralph_args+=("$1")
        shift
        ;;
    esac
  done

  # Get repo info
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "${RED}❌ Not in a git repository${NC}"
    return 1
  fi

  local repo_name=$(basename "$repo_root")
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  local worktree_base="$HOME/worktrees/$repo_name"
  local worktree_path="$worktree_base/ralph-session"

  echo ""
  echo "${CYAN}${BOLD}🌳 Ralph Session Isolation${NC}"
  echo ""

  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    echo "${YELLOW}⚠️  Worktree already exists: $worktree_path${NC}"
    echo ""
    echo "   Options:"
    echo "   1. cd $worktree_path && source ~/.config/ralphtools/ralph.zsh && ralph ${ralph_args[*]}"
    echo "   2. ralph-cleanup (to remove it first)"
    echo ""
    read -q "REPLY?Resume existing worktree? (y/n) "
    echo ""
    if [[ "$REPLY" == "y" ]]; then
      _ralph_output_worktree_command "$worktree_path" "${ralph_args[@]}"
      return 0
    else
      return 1
    fi
  fi

  # Create worktree directory structure
  mkdir -p "$worktree_base"

  echo "📁 Creating worktree at: $worktree_path"
  echo "   Source branch: $current_branch"
  echo ""

  # Create the worktree (uses current branch as source)
  if ! git worktree add "$worktree_path" -b "ralph-session-$(date +%Y%m%d)" 2>/dev/null; then
    # Branch might already exist, try without -b
    if ! git worktree add "$worktree_path" HEAD 2>&1; then
      echo "${RED}❌ Failed to create worktree${NC}"
      return 1
    fi
  fi

  echo "${GREEN}✓ Worktree created${NC}"
  echo ""

  # ─────────────────────────────────────────────────────────────
  # Phase 1: Sync files from main repo
  # ─────────────────────────────────────────────────────────────
  echo "${CYAN}${BOLD}📦 Syncing files...${NC}"
  echo ""

  # Load .worktree-sync.json if exists
  local sync_config="$repo_root/.worktree-sync.json"
  local has_sync_config=false
  if [[ -f "$sync_config" ]]; then
    has_sync_config=true
    echo "${GREEN}✓ Found .worktree-sync.json${NC}"
  fi

  # Always sync: prd-json, progress.txt, AGENTS.md
  if [[ -d "$repo_root/prd-json" ]]; then
    cp -r "$repo_root/prd-json" "$worktree_path/"
    echo "${GREEN}✓ Copied prd-json/ to worktree${NC}"
  fi

  if [[ -f "$repo_root/progress.txt" ]]; then
    cp "$repo_root/progress.txt" "$worktree_path/"
    echo "${GREEN}✓ Copied progress.txt to worktree${NC}"
  fi

  if [[ -f "$repo_root/AGENTS.md" ]]; then
    cp "$repo_root/AGENTS.md" "$worktree_path/"
    echo "${GREEN}✓ Copied AGENTS.md to worktree${NC}"
  fi

  # Sync .env files (unless skipped or using 1Password)
  if ! $skip_env && ! $use_1password; then
    if [[ -f "$repo_root/.env" ]]; then
      cp "$repo_root/.env" "$worktree_path/"
      echo "${GREEN}✓ Copied .env to worktree${NC}"
    fi
    if [[ -f "$repo_root/.env.local" ]]; then
      cp "$repo_root/.env.local" "$worktree_path/"
      echo "${GREEN}✓ Copied .env.local to worktree${NC}"
    fi
  fi

  # Handle 1Password injection
  if $use_1password; then
    if [[ -f "$repo_root/.env.template" ]]; then
      cp "$repo_root/.env.template" "$worktree_path/"
      echo "${GREEN}✓ Copied .env.template for 1Password injection${NC}"
      echo "${YELLOW}   Use: op run --env-file=.env.template -- <command>${NC}"
    else
      echo "${YELLOW}⚠️  No .env.template found for 1Password injection${NC}"
    fi
  fi

  # Process .worktree-sync.json if exists
  if $has_sync_config; then
    _ralph_process_worktree_sync "$repo_root" "$worktree_path" "$sync_config"
  fi

  echo ""

  # ─────────────────────────────────────────────────────────────
  # Phase 2: Handle dependencies
  # ─────────────────────────────────────────────────────────────
  if $symlink_deps || $do_install; then
    echo "${CYAN}${BOLD}📦 Setting up dependencies...${NC}"
    echo ""

    # Detect package manager
    local pkg_manager=$(_ralph_detect_package_manager "$worktree_path")
    echo "   Package manager: ${BOLD}$pkg_manager${NC}"

    if $symlink_deps; then
      # Symlink node_modules from main repo (faster than install)
      if [[ -d "$repo_root/node_modules" ]]; then
        ln -s "$repo_root/node_modules" "$worktree_path/node_modules"
        echo "${GREEN}✓ Symlinked node_modules from main repo${NC}"
      else
        echo "${YELLOW}⚠️  No node_modules found in main repo, running install instead${NC}"
        do_install=true
      fi
    fi

    if $do_install; then
      echo "   Running $pkg_manager install..."
      (
        cd "$worktree_path" || exit 1
        case "$pkg_manager" in
          bun)
            bun install
            ;;
          pnpm)
            pnpm install
            ;;
          yarn)
            yarn install
            ;;
          *)
            npm install
            ;;
        esac
      )
      if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ Dependencies installed${NC}"
      else
        echo "${RED}❌ Failed to install dependencies${NC}"
      fi
    fi

    echo ""
  fi

  # ─────────────────────────────────────────────────────────────
  # Phase 3: Start dev server (if requested)
  # ─────────────────────────────────────────────────────────────
  if $do_dev; then
    echo "${CYAN}${BOLD}🚀 Starting dev server...${NC}"
    echo ""

    local pkg_manager=$(_ralph_detect_package_manager "$worktree_path")
    (
      cd "$worktree_path" || exit 1
      case "$pkg_manager" in
        bun)
          bun run dev &
          ;;
        pnpm)
          pnpm run dev &
          ;;
        yarn)
          yarn dev &
          ;;
        *)
          npm run dev &
          ;;
      esac
    )
    echo "${GREEN}✓ Dev server started in background${NC}"
    echo ""
  fi

  # ─────────────────────────────────────────────────────────────
  # Phase 4: Run post-setup commands from .worktree-sync.json
  # ─────────────────────────────────────────────────────────────
  if $has_sync_config; then
    _ralph_run_sync_commands "$worktree_path" "$sync_config"
  fi

  echo "${CYAN}─────────────────────────────────────────────────────────────${NC}"
  echo ""
  echo "${BOLD}Session isolated! Run this command to start Ralph:${NC}"
  echo ""

  _ralph_output_worktree_command "$worktree_path" "${ralph_args[@]}"

  echo ""
  echo "${CYAN}─────────────────────────────────────────────────────────────${NC}"
  echo ""
  echo "When done, run ${BOLD}ralph-cleanup${NC} from the worktree to merge back."
  echo ""
}

# Detect package manager based on lock files
_ralph_detect_package_manager() {
  local dir="$1"

  if [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
    echo "bun"
  elif [[ -f "$dir/pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$dir/yarn.lock" ]]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

# Process .worktree-sync.json for custom sync rules
_ralph_process_worktree_sync() {
  local repo_root="$1"
  local worktree_path="$2"
  local sync_config="$3"

  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local NC='\033[0m'

  # Process sync.files - additional files to copy
  local files_count=$(jq -r '.sync.files | length // 0' "$sync_config" 2>/dev/null)
  if [[ "$files_count" -gt 0 ]]; then
    local i=0
    while [[ $i -lt $files_count ]]; do
      local file=$(jq -r ".sync.files[$i]" "$sync_config" 2>/dev/null)
      if [[ -f "$repo_root/$file" ]]; then
        # Create parent directory if needed
        local parent_dir=$(dirname "$file")
        if [[ "$parent_dir" != "." ]]; then
          mkdir -p "$worktree_path/$parent_dir"
        fi
        cp "$repo_root/$file" "$worktree_path/$file"
        echo "${GREEN}✓ Copied $file${NC}"
      elif [[ -d "$repo_root/$file" ]]; then
        # Create parent directory if needed for directories too
        local parent_dir=$(dirname "$file")
        if [[ "$parent_dir" != "." ]]; then
          mkdir -p "$worktree_path/$parent_dir"
        fi
        cp -r "$repo_root/$file" "$worktree_path/$file"
        echo "${GREEN}✓ Copied $file/${NC}"
      else
        echo "${YELLOW}⚠️  File not found: $file${NC}"
      fi
      i=$((i + 1))
    done
  fi

  # Process sync.symlinks - files to symlink instead of copy
  local symlinks_count=$(jq -r '.sync.symlinks | length // 0' "$sync_config" 2>/dev/null)
  if [[ "$symlinks_count" -gt 0 ]]; then
    local i=0
    while [[ $i -lt $symlinks_count ]]; do
      local file=$(jq -r ".sync.symlinks[$i]" "$sync_config" 2>/dev/null)
      if [[ -e "$repo_root/$file" ]]; then
        # Create parent directory if needed
        local parent_dir=$(dirname "$file")
        if [[ "$parent_dir" != "." ]]; then
          mkdir -p "$worktree_path/$parent_dir"
        fi
        ln -s "$repo_root/$file" "$worktree_path/$file"
        echo "${GREEN}✓ Symlinked $file${NC}"
      else
        echo "${YELLOW}⚠️  Path not found for symlink: $file${NC}"
      fi
      i=$((i + 1))
    done
  fi
}

# Run post-setup commands from .worktree-sync.json
_ralph_run_sync_commands() {
  local worktree_path="$1"
  local sync_config="$2"

  local GREEN='\033[0;32m'
  local RED='\033[0;31m'
  local CYAN='\033[0;36m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  local commands_count=$(jq -r '.sync.commands | length // 0' "$sync_config" 2>/dev/null)
  if [[ "$commands_count" -gt 0 ]]; then
    echo "${CYAN}${BOLD}🔧 Running post-setup commands...${NC}"
    echo ""

    local i=0
    while [[ $i -lt $commands_count ]]; do
      local cmd=$(jq -r ".sync.commands[$i]" "$sync_config" 2>/dev/null)
      echo "   Running: $cmd"
      (
        cd "$worktree_path" || exit 1
        eval "$cmd"
      )
      if [[ $? -eq 0 ]]; then
        echo "${GREEN}✓ Command succeeded${NC}"
      else
        echo "${RED}❌ Command failed${NC}"
      fi
      i=$((i + 1))
    done
    echo ""
  fi
}

# Helper to output the cd + source + ralph command
_ralph_output_worktree_command() {
  local worktree_path="$1"
  shift
  local ralph_args="$@"

  local BOLD='\033[1m'
  local NC='\033[0m'

  if [[ -n "$ralph_args" ]]; then
    echo "  ${BOLD}cd $worktree_path && source ~/.config/ralphtools/ralph.zsh && ralph $ralph_args${NC}"
  else
    echo "  ${BOLD}cd $worktree_path && source ~/.config/ralphtools/ralph.zsh && ralph${NC}"
  fi
}

# ralph-cleanup - Merge worktree changes and remove it
# Usage: ralph-cleanup [--force]
# Must be run from within a Ralph worktree
function ralph-cleanup() {
  local CYAN='\033[0;36m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local RED='\033[0;31m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  local force=false
  [[ "$1" == "--force" ]] && force=true

  # Check if we're in a worktree
  local worktree_path=$(pwd)
  local git_dir=$(git rev-parse --git-dir 2>/dev/null)

  if [[ ! "$git_dir" =~ "worktrees" ]]; then
    echo "${RED}❌ Not in a git worktree${NC}"
    echo "   Run this from within a Ralph worktree (created by ralph-start)"
    return 1
  fi

  # Get main repo path and branch info
  local main_repo=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||')
  local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

  echo ""
  echo "${CYAN}${BOLD}🧹 Ralph Cleanup${NC}"
  echo ""
  echo "   Worktree: $worktree_path"
  echo "   Main repo: $main_repo"
  echo "   Branch: $current_branch"
  echo ""

  # Check for uncommitted changes
  local git_status=$(git status --porcelain 2>/dev/null)
  if [[ -n "$git_status" ]]; then
    echo "${YELLOW}⚠️  Uncommitted changes detected:${NC}"
    git status --short
    echo ""

    if [[ "$force" != "true" ]]; then
      read -q "REPLY?Commit these changes before cleanup? (y/n) "
      echo ""
      if [[ "$REPLY" == "y" ]]; then
        git add -A
        git commit -m "Ralph session: $(date +%Y-%m-%d)"
      else
        read -q "REPLY?Discard changes and continue? (y/n) "
        echo ""
        if [[ "$REPLY" != "y" ]]; then
          return 1
        fi
      fi
    fi
  fi

  # Copy back prd-json and progress.txt (the important state)
  echo "📋 Syncing state back to main repo..."

  if [[ -d "$worktree_path/prd-json" ]]; then
    cp -r "$worktree_path/prd-json" "$main_repo/"
    echo "${GREEN}✓ Synced prd-json/${NC}"
  fi

  if [[ -f "$worktree_path/progress.txt" ]]; then
    cp "$worktree_path/progress.txt" "$main_repo/"
    echo "${GREEN}✓ Synced progress.txt${NC}"
  fi

  # Merge branch back to original
  echo ""
  echo "🔀 Merging changes to main repo..."

  # Navigate to main repo
  cd "$main_repo" || { echo "${RED}❌ Failed to cd to main repo${NC}"; return 1; }

  # Get the original branch (stored in worktree name or default to main/master)
  local target_branch=$(git branch --show-current 2>/dev/null)
  if [[ -z "$target_branch" ]]; then
    target_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi

  # Merge the worktree branch
  if [[ "$current_branch" != "$target_branch" ]]; then
    if git merge "$current_branch" --no-edit 2>/dev/null; then
      echo "${GREEN}✓ Merged $current_branch into $target_branch${NC}"
    else
      echo "${YELLOW}⚠️  Merge had conflicts or nothing to merge${NC}"
    fi
  fi

  # Remove the worktree
  echo ""
  echo "🗑️  Removing worktree..."

  git worktree remove "$worktree_path" --force 2>/dev/null

  # Delete the temporary branch
  git branch -d "$current_branch" 2>/dev/null || git branch -D "$current_branch" 2>/dev/null

  # Prune stale worktree references
  git worktree prune 2>/dev/null

  echo "${GREEN}✓ Worktree removed${NC}"
  echo ""
  echo "${GREEN}${BOLD}✅ Cleanup complete!${NC}"
  echo ""
  echo "   Your main project is at: $main_repo"
  echo "   /resume in Claude will now show clean history"
  echo ""
}

# ralph-archive [app] [--keep|--clean] - Archive completed stories to docs.local
# Flags:
#   --keep   Archive only, skip cleanup prompt
#   --clean  Archive and auto-cleanup without prompt
function ralph-archive() {
  local app=""
  local mode="prompt"  # prompt, keep, or clean
  local prd_dir
  local archive_dir="docs.local/prd-archive"

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --keep)
        mode="keep"
        ;;
      --clean)
        mode="clean"
        ;;
      -*)
        echo "❌ Unknown flag: $arg"
        echo "   Usage: ralph-archive [app] [--keep|--clean]"
        return 1
        ;;
      *)
        app="$arg"
        ;;
    esac
  done

  # Determine path
  if [[ -n "$app" ]]; then
    prd_dir="apps/$app/prd-json"
  else
    prd_dir="prd-json"
  fi

  # Check for JSON mode first, fall back to markdown
  if [[ -d "$prd_dir" ]]; then
    _ralph_archive_json "$prd_dir" "$app" "$mode"
  elif [[ -f "${prd_dir%prd-json}PRD.md" ]]; then
    _ralph_archive_md "${prd_dir%prd-json}PRD.md" "$app" "$mode"
  else
    echo "❌ PRD not found: $prd_dir or PRD.md"
    return 1
  fi
}

# Archive JSON PRD
# Usage: _ralph_archive_json <prd_dir> <app> <mode>
# mode: "prompt" (interactive), "keep" (no cleanup), "clean" (auto cleanup)
_ralph_archive_json() {
  local prd_dir="$1"
  local app="$2"
  local mode="${3:-prompt}"
  local archive_dir="docs.local/prd-archive"
  local index_file="$prd_dir/index.json"

  mkdir -p "$archive_dir"

  # Generate archive filename
  local date_suffix=$(date +%Y%m%d-%H%M%S)
  local app_prefix=""
  [[ -n "$app" ]] && app_prefix="${app}-"
  local archive_subdir="$archive_dir/${app_prefix}${date_suffix}"

  # Copy entire prd-json to archive
  mkdir -p "$archive_subdir"
  cp -r "$prd_dir"/* "$archive_subdir/"

  # Archive progress.txt if it exists
  if [[ -f "progress.txt" ]]; then
    cp "progress.txt" "$archive_subdir/"
    echo "✅ Archived progress.txt to: $archive_subdir/"
  fi

  echo "✅ Archived PRD to: $archive_subdir/"

  # Handle cleanup based on mode
  local do_cleanup=false

  case "$mode" in
    keep)
      echo "ℹ️  Keeping working PRD intact (--keep flag)"
      return 0
      ;;
    clean)
      echo "🧹 Auto-cleanup enabled (--clean flag)"
      do_cleanup=true
      ;;
    prompt)
      # Interactive prompt using gum if available, fallback to read
      if command -v gum &>/dev/null; then
        if gum confirm "Reset PRD for fresh start?" --default=false; then
          do_cleanup=true
        fi
      else
        read -q "REPLY?Reset PRD for fresh start? (y/n) "
        echo ""
        [[ "$REPLY" == "y" ]] && do_cleanup=true
      fi
      ;;
  esac

  if [[ "$do_cleanup" == "true" ]]; then
    _ralph_archive_cleanup "$prd_dir" "$index_file"
  fi
}

# Cleanup completed stories and reset PRD
_ralph_archive_cleanup() {
  local prd_dir="$1"
  local index_file="$2"

  echo ""
  echo "🧹 Cleaning up completed stories..."

  # Find and remove completed stories
  local removed_count=0
  for story_file in "$prd_dir/stories"/*.json(N); do
    if [[ -f "$story_file" ]]; then
      if jq -e '.passes == true' "$story_file" >/dev/null 2>&1; then
        local story_id=$(basename "$story_file" .json)
        rm -f "$story_file"
        echo "   ✓ Removed: $story_id"
        ((removed_count++))
      fi
    fi
  done

  # Get remaining stories for pending and blocked
  local pending_stories=()
  local blocked_stories=()

  # Read current blocked array
  blocked_stories=($(jq -r '.blocked[]? // empty' "$index_file" 2>/dev/null))

  # Build pending array from remaining story files
  for story_file in "$prd_dir/stories"/*.json(N); do
    if [[ -f "$story_file" ]]; then
      local story_id=$(basename "$story_file" .json)
      # Check if it's in blocked array
      local is_blocked=false
      for blocked_id in "${blocked_stories[@]}"; do
        if [[ "$story_id" == "$blocked_id" ]]; then
          is_blocked=true
          break
        fi
      done
      if [[ "$is_blocked" == "false" ]]; then
        pending_stories+=("$story_id")
      fi
    fi
  done

  # Calculate totals
  local total_count=$((${#pending_stories[@]} + ${#blocked_stories[@]}))
  local pending_count=${#pending_stories[@]}
  local blocked_count=${#blocked_stories[@]}

  # Build JSON arrays
  local pending_json=$(printf '%s\n' "${pending_stories[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
  local blocked_json=$(printf '%s\n' "${blocked_stories[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
  local story_order_json=$(printf '%s\n' "${pending_stories[@]}" "${blocked_stories[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

  # Determine next story
  local next_story="null"
  if [[ ${#pending_stories[@]} -gt 0 ]]; then
    next_story="\"${pending_stories[1]}\""  # zsh arrays are 1-indexed
  fi

  # Update index.json (stats are derived on-the-fly, US-106)
  jq --argjson pending "$pending_json" \
     --argjson blocked "$blocked_json" \
     --argjson order "$story_order_json" \
     --argjson next "$next_story" '
    .storyOrder = $order |
    .pending = $pending |
    .blocked = $blocked |
    del(.stats) |
    .nextStory = $next
  ' "$index_file" > "${index_file}.tmp" && mv "${index_file}.tmp" "$index_file"

  # Create fresh progress.txt
  local progress_file="progress.txt"
  cat > "$progress_file" << EOF
# Ralph Progress - Fresh Start
Started: $(date '+%a %b %d %H:%M:%S %Z %Y')

(Previous progress archived to docs.local/prd-archive/)

EOF

  echo ""
  echo "✅ Cleanup complete!"
  echo "   • Removed $removed_count completed stories"
  echo "   • Remaining: $pending_count pending, $blocked_count blocked"
  echo "   • Fresh progress.txt created"
}

# Archive Markdown PRD (legacy)
# Usage: _ralph_archive_md <prd_path> <app> <mode>
_ralph_archive_md() {
  local prd_path="$1"
  local app="$2"
  local mode="${3:-prompt}"
  local archive_dir="docs.local/prd-archive"

  mkdir -p "$archive_dir"

  local date_suffix=$(date +%Y%m%d-%H%M%S)
  local app_prefix=""
  [[ -n "$app" ]] && app_prefix="${app}-"
  local archive_file="$archive_dir/${app_prefix}completed-${date_suffix}.md"

  echo "# Archived PRD Stories" > "$archive_file"
  echo "" >> "$archive_file"
  echo "**Archived:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$archive_file"
  [[ -n "$app" ]] && echo "**App:** $app" >> "$archive_file"
  echo "" >> "$archive_file"
  echo "---" >> "$archive_file"
  echo "" >> "$archive_file"
  cat "$prd_path" >> "$archive_file"

  # Archive progress.txt if it exists
  if [[ -f "progress.txt" ]]; then
    cp "progress.txt" "${archive_file%.md}-progress.txt"
    echo "✅ Archived progress.txt"
  fi

  echo "✅ Archived PRD to: $archive_file"

  # Handle cleanup based on mode
  local do_cleanup=false

  case "$mode" in
    keep)
      echo "ℹ️  Keeping working PRD intact (--keep flag)"
      return 0
      ;;
    clean)
      echo "🧹 Auto-cleanup enabled (--clean flag)"
      do_cleanup=true
      ;;
    prompt)
      if command -v gum &>/dev/null; then
        if gum confirm "Reset PRD for fresh start?" --default=false; then
          do_cleanup=true
        fi
      else
        read -q "REPLY?Reset PRD for fresh start? (y/n) "
        echo ""
        [[ "$REPLY" == "y" ]] && do_cleanup=true
      fi
      ;;
  esac

  if [[ "$do_cleanup" == "true" ]]; then
    local working_dir=$(grep '^\*\*Working Directory:\*\*' "$prd_path" 2>/dev/null)
    echo "# PRD: Next Sprint" > "$prd_path"
    echo "" >> "$prd_path"
    [[ -n "$working_dir" ]] && echo "$working_dir" >> "$prd_path"
    echo "**Created:** $(date +%Y-%m-%d)" >> "$prd_path"
    echo "" >> "$prd_path"
    echo "---" >> "$prd_path"
    echo "" >> "$prd_path"
    echo "## User Stories" >> "$prd_path"
    echo "" >> "$prd_path"
    echo "(Add new stories here)" >> "$prd_path"

    # Create fresh progress.txt
    cat > "progress.txt" << EOF
# Ralph Progress - Fresh Start
Started: $(date '+%a %b %d %H:%M:%S %Z %Y')

(Previous progress archived to docs.local/prd-archive/)

EOF

    echo "✅ PRD cleared for next sprint"
  fi
}

# ralph-learnings - Show detailed status of learnings in docs.local/learnings/
function ralph-learnings() {
  local BLUE='\033[0;34m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local RED='\033[0;31m'
  local CYAN='\033[0;36m'
  local GRAY='\033[0;90m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  local learnings_dir="docs.local/learnings"
  local archive_dir="docs.local/learnings-archive"
  local max_lines_per_file=200

  echo ""
  echo "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo "${BLUE}║${NC}                    📚 ${BOLD}Ralph Learnings${NC}                         ${BLUE}║${NC}"
  echo "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Check if learnings directory exists
  if [[ ! -d "$learnings_dir" ]]; then
    echo "${YELLOW}ℹ️  No learnings directory found${NC}"
    echo ""
    echo "   Create structure with:"
    echo "   ${GRAY}mkdir -p docs.local/learnings${NC}"
    echo "   ${GRAY}touch docs.local/learnings/example-topic.md${NC}"
    echo ""
    echo "   Or run ${CYAN}/prd${NC} skill which creates this automatically"
    return 0
  fi

  # Count files and total lines
  local file_count=$(find "$learnings_dir" -name "*.md" -type f | wc -l | tr -d ' ')
  local total_lines=0
  local total_tags=0
  local large_files=()
  local all_tags=()

  # Process each file
  for file in "$learnings_dir"/*.md(N); do
    if [[ -f "$file" ]]; then
      local basename=$(basename "$file")
      local title="${basename%.md}"
      local lines=$(wc -l < "$file" | tr -d ' ')
      local modified=$(stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1)
      total_lines=$((total_lines + lines))

      # Extract tags (#tag format)
      local tags=$(grep -oE '#[a-zA-Z0-9_-]+' "$file" 2>/dev/null | sort -u | tr '\n' ' ')
      local tag_count=$(echo "$tags" | wc -w | tr -d ' ')
      total_tags=$((total_tags + tag_count))

      # Extract first heading or first non-empty line as description
      local desc=$(grep -E '^#+ ' "$file" 2>/dev/null | head -1 | sed 's/^#* //')
      [[ -z "$desc" ]] && desc=$(grep -v '^$' "$file" 2>/dev/null | head -1 | cut -c1-50)

      # Status icon
      local status_icon="${GREEN}✓${NC}"
      if [[ "$lines" -gt "$max_lines_per_file" ]]; then
        status_icon="${YELLOW}⚠${NC}"
        large_files+=("$file")
      fi

      # Display file info
      echo "$status_icon ${CYAN}${BOLD}$title${NC}"
      echo "   ${GRAY}$lines lines${NC} │ ${GRAY}modified: $modified${NC}"
      [[ -n "$tags" ]] && echo "   ${YELLOW}$tags${NC}"
      [[ -n "$desc" ]] && echo "   ${GRAY}\"$desc\"${NC}"
      echo ""

      # Collect all tags
      for tag in $(echo "$tags"); do
        all_tags+=("$tag")
      done
    fi
  done

  # Summary section
  echo "${BLUE}───────────────────────────────────────────────────────────────${NC}"
  echo "${CYAN}📊 Summary${NC}"
  echo "   📁 Files: ${BOLD}$file_count${NC}"
  echo "   📝 Lines: ${BOLD}$total_lines${NC}"
  echo "   🏷️  Tags:  ${BOLD}$total_tags${NC}"
  echo ""

  # Show unique tags across all files
  if [[ ${#all_tags[@]} -gt 0 ]]; then
    local unique_tags=$(printf '%s\n' "${all_tags[@]}" | sort -u | tr '\n' ' ')
    echo "${CYAN}🏷️  All Tags:${NC}"
    echo "   ${YELLOW}$unique_tags${NC}"
    echo ""
    echo "   ${GRAY}Search: grep -r \"#tagname\" docs.local/learnings/${NC}"
    echo ""
  fi

  # Archive prompt for large files
  if [[ ${#large_files[@]} -gt 0 ]]; then
    echo "${YELLOW}⚠️  ${#large_files[@]} file(s) exceed $max_lines_per_file lines${NC}"
    echo ""
    read -q "REPLY?Archive large files? (y/n) "
    echo ""

    if [[ "$REPLY" == "y" ]]; then
      mkdir -p "$archive_dir"
      local month=$(date +%Y-%m)

      for file in "${large_files[@]}"; do
        local basename=$(basename "$file")
        local archive_file="$archive_dir/${month}-${basename}"
        cp "$file" "$archive_file"

        local keep_lines=50
        echo "# ${basename%.md}" > "$file.new"
        echo "" >> "$file.new"
        echo "(Older content archived to $archive_dir/)" >> "$file.new"
        echo "" >> "$file.new"
        echo "---" >> "$file.new"
        echo "" >> "$file.new"
        tail -n $keep_lines "$file" >> "$file.new"
        mv "$file.new" "$file"

        echo "  ${GREEN}✅${NC} Archived: $basename → $archive_file"
      done
    fi
  else
    echo "${GREEN}✅ All files within limits${NC}"
  fi
  echo ""

  # Interactive menu
  echo "${BLUE}───────────────────────────────────────────────────────────────${NC}"
  echo "${CYAN}🎛️  Actions:${NC}"
  echo "   ${BOLD}[a]${NC} Analyze with Claude (find patterns, suggest CLAUDE.md promotions)"
  echo "   ${BOLD}[s]${NC} Search by tag"
  echo "   ${BOLD}[p]${NC} Promote a learning to CLAUDE.md"
  echo "   ${BOLD}[q]${NC} Quit"
  echo ""
  read -k1 "action?Choose action: "
  echo ""

  case "$action" in
    a|A)
      echo ""
      echo "${CYAN}🤖 Analyzing learnings with Claude...${NC}"
      echo ""
      ralph-learnings-analyze
      ;;
    s|S)
      echo ""
      read "tag?Enter tag to search (without #): "
      echo ""
      echo "${CYAN}🔍 Searching for #$tag...${NC}"
      echo ""
      grep -rn --color=always "#$tag" "$learnings_dir" 2>/dev/null || echo "${YELLOW}No matches found${NC}"
      echo ""
      ;;
    p|P)
      echo ""
      echo "${CYAN}📤 Promote learning to CLAUDE.md${NC}"
      echo ""
      echo "Available files:"
      local i=1
      for file in "$learnings_dir"/*.md(N); do
        echo "   ${BOLD}[$i]${NC} $(basename "$file")"
        i=$((i + 1))
      done
      echo ""
      read "choice?Select file number: "
      local files=("$learnings_dir"/*.md(N))
      if [[ "$choice" -gt 0 && "$choice" -le ${#files[@]} ]]; then
        local selected_file="${files[$choice]}"
        echo ""
        echo "${CYAN}Opening $selected_file for review...${NC}"
        echo "${GRAY}Add relevant content to CLAUDE.md manually, then mark as [PROMOTED] in the learning file.${NC}"
        echo ""
        cat "$selected_file"
      fi
      ;;
    q|Q|*)
      ;;
  esac
}

# ralph-learnings-analyze - Run Claude to analyze learnings and suggest promotions
function ralph-learnings-analyze() {
  local learnings_dir="docs.local/learnings"
  local claude_md="CLAUDE.md"
  local CYAN='\033[0;36m'
  local YELLOW='\033[1;33m'
  local NC='\033[0m'

  if [[ ! -d "$learnings_dir" ]]; then
    echo "${YELLOW}No learnings directory found at $learnings_dir${NC}"
    return 1
  fi

  local file_count=$(find "$learnings_dir" -name '*.md' -type f | wc -l | tr -d ' ')
  echo "${CYAN}📚 Analyzing $file_count learning file(s)...${NC}"
  echo ""

  # Build the full prompt directly (avoid sed issues with special chars)
  local prompt_file=$(mktemp)

  # Write header
  cat > "$prompt_file" << 'EOF'
You are analyzing project learnings to help organize and promote important patterns.

## Your Task

1. **Find Patterns**: Look for repeated learnings across files (same problem solved multiple times)
2. **Identify Promotions**: Which learnings are important enough to add to CLAUDE.md as permanent rules?
3. **Suggest Consolidation**: Which learnings files could be merged or reorganized?
4. **Flag Stale Content**: Any learnings that seem outdated or superseded?

## Current CLAUDE.md Content
```
EOF

  # Append CLAUDE.md content safely
  if [[ -f "$claude_md" ]]; then
    cat "$claude_md" >> "$prompt_file"
  else
    echo "(No CLAUDE.md found)" >> "$prompt_file"
  fi

  # Continue prompt
  cat >> "$prompt_file" << 'EOF'
```

## Learnings Files

EOF

  # Append each learning file
  for file in "$learnings_dir"/*.md(N); do
    if [[ -f "$file" ]]; then
      local basename=$(basename "$file")
      echo "=== FILE: $basename ===" >> "$prompt_file"
      cat "$file" >> "$prompt_file"
      echo "" >> "$prompt_file"
    fi
  done

  # Add output format
  cat >> "$prompt_file" << 'EOF'

## Output Format

### 🔄 Repeated Patterns Found
- [pattern]: found in [files]

### 📤 Recommended for CLAUDE.md Promotion
1. **[Learning Name]** from [file]
   - Why: [reason]
   - Suggested CLAUDE.md section: [section name]
   - Content to add:
   ```
   [exact text to add]
   ```

### 🗂️ Consolidation Suggestions
- Merge [file1] and [file2] because [reason]

### 🗑️ Potentially Stale
- [file]: [reason it might be outdated]

### ✅ Summary
- X learnings analyzed
- X recommended for promotion
- X consolidation opportunities
EOF

  # Run Claude with the full prompt file
  cat "$prompt_file" | claude --print "Analyze these project learnings and suggest which should be promoted to CLAUDE.md. Look for patterns, repetition, and important rules that should be permanent."

  rm -f "$prompt_file"
}

# ralph-live - DEPRECATED: Live updates now built into ralph command
# The main ralph command now uses file watching for live progress updates
# Use --no-live flag to disable if needed
function ralph-live() {
  echo ""
  echo -e "${RALPH_COLOR_YELLOW}⚠️  ralph-live is deprecated. Live progress updates are now built into 'ralph'.${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_GRAY}   The main ralph loop uses file watching (fswatch) to update progress bars in-place.${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_GRAY}   Use 'ralph-status' for a one-time status snapshot, or 'ralph --no-live' to disable updates.${RALPH_COLOR_RESET}"
  echo ""
  ralph-status "$@"
}

# ralph-status - Show detailed status of all Ralph PRDs
function ralph-status() {
  local BLUE='\033[0;34m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local RED='\033[0;31m'
  local CYAN='\033[0;36m'
  local GRAY='\033[0;90m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  echo ""
  echo "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo "${BLUE}║${NC}                    📋 ${BOLD}Ralph PRD Status${NC}                        ${BLUE}║${NC}"
  echo "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Check for JSON mode first
  if [[ -f "prd-json/index.json" ]]; then
    _ralph_show_prd_json "prd-json" "📁 prd-json/ (JSON mode)"
  elif [[ -f "PRD.md" ]]; then
    _ralph_show_prd "PRD.md" "📁 Root PRD.md"
  fi

  # Check app-specific PRDs (markdown only for now)
  for app in expo public admin frontend backend mobile; do
    if [[ -f "apps/$app/prd-json/index.json" ]]; then
      _ralph_show_prd_json "apps/$app/prd-json" "📱 apps/$app/prd-json/"
    elif [[ -f "apps/$app/PRD.md" ]]; then
      local branch_info=""
      if git show-ref --verify --quiet "refs/heads/feat/${app}-work" 2>/dev/null; then
        branch_info="  ${GREEN}🌿 feat/${app}-work${NC}"
      fi
      _ralph_show_prd "apps/$app/PRD.md" "📱 apps/$app/PRD.md$branch_info"
    fi
  done

  # Current Iteration info
  echo "${BLUE}───────────────────────────────────────────────────────────────${NC}"

  # Check if Ralph is currently running
  local ralph_running=$(pgrep -f "tee /tmp/ralph_output" 2>/dev/null | head -1)
  if [[ -n "$ralph_running" ]]; then
    echo "${GREEN}🔄 Ralph is currently running (PID: $ralph_running)${NC}"
  else
    echo "${GRAY}Ralph is not running. Use 'ralph [N]' to start.${NC}"
  fi
  echo ""
}

# Helper function to show PRD status from JSON
_ralph_show_prd_json() {
  local json_dir="$1"
  local label="$2"
  local index_file="$json_dir/index.json"

  [[ ! -f "$index_file" ]] && return

  # Derive stats on-the-fly (US-106)
  local derived_stats=$(_ralph_derive_stats "$json_dir")
  local pending=$(echo "$derived_stats" | awk '{print $1}')
  local blocked=$(echo "$derived_stats" | awk '{print $2}')
  local done=$(echo "$derived_stats" | awk '{print $3}')
  local total=$(echo "$derived_stats" | awk '{print $4}')
  local next_story=$(jq -r '.nextStory // "none"' "$index_file" 2>/dev/null)
  local percent=0
  [[ "$total" -gt 0 ]] && percent=$((done * 100 / total))
  # Cap percentage at 100% (defensive guard)
  (( percent > 100 )) && percent=100

  # Progress bar (30 chars)
  local bar_filled=$((percent * 30 / 100))
  local bar_empty=$((30 - bar_filled))
  local progress_bar="${GREEN}"
  for ((i=0; i<bar_filled; i++)); do progress_bar+="█"; done
  progress_bar+="${GRAY}"
  for ((i=0; i<bar_empty; i++)); do progress_bar+="░"; done
  progress_bar+="${NC}"

  echo "${CYAN}${BOLD}$label${NC}"
  echo "   ${progress_bar} ${BOLD}${percent}%${NC}"
  echo "   ${GREEN}✅ $done${NC} completed  │  ${YELLOW}⏳ $pending${NC} pending  │  ${RED}🚫 $blocked${NC} blocked  │  📊 $total total"
  echo ""

  # Show blocked stories
  local blocked_list=$(jq -r '.blocked[]?.id // empty' "$index_file" 2>/dev/null)
  if [[ -n "$blocked_list" ]]; then
    echo "   ${RED}🚫 BLOCKED:${NC}"
    while IFS= read -r story_id; do
      local reason=$(jq -r --arg id "$story_id" '.blocked[] | select(.id == $id) | .reason // "unknown"' "$index_file" 2>/dev/null)
      echo "      ${RED}•${NC} $story_id: ${GRAY}$reason${NC}"
    done <<< "$blocked_list"
    echo ""
  fi

  # Show next story with acceptance criteria checklist
  if [[ "$next_story" != "none" && "$next_story" != "null" ]]; then
    local story_file="$json_dir/stories/${next_story}.json"
    if [[ -f "$story_file" ]]; then
      local story_title=$(jq -r '.title // "Untitled"' "$story_file" 2>/dev/null)
      local total_criteria=$(jq '.acceptanceCriteria | length' "$story_file" 2>/dev/null)
      local done_criteria=$(jq '[.acceptanceCriteria[] | select(.checked == true)] | length' "$story_file" 2>/dev/null)
      echo "   ${GREEN}▶ CURRENT STORY:${NC} ${BOLD}$next_story${NC}"
      echo "      ${story_title}"
      echo "      ${CYAN}Progress: $done_criteria/$total_criteria criteria${NC}"
      echo ""
      # Show each acceptance criterion with checkbox
      jq -r '.acceptanceCriteria[] | if .checked then "      \u001b[32m✓\u001b[0m " + .text else "      \u001b[90m○\u001b[0m " + .text end' "$story_file" 2>/dev/null
      echo ""
    fi
  fi

  # Show pending stories (up to 8)
  echo "   ${YELLOW}📝 Pending Stories:${NC}"
  local pending_list=$(jq -r '.pending[]? // empty' "$index_file" 2>/dev/null)
  local story_num=0
  while IFS= read -r story_id; do
    [[ -z "$story_id" ]] && continue
    story_num=$((story_num + 1))
    local story_file="$json_dir/stories/${story_id}.json"
    local story_title="Unknown"
    local criteria_count=0
    if [[ -f "$story_file" ]]; then
      story_title=$(jq -r '.title // "Untitled"' "$story_file" 2>/dev/null)
      criteria_count=$(jq '[.acceptanceCriteria[] | select(.checked == false)] | length' "$story_file" 2>/dev/null)
    fi
    if [[ "$story_num" -le 8 ]]; then
      echo "      ${GRAY}$story_num.${NC} $story_id: $story_title ${GRAY}[$criteria_count]${NC}"
    fi
  done <<< "$pending_list"

  if [[ "$story_num" -gt 8 ]]; then
    echo "      ${GRAY}... and $((story_num - 8)) more pending stories${NC}"
  fi
  [[ "$story_num" -eq 0 ]] && echo "      ${GREEN}🎉 All stories complete!${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# RALPH-PROJECTS - Manage projects registry
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph-projects [add|remove|list] [args]
# Manage projects in ~/.config/ralphtools/projects.json
# ═══════════════════════════════════════════════════════════════════

function ralph-projects() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local NC='\033[0m'
  local projects_file="$HOME/.config/ralphtools/projects.json"
  local subcommand="${1:-list}"

  case "$subcommand" in
    add)
      if [[ $# -lt 3 ]]; then
        echo "Usage: ralph-projects add <name> <path> [--mcps figma,linear,...]"
        echo ""
        echo "Supported MCPs: figma, linear, supabase, browser-tools, context7"
        return 1
      fi

      local name="$2"
      local path="$3"
      local mcps_arg=""

      # Parse optional --mcps flag
      shift 3
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --mcps)
            mcps_arg="$2"
            shift 2
            ;;
          *)
            echo "${RED}Unknown option: $1${NC}"
            return 1
            ;;
        esac
      done

      # Validate path exists
      if [[ ! -d "$path" ]]; then
        echo "${RED}Error: Path does not exist: $path${NC}"
        return 1
      fi

      # Initialize projects.json if it doesn't exist
      if [[ ! -f "$projects_file" ]]; then
        echo '{"projects": []}' > "$projects_file"
      fi

      # Check if project already exists
      local existing=$(/usr/bin/jq -r ".projects[] | select(.name==\"$name\") | .name" "$projects_file" 2>/dev/null)
      if [[ -n "$existing" ]]; then
        echo "${RED}Error: Project '$name' already exists${NC}"
        return 1
      fi

      # Add new project
      local timestamp=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")

      # Convert comma-separated MCPs to JSON array
      local mcps_json="[]"
      if [[ -n "$mcps_arg" ]]; then
        # Split by comma and build JSON array
        mcps_json="[$(echo "$mcps_arg" | /usr/bin/tr ',' '\n' | /usr/bin/sed 's/^/"/;s/$/"/' | /usr/bin/tr '\n' ',' | /usr/bin/sed 's/,$//')]]"
        # Fix the double bracket from sed
        mcps_json="${mcps_json%]}"
      fi

      /usr/bin/jq ".projects += [{\"name\": \"$name\", \"path\": \"$path\", \"mcps\": $mcps_json, \"created\": \"$timestamp\"}]" "$projects_file" > "${projects_file}.tmp"
      /bin/mv "${projects_file}.tmp" "$projects_file"

      echo "${GREEN}✓ Project '$name' added${NC}"
      if [[ -n "$mcps_arg" ]]; then
        echo "  MCPs: $mcps_arg"
      fi

      # Regenerate launcher functions
      _ralph_generate_launchers
      ;;

    remove)
      if [[ $# -lt 2 ]]; then
        echo "Usage: ralph-projects remove <name>"
        return 1
      fi

      local name="$2"

      if [[ ! -f "$projects_file" ]]; then
        echo "${RED}Error: No projects registered${NC}"
        return 1
      fi

      # Check if project exists
      local existing=$(/usr/bin/jq -r ".projects[] | select(.name==\"$name\") | .name" "$projects_file" 2>/dev/null)
      if [[ -z "$existing" ]]; then
        echo "${RED}Error: Project '$name' not found${NC}"
        return 1
      fi

      # Remove project
      /usr/bin/jq ".projects |= map(select(.name != \"$name\"))" "$projects_file" > "${projects_file}.tmp"
      /bin/mv "${projects_file}.tmp" "$projects_file"

      echo "${GREEN}✓ Project '$name' removed${NC}"

      # Regenerate launcher functions
      _ralph_generate_launchers
      ;;

    list)
      if [[ ! -f "$projects_file" ]]; then
        echo "No projects registered"
        return 0
      fi

      local count=$(/usr/bin/jq '.projects | length' "$projects_file" 2>/dev/null || echo "0")
      if [[ "$count" -eq 0 ]]; then
        echo "No projects registered"
        return 0
      fi

      echo "Registered projects:"
      /usr/bin/jq -r '.projects[] | "  \(.name)\n    Path: \(.path)\n    MCPs: \(if .mcps | length > 0 then (.mcps | join(", ")) else "(none)" end)\n    Created: \(.created)"' "$projects_file"
      ;;

    *)
      echo "Usage: ralph-projects [add|remove|list]"
      echo ""
      echo "Subcommands:"
      echo "  add <name> <path> [--mcps figma,linear,...]  - Add a new project"
      echo "  remove <name>                                 - Remove a project"
      echo "  list                                          - List all registered projects"
      echo ""
      echo "Supported MCPs: figma, linear, supabase, browser-tools, context7"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
# SECRETS MANAGEMENT - 1Password integration for project secrets
# ═══════════════════════════════════════════════════════════════════
# ralph-secrets setup            - Configure 1Password vault
# ralph-secrets status           - Show 1Password configuration and sign-in status
# ralph-secrets migrate <.env>   - Migrate .env file secrets to 1Password
# ═══════════════════════════════════════════════════════════════════

# SERVICE_PREFIXES: Map env var prefixes to service names
# Used by _ralph_detect_service() to auto-categorize secrets
typeset -gA RALPH_SERVICE_PREFIXES
RALPH_SERVICE_PREFIXES[ANTHROPIC]=anthropic
RALPH_SERVICE_PREFIXES[OPENAI]=openai
RALPH_SERVICE_PREFIXES[SUPABASE]=supabase
RALPH_SERVICE_PREFIXES[VERCEL]=vercel
RALPH_SERVICE_PREFIXES[AWS]=aws
RALPH_SERVICE_PREFIXES[STRIPE]=stripe
RALPH_SERVICE_PREFIXES[DATABASE]=db
RALPH_SERVICE_PREFIXES[DB]=db
RALPH_SERVICE_PREFIXES[REDIS]=redis
RALPH_SERVICE_PREFIXES[GITHUB]=github
RALPH_SERVICE_PREFIXES[LINEAR]=linear
RALPH_SERVICE_PREFIXES[FIGMA]=figma
RALPH_SERVICE_PREFIXES[TWILIO]=twilio
RALPH_SERVICE_PREFIXES[SENDGRID]=sendgrid
RALPH_SERVICE_PREFIXES[SLACK]=slack
RALPH_SERVICE_PREFIXES[FIREBASE]=firebase
RALPH_SERVICE_PREFIXES[GOOGLE]=google
RALPH_SERVICE_PREFIXES[AZURE]=azure
RALPH_SERVICE_PREFIXES[CLOUDFLARE]=cloudflare
RALPH_SERVICE_PREFIXES[POSTGRES]=db
RALPH_SERVICE_PREFIXES[MYSQL]=db
RALPH_SERVICE_PREFIXES[MONGO]=db
RALPH_SERVICE_PREFIXES[MONGODB]=db

# GLOBAL_VARS: Variables that are truly global (not project-specific)
# These go to _global/{service}/{key} instead of {project}/{service}/{key}
typeset -ga RALPH_GLOBAL_VARS
RALPH_GLOBAL_VARS=(
  "EDITOR"
  "VISUAL"
  "GIT_AUTHOR_NAME"
  "GIT_AUTHOR_EMAIL"
  "GIT_COMMITTER_NAME"
  "GIT_COMMITTER_EMAIL"
  "PATH"
  "HOME"
  "USER"
  "SHELL"
  "TERM"
  "LANG"
  "LC_ALL"
)

# _ralph_detect_service: Detect service name from env var key
# Arguments: $1 = key name (e.g., ANTHROPIC_API_KEY)
# Returns: service name (e.g., anthropic) or 'misc' if no match
function _ralph_detect_service() {
  local key="$1"
  local prefix=""

  # Try each known prefix (longest match first by iterating)
  for p in "${(@k)RALPH_SERVICE_PREFIXES}"; do
    if [[ "$key" == ${p}_* || "$key" == ${p} ]]; then
      # Check if this is a longer match than current
      if [[ ${#p} -gt ${#prefix} ]]; then
        prefix="$p"
      fi
    fi
  done

  if [[ -n "$prefix" ]]; then
    echo "${RALPH_SERVICE_PREFIXES[$prefix]}"
  else
    echo "misc"
  fi
}

# _ralph_normalize_key: Strip service prefix from key
# Arguments: $1 = key name (e.g., ANTHROPIC_API_KEY)
# Returns: normalized key (e.g., API_KEY) or original if no prefix
function _ralph_normalize_key() {
  local key="$1"
  local prefix=""

  # Find matching prefix
  for p in "${(@k)RALPH_SERVICE_PREFIXES}"; do
    if [[ "$key" == ${p}_* ]]; then
      if [[ ${#p} -gt ${#prefix} ]]; then
        prefix="$p"
      fi
    fi
  done

  if [[ -n "$prefix" ]]; then
    # Strip prefix and underscore
    echo "${key#${prefix}_}"
  else
    echo "$key"
  fi
}

# _ralph_is_global_var: Check if var is in GLOBAL_VARS list
# Arguments: $1 = key name
# Returns: 0 if global, 1 if not
function _ralph_is_global_var() {
  local key="$1"
  for gv in "${RALPH_GLOBAL_VARS[@]}"; do
    if [[ "$key" == "$gv" ]]; then
      return 0
    fi
    # Also check for prefix match (GIT_* matches GIT_AUTHOR_NAME, etc.)
    if [[ "$gv" == *"_" && "$key" == ${gv}* ]]; then
      return 0
    fi
  done
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# 1PASSWORD ENVIRONMENT DETECTION
# Check if 1Password Environments are configured in a project
# Looks for .env.1password files or op:// references in env files
# ═══════════════════════════════════════════════════════════════════

# Returns 0 if 1Password Environments are configured, 1 if not
function _ralph_check_op_environments() {
  local project_path="${1:-.}"

  # Check for .env.1password file
  if [[ -f "$project_path/.env.1password" ]]; then
    return 0
  fi

  # Check for op:// references in common env files
  local env_files=(".env" ".env.local" ".env.development" ".env.production" ".env.example")
  for env_file in "${env_files[@]}"; do
    if [[ -f "$project_path/$env_file" ]]; then
      if grep -q "op://" "$project_path/$env_file" 2>/dev/null; then
        return 0
      fi
    fi
  done

  # Check for op:// in package.json scripts (some projects use this pattern)
  if [[ -f "$project_path/package.json" ]]; then
    if grep -q "op://" "$project_path/package.json" 2>/dev/null; then
      return 0
    fi
  fi

  # Not configured
  return 1
}

# ═══════════════════════════════════════════════════════════════════
# SECRETS MANAGEMENT - 1Password integration
# ═══════════════════════════════════════════════════════════════════

function ralph-secrets() {
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local NC='\033[0m'
  local config_file="$HOME/.config/ralphtools/config.json"
  local subcommand="${1:-status}"

  # Helper function: Check if op CLI is installed
  _ralph_check_op_cli() {
    if ! command -v op &>/dev/null; then
      echo "${RED}Error: 1Password CLI (op) is not installed${NC}"
      echo ""
      echo "Install with:"
      echo "  brew install 1password-cli"
      echo ""
      echo "Or download from:"
      echo "  https://1password.com/downloads/command-line/"
      return 1
    fi
    return 0
  }

  # Helper function: Check if user is signed into 1Password
  _ralph_check_op_signin() {
    if ! op account list &>/dev/null; then
      echo "${RED}Error: Not signed into 1Password${NC}"
      echo ""
      echo "Sign in with:"
      echo "  eval \$(op signin)"
      echo ""
      echo "Or if using biometric unlock:"
      echo "  op signin"
      return 1
    fi
    return 0
  }

  case "$subcommand" in
    setup)
      echo ""
      echo "┌─────────────────────────────────────────────────────────────┐"
      echo "│  🔐 Ralph Secrets Setup (1Password)                         │"
      echo "└─────────────────────────────────────────────────────────────┘"
      echo ""

      # Check op CLI is installed
      if ! _ralph_check_op_cli; then
        return 1
      fi
      echo "${GREEN}✓ 1Password CLI installed${NC}"

      # Check user is signed in
      if ! _ralph_check_op_signin; then
        return 1
      fi
      echo "${GREEN}✓ Signed into 1Password${NC}"
      echo ""

      # Get available vaults
      echo "📁 Available vaults:"
      local vaults
      vaults=$(op vault list --format=json 2>/dev/null | /usr/bin/jq -r '.[].name')
      if [[ -z "$vaults" ]]; then
        echo "${RED}Error: No vaults found${NC}"
        return 1
      fi

      local vault_array=()
      while IFS= read -r vault; do
        vault_array+=("$vault")
        echo "   - $vault"
      done <<< "$vaults"
      echo ""

      local selected_vault=""

      # Select vault
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        echo "Select vault to use for Ralph secrets:"
        selected_vault=$(gum choose "${vault_array[@]}")
      else
        echo "Enter vault name to use for Ralph secrets:"
        echo -n "   Vault name: "
        read selected_vault
        # Validate vault exists
        local vault_exists=false
        for v in "${vault_array[@]}"; do
          if [[ "$v" == "$selected_vault" ]]; then
            vault_exists=true
            break
          fi
        done
        if ! $vault_exists; then
          echo "${RED}Error: Vault '$selected_vault' not found${NC}"
          return 1
        fi
      fi

      echo ""
      echo "${GREEN}✓ Selected vault: $selected_vault${NC}"
      echo ""

      # Update config.json with secrets configuration
      # Ensure config file exists
      if [[ ! -f "$config_file" ]]; then
        mkdir -p "$HOME/.config/ralphtools"
        echo '{}' > "$config_file"
      fi

      # Add secrets section to config using jq
      /usr/bin/jq ".secrets = {\"provider\": \"1password\", \"vault\": \"$selected_vault\"}" "$config_file" > "${config_file}.tmp"
      /bin/mv "${config_file}.tmp" "$config_file"

      echo "✅ Secrets configuration saved!"
      echo ""
      echo "   Provider: 1password"
      echo "   Vault: $selected_vault"
      echo ""
      echo "Ralph will now look for credentials in this vault."
      ;;

    status)
      echo ""
      echo "┌─────────────────────────────────────────────────────────────┐"
      echo "│  🔐 Ralph Secrets Status                                    │"
      echo "└─────────────────────────────────────────────────────────────┘"
      echo ""

      # Check op CLI
      echo "1Password CLI:"
      if command -v op &>/dev/null; then
        local op_version
        op_version=$(op --version 2>/dev/null || echo "unknown")
        echo "   ${GREEN}✓ Installed (version $op_version)${NC}"
      else
        echo "   ${RED}✗ Not installed${NC}"
        echo "     Install with: brew install 1password-cli"
        return 0
      fi

      # Check sign-in status
      echo ""
      echo "Sign-in Status:"
      if op account list &>/dev/null; then
        local account
        account=$(op account list --format=json 2>/dev/null | /usr/bin/jq -r '.[0].email // "Unknown"')
        echo "   ${GREEN}✓ Signed in as: $account${NC}"
      else
        echo "   ${RED}✗ Not signed in${NC}"
        echo "     Sign in with: eval \$(op signin)"
        return 0
      fi

      # Check config
      echo ""
      echo "Ralph Configuration:"
      if [[ -f "$config_file" ]]; then
        local provider
        local vault
        provider=$(/usr/bin/jq -r '.secrets.provider // "not configured"' "$config_file" 2>/dev/null)
        vault=$(/usr/bin/jq -r '.secrets.vault // "not configured"' "$config_file" 2>/dev/null)

        if [[ "$provider" != "not configured" && "$provider" != "null" ]]; then
          echo "   ${GREEN}✓ Provider: $provider${NC}"
          echo "   ${GREEN}✓ Vault: $vault${NC}"

          # Check if vault exists
          if op vault get "$vault" &>/dev/null; then
            echo "   ${GREEN}✓ Vault accessible${NC}"
          else
            echo "   ${YELLOW}⚠ Vault '$vault' not accessible${NC}"
          fi
        else
          echo "   ${YELLOW}⚠ Not configured${NC}"
          echo "     Run: ralph-secrets setup"
        fi
      else
        echo "   ${YELLOW}⚠ No config file found${NC}"
        echo "     Run: ralph-secrets setup"
      fi
      ;;

    migrate)
      local env_path=""
      local dry_run=false
      local service_override=""
      shift # remove 'migrate' from args

      # Parse arguments
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run)
            dry_run=true
            shift
            ;;
          --service)
            if [[ -n "$2" && "$2" != -* ]]; then
              service_override="$2"
              shift 2
            else
              echo "${RED}Error: --service requires a service name${NC}"
              return 1
            fi
            ;;
          -*)
            echo "${RED}Error: Unknown option: $1${NC}"
            echo "Usage: ralph-secrets migrate <.env path> [--dry-run] [--service <name>]"
            return 1
            ;;
          *)
            if [[ -z "$env_path" ]]; then
              env_path="$1"
            fi
            shift
            ;;
        esac
      done

      echo ""
      echo "┌─────────────────────────────────────────────────────────────┐"
      echo "│  🔐 Ralph Secrets Migration                                 │"
      echo "└─────────────────────────────────────────────────────────────┘"
      echo ""

      if $dry_run; then
        echo "${YELLOW}[DRY RUN MODE - No changes will be made]${NC}"
        echo ""
      fi

      # Validate .env path provided
      if [[ -z "$env_path" ]]; then
        echo "${RED}Error: .env file path required${NC}"
        echo ""
        echo "Usage: ralph-secrets migrate <.env path> [--dry-run] [--service <name>]"
        echo ""
        echo "Examples:"
        echo "  ralph-secrets migrate .env"
        echo "  ralph-secrets migrate ~/myproject/.env --dry-run"
        echo "  ralph-secrets migrate .env --service backend"
        return 1
      fi

      # Validate file exists
      if [[ ! -f "$env_path" ]]; then
        echo "${RED}Error: File not found: $env_path${NC}"
        return 1
      fi

      # Check op CLI
      if ! _ralph_check_op_cli; then
        return 1
      fi

      # Check signed in
      if ! _ralph_check_op_signin; then
        return 1
      fi

      # Get configured vault from config
      local vault=""
      if [[ -f "$config_file" ]]; then
        vault=$(/usr/bin/jq -r '.secrets.vault // ""' "$config_file" 2>/dev/null)
      fi

      if [[ -z "$vault" || "$vault" == "null" ]]; then
        echo "${RED}Error: No vault configured${NC}"
        echo "Run: ralph-secrets setup"
        return 1
      fi

      echo "📁 Source: $env_path"
      echo "🔐 Target vault: $vault"
      echo ""

      # Parse .env file and count secrets
      local secrets_count=0
      local migrated_count=0
      local skipped_count=0
      local overwritten_count=0
      local env_template=""

      # Get the project name from the .env path (parent directory name)
      local project_dir
      project_dir=$(/usr/bin/dirname "$env_path")
      local project_name
      project_name=$(/usr/bin/basename "$project_dir")
      if [[ "$project_name" == "." ]]; then
        project_name=$(/usr/bin/basename "$PWD")
      fi

      echo "📋 Scanning .env file..."
      echo ""

      # Read and process each line
      while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && {
          # Preserve comments in template
          env_template+="$line"$'\n'
          continue
        }

        # Extract KEY=VALUE
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
          local key="${match[1]}"
          local value="${match[2]}"

          # Remove surrounding quotes from value if present
          if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${match[1]}"
          elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${match[1]}"
          fi

          ((secrets_count++))

          # Detect service: use override if provided, else auto-detect
          local service=""
          if [[ -n "$service_override" ]]; then
            service="$service_override"
          else
            service=$(_ralph_detect_service "$key")
          fi

          # Normalize key (strip service prefix)
          local normalized_key=$(_ralph_normalize_key "$key")

          # Determine if this is a global var
          local is_global=false
          local item_prefix=""
          if _ralph_is_global_var "$key"; then
            is_global=true
            item_prefix="_global"
          else
            item_prefix="$project_name"
          fi

          # Build item name: {project|_global}/{service}/{normalized_key}
          local item_name="${item_prefix}/${service}/${normalized_key}"
          # Build op:// reference path
          local op_path="op://${vault}/${item_prefix}/${service}/${normalized_key}/password"

          echo "├─ ${YELLOW}${key}${NC}"
          if $dry_run; then
            echo "│  ├─ Service: ${service}"
            echo "│  ├─ Normalized: ${normalized_key}"
            if $is_global; then
              echo "│  ├─ Scope: global"
            else
              echo "│  ├─ Scope: project (${project_name})"
            fi
          fi

          # Check if item already exists in 1Password
          local item_exists=false
          if op item get "$item_name" --vault "$vault" &>/dev/null 2>&1; then
            item_exists=true
          fi

          if $item_exists; then
            # Prompt before overwriting (unless dry-run)
            if $dry_run; then
              echo "│  └─ Would prompt to overwrite (item exists)"
              env_template+="${key}=${op_path}"$'\n'
              ((skipped_count++))
            else
              local overwrite_choice="no"
              if [[ $RALPH_HAS_GUM -eq 0 ]]; then
                if gum confirm "Item '$item_name' already exists. Overwrite?"; then
                  overwrite_choice="yes"
                fi
              else
                echo -n "│  └─ Item exists. Overwrite? (y/n): "
                read overwrite_choice
              fi

              if [[ "$overwrite_choice" == "yes" || "$overwrite_choice" == "y" ]]; then
                # Edit existing item
                if op item edit "$item_name" --vault "$vault" "password=$value" &>/dev/null; then
                  echo "│  └─ ${GREEN}✓ Updated${NC}"
                  ((overwritten_count++))
                  ((migrated_count++))
                  env_template+="${key}=${op_path}"$'\n'
                else
                  echo "│  └─ ${RED}✗ Failed to update${NC}"
                  ((skipped_count++))
                  env_template+="${key}=${value}"$'\n'
                fi
              else
                echo "│  └─ ${YELLOW}Skipped (not overwritten)${NC}"
                ((skipped_count++))
                env_template+="${key}=${op_path}"$'\n'
              fi
            fi
          else
            # Create new item
            if $dry_run; then
              echo "│  └─ Would create: ${item_name}"
              env_template+="${key}=${op_path}"$'\n'
              ((migrated_count++))
            else
              if op item create --vault "$vault" --category "Password" --title "$item_name" "password=$value" &>/dev/null; then
                echo "│  └─ ${GREEN}✓ Created${NC}"
                ((migrated_count++))
                env_template+="${key}=${op_path}"$'\n'
              else
                echo "│  └─ ${RED}✗ Failed to create${NC}"
                ((skipped_count++))
                env_template+="${key}=${value}"$'\n'
              fi
            fi
          fi
        fi
      done < "$env_path"

      echo ""
      echo "─────────────────────────────────────────────────────────────"

      # Generate .env.template
      local template_path="${env_path}.template"
      if $dry_run; then
        echo ""
        echo "📄 Would generate: $template_path"
        echo ""
        echo "Template preview:"
        echo "─────────────────────────────────────────────────────────────"
        echo "$env_template"
        echo "─────────────────────────────────────────────────────────────"
      else
        echo "$env_template" > "$template_path"
        echo ""
        echo "${GREEN}📄 Generated: $template_path${NC}"
      fi

      echo ""
      echo "┌─────────────────────────────────────────────────────────────┐"
      echo "│  Summary                                                    │"
      echo "└─────────────────────────────────────────────────────────────┘"
      if $dry_run; then
        echo ""
        echo "   ${YELLOW}[DRY RUN - No changes made]${NC}"
      fi
      echo ""
      echo "   📊 Total secrets found: $secrets_count"
      echo "   ${GREEN}✓ Migrated to 1Password: $migrated_count${NC}"
      if [[ $overwritten_count -gt 0 ]]; then
        echo "   ${YELLOW}↻ Overwritten: $overwritten_count${NC}"
      fi
      if [[ $skipped_count -gt 0 ]]; then
        echo "   ${YELLOW}⊘ Skipped: $skipped_count${NC}"
      fi
      echo ""
      if ! $dry_run && [[ $migrated_count -gt 0 ]]; then
        echo "   To use in your project:"
        echo "   1. Copy ${template_path} to .env"
        echo "   2. Load secrets with: source <(op inject -i .env)"
        echo "   3. Or use: op run --env-file .env -- your-command"
      fi
      ;;

    *)
      echo "Usage: ralph-secrets [setup|status|migrate <path>]"
      echo ""
      echo "Subcommands:"
      echo "  setup              - Configure 1Password vault for Ralph secrets"
      echo "  status             - Show 1Password configuration and sign-in status"
      echo "  migrate <.env>     - Migrate .env file secrets to 1Password"
      echo ""
      echo "Options for migrate:"
      echo "  --dry-run          - Preview migration without making changes"
      echo "  --service <name>   - Override auto-detected service for all vars"
      echo ""
      echo "Item naming format:"
      echo "  Project vars: {project}/{service}/{normalized_key}"
      echo "  Global vars:  _global/{service}/{key}"
      echo ""
      echo "Examples:"
      echo "  ralph-secrets migrate .env --dry-run"
      echo "  ralph-secrets migrate .env --service backend"
      return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
# MCP SETUP - Configure MCPs for project launchers
# ═══════════════════════════════════════════════════════════════════
# Supported MCPs: figma, linear, supabase, browser-tools, context7
# Credentials: 1Password (if op CLI available) or environment variables
# ═══════════════════════════════════════════════════════════════════

function _ralph_setup_mcps() {
  local mcps_json="$1"
  local YELLOW='\033[0;33m'
  local GREEN='\033[0;32m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  # Parse MCPs from JSON array
  local mcps=()
  if [[ -n "$mcps_json" && "$mcps_json" != "[]" ]]; then
    # Convert JSON array to zsh array
    while IFS= read -r mcp; do
      mcps+=("$mcp")
    done < <(echo "$mcps_json" | /usr/bin/jq -r '.[]' 2>/dev/null)
  fi

  if [[ ${#mcps[@]} -eq 0 ]]; then
    return 0
  fi

  echo "${YELLOW}Setting up MCPs: ${mcps[*]}${NC}"

  # Check if 1Password CLI is available
  local has_1password=false
  if command -v op &>/dev/null; then
    has_1password=true
  fi

  for mcp in "${mcps[@]}"; do
    case "$mcp" in
      figma)
        if [[ -z "$FIGMA_PERSONAL_ACCESS_TOKEN" ]]; then
          if $has_1password; then
            export FIGMA_PERSONAL_ACCESS_TOKEN=$(op read "op://Private/Figma Personal Access Token/credential" 2>/dev/null)
          fi
        fi
        if [[ -n "$FIGMA_PERSONAL_ACCESS_TOKEN" ]]; then
          echo "${GREEN}  ✓ Figma MCP configured${NC}"
        else
          echo "${RED}  ✗ Figma: Set FIGMA_PERSONAL_ACCESS_TOKEN or add to 1Password${NC}"
        fi
        ;;

      linear)
        if [[ -z "$LINEAR_API_KEY" ]]; then
          if $has_1password; then
            export LINEAR_API_KEY=$(op read "op://Private/Linear API Key/credential" 2>/dev/null)
          fi
        fi
        if [[ -n "$LINEAR_API_KEY" ]]; then
          echo "${GREEN}  ✓ Linear MCP configured${NC}"
        else
          echo "${RED}  ✗ Linear: Set LINEAR_API_KEY or add to 1Password${NC}"
        fi
        ;;

      supabase)
        if [[ -z "$SUPABASE_ACCESS_TOKEN" ]]; then
          if $has_1password; then
            export SUPABASE_ACCESS_TOKEN=$(op read "op://Private/Supabase Access Token/credential" 2>/dev/null)
          fi
        fi
        if [[ -n "$SUPABASE_ACCESS_TOKEN" ]]; then
          echo "${GREEN}  ✓ Supabase MCP configured${NC}"
        else
          echo "${RED}  ✗ Supabase: Set SUPABASE_ACCESS_TOKEN or add to 1Password${NC}"
        fi
        ;;

      browser-tools)
        # Browser-tools MCP doesn't require credentials, just needs to be enabled
        echo "${GREEN}  ✓ Browser-tools MCP enabled${NC}"
        ;;

      context7|Context7)
        # Context7 MCP doesn't require credentials
        echo "${GREEN}  ✓ Context7 MCP enabled${NC}"
        ;;

      tempmail)
        # Tempmail MCP - check for API key
        if [[ -z "$TEMPMAIL_API_KEY" ]]; then
          if $has_1password; then
            export TEMPMAIL_API_KEY=$(op read "op://development/tempmail/credential" 2>/dev/null)
          fi
        fi
        if [[ -n "$TEMPMAIL_API_KEY" ]]; then
          echo "${GREEN}  ✓ Tempmail MCP configured${NC}"
        else
          echo "${RED}  ✗ Tempmail: Set TEMPMAIL_API_KEY or add to 1Password${NC}"
        fi
        ;;

      figma-local|figma-remote)
        # Figma MCPs use HTTP transport, no credentials needed here
        echo "${GREEN}  ✓ ${mcp} MCP enabled${NC}"
        ;;

      *)
        echo "${YELLOW}  ? Unknown MCP: $mcp (no setup configured)${NC}"
        ;;
    esac
  done

  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# RALPH-SETUP - Interactive setup wizard for new users
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph-setup
# Interactive gum-based wizard for:
#   - Adding new projects
#   - Configuring MCPs
#   - Migrating secrets to 1Password
#   - Viewing current configuration
# ═══════════════════════════════════════════════════════════════════

# List of available MCPs for multi-select (fallback if registry not available)
RALPH_AVAILABLE_MCPS=("figma" "linear" "supabase" "browser-tools" "context7")

# Get available MCPs from registry mcpDefinitions
function _ralph_get_available_mcps() {
  if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
    local mcps=($(jq -r '.mcpDefinitions | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null))
    if [[ ${#mcps[@]} -gt 0 ]]; then
      echo "${mcps[@]}"
      return 0
    fi
  fi
  # Fallback to hardcoded list
  echo "${RALPH_AVAILABLE_MCPS[@]}"
}

function ralph-setup() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local BLUE='\033[0;34m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'
  local BOLD='\033[1m'

  # Parse flags
  local skip_context_migration=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-context-migration)
        skip_context_migration=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  # Check if 1Password CLI is available and environments are configured
  local has_1password=false
  local op_signed_in=false
  local op_env_configured=false
  if command -v op &>/dev/null; then
    has_1password=true
    if op account list &>/dev/null 2>&1; then
      op_signed_in=true
      # Check if environments are configured in current directory
      if _ralph_check_op_environments "."; then
        op_env_configured=true
      fi
    fi
  fi

  # Main menu loop
  while true; do
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  🛠️  Ralph Setup Wizard                                      │"
    echo "├─────────────────────────────────────────────────────────────┤"
    if $has_1password; then
      if $op_signed_in; then
        if $op_env_configured; then
          echo "│  🔐 1Password: ${GREEN}Configured (environments ready)${NC}             │"
        else
          echo "│  🔐 1Password: ${YELLOW}CLI ready (environments not configured)${NC}    │"
        fi
      else
        echo "│  🔐 1Password: ${YELLOW}CLI installed, not signed in${NC}              │"
      fi
    else
      echo "│  🔐 1Password: ${YELLOW}Not installed${NC}                               │"
    fi
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""

    local choice=""

    if [[ $RALPH_HAS_GUM -eq 0 ]]; then
      # GUM mode - beautiful interactive menu
      choice=$(gum choose \
        "📂 Add new project" \
        "🔧 Configure MCPs for a project" \
        "➕ Manage MCP definitions" \
        "🔐 Configure 1Password Environments" \
        "🔑 Migrate secrets to 1Password" \
        "🐰 Configure CodeRabbit" \
        "📓 Configure Obsidian MCP" \
        "📜 Migrate CLAUDE.md contexts" \
        "📋 View current configuration" \
        "🚪 Exit setup")
    else
      # Fallback mode - numbered menu
      echo "What would you like to do?"
      echo ""
      echo "  1) 📂 Add new project"
      echo "  2) 🔧 Configure MCPs for a project"
      echo "  3) ➕ Manage MCP definitions"
      echo "  4) 🔐 Configure 1Password Environments"
      echo "  5) 🔑 Migrate secrets to 1Password"
      echo "  6) 🐰 Configure CodeRabbit"
      echo "  7) 📓 Configure Obsidian MCP"
      echo "  8) 📜 Migrate CLAUDE.md contexts"
      echo "  9) 📋 View current configuration"
      echo " 10) 🚪 Exit setup"
      echo ""
      echo -n "Choose [1-10]: "
      read menu_choice
      case "$menu_choice" in
        1) choice="📂 Add new project" ;;
        2) choice="🔧 Configure MCPs for a project" ;;
        3) choice="➕ Manage MCP definitions" ;;
        4) choice="🔐 Configure 1Password Environments" ;;
        5) choice="🔑 Migrate secrets to 1Password" ;;
        6) choice="🐰 Configure CodeRabbit" ;;
        7) choice="📓 Configure Obsidian MCP" ;;
        8) choice="📜 Migrate CLAUDE.md contexts" ;;
        9) choice="📋 View current configuration" ;;
        10|*) choice="🚪 Exit setup" ;;
      esac
    fi

    case "$choice" in
      *"Add new project"*)
        _ralph_setup_add_project
        ;;
      *"Configure MCPs"*)
        _ralph_setup_configure_mcps
        ;;
      *"Manage MCP definitions"*)
        _ralph_setup_manage_mcp_definitions
        ;;
      *"Configure 1Password Environments"*)
        _ralph_setup_configure_op_environments
        # Refresh state after configuration
        if _ralph_check_op_environments "."; then
          op_env_configured=true
        fi
        ;;
      *"Migrate secrets"*)
        if ! $has_1password; then
          echo ""
          echo "${YELLOW}⚠️  1Password CLI not installed${NC}"
          echo "   Install with: brew install 1password-cli"
          echo "   Or skip secrets management for now."
          echo ""
          if [[ $RALPH_HAS_GUM -eq 0 ]]; then
            gum confirm "Continue without 1Password?" || continue
          else
            echo -n "Continue without 1Password? [y/N]: "
            read skip_choice
            [[ "$skip_choice" != [Yy]* ]] && continue
          fi
        elif ! $op_signed_in; then
          echo ""
          echo "${YELLOW}⚠️  Not signed in to 1Password${NC}"
          echo "   Run: op signin"
          echo ""
          continue
        fi
        _ralph_setup_migrate_secrets
        ;;
      *"View current configuration"*)
        _ralph_setup_view_config
        ;;
      *"Configure CodeRabbit"*)
        _ralph_setup_configure_coderabbit
        ;;
      *"Configure Obsidian MCP"*)
        _ralph_setup_obsidian_mcp
        ;;
      *"Migrate CLAUDE.md contexts"*)
        if $skip_context_migration; then
          echo "${YELLOW}Skipping context migration (--skip-context-migration flag)${NC}"
        else
          _ralph_setup_context_migration
        fi
        ;;
      *"Exit"*)
        echo ""
        echo "${GREEN}✓ Setup complete!${NC}"
        echo ""
        return 0
        ;;
    esac
  done
}

# Helper: Add a new project to the registry
function _ralph_setup_add_project() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  📂 Add New Project                                         │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Auto-detect from current directory
  local detected_path="$(pwd)"
  local detected_name="$(basename "$detected_path")"

  local project_name=""
  local project_path=""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # GUM mode
    echo "Detected: ${YELLOW}$detected_name${NC} at ${YELLOW}$detected_path${NC}"
    echo ""

    if gum confirm "Use current directory?"; then
      project_path="$detected_path"
      project_name=$(gum input --value "$detected_name" --placeholder "Project name")
    else
      project_path=$(gum input --placeholder "Full path to project (e.g., ~/projects/myapp)")
      project_name=$(gum input --placeholder "Project name")
    fi
  else
    # Fallback mode
    echo "Detected: $detected_name at $detected_path"
    echo ""
    echo -n "Use current directory? [Y/n]: "
    read use_cwd
    if [[ "$use_cwd" != [Nn]* ]]; then
      project_path="$detected_path"
      echo -n "Project name [$detected_name]: "
      read project_name
      [[ -z "$project_name" ]] && project_name="$detected_name"
    else
      echo -n "Full path to project: "
      read project_path
      echo -n "Project name: "
      read project_name
    fi
  fi

  # Validate inputs
  if [[ -z "$project_name" || -z "$project_path" ]]; then
    echo "${RED}Error: Project name and path are required${NC}"
    return 1
  fi

  # Expand ~ in path
  project_path="${project_path/#\~/$HOME}"

  # Validate path exists
  if [[ ! -d "$project_path" ]]; then
    echo "${RED}Error: Path does not exist: $project_path${NC}"
    return 1
  fi

  # Ensure registry exists
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    _ralph_migrate_to_registry
  fi

  # Check if project already exists
  local existing=$(jq -r --arg name "$project_name" '.projects[$name] // empty' "$RALPH_REGISTRY_FILE" 2>/dev/null)
  if [[ -n "$existing" ]]; then
    echo "${RED}Error: Project '$project_name' already exists${NC}"
    return 1
  fi

  # Add to registry
  local timestamp=$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg name "$project_name" \
     --arg path "$project_path" \
     --arg created "$timestamp" \
     '.projects[$name] = {path: $path, mcps: [], secrets: {}, created: $created}' \
     "$RALPH_REGISTRY_FILE" > "${RALPH_REGISTRY_FILE}.tmp"
  mv "${RALPH_REGISTRY_FILE}.tmp" "$RALPH_REGISTRY_FILE"

  echo ""
  echo "${GREEN}✓ Project '$project_name' added!${NC}"
  echo "  Path: $project_path"
  echo ""

  # Offer to configure MCPs immediately
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    if gum confirm "Configure MCPs for this project now?"; then
      _ralph_setup_configure_mcps_for_project "$project_name"
    fi
  else
    echo -n "Configure MCPs for this project? [y/N]: "
    read config_mcps
    if [[ "$config_mcps" == [Yy]* ]]; then
      _ralph_setup_configure_mcps_for_project "$project_name"
    fi
  fi

  # Regenerate launchers
  _ralph_generate_launchers_from_registry

  echo ""
}

# Helper: Configure MCPs (select project first, then MCPs)
function _ralph_setup_configure_mcps() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🔧 Configure MCPs                                          │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Ensure registry exists
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "${YELLOW}No registry found. Creating one...${NC}"
    _ralph_migrate_to_registry
  fi

  # Get list of projects
  local projects=($(jq -r '.projects | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null))

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "${YELLOW}No projects registered. Add a project first.${NC}"
    return 1
  fi

  local selected_project=""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    selected_project=$(printf '%s\n' "${projects[@]}" | gum choose --header "Select a project:")
  else
    echo "Available projects:"
    local i=1
    for proj in "${projects[@]}"; do
      echo "  $i) $proj"
      ((i++))
    done
    echo -n "Choose project [1-${#projects[@]}]: "
    read proj_choice
    if [[ "$proj_choice" =~ ^[0-9]+$ ]] && [[ "$proj_choice" -ge 1 ]] && [[ "$proj_choice" -le ${#projects[@]} ]]; then
      selected_project="${projects[$proj_choice]}"
    else
      echo "${RED}Invalid selection${NC}"
      return 1
    fi
  fi

  if [[ -z "$selected_project" ]]; then
    return 1
  fi

  _ralph_setup_configure_mcps_for_project "$selected_project"
}

# Helper: Configure MCPs for a specific project
function _ralph_setup_configure_mcps_for_project() {
  local project_name="$1"
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  echo ""
  echo "Configuring MCPs for: ${YELLOW}$project_name${NC}"
  echo ""

  # Get available MCPs from registry mcpDefinitions
  local available_mcps=($(_ralph_get_available_mcps))

  # Get current MCPs for this project
  local current_mcps=$(jq -r --arg name "$project_name" '.projects[$name].mcps // [] | join(",")' "$RALPH_REGISTRY_FILE" 2>/dev/null)

  echo "${CYAN}Available MCPs from registry (${#available_mcps[@]}):${NC}"
  echo ""

  local selected_mcps=()

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # GUM mode - multi-select with current selections pre-marked
    # Build list with descriptions
    local mcp_options=()
    for mcp in "${available_mcps[@]}"; do
      local marker=""
      [[ "$current_mcps" == *"$mcp"* ]] && marker=" (current)"
      mcp_options+=("${mcp}${marker}")
    done

    local selections=$(printf '%s\n' "${available_mcps[@]}" | gum choose --no-limit --header "Select MCPs (space to select, enter to confirm):")
    while IFS= read -r mcp; do
      [[ -n "$mcp" ]] && selected_mcps+=("$mcp")
    done <<< "$selections"
  else
    # Fallback mode - numbered multi-select
    echo "Available MCPs:"
    local i=1
    for mcp in "${available_mcps[@]}"; do
      local marker=" "
      [[ "$current_mcps" == *"$mcp"* ]] && marker="*"
      echo "  $i) [$marker] $mcp"
      ((i++))
    done
    echo ""
    echo "Enter numbers separated by spaces (e.g., '1 3 5'):"
    echo -n "> "
    read mcp_choices
    for choice in $mcp_choices; do
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#available_mcps[@]} ]]; then
        selected_mcps+=("${available_mcps[$choice]}")
      fi
    done
  fi

  # Convert to JSON array
  local mcps_json="[]"
  if [[ ${#selected_mcps[@]} -gt 0 ]]; then
    mcps_json=$(printf '%s\n' "${selected_mcps[@]}" | jq -R . | jq -s .)
  fi

  # Update registry
  jq --arg name "$project_name" \
     --argjson mcps "$mcps_json" \
     '.projects[$name].mcps = $mcps' \
     "$RALPH_REGISTRY_FILE" > "${RALPH_REGISTRY_FILE}.tmp"
  mv "${RALPH_REGISTRY_FILE}.tmp" "$RALPH_REGISTRY_FILE"

  echo ""
  if [[ ${#selected_mcps[@]} -gt 0 ]]; then
    echo "${GREEN}✓ MCPs configured: ${selected_mcps[*]}${NC}"
  else
    echo "${YELLOW}No MCPs selected${NC}"
  fi

  # Regenerate launchers
  _ralph_generate_launchers_from_registry
}

# Helper: Manage MCP definitions in the registry
function _ralph_setup_manage_mcp_definitions() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  ➕ Manage MCP Definitions                                  │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Ensure registry exists
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "${YELLOW}No registry found. Creating one...${NC}"
    _ralph_migrate_to_registry
  fi

  # Show current MCP definitions
  local mcp_count=$(jq '.mcpDefinitions | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
  echo "${CYAN}Current MCP definitions ($mcp_count):${NC}"
  echo ""
  jq -r '.mcpDefinitions | keys[] | "  • \(.)"' "$RALPH_REGISTRY_FILE" 2>/dev/null
  echo ""

  local action=""
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    action=$(gum choose \
      "➕ Add new MCP definition" \
      "👁️  View MCP definition details" \
      "🗑️  Remove MCP definition" \
      "⬅️  Back to main menu")
  else
    echo "What would you like to do?"
    echo ""
    echo "  1) ➕ Add new MCP definition"
    echo "  2) 👁️  View MCP definition details"
    echo "  3) 🗑️  Remove MCP definition"
    echo "  4) ⬅️  Back to main menu"
    echo ""
    echo -n "Choose [1-4]: "
    read action_choice
    case "$action_choice" in
      1) action="➕ Add new MCP" ;;
      2) action="👁️  View MCP" ;;
      3) action="🗑️  Remove MCP" ;;
      *) action="⬅️  Back" ;;
    esac
  fi

  case "$action" in
    *"Add new MCP"*)
      _ralph_setup_add_mcp_definition
      ;;
    *"View MCP"*)
      _ralph_setup_view_mcp_definition
      ;;
    *"Remove MCP"*)
      _ralph_setup_remove_mcp_definition
      ;;
    *)
      return 0
      ;;
  esac
}

# Helper: Add a new MCP definition to the registry
function _ralph_setup_add_mcp_definition() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "Adding a new MCP definition..."
  echo ""

  local mcp_name=""
  local mcp_command=""
  local mcp_args=""
  local mcp_env=""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    mcp_name=$(gum input --placeholder "MCP name (e.g., my-mcp)")
    [[ -z "$mcp_name" ]] && return 1

    mcp_command=$(gum input --placeholder "Command (e.g., npx, node, python)")
    [[ -z "$mcp_command" ]] && return 1

    mcp_args=$(gum input --placeholder "Args as JSON array (e.g., [\"-y\", \"@some/mcp\"])")
    [[ -z "$mcp_args" ]] && mcp_args="[]"

    echo "Environment variables (optional, JSON object):"
    mcp_env=$(gum input --placeholder "{\"KEY\": \"value\"}")
    [[ -z "$mcp_env" ]] && mcp_env="{}"
  else
    echo -n "MCP name (e.g., my-mcp): "
    read mcp_name
    [[ -z "$mcp_name" ]] && return 1

    echo -n "Command (e.g., npx, node, python): "
    read mcp_command
    [[ -z "$mcp_command" ]] && return 1

    echo -n "Args as JSON array (e.g., [\"-y\", \"@some/mcp\"]): "
    read mcp_args
    [[ -z "$mcp_args" ]] && mcp_args="[]"

    echo -n "Environment variables (JSON object, optional): "
    read mcp_env
    [[ -z "$mcp_env" ]] && mcp_env="{}"
  fi

  # Validate JSON
  if ! echo "$mcp_args" | jq -e '.' &>/dev/null; then
    echo "${RED}Error: Invalid JSON for args${NC}"
    return 1
  fi
  if ! echo "$mcp_env" | jq -e '.' &>/dev/null; then
    echo "${RED}Error: Invalid JSON for env${NC}"
    return 1
  fi

  # Check if MCP already exists
  local existing=$(jq -r --arg name "$mcp_name" '.mcpDefinitions[$name] // empty' "$RALPH_REGISTRY_FILE" 2>/dev/null)
  if [[ -n "$existing" ]]; then
    echo "${YELLOW}Warning: MCP '$mcp_name' already exists${NC}"
    if [[ $RALPH_HAS_GUM -eq 0 ]]; then
      gum confirm "Overwrite existing definition?" || return 1
    else
      echo -n "Overwrite existing definition? [y/N]: "
      read overwrite
      [[ "$overwrite" != [Yy]* ]] && return 1
    fi
  fi

  # Add to registry
  jq --arg name "$mcp_name" \
     --arg cmd "$mcp_command" \
     --argjson args "$mcp_args" \
     --argjson env "$mcp_env" \
     '.mcpDefinitions[$name] = {command: $cmd, args: $args, env: $env}' \
     "$RALPH_REGISTRY_FILE" > "${RALPH_REGISTRY_FILE}.tmp"
  mv "${RALPH_REGISTRY_FILE}.tmp" "$RALPH_REGISTRY_FILE"

  echo ""
  echo "${GREEN}✓ MCP definition '$mcp_name' added!${NC}"
  echo ""
}

# Helper: View details of an MCP definition
function _ralph_setup_view_mcp_definition() {
  local CYAN='\033[0;36m'
  local YELLOW='\033[0;33m'
  local NC='\033[0m'

  echo ""
  local mcps=($(jq -r '.mcpDefinitions | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null))

  if [[ ${#mcps[@]} -eq 0 ]]; then
    echo "${YELLOW}No MCP definitions found${NC}"
    return 1
  fi

  local selected_mcp=""
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    selected_mcp=$(printf '%s\n' "${mcps[@]}" | gum choose --header "Select MCP to view:")
  else
    echo "Available MCPs:"
    local i=1
    for mcp in "${mcps[@]}"; do
      echo "  $i) $mcp"
      ((i++))
    done
    echo -n "Choose MCP [1-${#mcps[@]}]: "
    read mcp_choice
    if [[ "$mcp_choice" =~ ^[0-9]+$ ]] && [[ "$mcp_choice" -ge 1 ]] && [[ "$mcp_choice" -le ${#mcps[@]} ]]; then
      selected_mcp="${mcps[$mcp_choice]}"
    fi
  fi

  [[ -z "$selected_mcp" ]] && return 1

  echo ""
  echo "${CYAN}MCP: $selected_mcp${NC}"
  echo ""
  jq --arg name "$selected_mcp" '.mcpDefinitions[$name]' "$RALPH_REGISTRY_FILE" 2>/dev/null
  echo ""
}

# Helper: Remove an MCP definition from the registry
function _ralph_setup_remove_mcp_definition() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  local mcps=($(jq -r '.mcpDefinitions | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null))

  if [[ ${#mcps[@]} -eq 0 ]]; then
    echo "${YELLOW}No MCP definitions found${NC}"
    return 1
  fi

  local selected_mcp=""
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    selected_mcp=$(printf '%s\n' "${mcps[@]}" | gum choose --header "Select MCP to remove:")
  else
    echo "Available MCPs:"
    local i=1
    for mcp in "${mcps[@]}"; do
      echo "  $i) $mcp"
      ((i++))
    done
    echo -n "Choose MCP to remove [1-${#mcps[@]}]: "
    read mcp_choice
    if [[ "$mcp_choice" =~ ^[0-9]+$ ]] && [[ "$mcp_choice" -ge 1 ]] && [[ "$mcp_choice" -le ${#mcps[@]} ]]; then
      selected_mcp="${mcps[$mcp_choice]}"
    fi
  fi

  [[ -z "$selected_mcp" ]] && return 1

  # Confirm deletion
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    gum confirm "Remove MCP definition '$selected_mcp'?" || return 1
  else
    echo -n "Remove MCP definition '$selected_mcp'? [y/N]: "
    read confirm
    [[ "$confirm" != [Yy]* ]] && return 1
  fi

  # Remove from registry
  jq --arg name "$selected_mcp" 'del(.mcpDefinitions[$name])' \
     "$RALPH_REGISTRY_FILE" > "${RALPH_REGISTRY_FILE}.tmp"
  mv "${RALPH_REGISTRY_FILE}.tmp" "$RALPH_REGISTRY_FILE"

  echo ""
  echo "${GREEN}✓ MCP definition '$selected_mcp' removed${NC}"
  echo ""

  # Warn about projects using this MCP
  local projects_using=$(jq -r --arg mcp "$selected_mcp" '.projects | to_entries[] | select(.value.mcps | index($mcp)) | .key' "$RALPH_REGISTRY_FILE" 2>/dev/null)
  if [[ -n "$projects_using" ]]; then
    echo "${YELLOW}Warning: The following projects still reference this MCP:${NC}"
    echo "$projects_using" | while read -r proj; do
      echo "  • $proj"
    done
    echo ""
    echo "You may want to reconfigure their MCPs."
    echo ""
  fi
}

# Helper: Configure 1Password Environments for the current project
function _ralph_setup_configure_op_environments() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🔐 Configure 1Password Environments                        │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Check prerequisites
  if ! command -v op &>/dev/null; then
    echo "${RED}Error: 1Password CLI (op) is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  ${YELLOW}brew install 1password-cli${NC}"
    echo ""
    return 1
  fi

  if ! op account list &>/dev/null 2>&1; then
    echo "${RED}Error: Not signed in to 1Password${NC}"
    echo ""
    echo "Sign in with:"
    echo "  ${YELLOW}eval \$(op signin)${NC}"
    echo ""
    return 1
  fi

  echo "${GREEN}✓ 1Password CLI installed and signed in${NC}"
  echo ""

  # Check current state
  if _ralph_check_op_environments "."; then
    echo "${GREEN}✓ 1Password Environments already configured!${NC}"
    echo ""
    # Show what's configured
    if [[ -f ".env.1password" ]]; then
      echo "Found: ${CYAN}.env.1password${NC}"
      local op_refs=$(grep -c "op://" ".env.1password" 2>/dev/null || echo "0")
      echo "       Contains $op_refs secret references"
    fi
    local env_files=(".env" ".env.local" ".env.development" ".env.production" ".env.example")
    for env_file in "${env_files[@]}"; do
      if [[ -f "$env_file" ]] && grep -q "op://" "$env_file" 2>/dev/null; then
        local op_refs=$(grep -c "op://" "$env_file" 2>/dev/null || echo "0")
        echo "Found: ${CYAN}$env_file${NC} with $op_refs op:// references"
      fi
    done
    echo ""
    echo "To add more secrets, use:"
    echo "  ${YELLOW}ralph-secrets migrate .env${NC}"
    echo ""
    return 0
  fi

  # Not configured - guide setup
  echo "${YELLOW}1Password Environments not yet configured for this project.${NC}"
  echo ""
  echo "1Password Environments allow you to securely inject secrets into"
  echo "your project using op:// references instead of hardcoded values."
  echo ""
  echo "${CYAN}Setup options:${NC}"
  echo ""
  echo "  ${YELLOW}Option 1:${NC} Migrate existing .env file"
  echo "    Converts hardcoded secrets to op:// references"
  echo "    Command: ${YELLOW}ralph-secrets migrate .env${NC}"
  echo ""
  echo "  ${YELLOW}Option 2:${NC} Create .env.1password manually"
  echo "    Create a file with op:// references like:"
  echo "    ${CYAN}DATABASE_URL=op://Private/Database/password${NC}"
  echo "    ${CYAN}API_KEY=op://Private/MyAPI/credential${NC}"
  echo ""
  echo "  ${YELLOW}Option 3:${NC} Use /1password skill in Claude"
  echo "    Run ${CYAN}/1password${NC} for guided setup"
  echo ""

  # Offer to run migration if .env exists
  if [[ -f ".env" ]]; then
    echo "Detected: ${CYAN}.env${NC} file exists in this project"
    echo ""
    if [[ $RALPH_HAS_GUM -eq 0 ]]; then
      if gum confirm "Would you like to preview migrating .env to 1Password?"; then
        echo ""
        ralph-secrets migrate .env --dry-run
      fi
    else
      echo -n "Would you like to preview migrating .env to 1Password? [y/N]: "
      read migrate_choice
      if [[ "$migrate_choice" == [Yy]* ]]; then
        echo ""
        ralph-secrets migrate .env --dry-run
      fi
    fi
  fi

  echo ""
}

# Helper: Migrate secrets (invokes 1Password workflow)
function _ralph_setup_migrate_secrets() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🔑 Migrate Secrets to 1Password                            │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Scan for .env files in current directory
  local env_files=()
  local env_secrets_count=0

  echo "${CYAN}Scanning for .env files...${NC}"
  echo ""

  for env_file in .env .env.local .env.development .env.production .env.staging .env.test; do
    if [[ -f "$env_file" ]]; then
      # Count non-comment, non-empty lines with = (secrets)
      local secrets=$(grep -v "^#" "$env_file" 2>/dev/null | grep -v "^$" | grep "=" | wc -l | tr -d ' ')
      # Count lines already using op://
      local op_refs=$(grep "op://" "$env_file" 2>/dev/null | wc -l | tr -d ' ')
      local plain_secrets=$((secrets - op_refs))

      if [[ "$plain_secrets" -gt 0 ]]; then
        env_files+=("$env_file")
        env_secrets_count=$((env_secrets_count + plain_secrets))
        echo "  📄 ${YELLOW}$env_file${NC}: ${plain_secrets} secrets (${op_refs} already using op://)"
      elif [[ "$secrets" -gt 0 ]]; then
        echo "  ✅ ${GREEN}$env_file${NC}: All $secrets secrets already use op://"
      fi
    fi
  done

  if [[ ${#env_files[@]} -eq 0 ]]; then
    echo "  ${GREEN}✓ No .env files with plain secrets found${NC}"
    echo ""
    echo "All secrets are either migrated or you don't have .env files."
    echo ""
    return 0
  fi

  echo ""
  echo "Found ${YELLOW}$env_secrets_count${NC} plain secrets in ${#env_files[@]} file(s)"
  echo ""

  local migrate_choice=""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    migrate_choice=$(gum choose \
      "🔍 Scan .env files (preview migration)" \
      "📄 Migrate .env file to 1Password" \
      "⚙️  Migrate MCP config secrets" \
      "⬅️  Back to main menu")
  else
    echo "What would you like to do?"
    echo ""
    echo "  1) 🔍 Scan .env files (preview migration)"
    echo "  2) 📄 Migrate .env file to 1Password"
    echo "  3) ⚙️  Migrate MCP config secrets"
    echo "  4) ⬅️  Back to main menu"
    echo ""
    echo -n "Choose [1-4]: "
    read migrate_opt
    case "$migrate_opt" in
      1) migrate_choice="🔍 Scan .env" ;;
      2) migrate_choice="📄 Migrate .env file" ;;
      3) migrate_choice="⚙️  Migrate MCP config" ;;
      *) migrate_choice="⬅️  Back" ;;
    esac
  fi

  case "$migrate_choice" in
    *"Scan .env"*)
      echo ""
      echo "${CYAN}Scanning .env files for secrets...${NC}"
      echo ""
      for env_file in "${env_files[@]}"; do
        echo "━━━ ${YELLOW}$env_file${NC} ━━━"
        # Show keys only (not values) for security
        grep -v "^#" "$env_file" 2>/dev/null | grep -v "^$" | grep "=" | grep -v "op://" | sed 's/=.*/=***/' | head -20
        echo ""
      done
      echo "${YELLOW}To migrate these secrets to 1Password:${NC}"
      echo "  ${CYAN}ralph-secrets migrate .env --dry-run${NC}  # Preview"
      echo "  ${CYAN}ralph-secrets migrate .env${NC}            # Execute"
      echo ""
      ;;
    *".env file"*)
      echo ""
      echo "${CYAN}For .env migration, use the ralph-secrets command:${NC}"
      echo ""
      echo "  ${YELLOW}ralph-secrets migrate .env --dry-run${NC}  # Preview first"
      echo "  ${YELLOW}ralph-secrets migrate .env${NC}            # Actually migrate"
      echo ""
      echo "Or invoke the /1password skill in Claude:"
      echo "  ${YELLOW}/1password${NC} → Select 'Migrate .env to 1Password'"
      echo ""
      ;;
    *"MCP config"*)
      echo ""
      echo "${CYAN}To migrate MCP config secrets:${NC}"
      echo ""
      echo "  1. Scan for hardcoded secrets:"
      echo "     ${YELLOW}bash ~/.claude/commands/golem-powers/1password/scripts/scan-mcp-secrets.sh${NC}"
      echo ""
      echo "  2. Or invoke the /1password skill in Claude:"
      echo "     ${YELLOW}/golem-powers:1password${NC} → Select 'Migrate MCP config secrets'"
      echo ""
      ;;
    *)
      return 0
      ;;
  esac

  # Generate .env.1password for projects with secrets
  _ralph_setup_generate_env_files
}

# Helper: Generate .env.1password files for all projects with secrets
function _ralph_setup_generate_env_files() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local NC='\033[0m'

  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    return 0
  fi

  # Get projects with secrets
  local projects_with_secrets=$(jq -r '.projects | to_entries[] | select(.value.secrets | length > 0) | .key' "$RALPH_REGISTRY_FILE" 2>/dev/null)

  if [[ -z "$projects_with_secrets" ]]; then
    echo "${YELLOW}No projects have secrets configured in the registry.${NC}"
    echo "Use 'ralph-secrets migrate' to add secrets first."
    return 0
  fi

  echo ""
  echo "Generating .env.1password files..."

  while IFS= read -r project; do
    [[ -z "$project" ]] && continue
    local project_path=$(jq -r --arg name "$project" '.projects[$name].path' "$RALPH_REGISTRY_FILE" 2>/dev/null)
    local env_file="${project_path}/.env.1password"

    _ralph_generate_env_1password "$project" "$env_file"
    echo "${GREEN}✓ Generated: $env_file${NC}"
  done <<< "$projects_with_secrets"

  echo ""
}

# Helper: Configure CodeRabbit pre-commit reviews
function _ralph_setup_configure_coderabbit() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🐰 Configure CodeRabbit                                    │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Check if cr CLI is installed
  if ! command -v cr >/dev/null 2>&1; then
    echo "${YELLOW}⚠️  CodeRabbit CLI (cr) not installed${NC}"
    echo ""
    echo "Install with: npm install -g coderabbit"
    echo "Or: brew install coderabbit/tap/coderabbit"
    echo ""
    echo "CodeRabbit provides free AI code reviews for open source projects."
    echo ""
    return 0
  fi

  local cr_version=$(cr --version 2>/dev/null || echo "unknown")
  echo "${GREEN}✓ CodeRabbit CLI installed (v$cr_version)${NC}"
  echo ""

  # Get current settings
  local current_enabled="true"
  local current_repos=""
  if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
    current_enabled=$(jq -r '.coderabbit.enabled // "true"' "$RALPH_REGISTRY_FILE" 2>/dev/null)
    current_repos=$(jq -r '.coderabbit.repos // [] | join(", ")' "$RALPH_REGISTRY_FILE" 2>/dev/null)
  fi

  echo "CodeRabbit runs 'cr review' before commits to catch issues early."
  echo "This is ${GREEN}free for open source repos${NC}."
  echo ""
  echo "Current settings:"
  echo "  ${CYAN}Enabled:${NC} $current_enabled"
  echo "  ${CYAN}Repos:${NC}   ${current_repos:-"(none - opt-in required)"}"
  echo ""

  # Enable/disable
  local enable_cr="true"
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    if gum confirm "Enable CodeRabbit pre-commit checks?"; then
      enable_cr="true"
    else
      enable_cr="false"
    fi
  else
    echo -n "Enable CodeRabbit pre-commit checks? [Y/n]: "
    read enable_choice
    if [[ "$enable_choice" == [Nn]* ]]; then
      enable_cr="false"
    fi
  fi

  if [[ "$enable_cr" == "false" ]]; then
    # Update registry with disabled state
    if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
      local tmp=$(mktemp)
      jq '.coderabbit = {"enabled": false, "repos": []}' "$RALPH_REGISTRY_FILE" > "$tmp" && mv "$tmp" "$RALPH_REGISTRY_FILE"
    fi
    RALPH_CODERABBIT_ENABLED="false"
    RALPH_CODERABBIT_ALLOWED_REPOS=""
    echo ""
    echo "${GREEN}✓ CodeRabbit disabled${NC}"
    return 0
  fi

  # Which repos?
  echo ""
  echo "Which repos should use CodeRabbit?"
  echo "  • Enter repo names comma-separated (e.g., claude-golem, songscript)"
  echo "  • Enter * for all repos"
  echo ""

  local repos_input=""
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    repos_input=$(gum input --placeholder "Repo names (comma-separated) or * for all" --value "$current_repos")
  else
    echo -n "Repos (comma-separated or * for all): "
    read repos_input
  fi

  # Parse repos into array
  local repos_array=""
  if [[ "$repos_input" == "*" ]]; then
    repos_array='["*"]'
  elif [[ -n "$repos_input" ]]; then
    # Convert comma-separated to JSON array
    repos_array=$(echo "$repos_input" | sed 's/,/","/g' | sed 's/^/["/g' | sed 's/$/"]/g' | sed 's/ //g')
  else
    repos_array='[]'
  fi

  # Update registry
  mkdir -p "$RALPH_CONFIG_DIR"
  if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
    local tmp=$(mktemp)
    jq --argjson repos "$repos_array" '.coderabbit = {"enabled": true, "repos": $repos}' "$RALPH_REGISTRY_FILE" > "$tmp" && mv "$tmp" "$RALPH_REGISTRY_FILE"
  else
    # Create minimal registry with CodeRabbit config
    echo "{\"version\": 1, \"coderabbit\": {\"enabled\": true, \"repos\": $repos_array}}" > "$RALPH_REGISTRY_FILE"
  fi

  # Update runtime variables
  RALPH_CODERABBIT_ENABLED="true"
  if [[ "$repos_input" == "*" ]]; then
    RALPH_CODERABBIT_ALLOWED_REPOS="*"
  else
    RALPH_CODERABBIT_ALLOWED_REPOS="$repos_input"
  fi

  echo ""
  echo "${GREEN}✓ CodeRabbit configured${NC}"
  echo "  Enabled: true"
  echo "  Repos: $repos_input"
  echo ""
  echo "Ralph will now run 'cr review' before commits in these repos."
  echo ""
}

# Helper: Obsidian MCP setup
function _ralph_setup_obsidian_mcp() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  📓 Obsidian Claude Code MCP Setup                          │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""
  echo "This will help you configure the Obsidian Claude Code MCP plugin."
  echo "The plugin enables Claude to read and write to your Obsidian vault."
  echo ""
  echo "${CYAN}Prerequisites:${NC}"
  echo "  • Obsidian installed"
  echo "  • Claude Code MCP plugin installed from Community Plugins"
  echo ""

  local do_setup=""
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    gum confirm "Would you like to set up Obsidian MCP integration?" && do_setup="yes"
  else
    echo -n "Would you like to set up Obsidian MCP integration? [y/N]: "
    read do_setup_input
    [[ "$do_setup_input" == [Yy]* ]] && do_setup="yes"
  fi

  if [[ -z "$do_setup" ]]; then
    echo ""
    echo "${YELLOW}Skipping Obsidian MCP setup${NC}"
    return 0
  fi

  # Find and run the install script
  local script_path=""

  # Check in multiple locations
  if [[ -f "${RALPH_SCRIPT_DIR}/scripts/install-obsidian-mcp.sh" ]]; then
    script_path="${RALPH_SCRIPT_DIR}/scripts/install-obsidian-mcp.sh"
  elif [[ -f "${RALPH_CONFIG_DIR}/../ralph/scripts/install-obsidian-mcp.sh" ]]; then
    script_path="${RALPH_CONFIG_DIR}/../ralph/scripts/install-obsidian-mcp.sh"
  elif [[ -f "$HOME/.config/ralphtools/scripts/install-obsidian-mcp.sh" ]]; then
    script_path="$HOME/.config/ralphtools/scripts/install-obsidian-mcp.sh"
  fi

  if [[ -n "$script_path" ]] && [[ -f "$script_path" ]]; then
    echo ""
    echo "Running Obsidian MCP setup script..."
    echo ""
    bash "$script_path"
  else
    # Fallback: inline setup if script not found
    echo ""
    echo "${YELLOW}Setup script not found. Running inline setup...${NC}"
    echo ""

    # Detect vaults
    local obsidian_config="$HOME/Library/Application Support/obsidian/obsidian.json"
    local -a vaults=()

    if [[ -f "$obsidian_config" ]] && command -v jq &>/dev/null; then
      while IFS= read -r vault_path; do
        [[ -d "$vault_path" ]] && vaults+=("$vault_path")
      done < <(jq -r '.vaults | to_entries[] | .value.path // empty' "$obsidian_config" 2>/dev/null)
    fi

    if [[ ${#vaults[@]} -eq 0 ]]; then
      echo "${YELLOW}No Obsidian vaults found automatically.${NC}"
      echo "Please enter your vault path:"
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        local vault_path=$(gum input --placeholder "/path/to/vault")
      else
        echo -n "Vault path: "
        read vault_path
      fi
      [[ -d "$vault_path" ]] && vaults+=("$vault_path")
    fi

    if [[ ${#vaults[@]} -eq 0 ]]; then
      echo "${RED}No valid vault path provided.${NC}"
      return 1
    fi

    local selected_vault="${vaults[1]}"  # zsh arrays start at 1
    local vault_name=$(basename "$selected_vault")

    if [[ ${#vaults[@]} -gt 1 ]]; then
      echo ""
      echo "Multiple vaults found. Please select one:"
      local i=1
      for v in "${vaults[@]}"; do
        echo "  $i) $(basename "$v") - $v"
        ((i++))
      done
      echo ""
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        local vault_names=()
        for v in "${vaults[@]}"; do
          vault_names+=("$(basename "$v")")
        done
        local selected_name=$(gum choose "${vault_names[@]}")
        for i in {1..${#vaults[@]}}; do
          if [[ "$(basename "${vaults[$i]}")" == "$selected_name" ]]; then
            selected_vault="${vaults[$i]}"
            vault_name="$selected_name"
            break
          fi
        done
      else
        echo -n "Enter vault number [1-${#vaults[@]}]: "
        read vault_num
        if [[ "$vault_num" =~ ^[0-9]+$ ]] && [[ "$vault_num" -ge 1 ]] && [[ "$vault_num" -le ${#vaults[@]} ]]; then
          selected_vault="${vaults[$vault_num]}"
          vault_name=$(basename "$selected_vault")
        fi
      fi
    fi

    echo ""
    echo "${GREEN}✓${NC} Selected vault: $vault_name"
    echo "  Path: $selected_vault"

    # Get port
    local mcp_port=22360
    echo ""
    echo "Default MCP port is 22360."
    if [[ $RALPH_HAS_GUM -eq 0 ]]; then
      local port_input=$(gum input --placeholder "22360" --value "22360" --header "MCP Port:")
      [[ -n "$port_input" ]] && mcp_port="$port_input"
    else
      echo -n "MCP Port [22360]: "
      read port_input
      [[ -n "$port_input" ]] && mcp_port="$port_input"
    fi

    local mcp_url="http://localhost:$mcp_port/sse"

    # Store in 1Password if available
    if command -v op &>/dev/null; then
      echo ""
      local store_op=""
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        gum confirm "Store MCP URL in 1Password?" && store_op="yes"
      else
        echo -n "Store MCP URL in 1Password? [y/N]: "
        read store_op_input
        [[ "$store_op_input" == [Yy]* ]] && store_op="yes"
      fi

      if [[ "$store_op" == "yes" ]]; then
        if op item get "Obsidian-MCP" --vault "Private" &>/dev/null 2>&1; then
          op item edit "Obsidian-MCP" --vault "Private" "url=$mcp_url" "vault_name=$vault_name" "port=$mcp_port" &>/dev/null && \
            echo "${GREEN}✓${NC} Updated 1Password item: Obsidian-MCP" || \
            echo "${YELLOW}⚠${NC} Failed to update 1Password item"
        else
          op item create --category "API Credential" --vault "Private" --title "Obsidian-MCP" "url=$mcp_url" "vault_name=$vault_name" "port=$mcp_port" &>/dev/null && \
            echo "${GREEN}✓${NC} Created 1Password item: Obsidian-MCP" || \
            echo "${YELLOW}⚠${NC} Failed to create 1Password item"
        fi
      fi
    fi

    echo ""
    echo "${CYAN}MCP Configuration for settings.json:${NC}"
    echo ""
    echo "{"
    echo "  \"mcpServers\": {"
    echo "    \"obsidian-$vault_name\": {"
    echo "      \"command\": \"npx\","
    echo "      \"args\": [\"mcp-remote\", \"$mcp_url\"]"
    echo "    }"
    echo "  }"
    echo "}"
    echo ""
    echo "${GREEN}✓${NC} Obsidian MCP setup complete!"
    echo ""
    echo "${CYAN}Next steps:${NC}"
    echo "  1. Ensure the Claude Code MCP plugin is installed in Obsidian"
    echo "  2. Set the plugin port to: $mcp_port"
    echo "  3. Enable the server in plugin settings"
    echo "  4. Use 'claude' → '/ide' to connect"
    echo ""
  fi
}

# Helper: Context migration wizard
function _ralph_setup_context_migration() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local NC='\033[0m'
  local BOLD='\033[1m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  📜 CLAUDE.md Context Migration                             │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Check if contexts directory exists at ~/.claude/contexts/
  local contexts_source="${RALPH_SCRIPT_DIR}/contexts"
  local contexts_target="$HOME/.claude/contexts"

  # First, ensure the contexts directory exists
  if [[ ! -d "$contexts_target" ]]; then
    echo "${YELLOW}⚠️  Contexts directory not found${NC}"
    echo "   Location: $contexts_target"
    echo ""

    # Check if we have context templates to copy
    if [[ -d "$contexts_source" ]]; then
      echo "Found context templates at: ${CYAN}$contexts_source${NC}"
      echo ""

      local should_create=false
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        if gum confirm "Create contexts directory and copy templates?"; then
          should_create=true
        fi
      else
        echo -n "Create contexts directory and copy templates? [Y/n]: "
        read create_choice
        if [[ "$create_choice" != [Nn]* ]]; then
          should_create=true
        fi
      fi

      if $should_create; then
        # Check if source has files before copying
        local has_files=false
        if [[ -f "$contexts_source/base.md" ]] || [[ -d "$contexts_source/tech" ]] || [[ -d "$contexts_source/workflow" ]]; then
          has_files=true
        fi

        if $has_files; then
          mkdir -p "$contexts_target/tech" "$contexts_target/workflow"
          cp -r "$contexts_source/"* "$contexts_target/" 2>/dev/null || true
          echo "${GREEN}✓ Contexts directory created${NC}"
          echo ""
        else
          echo "${YELLOW}⚠️  No context templates found in source directory${NC}"
          echo ""
        fi
      else
        echo "${YELLOW}Skipping context setup${NC}"
        return 0
      fi
    else
      echo "No context templates found in ralphtools."
      echo "Run this from the ralphtools directory or ensure contexts/ exists."
      echo ""
      return 1
    fi
  else
    echo "${GREEN}✓ Contexts directory exists${NC}: $contexts_target"
    echo ""
  fi

  # List available contexts
  echo "${BOLD}Available Contexts:${NC}"
  echo "──────────────────────────────────────────────────────────────"
  if [[ -f "$contexts_target/base.md" ]]; then
    echo "  ${GREEN}✓${NC} base.md"
  else
    echo "  ${RED}✗${NC} base.md (missing)"
  fi

  for subdir in tech workflow; do
    if [[ -d "$contexts_target/$subdir" ]]; then
      for ctx_file in "$contexts_target/$subdir"/*.md; do
        [[ -f "$ctx_file" ]] && echo "  ${GREEN}✓${NC} $subdir/$(basename "$ctx_file" .md)"
      done
    fi
  done
  echo ""

  # Check if source templates are newer and offer to update
  if [[ -d "$contexts_source" ]]; then
    local updates_available=false
    for src_file in "$contexts_source/"*.md "$contexts_source/tech/"*.md "$contexts_source/workflow/"*.md; do
      [[ ! -f "$src_file" ]] && continue
      local rel_path="${src_file#$contexts_source/}"
      local target_file="$contexts_target/$rel_path"
      if [[ ! -f "$target_file" ]]; then
        updates_available=true
        break
      fi
    done

    if $updates_available; then
      echo "${YELLOW}Some context templates are missing. Copy from ralphtools?${NC}"
      local should_copy=false
      if [[ $RALPH_HAS_GUM -eq 0 ]]; then
        gum confirm "Copy missing context templates?" && should_copy=true
      else
        echo -n "Copy missing context templates? [y/N]: "
        read copy_choice
        [[ "$copy_choice" == [Yy]* ]] && should_copy=true
      fi

      if $should_copy; then
        cp -rn "$contexts_source/"* "$contexts_target/" 2>/dev/null
        echo "${GREEN}✓ Context templates updated${NC}"
        echo ""
      fi
    fi
  fi

  # Now offer to migrate a project's CLAUDE.md
  echo "${BOLD}Migrate a Project's CLAUDE.md:${NC}"
  echo "──────────────────────────────────────────────────────────────"
  echo ""
  echo "The migration script analyzes your CLAUDE.md and suggests"
  echo "which content can be moved to shared contexts."
  echo ""

  # Get project path
  local project_path=""
  local detected_path="$(pwd)"

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    local path_choice=$(gum choose \
      "Analyze current directory ($detected_path)" \
      "Enter a different path" \
      "Skip migration")

    case "$path_choice" in
      *"current directory"*)
        project_path="$detected_path"
        ;;
      *"different path"*)
        project_path=$(gum input --placeholder "Path to project with CLAUDE.md")
        ;;
      *)
        echo "${YELLOW}Skipping migration analysis${NC}"
        return 0
        ;;
    esac
  else
    echo "Options:"
    echo "  1) Analyze current directory ($detected_path)"
    echo "  2) Enter a different path"
    echo "  3) Skip migration"
    echo ""
    echo -n "Choose [1-3]: "
    read path_choice
    case "$path_choice" in
      1)
        project_path="$detected_path"
        ;;
      2)
        echo -n "Path to project: "
        read project_path
        ;;
      *)
        echo "${YELLOW}Skipping migration analysis${NC}"
        return 0
        ;;
    esac
  fi

  # Expand ~ in path
  project_path="${project_path/#\~/$HOME}"

  # Check for CLAUDE.md
  if [[ ! -f "$project_path/CLAUDE.md" ]]; then
    echo "${RED}Error: No CLAUDE.md found at $project_path${NC}"
    return 1
  fi

  # Check for migration script
  local migrate_script="${RALPH_SCRIPT_DIR}/scripts/context-migrate.zsh"
  if [[ ! -f "$migrate_script" ]]; then
    echo "${RED}Error: Migration script not found at $migrate_script${NC}"
    return 1
  fi

  # Run the analysis
  echo ""
  echo "${CYAN}Running analysis...${NC}"
  echo ""
  "$migrate_script" "$project_path"

  # Ask if user wants to apply
  echo ""
  local should_apply=false
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    if gum confirm "Apply migration now?"; then
      should_apply=true
    fi
  else
    echo -n "Apply migration now? [y/N]: "
    read apply_choice
    [[ "$apply_choice" == [Yy]* ]] && should_apply=true
  fi

  if $should_apply; then
    echo ""
    "$migrate_script" "$project_path" --apply
    echo ""
    echo "${GREEN}✓ Migration applied!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Open $project_path/CLAUDE.md"
    echo "  2. Review the backup file for any project-specific rules"
    echo "  3. Add unique rules to the 'Project-Specific' section"
  else
    echo ""
    echo "${YELLOW}Migration not applied${NC}"
    echo ""
    echo "You can run the migration later with:"
    echo "  ${CYAN}$migrate_script $project_path --apply${NC}"
    echo ""
    echo "Or manually:"
    echo "  1. Add context references at the top of CLAUDE.md:"
    echo "     @context: base"
    echo "     @context: tech/nextjs  (if applicable)"
    echo "     @context: workflow/rtl (if applicable)"
    echo "  2. Remove sections that duplicate shared contexts"
    echo "  3. Keep only project-specific rules"
  fi
  echo ""
}

# Helper: View current configuration
function _ralph_setup_view_config() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local BOLD='\033[1m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  📋 Current Configuration                                   │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Show registry
  if [[ -f "$RALPH_REGISTRY_FILE" ]]; then
    local version=$(jq -r '.version // "unknown"' "$RALPH_REGISTRY_FILE" 2>/dev/null)
    echo "${CYAN}Registry:${NC} $RALPH_REGISTRY_FILE (v$version)"
    echo ""

    # Projects - pretty printed
    local project_count=$(jq '.projects | length' "$RALPH_REGISTRY_FILE" 2>/dev/null)
    echo "${BOLD}${YELLOW}═══ Projects ($project_count) ═══${NC}"
    echo ""

    jq -r '.projects | to_entries[] | .key' "$RALPH_REGISTRY_FILE" 2>/dev/null | while read -r project_name; do
      local path=$(jq -r --arg name "$project_name" '.projects[$name].path' "$RALPH_REGISTRY_FILE" 2>/dev/null)
      local mcps=$(jq -r --arg name "$project_name" '.projects[$name].mcps // [] | join(", ")' "$RALPH_REGISTRY_FILE" 2>/dev/null)
      local secrets_count=$(jq -r --arg name "$project_name" '.projects[$name].secrets | keys | length' "$RALPH_REGISTRY_FILE" 2>/dev/null)
      local display_name=$(jq -r --arg name "$project_name" '.projects[$name].displayName // empty' "$RALPH_REGISTRY_FILE" 2>/dev/null)

      echo "  ${BOLD}${GREEN}$project_name${NC}"
      [[ -n "$display_name" ]] && echo "    ${CYAN}Display:${NC} $display_name"
      echo "    ${CYAN}Path:${NC}    $path"
      if [[ -n "$mcps" ]]; then
        echo "    ${CYAN}MCPs:${NC}    $mcps"
      else
        echo "    ${CYAN}MCPs:${NC}    (none)"
      fi
      if [[ "$secrets_count" -gt 0 ]]; then
        local secret_keys=$(jq -r --arg name "$project_name" '.projects[$name].secrets | keys | join(", ")' "$RALPH_REGISTRY_FILE" 2>/dev/null)
        echo "    ${CYAN}Secrets:${NC} $secrets_count configured ($secret_keys)"
      else
        echo "    ${CYAN}Secrets:${NC} (none)"
      fi
      echo ""
    done

    # MCP Definitions
    local mcp_def_count=$(jq '.mcpDefinitions | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
    if [[ "$mcp_def_count" -gt 0 ]]; then
      echo "${BOLD}${YELLOW}═══ MCP Definitions ($mcp_def_count) ═══${NC}"
      echo ""
      jq -r '.mcpDefinitions | to_entries[] | .key' "$RALPH_REGISTRY_FILE" 2>/dev/null | while read -r mcp_name; do
        local cmd=$(jq -r --arg name "$mcp_name" '.mcpDefinitions[$name].command // empty' "$RALPH_REGISTRY_FILE" 2>/dev/null)
        local args=$(jq -r --arg name "$mcp_name" '.mcpDefinitions[$name].args // [] | join(" ")' "$RALPH_REGISTRY_FILE" 2>/dev/null)
        local env_count=$(jq -r --arg name "$mcp_name" '.mcpDefinitions[$name].env // {} | keys | length' "$RALPH_REGISTRY_FILE" 2>/dev/null)

        echo "  ${GREEN}•${NC} ${BOLD}$mcp_name${NC}"
        if [[ -n "$cmd" ]]; then
          echo "      ${CYAN}Command:${NC} $cmd $args"
        fi
        if [[ "$env_count" -gt 0 ]]; then
          echo "      ${CYAN}Env vars:${NC} $env_count"
        fi
      done
      echo ""
    fi

    # Global MCPs
    local global_mcp_count=$(jq '.global.mcps | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
    if [[ "$global_mcp_count" -gt 0 ]]; then
      echo "${BOLD}${YELLOW}═══ Global MCPs ($global_mcp_count) ═══${NC}"
      echo ""
      jq -r '.global.mcps | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null | while read -r mcp; do
        echo "  ${GREEN}•${NC} $mcp"
      done
      echo ""
    fi
  else
    echo "${YELLOW}No registry found.${NC}"
    echo "Run 'ralph-setup' and add a project to create one."
    echo ""
  fi

  # Show config.json summary
  if [[ -f "$RALPH_CONFIG_FILE" ]]; then
    echo "${CYAN}Config: $RALPH_CONFIG_FILE${NC}"
    echo ""
    local strategy=$(jq -r '.modelStrategy // "smart"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    local default_model=$(jq -r '.defaultModel // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    local notifications=$(jq -r '.notifications.enabled // false' "$RALPH_CONFIG_FILE" 2>/dev/null)

    echo "  Model Strategy: $strategy"
    echo "  Default Model: $default_model"
    echo "  Notifications: $notifications"
    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════════════
# repoGolem - Create project launcher functions dynamically
# ═══════════════════════════════════════════════════════════════════
# Usage: repoGolem <name> <path> [mcp1 mcp2 ...]
# Creates: {name}Claude, open{Name}, run{Name}
#
# Example:
#   repoGolem domica ~/Desktop/Gits/domica Context7 tempmail linear
#   → Creates: domicaClaude, openDomica, runDomica
# ═══════════════════════════════════════════════════════════════════
function repoGolem() {
  local name="$1"
  local path="$2"
  shift 2
  local mcps=("$@")

  # Validate inputs
  if [[ -z "$name" || -z "$path" ]]; then
    echo "Usage: repoGolem <name> <path> [mcp1 mcp2 ...]" >&2
    return 1
  fi

  # Expand ~ in path
  path="${path/#\~/$HOME}"

  # Capitalize first letter: domica -> Domica
  local capitalized_name="${(C)name[1]}${name[2,-1]}"
  # Lowercase: Domica -> domica
  local lowercase_name="${(L)name}"

  # Convert mcps array to JSON for _ralph_setup_mcps (no jq dependency)
  local mcps_json="[]"
  if [[ ${#mcps[@]} -gt 0 ]]; then
    local quoted_mcps=()
    for mcp in "${mcps[@]}"; do
      quoted_mcps+=("\"$mcp\"")
    done
    mcps_json="[${(j:,:)quoted_mcps}]"
  fi

  # Create run{Name} function
  eval "function run${capitalized_name}() {
    cd \"$path\" || return 1
    if [[ -f \"package.json\" ]]; then
      if [[ -f \"bun.lockb\" ]] || command -v bun &>/dev/null && grep -q '\"bun\"' package.json 2>/dev/null; then
        bun run dev
      else
        npm run dev
      fi
    else
      echo \"No package.json found in $path\"
      return 1
    fi
  }"

  # Create open{Name} function
  eval "function open${capitalized_name}() {
    cd \"$path\" || return 1
    echo \"Changed to: \$(pwd)\"
  }"

  # Create {name}Claude function with flag shortcuts
  eval "function ${lowercase_name}Claude() {
    local should_update=false
    local notify_mode=\"\"
    local claude_args=()
    local project_key=\"$lowercase_name\"
    local ntfy_topic=\"etans-${lowercase_name}Claude\"

    while [[ \$# -gt 0 ]]; do
      case \"\$1\" in
        -u|--update)
          should_update=true
          shift
          ;;
        -s|--skip-permissions)
          claude_args+=(\"--dangerously-skip-permissions\")
          shift
          ;;
        -c|--continue)
          claude_args+=(\"--continue\")
          shift
          ;;
        -QN|--quiet-notify)
          notify_mode=\"quiet\"
          shift
          ;;
        -SN|--simple-notify)
          notify_mode=\"simple\"
          shift
          ;;
        -VN|--verbose-notify)
          notify_mode=\"verbose\"
          shift
          ;;
        *)
          claude_args+=(\"\$1\")
          shift
          ;;
      esac
    done

    cd \"$path\" || return 1

    # Setup notifications
    rm -f \"/tmp/.claude_notify_config_\${project_key}.json\" 2>/dev/null
    if [[ -n \"\$notify_mode\" ]]; then
      local quiet_val=\"false\"
      local verbose_val=\"false\"
      [[ \"\$notify_mode\" == \"quiet\" ]] && quiet_val=\"true\"
      [[ \"\$notify_mode\" == \"verbose\" ]] && verbose_val=\"true\"
      echo \"{\\\"name\\\":\\\"${capitalized_name} Claude\\\",\\\"topic\\\":\\\"\${ntfy_topic}\\\",\\\"quiet\\\":\${quiet_val},\\\"verbose\\\":\${verbose_val},\\\"cwd\\\":\\\"$path\\\"}\" > \"/tmp/.claude_notify_config_\${project_key}.json\"
    fi

    if \$should_update; then
      echo \"Updating Claude Code...\"
      claude update
    fi

    _ralph_setup_mcps '$mcps_json'
    claude \"\${claude_args[@]}\"
  }"
}

# Generate launchers from registry (new registry-based function)
function _ralph_generate_launchers_from_registry() {
  local launchers_file="$HOME/.config/ralphtools/launchers.zsh"
  local GREEN='\033[0;32m'
  local NC='\033[0m'

  # Create config directory if needed
  /bin/mkdir -p "$HOME/.config/ralphtools"

  # Start with header
  cat > "$launchers_file" << 'HEADER'
# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED by Ralph - do not edit manually
# Regenerate with: _ralph_generate_launchers_from_registry
# ═══════════════════════════════════════════════════════════════════

HEADER

  # If no registry, create empty launchers
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "# No registry found" >> "$launchers_file"
    return 0
  fi

  local project_count=$(jq '.projects | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
  if [[ "$project_count" -eq 0 ]]; then
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  # Generate repoGolem calls for each project
  jq -r '.projects | to_entries[] | "\(.key)|\(.value.path)|\(.value.mcps | join(" "))"' "$RALPH_REGISTRY_FILE" 2>/dev/null | while IFS='|' read -r name path mcps; do
    # Expand ~ in path
    path="${path/#\~/$HOME}"
    echo "repoGolem $name \"$path\" $mcps" >> "$launchers_file"
  done

  echo "${GREEN}✓ Launchers regenerated: $launchers_file${NC}"
}

# First-run detection for ralph-setup
function _ralph_setup_first_run_check() {
  # Check if registry exists and has projects
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    return 0  # Needs setup
  fi

  local project_count=$(jq '.projects | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
  if [[ "$project_count" -eq 0 ]]; then
    return 0  # Needs setup
  fi

  return 1  # Already set up
}

# Show first-run welcome and guide through setup
function _ralph_setup_welcome() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  👋 Welcome to Ralph!                                       │"
  echo "│                                                             │"
  echo "│  Let's set up your first project.                           │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    if gum confirm "Would you like to run the setup wizard?"; then
      ralph-setup
    else
      echo ""
      echo "${YELLOW}You can run 'ralph-setup' later to configure Ralph.${NC}"
      echo ""
    fi
  else
    echo -n "Would you like to run the setup wizard? [Y/n]: "
    read setup_choice
    if [[ "$setup_choice" != [Nn]* ]]; then
      ralph-setup
    else
      echo ""
      echo "${YELLOW}You can run 'ralph-setup' later to configure Ralph.${NC}"
      echo ""
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════
# LAUNCHER GENERATION - Auto-generate project launcher functions
# ═══════════════════════════════════════════════════════════════════
# Generates: run{Name}(), open{Name}(), {name}Claude() for each project
# Output: ~/.config/ralphtools/launchers.zsh
# ═══════════════════════════════════════════════════════════════════

function _ralph_generate_launchers() {
  local projects_file="$HOME/.config/ralphtools/projects.json"
  local launchers_file="$HOME/.config/ralphtools/launchers.zsh"
  local GREEN='\033[0;32m'
  local NC='\033[0m'

  # Create config directory if needed
  /bin/mkdir -p "$HOME/.config/ralphtools"

  # Start with header
  cat > "$launchers_file" << 'HEADER'
# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED by Ralph - do not edit manually
# Regenerate with: _ralph_generate_launchers
# ═══════════════════════════════════════════════════════════════════

HEADER

  # If no projects file, create empty one
  if [[ ! -f "$projects_file" ]]; then
    echo '{"projects": []}' > "$projects_file"
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  local count=$(/usr/bin/jq '.projects | length' "$projects_file" 2>/dev/null || echo "0")
  if [[ "$count" -eq 0 ]]; then
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  # Generate functions for each project
  /usr/bin/jq -r '.projects[] | "\(.name)|\(.path)|\(.mcps | @json)"' "$projects_file" 2>/dev/null | while IFS='|' read -r name path mcps_json; do
    # Capitalize first letter for function names: myProject -> MyProject
    local capitalized_name="${(C)name[1]}${name[2,-1]}"
    # Lowercase name for {name}Claude: MyProject -> myproject
    local lowercase_name="${(L)name}"

    # run{Name}: cd to path and run dev server
    /bin/cat >> "$launchers_file" << EOF
# Project: $name
# Path: $path
# MCPs: $mcps_json

function run${capitalized_name}() {
  cd "$path" || return 1
  if [[ -f "package.json" ]]; then
    if [[ -f "bun.lockb" ]] || command -v bun &>/dev/null && grep -q '"bun"' package.json 2>/dev/null; then
      bun run dev
    else
      npm run dev
    fi
  else
    echo "No package.json found in $path"
    return 1
  fi
}

function open${capitalized_name}() {
  cd "$path" || return 1
  echo "Changed to: \$(pwd)"
}

function ${lowercase_name}Claude() {
  cd "$path" || return 1
  # Set up project-specific MCPs
  _ralph_setup_mcps '$mcps_json'
  claude "\$@"
}

EOF
  done

  echo "${GREEN}✓ Launchers regenerated: $launchers_file${NC}"
}

# Source launchers on load
[[ -f "$HOME/.config/ralphtools/launchers.zsh" ]] && source "$HOME/.config/ralphtools/launchers.zsh"

# ═══════════════════════════════════════════════════════════════════
# RALPH-AUTO - Auto-restart wrapper for Ralph
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph-auto [same args as ralph]
# Automatically restarts Ralph if it crashes due to API errors
# ═══════════════════════════════════════════════════════════════════

function ralph-auto() {
  local max_crashes=10
  local crash_count=0
  local restart_delay=20

  echo "🔄 Ralph Auto-Restart Mode"
  echo "   Max crashes before giving up: $max_crashes"
  echo "   Restart delay: ${restart_delay}s"
  echo ""

  while [[ "$crash_count" -lt "$max_crashes" ]]; do
    # Run ralph with all passed arguments
    ralph "$@"
    local exit_code=$?

    # Check exit codes
    case $exit_code in
      0)
        echo ""
        echo "✅ Ralph completed successfully!"
        return 0
        ;;
      2)
        echo ""
        echo "⏹️ Ralph stopped - all tasks blocked"
        return 2
        ;;
      130)
        echo ""
        echo "🛑 Ralph stopped by user (Ctrl+C)"
        return 130
        ;;
      *)
        crash_count=$((crash_count + 1))

        # Log the crash
        local crash_log="/tmp/ralph_crash_$(date +%Y%m%d_%H%M%S).log"
        {
          echo "═══════════════════════════════════════════════════════════════"
          echo "RALPH CRASH LOG - $(date)"
          echo "═══════════════════════════════════════════════════════════════"
          echo "Exit code: $exit_code"
          echo "Crash count: $crash_count / $max_crashes"
          echo "Working dir: $(pwd)"
          echo "Args: $@"
          echo ""
          echo "─── Last error output ──────────────────────────────────────────"
          [[ -f /tmp/ralph_output.md ]] && tail -50 /tmp/ralph_output.md
          echo ""
        } > "$crash_log"

        echo ""
        echo "  💥 Ralph crashed! (exit code: $exit_code)"
        echo "  📝 Crash log: $crash_log"
        echo "  🔄 Auto-restarting in ${restart_delay}s... (crash $crash_count/$max_crashes)"
        echo ""

        sleep $restart_delay
        ;;
    esac
  done

  echo ""
  echo "❌ Ralph crashed $max_crashes times. Giving up."
  echo "   Check /tmp/ralph_crash_*.log and /tmp/ralph_error_*.log for details"
  return 1
}


# ═══════════════════════════════════════════════════════════════════
# CONVEX DEPLOY WRAPPER - Auto-clean JS artifacts
# ═══════════════════════════════════════════════════════════════════
# Usage: convex-deploy [args...]
# Cleans duplicate JS files before deploying to avoid esbuild errors
function convex-deploy() {
  echo "🧹 Cleaning convex/*.js artifacts..."
  rm -f convex/*.js 2>/dev/null
  echo "🚀 Running convex deploy..."
  npx convex deploy "$@"
  echo "🧹 Post-deploy cleanup..."
  rm -f convex/*.js 2>/dev/null
  echo "✅ Done"
}

# brave-manager - Global wrapper for the Brave Browser Manager script
function brave-manager() {
  node "$RALPH_CONFIG_DIR/scripts/brave-manager.js" "$@"
}

# ═══════════════════════════════════════════════════════════════════
# CONTEXT MIGRATION TOOL
# ═══════════════════════════════════════════════════════════════════

# ralph-migrate-contexts - Analyze CLAUDE.md and suggest shared contexts
# Usage:
#   ralph-migrate-contexts                 # Analyze current project
#   ralph-migrate-contexts /path/to/proj   # Analyze specific project
#   ralph-migrate-contexts --diff          # Show detailed content analysis
#   ralph-migrate-contexts --apply         # Apply migration
function ralph-migrate-contexts() {
  local script_path="$RALPH_CONFIG_DIR/scripts/context-migrate.zsh"

  if [[ ! -f "$script_path" ]]; then
    echo "Error: Migration script not found at $script_path"
    echo "Please ensure ralphtools is properly installed."
    return 1
  fi

  "$script_path" "$@"
}

# ═══════════════════════════════════════════════════════════════════
# INITIALIZATION (runs when sourced)
# ═══════════════════════════════════════════════════════════════════
_ralph_show_whatsnew
