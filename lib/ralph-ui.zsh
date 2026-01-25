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
