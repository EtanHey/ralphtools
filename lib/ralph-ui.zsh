#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH UI - Colors, progress bars, display helpers
# ═══════════════════════════════════════════════════════════════════
# Part of the Ralph modular system. Sourced by ralph.zsh
# Contains: color constants, semantic color helpers, progress bars,
#           display width calculation, changelog display
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# GLOBAL COLOR CONSTANTS (ANSI escape codes)
# ═══════════════════════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════════════════════
# DISPLAY WIDTH CALCULATION
# ═══════════════════════════════════════════════════════════════════

# Calculate display width of a string
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
# SEMANTIC COLOR HELPERS
# ═══════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════
# STATUS FILE (for UI tools like Ink dashboard)
# ═══════════════════════════════════════════════════════════════════

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

  # Build JSON with proper escaping using jq for safety
  if [[ "$error_msg" != "null" ]]; then
    # Use jq for proper JSON string escaping (handles quotes, backslashes, newlines, etc.)
    if command -v jq >/dev/null 2>&1; then
      error_msg=$(printf '%s' "$error_msg" | jq -Rs '.')
    else
      # Fallback: escape quotes and backslashes
      error_msg="\"$(echo "$error_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')\""
    fi
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

# ═══════════════════════════════════════════════════════════════════
# CHANGELOG DISPLAY
# ═══════════════════════════════════════════════════════════════════

# Show what's new dialog (shown once per version upgrade)
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

# ═══════════════════════════════════════════════════════════════════
# TEXT TRUNCATION HELPERS
# ═══════════════════════════════════════════════════════════════════

