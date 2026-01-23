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
#   (no flag) : No notifications, Opus model (default)
#
# Model Flags (can specify two: first=primary, second=verification):
#   -O   : Opus (Claude, default)
#   -S   : Sonnet (Claude, faster)
#   -H   : Haiku (Claude, fastest)
#   -K   : Kiro CLI (no browser MCPs)
#   -G   : Gemini CLI (has browser MCPs)
#
# Model Routing:
#   - First flag = model for US-*/BUG-* stories
#   - Second flag = model for V-* verification stories (default: Haiku)
#   - Examples: -G -H (Gemini main, Haiku verify), -K -G (Kiro main, Gemini verify)
#
# App Mode:
#   - PRD: apps/{app}/prd-json/
#   - Branch: feat/{app}-work (creates if needed)
#   - Notifications: {project}-{app} topic
#   - Multiple can run simultaneously on different branches
#
# Prerequisites:
# 1. Create prd-json/ with user stories (use /prd skill)
# 2. Each story should be small (completable in one context window)
# 3. Run `ralph` from project root
#
# This is the ORIGINAL Ralph concept - a bash loop spawning FRESH
# Claude instances. Unlike the plugin, each iteration gets clean context.
# Output streams in REAL-TIME so you can watch Claude work.
# ═══════════════════════════════════════════════════════════════════

RALPH_VERSION="1.3.0"

# ═══════════════════════════════════════════════════════════════════
# CHANGELOG (associative array with version -> changes mapping)
# ═══════════════════════════════════════════════════════════════════
declare -A RALPH_CHANGELOG
RALPH_CHANGELOG[1.3.0]="Per-iteration cost tracking (actual tokens from JSONL)|Enhanced ntfy notifications with titles & priorities|Session IDs passed to Claude for precise tracking|ralph-costs shows ✓ actual vs ~ estimated data"
RALPH_CHANGELOG[1.2.0]="Smart model routing (US→Sonnet, V→Haiku, etc.)|Config-based model assignment via config.json|Cost tracking infrastructure"
RALPH_CHANGELOG[1.1.0]="JSON mode with automatic unblocking|Brave browser manager integration|Smart file access with shell fallbacks"
RALPH_CHANGELOG[1.0.0]="Initial Ralph release|Autonomous loop for executing user stories|Git-based workflow and commit tracking"

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
    # Print with formatting
    printf "│  • %-57s │\n" "$change"
    # Remove processed change from string
    [[ "$changes" == *"|"* ]] && changes="${changes#*\|}" || changes=""
  done

  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""
}

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
# Source local config if it exists (for personal overrides)
RALPH_CONFIG_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}"
[[ -f "$RALPH_CONFIG_DIR/ralph-config.local" ]] && source "$RALPH_CONFIG_DIR/ralph-config.local"