# Truncate text at word boundary with ellipsis
# Usage: _ralph_truncate_word_boundary "long text here" 20
# Returns: "long text..." (truncated at word boundary)
_ralph_truncate_word_boundary() {
  local text="$1"
  local max_len="$2"

  # If text fits, return as-is
  if (( ${#text} <= max_len )); then
    echo "$text"
    return
  fi

  # Find last space before max_len-3 (leave room for "...")
  local truncate_at=$((max_len - 3))
  local last_space=0
  local i=0

  # Find the last space position before truncate_at
  for (( i=0; i < truncate_at; i++ )); do
    if [[ "${text:$i:1}" == " " ]]; then
      last_space=$i
    fi
  done

  # If no space found, hard truncate
  if (( last_space == 0 )); then
    echo "${text:0:$truncate_at}..."
  else
    echo "${text:0:$last_space}..."
  fi
}

# ═══════════════════════════════════════════════════════════════════
# VERIFICATION HELPERS
# ═══════════════════════════════════════════════════════════════════

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
# ELAPSED TIME HELPERS
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
# ITERATION STATUS DISPLAY
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

# ═══════════════════════════════════════════════════════════════════
# KEYBOARD CONTROLS
# ═══════════════════════════════════════════════════════════════════

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
# GUM AVAILABILITY CHECK (US-108)
# ═══════════════════════════════════════════════════════════════════

# Global flag for gum availability (set once at startup)
RALPH_HAS_GUM=1  # Default: not available (non-zero = false in shell)

# Check if gum is available
# Usage: _ralph_has_gum  → returns 0 if available, 1 if not
_ralph_has_gum() {
  command -v gum >/dev/null 2>&1
}

# Initialize gum availability (call once at startup)
_ralph_init_gum() {
  if _ralph_has_gum; then
    RALPH_HAS_GUM=0
  else
    RALPH_HAS_GUM=1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# LIVE BASH DASHBOARD (US-108)
# ═══════════════════════════════════════════════════════════════════
# Feature-parity with Ink UI, with live updates via ANSI cursor positioning
# or full re-render on file changes. Uses gum for enhanced styling when available,
# falls back to pure ANSI when not.

# Global state for live dashboard
RALPH_LIVE_DASHBOARD_ROW=0      # Starting row for dashboard
RALPH_LIVE_STATUS_STATE="idle"  # Current status: running, cr_review, error, retry, idle
RALPH_LIVE_LAST_ACTIVITY=0      # Unix timestamp of last activity
RALPH_LIVE_RETRY_SECONDS=0      # Seconds until retry (for retry state)
RALPH_LIVE_ERROR_MSG=""         # Error message (for error state)

# ANSI escape codes for cursor control
ANSI_SAVE_CURSOR='\033[s'
ANSI_RESTORE_CURSOR='\033[u'
ANSI_MOVE_TO_ROW='\033[%d;1H'  # Move to row N, column 1
ANSI_CLEAR_LINE='\033[2K'      # Clear entire line
ANSI_HIDE_CURSOR='\033[?25l'
ANSI_SHOW_CURSOR='\033[?25h'

# Read status from Ralph status file (shared with Ink UI)
# Usage: _ralph_read_status_file
# Sets: RALPH_LIVE_STATUS_STATE, RALPH_LIVE_LAST_ACTIVITY, RALPH_LIVE_ERROR_MSG, RALPH_LIVE_RETRY_SECONDS
_ralph_read_status_file() {
  local status_file="${RALPH_STATUS_FILE:-/tmp/ralph-status-$$.json}"

  if [[ ! -f "$status_file" ]]; then
    RALPH_LIVE_STATUS_STATE="idle"
    RALPH_LIVE_LAST_ACTIVITY=$(date +%s)
    RALPH_LIVE_ERROR_MSG=""
    RALPH_LIVE_RETRY_SECONDS=0
    return 1
  fi

  # Parse JSON status file
  RALPH_LIVE_STATUS_STATE=$(jq -r '.state // "running"' "$status_file" 2>/dev/null)
  RALPH_LIVE_LAST_ACTIVITY=$(jq -r '.lastActivity // 0' "$status_file" 2>/dev/null)
  RALPH_LIVE_ERROR_MSG=$(jq -r '.error // ""' "$status_file" 2>/dev/null)
  RALPH_LIVE_RETRY_SECONDS=$(jq -r '.retryIn // 0' "$status_file" 2>/dev/null)

  # Handle null values
  [[ "$RALPH_LIVE_STATUS_STATE" == "null" ]] && RALPH_LIVE_STATUS_STATE="running"
  [[ "$RALPH_LIVE_ERROR_MSG" == "null" ]] && RALPH_LIVE_ERROR_MSG=""
  [[ "$RALPH_LIVE_LAST_ACTIVITY" == "null" || -z "$RALPH_LIVE_LAST_ACTIVITY" ]] && RALPH_LIVE_LAST_ACTIVITY=$(date +%s)
  [[ "$RALPH_LIVE_RETRY_SECONDS" == "null" || -z "$RALPH_LIVE_RETRY_SECONDS" ]] && RALPH_LIVE_RETRY_SECONDS=0

  return 0
}

# Format time ago string
# Usage: _ralph_format_time_ago 45 → "45s ago"
_ralph_format_time_ago() {
  local seconds="$1"
  if (( seconds < 5 )); then
    echo "just now"
  elif (( seconds < 60 )); then
    echo "${seconds}s ago"
  elif (( seconds < 3600 )); then
    echo "$((seconds / 60))m ago"
  else
    echo "$((seconds / 3600))h ago"
  fi
}

# Get color for time-ago display
# Usage: color=$(_ralph_get_activity_color 30) → yellow
_ralph_get_activity_color() {
  local seconds="$1"
  if (( seconds < 10 )); then
    echo "$RALPH_COLOR_GREEN"
  elif (( seconds < 30 )); then
    echo "$RALPH_COLOR_YELLOW"
  elif (( seconds < 60 )); then
    echo "${RALPH_COLOR_YELLOW}"  # yellowBright approximation
  else
    echo "$RALPH_COLOR_RED"
  fi
}

# Show alive indicator (spinner + last activity)
# Usage: _ralph_show_alive_indicator
_ralph_show_alive_indicator() {
  local now=$(date +%s)
  local seconds_ago=$((now - RALPH_LIVE_LAST_ACTIVITY))
  local time_ago=$(_ralph_format_time_ago $seconds_ago)
  local color=$(_ralph_get_activity_color $seconds_ago)

  if [[ "$RALPH_LIVE_STATUS_STATE" == "idle" ]]; then
    echo -e "${RALPH_COLOR_GRAY}○ Idle${RALPH_COLOR_RESET}"
  else
    # Spinner character (cycles through dots pattern)
    local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local spin_idx=$(( (now % 10) ))
    local spinner="${spinners[$spin_idx]}"
    echo -e "${RALPH_COLOR_GREEN}${spinner}${RALPH_COLOR_RESET} ${color}Last activity: ${time_ago}${RALPH_COLOR_RESET}"
  fi
}

# Show CodeRabbit status indicator
# Usage: _ralph_show_coderabbit_indicator
_ralph_show_coderabbit_indicator() {
  if [[ "$RALPH_LIVE_STATUS_STATE" != "cr_review" ]]; then
    return 0
  fi

  local now=$(date +%s)
  local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local spin_idx=$(( (now % 10) ))
  local spinner="${spinners[$spin_idx]}"

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # Gum available - use gum style for box
    gum style --border rounded --border-foreground 13 --padding "0 1" \
      "${spinner} 🐰 CodeRabbit - Running code review..."
  else
    # Pure ANSI fallback
    echo -e "${RALPH_COLOR_MAGENTA}╭─────────────────────────────────────────╮${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_MAGENTA}│${RALPH_COLOR_RESET} ${spinner} 🐰 CodeRabbit - Running code review... ${RALPH_COLOR_MAGENTA}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_MAGENTA}╰─────────────────────────────────────────╯${RALPH_COLOR_RESET}"
  fi
}

# Show error banner
# Usage: _ralph_show_error_banner "Error message"
_ralph_show_error_banner() {
  local error_msg="${1:-$RALPH_LIVE_ERROR_MSG}"

  [[ -z "$error_msg" ]] && return 0

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # Gum available - use gum style
    gum style --border double --border-foreground 1 --padding "0 2" \
      "❌ ERROR" "$error_msg"
  else
    # Pure ANSI fallback
    echo -e "${RALPH_COLOR_RED}╔════════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_RED}║${RALPH_COLOR_RESET} ${RALPH_COLOR_BOLD}❌ ERROR${RALPH_COLOR_RESET}                                                       ${RALPH_COLOR_RED}║${RALPH_COLOR_RESET}"
    # Wrap error message if too long
    local max_len=60
    if (( ${#error_msg} > max_len )); then
      local line1="${error_msg:0:$max_len}"
      local line2="${error_msg:$max_len}"
      local pad1=$((62 - ${#line1}))
      local pad2=$((62 - ${#line2}))
      echo -e "${RALPH_COLOR_RED}║${RALPH_COLOR_RESET} ${line1}$(printf '%*s' $pad1 '')${RALPH_COLOR_RED}║${RALPH_COLOR_RESET}"
      echo -e "${RALPH_COLOR_RED}║${RALPH_COLOR_RESET} ${line2}$(printf '%*s' $pad2 '')${RALPH_COLOR_RED}║${RALPH_COLOR_RESET}"
    else
      local pad=$((62 - ${#error_msg}))
      echo -e "${RALPH_COLOR_RED}║${RALPH_COLOR_RESET} ${error_msg}$(printf '%*s' $pad '')${RALPH_COLOR_RED}║${RALPH_COLOR_RESET}"
    fi
    echo -e "${RALPH_COLOR_RED}╚════════════════════════════════════════════════════════════════╝${RALPH_COLOR_RESET}"
  fi
}

# Show retry countdown with progress bar
# Usage: _ralph_show_retry_countdown $retry_seconds
_ralph_show_retry_countdown() {
  local retry_in="${1:-$RALPH_LIVE_RETRY_SECONDS}"

  [[ "$RALPH_LIVE_STATUS_STATE" != "retry" || "$retry_in" -le 0 ]] && return 0

  # Build progress bar (20 chars)
  local max_width=20
  local now=$(date +%s)
  # Assume initial retry was stored, calculate remaining
  local progress=$((retry_in * max_width / 30))  # Assume max 30s retry
  (( progress > max_width )) && progress=$max_width
  local bar=$(printf '▓%.0s' $(seq 1 $progress))$(printf '░%.0s' $(seq 1 $((max_width - progress))))

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    gum style --border rounded --border-foreground 3 --padding "0 1" \
      "⏳ Retrying in ${retry_in}s" "[$bar]"
  else
    echo -e "${RALPH_COLOR_YELLOW}╭────────────────────────────╮${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET} ⏳ Retrying in ${retry_in}s          ${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET} [$bar] ${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}╰────────────────────────────╯${RALPH_COLOR_RESET}"
  fi
}

# Show hanging warning (no activity for >60s)
# Usage: _ralph_show_hanging_warning $threshold_seconds
_ralph_show_hanging_warning() {
  local threshold="${1:-60}"
  local now=$(date +%s)
  local seconds_ago=$((now - RALPH_LIVE_LAST_ACTIVITY))

  [[ "$RALPH_LIVE_STATUS_STATE" != "running" && "$RALPH_LIVE_STATUS_STATE" != "cr_review" ]] && return 0
  [[ $seconds_ago -lt $threshold ]] && return 0

  local duration=$(_ralph_format_elapsed $seconds_ago)

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    gum style --border rounded --border-foreground 3 --padding "0 1" \
      "⚠️ Possible Hang Detected" "No activity for ${duration}" \
      "$(gum style --dimmed 'Claude may be processing a large response, or stuck.')"
  else
    echo -e "${RALPH_COLOR_YELLOW}╭─────────────────────────────────────────────────╮${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET} ${RALPH_COLOR_BOLD}⚠️ Possible Hang Detected${RALPH_COLOR_RESET}                       ${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET}"
    local msg="No activity for ${duration}"
    local pad=$((46 - ${#msg}))
    echo -e "${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET} ${msg}$(printf '%*s' $pad '')${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET} ${RALPH_COLOR_GRAY}Claude may be processing a large response, or stuck.${RALPH_COLOR_RESET} ${RALPH_COLOR_YELLOW}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}╰─────────────────────────────────────────────────╯${RALPH_COLOR_RESET}"
  fi
}

# Show PRD status box (matches Ink UI's PRDStatus component)
# Usage: _ralph_show_prd_status_box $json_dir
_ralph_show_prd_status_box() {
  local json_dir="$1"

  # Derive stats on-the-fly
  local derived_stats=$(_ralph_derive_stats "$json_dir")
  local pending=$(echo "$derived_stats" | awk '{print $1}')
  local blocked=$(echo "$derived_stats" | awk '{print $2}')
  local completed=$(echo "$derived_stats" | awk '{print $3}')
  local total=$(echo "$derived_stats" | awk '{print $4}')

  # Get criteria progress
  local criteria_stats=$(_ralph_get_total_criteria "$json_dir")
  local criteria_checked=$(echo "$criteria_stats" | cut -d' ' -f1)
  local criteria_total=$(echo "$criteria_stats" | cut -d' ' -f2)

  # Calculate percentages
  local story_percent=0
  [[ "$total" -gt 0 ]] && story_percent=$((completed * 100 / total))
  local criteria_percent=0
  [[ "$criteria_total" -gt 0 ]] && criteria_percent=$((criteria_checked * 100 / criteria_total))

  # Build progress bars (25 chars)
  local story_bar=$(_ralph_progress_bar "$completed" "$total" 25)
  local criteria_bar=$(_ralph_progress_bar "$criteria_checked" "$criteria_total" 25)

  echo "┌───────────────────────────────────────────────────────────────┐"
  echo -e "│  ${RALPH_COLOR_BLUE}${RALPH_COLOR_BOLD}📊 PRD Status${RALPH_COLOR_RESET}                                              │"
  echo "│                                                               │"

  # Story counts line
  local stories_str="Stories: "
  stories_str+="${RALPH_COLOR_GREEN}${completed} done${RALPH_COLOR_RESET}"
  stories_str+=" / ${RALPH_COLOR_YELLOW}${pending} pending${RALPH_COLOR_RESET}"
  if [[ "$blocked" -gt 0 ]]; then
    stories_str+=" / ${RALPH_COLOR_RED}${blocked} blocked${RALPH_COLOR_RESET}"
  fi
  stories_str+=" ${RALPH_COLOR_GRAY}(${total} total)${RALPH_COLOR_RESET}"
  echo -e "│  ${stories_str}$(printf '%*s' 10 '')│"

  echo "│                                                               │"
  echo "│  Story Progress:                                              │"
  echo -e "│  ${story_bar}$(printf '%*s' 24 '')│"
  echo "│                                                               │"
  echo "│  Criteria Progress:                                           │"
  echo -e "│  ${criteria_bar}$(printf '%*s' 24 '')│"
  echo "└───────────────────────────────────────────────────────────────┘"
}

# Show current story box (matches Ink UI's StoryBox component)
# Usage: _ralph_show_story_box $story_id $json_dir
_ralph_show_story_box() {
  local story_id="$1"
  local json_dir="$2"
  local story_file="$json_dir/stories/${story_id}.json"

  [[ ! -f "$story_file" ]] && return 1

  local title=$(jq -r '.title // "Unknown"' "$story_file" 2>/dev/null)
  local passes=$(jq -r '.passes // false' "$story_file" 2>/dev/null)
  local blocked_by=$(jq -r '.blockedBy // null' "$story_file" 2>/dev/null)

  # Get criteria progress
  local criteria_stats=$(_ralph_get_story_criteria_progress "$story_id" "$json_dir")
  local checked=$(echo "$criteria_stats" | awk '{print $1}')
  local total_crit=$(echo "$criteria_stats" | awk '{print $2}')

  # Determine border color
  local border_color="$RALPH_COLOR_YELLOW"
  if [[ "$passes" == "true" ]]; then
    border_color="$RALPH_COLOR_GREEN"
  elif [[ "$blocked_by" != "null" && -n "$blocked_by" ]]; then
    border_color="$RALPH_COLOR_RED"
  fi

  # Build progress bar
  local criteria_bar=$(_ralph_progress_bar "$checked" "$total_crit" 20)

  echo -e "${border_color}╭───────────────────────────────────────────────────────────────╮${RALPH_COLOR_RESET}"

  # Story ID and title
  local colored_id=$(_ralph_color_story_id "$story_id")
  local title_display="$title"
  # Truncate title if too long
  if (( ${#title_display} > 50 )); then
    title_display="${title_display:0:47}..."
  fi
  echo -e "${border_color}│${RALPH_COLOR_RESET} ${colored_id} - ${title_display}$(printf '%*s' $((50 - ${#title_display})) '')${border_color}│${RALPH_COLOR_RESET}"

  echo -e "${border_color}│${RALPH_COLOR_RESET}                                                               ${border_color}│${RALPH_COLOR_RESET}"
  echo -e "${border_color}│${RALPH_COLOR_RESET} ${RALPH_COLOR_BOLD}Acceptance Criteria:${RALPH_COLOR_RESET}                                      ${border_color}│${RALPH_COLOR_RESET}"
  echo -e "${border_color}│${RALPH_COLOR_RESET} ${criteria_bar}$(printf '%*s' 29 '')${border_color}│${RALPH_COLOR_RESET}"

  # Show individual criteria (up to 10)
  local criteria_json=$(jq -r '.acceptanceCriteria // []' "$story_file" 2>/dev/null)
  local count=0
  while IFS= read -r criterion; do
    [[ -z "$criterion" || "$criterion" == "null" ]] && continue
    local text=$(echo "$criterion" | jq -r '.text // ""')
    local is_checked=$(echo "$criterion" | jq -r '.checked // false')

    # Truncate text if too long
    if (( ${#text} > 55 )); then
      text="${text:0:52}..."
    fi

    local check_mark="○"
    local check_color="$RALPH_COLOR_GRAY"
    if [[ "$is_checked" == "true" ]]; then
      check_mark="✓"
      check_color="$RALPH_COLOR_GREEN"
    fi

    local pad=$((58 - ${#text}))
    echo -e "${border_color}│${RALPH_COLOR_RESET} ${check_color}${check_mark}${RALPH_COLOR_RESET} ${text}$(printf '%*s' $pad '')${border_color}│${RALPH_COLOR_RESET}"

    ((count++))
    [[ $count -ge 10 ]] && break
  done < <(echo "$criteria_json" | jq -c '.[]' 2>/dev/null)

  # Show "and X more" if there are more criteria
  local total_criteria=$(echo "$criteria_json" | jq 'length' 2>/dev/null)
  if [[ "$total_criteria" -gt 10 ]]; then
    local remaining=$((total_criteria - 10))
    echo -e "${border_color}│${RALPH_COLOR_RESET} ${RALPH_COLOR_GRAY}...and ${remaining} more${RALPH_COLOR_RESET}$(printf '%*s' 48 '')${border_color}│${RALPH_COLOR_RESET}"
  fi

  echo -e "${border_color}╰───────────────────────────────────────────────────────────────╯${RALPH_COLOR_RESET}"
}

# Show notification status box (matches Ink UI's NotificationStatus component)
# Usage: _ralph_show_notification_box $topic [$enabled]
_ralph_show_notification_box() {
  local topic="$1"
  local enabled="${2:-true}"

  if [[ "$enabled" != "true" || -z "$topic" ]]; then
    echo "┌───────────────────────────────────────────────────────────────┐"
    echo -e "│  ${RALPH_COLOR_GRAY}🔔 Notifications: disabled${RALPH_COLOR_RESET}                                  │"
    echo "└───────────────────────────────────────────────────────────────┘"
    return
  fi

  echo -e "${RALPH_COLOR_GREEN}┌───────────────────────────────────────────────────────────────┐${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}  ${RALPH_COLOR_GREEN}🔔 Notifications: enabled${RALPH_COLOR_RESET}                                   ${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}"

  # Wrap topic if too long (instead of truncating)
  local max_topic_len=50
  if (( ${#topic} > max_topic_len )); then
    local line1="${topic:0:$max_topic_len}"
    local line2="${topic:$max_topic_len}"
    local pad1=$((58 - ${#line1}))
    local pad2=$((58 - ${#line2}))
    echo -e "${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}  ${RALPH_COLOR_GRAY}Topic:${RALPH_COLOR_RESET} ${line1}$(printf '%*s' $pad1 '')${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}         ${line2}$(printf '%*s' $pad2 '')${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}"
  else
    local pad=$((52 - ${#topic}))
    echo -e "${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}  ${RALPH_COLOR_GRAY}Topic:${RALPH_COLOR_RESET} ${topic}$(printf '%*s' $pad '')${RALPH_COLOR_GREEN}│${RALPH_COLOR_RESET}"
  fi

  echo -e "${RALPH_COLOR_GREEN}╰───────────────────────────────────────────────────────────────╯${RALPH_COLOR_RESET}"
}

# Show full live dashboard (feature-parity with Ink UI)
# Usage: _ralph_show_live_dashboard $json_dir $iteration $model $start_time $ntfy_topic [$story_id]
_ralph_show_live_dashboard() {
  local json_dir="$1"
  local iteration="${2:-1}"
  local model="${3:-sonnet}"
  local start_time="${4:-$(date +%s)}"
  local ntfy_topic="$5"
  local story_id="$6"

  # Read status file for live state
  _ralph_read_status_file

  # Calculate elapsed time
  local now=$(date +%s)
  local elapsed=$((now - start_time))
  local elapsed_str=$(_ralph_format_elapsed $elapsed)
  local current_time=$(date '+%H:%M:%S')

  # Get terminal width
  local term_width=$(tput cols 2>/dev/null || echo 80)
  local box_width=$((term_width < 80 ? term_width - 2 : 78))
  local border_line=$(printf '─%.0s' $(seq 1 $box_width))

  # Header
  echo -e "${RALPH_COLOR_BLUE}${RALPH_COLOR_BOLD}╭${border_line}╮${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_BLUE}${RALPH_COLOR_BOLD}│${RALPH_COLOR_RESET} 🐺 RALPH - Live Bash Dashboard $(printf '%*s' $((box_width - 45)) '') 🕐 ${current_time} ${RALPH_COLOR_BLUE}${RALPH_COLOR_BOLD}│${RALPH_COLOR_RESET}"

  # Iteration header
  local colored_model=$(_ralph_color_model "$model")
  echo ""
  echo -e "${RALPH_COLOR_CYAN}╭───────────────────────────────────────────────────────────────╮${RALPH_COLOR_RESET}"

  # Show spinner if running
  local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local spin_idx=$(( (now % 10) ))
  local spinner=""
  [[ "$RALPH_LIVE_STATUS_STATE" == "running" || "$RALPH_LIVE_STATUS_STATE" == "cr_review" ]] && spinner="${RALPH_COLOR_GREEN}${spinners[$spin_idx]}${RALPH_COLOR_RESET} "

  echo -e "${RALPH_COLOR_CYAN}│${RALPH_COLOR_RESET} ${spinner}${RALPH_COLOR_CYAN}${RALPH_COLOR_BOLD}Iteration ${iteration}${RALPH_COLOR_RESET}$(printf '%*s' 30 '')Model: ${colored_model} ${RALPH_COLOR_CYAN}│${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_CYAN}│${RALPH_COLOR_RESET}$(printf '%*s' 45 '')${RALPH_COLOR_GRAY}Elapsed: ${elapsed_str}${RALPH_COLOR_RESET} ${RALPH_COLOR_CYAN}│${RALPH_COLOR_RESET}"
  echo -e "${RALPH_COLOR_CYAN}╰───────────────────────────────────────────────────────────────╯${RALPH_COLOR_RESET}"

  # Status indicators (only shown when running)
  if [[ "$RALPH_LIVE_STATUS_STATE" != "idle" ]]; then
    echo ""

    # Alive indicator
    _ralph_show_alive_indicator

    # CodeRabbit status
    _ralph_show_coderabbit_indicator

    # Error banner
    if [[ -n "$RALPH_LIVE_ERROR_MSG" ]]; then
      _ralph_show_error_banner
    fi

    # Retry countdown
    _ralph_show_retry_countdown

    # Hanging warning (>60s no activity)
    _ralph_show_hanging_warning 60
  fi

  echo ""

  # PRD Status box
  _ralph_show_prd_status_box "$json_dir"

  echo ""

  # Current story box (if provided)
  if [[ -n "$story_id" ]]; then
    _ralph_show_story_box "$story_id" "$json_dir"
    echo ""
  fi

  # Notification status
  local notify_enabled="false"
  [[ -n "$ntfy_topic" ]] && notify_enabled="true"
  _ralph_show_notification_box "$ntfy_topic" "$notify_enabled"

  # Footer
  echo ""
  local footer_hint=""
  if [[ -t 0 ]]; then
    footer_hint="Press 'q' to quit"
  else
    footer_hint="Ctrl+C to quit"
  fi
  echo -e "${RALPH_COLOR_GRAY}${footer_hint} • Terminal width: ${term_width}${RALPH_COLOR_RESET}"
}

# Run live dashboard with polling updates
# Usage: _ralph_run_live_bash_dashboard $json_dir $iteration $model $start_time $ntfy_topic [$story_id]
_ralph_run_live_bash_dashboard() {
  local json_dir="$1"
  local iteration="${2:-1}"
  local model="${3:-sonnet}"
  local start_time="${4:-$(date +%s)}"
  local ntfy_topic="$5"
  local story_id="$6"

  # Initialize gum availability
  _ralph_init_gum

  # Hide cursor during updates
  printf "$ANSI_HIDE_CURSOR"

  # Trap to show cursor on exit
  trap 'printf "$ANSI_SHOW_CURSOR"; return 0' INT TERM

  local quit_requested=false

  while [[ "$quit_requested" != "true" ]]; do
    # Clear screen and move to top
    printf '\033[2J\033[H'

    # Render dashboard
    _ralph_show_live_dashboard "$json_dir" "$iteration" "$model" "$start_time" "$ntfy_topic" "$story_id"

    # Check for keyboard input (non-blocking)
    if read -t 1 -k 1 key 2>/dev/null; then
      case "$key" in
        q|Q) quit_requested=true ;;
      esac
    fi
  done

  # Show cursor on exit
  printf "$ANSI_SHOW_CURSOR"
}

# Show status spinner based on current state
# Uses gum spin if available, pure ANSI otherwise
# Usage: _ralph_show_status_spinner "Running..." &  # Run in background
_ralph_show_status_spinner() {
  local message="${1:-Running...}"
  local state="${2:-$RALPH_LIVE_STATUS_STATE}"

  # Select spinner type based on state
  local spinner_type="dot"
  local color="green"
  case "$state" in
    running)
      spinner_type="dot"
      color="green"
      message="🟢 ${message}"
      ;;
    cr_review)
      spinner_type="moon"
      color="magenta"
      message="🐰 CR reviewing..."
      ;;
    error)
      spinner_type="points"
      color="red"
      message="🔴 Error: ${message}"
      ;;
    retry)
      spinner_type="dot"
      color="yellow"
      message="🔴 Retry in ${RALPH_LIVE_RETRY_SECONDS}s..."
      ;;
    hanging)
      spinner_type="pulse"
      color="yellow"
      local now=$(date +%s)
      local wait_time=$((now - RALPH_LIVE_LAST_ACTIVITY))
      message="🟡 Waiting (${wait_time}s)..."
      ;;
  esac

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # Use gum spin
    gum spin --spinner "$spinner_type" --spinner.foreground "$color" --title "$message" -- sleep infinity &
    RALPH_SPINNER_PID=$!
  else
    # Pure ANSI spinner
    local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    while true; do
      local spinner="${spinners[$((i % 10))]}"
      printf '\r%s %s ' "$spinner" "$message"
      sleep 0.1
      ((i++))
    done &
    RALPH_SPINNER_PID=$!
  fi
}

# Stop the current spinner
_ralph_stop_status_spinner() {
  if [[ -n "$RALPH_SPINNER_PID" ]]; then
    kill "$RALPH_SPINNER_PID" 2>/dev/null
    wait "$RALPH_SPINNER_PID" 2>/dev/null
    RALPH_SPINNER_PID=""
    printf '\r\033[K'  # Clear spinner line
  fi
}