# Defaults (can be overridden in ralph-config.local or environment)
RALPH_NTFY_TOPIC="${RALPH_NTFY_TOPIC:-ralph-notifications}"
# Note: Use simple default without braces to avoid zsh glob interpretation
[[ -z "$RALPH_NTFY_TOPIC_PATTERN" ]] && RALPH_NTFY_TOPIC_PATTERN='{project}-{app}'
RALPH_DEFAULT_MODEL="${RALPH_DEFAULT_MODEL:-opus}"
RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-10}"
RALPH_SLEEP_SECONDS="${RALPH_SLEEP_SECONDS:-2}"
RALPH_VALID_APPS="${RALPH_VALID_APPS:-frontend backend mobile expo public admin}"
RALPH_CONFIG_FILE="${RALPH_CONFIG_DIR}/config.json"
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

  # Calculate percentage and filled blocks
  local percent=$((current * 100 / total))
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

  local model_strategy=""
  local default_model=""
  local notifications_enabled=""
  local ntfy_topic=""

  # Check if gum is available
  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    # ═══════════════════════════════════════════════════════════
    # GUM-BASED INTERACTIVE PROMPTS
    # ═══════════════════════════════════════════════════════════

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
      echo "📬 Enter your ntfy topic name:"
      ntfy_topic=$(gum input --placeholder "ralph-notifications")
      [[ -z "$ntfy_topic" ]] && ntfy_topic="ralph-notifications"
      echo "   Topic: $ntfy_topic"
    else
      notifications_enabled="false"
      ntfy_topic=""
    fi

  else
    # ═══════════════════════════════════════════════════════════
    # FALLBACK: Simple read prompts
    # ═══════════════════════════════════════════════════════════
    echo "ℹ️  (Install gum for a better experience: brew install gum)"
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
        echo -n "   Enter ntfy topic [ralph-notifications]: "
        read ntfy_topic
        [[ -z "$ntfy_topic" ]] && ntfy_topic="ralph-notifications"
        echo "   Topic: $ntfy_topic"
        ;;
      *)
        notifications_enabled="false"
        ntfy_topic=""
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
    "maxIterations": $RALPH_MAX_ITERATIONS,
    "sleepSeconds": $RALPH_SLEEP_SECONDS
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
    "maxIterations": 10,
    "sleepSeconds": 2
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
    "maxIterations": 10,
    "sleepSeconds": 2
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
    "maxIterations": 10,
    "sleepSeconds": 2
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
    RALPH_MODEL_STRATEGY=$(jq -r '.modelStrategy // "single"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_DEFAULT_MODEL_CFG=$(jq -r '.defaultModel // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_UNKNOWN_TASK_MODEL=$(jq -r '.unknownTaskType // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load model mappings for smart routing
    RALPH_MODEL_US=$(jq -r '.models.US // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_V=$(jq -r '.models.V // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_TEST=$(jq -r '.models.TEST // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_BUG=$(jq -r '.models.BUG // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_MODEL_AUDIT=$(jq -r '.models.AUDIT // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)

    # Load notification settings
    local notify_enabled=$(jq -r '.notifications.enabled // false' "$RALPH_CONFIG_FILE" 2>/dev/null)
    if [[ "$notify_enabled" == "true" ]]; then
      RALPH_NTFY_TOPIC=$(jq -r '.notifications.ntfyTopic // "ralph-notifications"' "$RALPH_CONFIG_FILE" 2>/dev/null)
    fi

    # Load defaults
    local max_iter=$(jq -r '.defaults.maxIterations // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    local sleep_sec=$(jq -r '.defaults.sleepSeconds // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
    [[ -n "$max_iter" && "$max_iter" != "null" ]] && RALPH_MAX_ITERATIONS="$max_iter"
    [[ -n "$sleep_sec" && "$sleep_sec" != "null" ]] && RALPH_SLEEP_SECONDS="$sleep_sec"

    # Load parallel verification settings
    RALPH_PARALLEL_VERIFICATION=$(jq -r '.parallelVerification // false' "$RALPH_CONFIG_FILE" 2>/dev/null)
    RALPH_PARALLEL_AGENTS=$(jq -r '.parallelAgents // 2' "$RALPH_CONFIG_FILE" 2>/dev/null)

    return 0
  fi
  return 1
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
    echo -e "   ???  → $(_ralph_color_model "${RALPH_UNKNOWN_TASK_MODEL:-sonnet}")"
  else
    echo -e "🧠 Single Model: $(_ralph_color_model "${RALPH_DEFAULT_MODEL_CFG:-opus}")"
  fi
}

# Load config on source
_ralph_load_config

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

# Send compact ntfy notification with emoji labels
# Usage: _ralph_ntfy "topic" "event_type" "story_id" "model" "iteration" "remaining_stats" "cost"
# remaining_stats should be "stories criteria" space-separated (from _ralph_json_remaining_stats)
# Body format (3 lines):
#   Line 1: repo name (e.g. 'ralphtools')
#   Line 2: 🔄iteration story_id model (e.g. '🔄5 TEST-004 haiku')
#   Line 3: 📚stories ☐criteria 💵cost (e.g. '📚26 ☐129 💵$0.28')
_ralph_ntfy() {
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

  # Send with ntfy headers for rich notification
  curl -s \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$(echo -e "$body")" \
    "ntfy.sh/${topic}" > /dev/null 2>&1
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

  # Update index.json - remove from pending
  if [[ -f "$index_file" ]]; then
    jq --arg id "$story_id" '.pending = [.pending[] | select(. != $id)] | .stats.completed += 1 | .stats.pending -= 1 | .nextStory = (.pending[0] // "COMPLETE")' "$index_file" > "$tmp_file"
    mv "$tmp_file" "$index_file"
  fi
}

# Apply queued updates from update.json (allows external processes to queue changes)
_ralph_apply_update_queue() {
  local json_dir="$1"
  local update_file="$json_dir/update.json"
  local index_file="$json_dir/index.json"

  if [[ -f "$update_file" ]] && [[ -f "$index_file" ]]; then
    # Merge update.json into index.json using jq
    local tmp_file=$(mktemp)
    if jq -s '.[0] * .[1]' "$index_file" "$update_file" > "$tmp_file" 2>/dev/null; then
      mv "$tmp_file" "$index_file"
      rm -f "$update_file"
      echo "  📥 Applied queued updates from update.json"
    else
      rm -f "$tmp_file"
    fi
  fi
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

        # Move from blocked to pending in index
        jq --arg id "$story_id" '
          .blocked = [.blocked[] | select(. != $id)] |
          .pending = (.pending + [$id]) |
          .stats.blocked = (.blocked | length) |
          .stats.pending = (.pending | length)
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

  local stories=$(jq -r '.stats.pending // 0' "$index_file")

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
  local json_dir="$1"
  local index_file="$json_dir/index.json"

  if [[ ! -f "$index_file" ]]; then
    echo "0 0"
    return
  fi

  local stories=$(jq -r '.stats.pending // 0' "$index_file")

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
  local ntfy_topic="$RALPH_NTFY_TOPIC"
  local app_mode=""
  local target_branch=""
  local original_branch=""
  local skip_setup=false     # Skip interactive setup, use defaults
  local compact_mode=false   # Compact output mode (less verbose)
  local debug_mode=false     # Debug output mode (more verbose)

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
          # Get project name from directory for ntfy topic
          local project_name=$(basename "$REPO_ROOT")
          # Build ntfy topic from pattern (replace {project} and {app})
          ntfy_topic="${RALPH_NTFY_TOPIC_PATTERN//\{project\}/$project_name}"
          ntfy_topic="${ntfy_topic//\{app\}/$app_mode}"
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
    echo "  1. Run 'claude' and use '/prd' to generate a PRD"
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

  # Create progress.txt if it doesn't exist
  if [[ ! -f "progress.txt" ]]; then
    echo "# Progress Log" > progress.txt
    echo "" >> progress.txt
    echo "## Learnings" >> progress.txt
    echo "(Patterns discovered during implementation)" >> progress.txt
    echo "" >> progress.txt
    echo "---" >> progress.txt
  fi

  # Cleanup on exit (and switch back to original branch in app mode)
  cleanup_ralph() {
    rm -f "$RALPH_TMP"
    if [[ -n "$app_mode" && -n "$original_branch" ]]; then
      echo ""
      echo "🔙 Returning to original branch: $original_branch"
      git checkout "$original_branch" 2>/dev/null
    fi
  }
  trap cleanup_ralph EXIT

  if [[ "$compact_mode" == "true" ]]; then
    # Compact mode: single-line startup
    local project_name=$(basename "$(pwd)")
    local pending=$(jq -r '.stats.pending // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null || echo "?")
    local completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null || echo "?")
    echo ""
    echo "🚀 Ralph v${RALPH_VERSION} │ ${project_name} │ ${completed}/${pending}+${completed} stories │ max ${MAX} iters"
  else
    # Normal mode: full startup banner
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  🚀 RALPH v${RALPH_VERSION}                                         ║"
    echo "╠───────────────────────────────────────────────────────────────╣"
    echo "║  📂 $(pwd | head -c 55)$(printf '%*s' $((55 - ${#$(pwd)})) '')║"
    if [[ -n "$app_mode" ]]; then
      echo "║  📱 App: $app_mode (branch: $target_branch)$(printf '%*s' $((45 - ${#app_mode} - ${#target_branch})) '')║"
    fi
    echo "║  🔄 Max iterations: $MAX$(printf '%*s' $((42 - ${#MAX})) '')║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Show routing config (smart vs single)
    if [[ -z "$primary_model" && -z "$verify_model" ]]; then
      # No CLI override - show config-based routing
      _ralph_show_routing
    fi
    # Count and display based on mode
    echo "┌─────────────────────────────────────────────────────────────┐"
    if [[ "$use_json_mode" == "true" ]]; then
      local pending=$(jq -r '.stats.pending // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
      local completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
      local blocked=$(jq -r '.stats.blocked // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
      echo "│  📋 Stories: $pending pending │ $completed completed │ $blocked blocked$(printf '%*s' $((27 - ${#pending} - ${#completed} - ${#blocked})) '')│"
    else
      local task_count=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
      echo "│  📋 Tasks remaining: $task_count$(printf '%*s' $((38 - ${#task_count})) '')│"
    fi
    if $notify_enabled; then
      echo "│  🔔 Notifications: ON (topic: ${ntfy_topic})$(printf '%*s' $((28 - ${#ntfy_topic})) '')│"
    else
      echo "│  🔕 Notifications: OFF                                      │"
    fi
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
  fi

  for ((i=1; i<=$MAX; i++)); do
    # Determine current story and model to use
    local current_story=""
    local effective_model=""

    if [[ "$use_json_mode" == "true" ]]; then
      current_story=$(_ralph_json_next_story "$PRD_JSON_DIR")
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
      echo -e "║  🔄 $(_ralph_bold "ITERATION $i") of $MAX                                       ║"
      echo "╠───────────────────────────────────────────────────────────────╣"
      echo "║  ⏱️  $(date '+%H:%M:%S')                                        ║"
      # Show iteration progress bar
      local iter_progress=$(_ralph_iteration_progress "$i" "$MAX")
      echo -e "║  📊 Iteration: ${iter_progress}$(printf '%*s' $((36 - ${#i} - ${#MAX})) '')║"
      if [[ -n "$current_story" ]]; then
        local colored_story=$(_ralph_color_story_id "$current_story")
        echo -e "║  📖 Story: ${colored_story}$(printf '%*s' $((47 - ${#current_story})) '')║"
        # Show criteria progress for current story (JSON mode only)
        if [[ "$use_json_mode" == "true" ]]; then
          local criteria_stats=$(_ralph_get_story_criteria_progress "$current_story" "$PRD_JSON_DIR")
          local criteria_checked=$(echo "$criteria_stats" | awk '{print $1}')
          local criteria_total=$(echo "$criteria_stats" | awk '{print $2}')
          if [[ "$criteria_total" -gt 0 ]]; then
            local criteria_bar=$(_ralph_criteria_progress "$criteria_checked" "$criteria_total")
            echo -e "║  ☐ Criteria:  ${criteria_bar}$(printf '%*s' $((35 - ${#criteria_checked} - ${#criteria_total})) '')║"
          fi
        fi
      fi
      local colored_model=$(_ralph_color_model "$effective_model")
      echo -e "║  🧠 Model: ${colored_model}$(printf '%*s' $((47 - ${#effective_model})) '')║"
      # Show story progress (JSON mode only)
      if [[ "$use_json_mode" == "true" ]]; then
        local story_completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        local story_total=$(jq -r '.stats.total // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        local story_bar=$(_ralph_story_progress "$story_completed" "$story_total")
        echo -e "║  📚 Stories:  ${story_bar}$(printf '%*s' $((35 - ${#story_completed} - ${#story_total})) '')║"
      fi
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""
    fi

    # Retry logic for transient API errors like "No messages returned"
    local max_retries=5
    local retry_count=0
    local no_messages_retry_count=0
    local no_messages_max_retries=3
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
          cli_cmd_arr=(kiro-cli chat --trust-all-tools --no-interactive)
          prompt_flag=""  # Kiro takes prompt as positional argument
          iteration_session_id=""  # Kiro doesn't use session IDs
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
          cli_cmd_arr=(claude --chrome --dangerously-skip-permissions --model "$active_model" --session-id "$iteration_session_id")
          ;;
        *)
          # Default: Claude Opus
          cli_cmd_arr=(claude --chrome --dangerously-skip-permissions --session-id "$iteration_session_id")
          ;;
      esac

      # Build the prompt based on JSON vs Markdown mode
      local ralph_prompt=""
      local brave_skill=""
      local ralph_agent_instructions=""
      [[ -f "$RALPH_CONFIG_DIR/skills/brave.md" ]] && brave_skill=$(cat "$RALPH_CONFIG_DIR/skills/brave.md")
      [[ -f "$RALPH_CONFIG_DIR/RALPH_AGENT.md" ]] && ralph_agent_instructions=$(cat "$RALPH_CONFIG_DIR/RALPH_AGENT.md")

      if [[ "$use_json_mode" == "true" ]]; then
        # JSON MODE PROMPT
        ralph_prompt="You are Ralph, an autonomous coding agent. Do exactly ONE task per iteration.

${brave_skill}

${ralph_agent_instructions}

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

      # Run CLI with output capture (tee for checking promises)
      # Note: Claude uses -p flag, Kiro uses positional argument (${prompt_flag:+...} expands only if non-empty)
      "${cli_cmd_arr[@]}" ${prompt_flag:+$prompt_flag} "${ralph_prompt}

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
3. **UPDATE progress.txt**: Add iteration summary
4. **COMMIT**: git add prd-json/ progress.txt && git commit -m \"feat: [story-id] [description]\"
5. **VERIFY**: git log -1 (confirm commit succeeded)
6. If commit fails, STOP and report error

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
- Some stories still pending: end response (next iteration continues)" 2>&1 | tee "$RALPH_TMP"

      # Capture exit code of Claude (pipestatus[1] in zsh gets first command in pipe)
      # Note: zsh uses lowercase 'pipestatus' and 1-indexed arrays
      local exit_code=${pipestatus[1]:-999}

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
      local error_patterns="No messages returned|EAGAIN|ECONNRESET|fetch failed|API error|promise rejected|UnhandledPromiseRejection|ETIMEDOUT|socket hang up|ENOTFOUND|rate limit|overloaded|Error: 5[0-9][0-9]|status.*(5[0-9][0-9])|HTTP.*5[0-9][0-9]"
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
          echo "  ⏳ Waiting 30 seconds (API cooldown)..."
          sleep 30
          # Fresh session ID will be generated at the start of the next loop iteration
          continue
        else
          # Max retries exhausted for this specific error - skip this story
          echo ""
          echo -e "  ❌ $(_ralph_error "'No messages returned' persisted") after $no_messages_max_retries retries."
          echo "  📝 Full error log: $no_msg_error_log"
          echo -e "  ⏭️  $(_ralph_warning "Skipping story") '$current_story' and continuing to next..."

          # Send ntfy notification for persistent failure
          if $notify_enabled; then
            local skip_stats
            if [[ "$use_json_mode" == "true" ]]; then
              skip_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
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
          echo "  ⏳ Waiting 15 seconds before retry..."
          sleep 15
          continue
        else
          echo ""
          echo -e "  ❌ $(_ralph_error "Error persisted") after $max_retries retries. $(_ralph_warning "Skipping iteration.")"
          echo "  📝 Full error log: $error_log"
          if $notify_enabled; then
            local error_stats
            if [[ "$use_json_mode" == "true" ]]; then
              error_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
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
    if grep -q "<promise>COMPLETE</promise>" "$RALPH_TMP" 2>/dev/null; then
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
          blocked_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
        else
          blocked_stats="? ?"
        fi
        _ralph_ntfy "$ntfy_topic" "blocked" "User action needed" "$current_story" "" "$i" "$blocked_stats" "$total_cost"
      fi
      rm -f "$RALPH_TMP"
      return 2  # Different exit code for blocked vs complete
    fi

    # Apply any queued updates and auto-unblock before showing remaining
    if [[ "$use_json_mode" == "true" ]]; then
      _ralph_apply_update_queue "$PRD_JSON_DIR"
      _ralph_auto_unblock "$PRD_JSON_DIR"
    fi

    # Show remaining tasks (suppress any debug output)
    local remaining
    local remaining_stats
    if [[ "$use_json_mode" == "true" ]]; then
      remaining=$(_ralph_json_remaining_count "$PRD_JSON_DIR" 2>/dev/null)
      remaining_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR" 2>/dev/null)
    else
      remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo "?")
      remaining_stats="? ?"
    fi
    if [[ "$compact_mode" == "true" ]]; then
      # Compact mode: minimal between-iteration display
      echo "── 📋 ${remaining} remaining │ ⏳ ${SLEEP}s ──"
    else
      # Normal mode: full box
      echo "┌───────────────────────────────────────────────────────────────┐"
      echo "│  📋 Remaining: $remaining$(printf '%*s' $((46 - ${#remaining})) '')│"
      # Show story progress bar (JSON mode only)
      if [[ "$use_json_mode" == "true" ]]; then
        local end_completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        local end_total=$(jq -r '.stats.total // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
        local end_story_bar=$(_ralph_story_progress "$end_completed" "$end_total")
        echo -e "│  📚 Stories:  ${end_story_bar}$(printf '%*s' $((35 - ${#end_completed} - ${#end_total})) '')│"
      fi
      echo "│  ⏳ Pausing ${SLEEP}s before next iteration...$(printf '%*s' $((35 - ${#SLEEP})) '')│"
      echo "└───────────────────────────────────────────────────────────────┘"
    fi

    # Per-iteration notification if enabled
    if $notify_enabled; then
      local iter_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
      _ralph_ntfy "$ntfy_topic" "iteration" "$current_story" "$routed_model" "$i" "$remaining_stats" "$iter_cost"
    fi

    sleep $SLEEP
  done

  # Apply queued updates, auto-unblock, and count remaining for final message
  if [[ "$use_json_mode" == "true" ]]; then
    _ralph_apply_update_queue "$PRD_JSON_DIR"
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
    # Normal mode: full box
    echo ""
    echo -e "${RALPH_COLOR_YELLOW}╔═══════════════════════════════════════════════════════════════╗${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  ⚠️  $(_ralph_warning "REACHED MAX ITERATIONS") ($(_ralph_bold "$MAX"))$(printf '%*s' $((37 - ${#MAX})) '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
    echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  📋 Remaining: $final_remaining$(printf '%*s' $((47 - ${#final_remaining})) '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
    # Show story progress bar (JSON mode only)
    if [[ "$use_json_mode" == "true" ]]; then
      local final_completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
      local final_total=$(jq -r '.stats.total // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
      local final_story_bar=$(_ralph_story_progress "$final_completed" "$final_total")
      echo -e "${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}  📚 Stories:  ${final_story_bar}$(printf '%*s' $((34 - ${#final_completed} - ${#final_total})) '')${RALPH_COLOR_YELLOW}║${RALPH_COLOR_RESET}"
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
  echo "${GRAY}Flags:${NC}"
  echo "  ${BOLD}-QN${NC}                   Enable ntfy notifications"
  echo "  ${BOLD}--compact, -c${NC}         Compact output mode (less verbose)"
  echo "  ${BOLD}--debug, -d${NC}           Debug output mode (more verbose)"
  echo ""
  echo "${GREEN}Model Flags (first=main, second=verify):${NC}"
  echo "  ${BOLD}-O${NC}                    Opus (Claude, default)"
  echo "  ${BOLD}-S${NC}                    Sonnet (Claude, faster)"
  echo "  ${BOLD}-H${NC}                    Haiku (Claude, fastest)"
  echo "  ${BOLD}-K${NC}                    Kiro CLI (no browser MCPs)"
  echo "  ${BOLD}-G${NC}                    Gemini CLI (has browser MCPs)"
  echo ""
  echo "${GREEN}Examples:${NC}"
  echo "  ralph 50 -G -H        Gemini for main, Haiku for V-*"
  echo "  ralph 50 -K -G        Kiro for main, Gemini for V-*"
  echo "  ralph 50 -G -G        Gemini for all stories"
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

# ralph-archive [app] - Archive completed stories to docs.local
function ralph-archive() {
  local app="$1"
  local prd_dir
  local archive_dir="docs.local/prd-archive"

  # Determine path
  if [[ -n "$app" ]]; then
    prd_dir="apps/$app/prd-json"
  else
    prd_dir="prd-json"
  fi

  # Check for JSON mode first, fall back to markdown
  if [[ -d "$prd_dir" ]]; then
    _ralph_archive_json "$prd_dir" "$app"
  elif [[ -f "${prd_dir%prd-json}PRD.md" ]]; then
    _ralph_archive_md "${prd_dir%prd-json}PRD.md" "$app"
  else
    echo "❌ PRD not found: $prd_dir or PRD.md"
    return 1
  fi
}

# Archive JSON PRD
_ralph_archive_json() {
  local prd_dir="$1"
  local app="$2"
  local archive_dir="docs.local/prd-archive"
  local index_file="$prd_dir/index.json"

  mkdir -p "$archive_dir"

  # Generate archive filename
  local date_suffix=$(date +%Y%m%d-%H%M%S)
  local app_prefix=""
  [[ -n "$app" ]] && app_prefix="${app}-"
  local archive_subdir="$archive_dir/${app_prefix}${date_suffix}"

  # Copy entire prd-json to archive
  cp -r "$prd_dir" "$archive_subdir"

  echo "✅ Archived to: $archive_subdir/"

  # Ask if user wants to clear completed stories
  read -q "REPLY?Remove completed stories from prd-json/ for next sprint? (y/n) "
  echo ""
  if [[ "$REPLY" == "y" ]]; then
    # Get completed stories and remove them
    local completed=$(jq -r '.storyOrder[] | select(. as $id |
      (input_filename | sub(".*/"; "") | sub("\\.json$"; "")) == $id)' \
      "$prd_dir/stories"/*.json 2>/dev/null | while read id; do
        if jq -e '.passes == true' "$prd_dir/stories/${id}.json" >/dev/null 2>&1; then
          echo "$id"
        fi
      done)

    for story_id in $completed; do
      rm -f "$prd_dir/stories/${story_id}.json"
      echo "   Removed: $story_id"
    done

    # Update index.json
    local pending=$(jq -r '.pending[]' "$index_file" 2>/dev/null)
    local new_order=$(echo "$pending" | jq -R -s 'split("\n") | map(select(length > 0))')
    local new_count=$(echo "$new_order" | jq 'length')

    jq --argjson order "$new_order" --argjson count "$new_count" '
      .storyOrder = $order |
      .pending = $order |
      .stats.total = $count |
      .stats.pending = $count |
      .stats.completed = 0 |
      .nextStory = ($order[0] // null)
    ' "$index_file" > "${index_file}.tmp" && mv "${index_file}.tmp" "$index_file"

    echo "✅ Completed stories archived and removed"
  fi
}

# Archive Markdown PRD (legacy)
_ralph_archive_md() {
  local prd_path="$1"
  local app="$2"
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

  echo "✅ Archived to: $archive_file"

  read -q "REPLY?Clear PRD.md for next sprint? (y/n) "
  echo ""
  if [[ "$REPLY" == "y" ]]; then
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

# ralph-live - Live refreshing PRD status (Ctrl+C to exit)
function ralph-live() {
  local interval="${1:-3}"  # Default 3 second refresh

  echo "📺 Ralph Live Status (refreshing every ${interval}s, Ctrl+C to exit)"
  echo ""

  while true; do
    clear
    ralph-status
    sleep "$interval"
  done
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

  # Read stats from index.json
  local total=$(jq -r '.stats.total // 0' "$index_file" 2>/dev/null)
  local done=$(jq -r '.stats.completed // 0' "$index_file" 2>/dev/null)
  local pending=$(jq -r '.stats.pending // 0' "$index_file" 2>/dev/null)
  local blocked=$(jq -r '.stats.blocked // 0' "$index_file" 2>/dev/null)
  local next_story=$(jq -r '.nextStory // "none"' "$index_file" 2>/dev/null)

  local percent=0
  [[ "$total" -gt 0 ]] && percent=$((done * 100 / total))

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

      context7)
        # Context7 MCP doesn't require credentials
        echo "${GREEN}  ✓ Context7 MCP enabled${NC}"
        ;;

      *)
        echo "${YELLOW}  ? Unknown MCP: $mcp (no setup configured)${NC}"
        ;;
    esac
  done

  echo ""
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
  claude
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
# INITIALIZATION (runs when sourced)
# ═══════════════════════════════════════════════════════════════════
_ralph_show_whatsnew
