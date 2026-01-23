#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH - Autonomous Coding Loop (Original Concept)
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph [app] [max_iterations] [sleep_seconds] [-QN] [-S]
# Examples:
#   ralph 30 5 -QN         # Classic mode: ./prd-json/, current branch
#   ralph expo 300         # App mode: apps/expo/prd-json/, feat/expo-work branch
#   ralph public 300 -QN   # App mode with notifications
#   ralph 100 -S           # Run with Sonnet model (faster, cheaper)
#
# Options:
#   app  : Optional app name - uses apps/{app}/prd-json/
#   -QN  : Enable quiet notifications via ntfy app
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
# WHAT'S NEW (shown once per version upgrade)
# ═══════════════════════════════════════════════════════════════════
_ralph_show_whatsnew() {
  local last_version_file="$RALPH_CONFIG_DIR/.ralph_last_version"
  local last_version=""

  [[ -f "$last_version_file" ]] && last_version=$(cat "$last_version_file" 2>/dev/null)

  # Skip if same version
  [[ "$last_version" == "$RALPH_VERSION" ]] && return 0

  # Show what's new
  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🆕 Ralph v${RALPH_VERSION}                                          │"
  echo "├─────────────────────────────────────────────────────────────┤"

  case "$RALPH_VERSION" in
    "1.3.0")
      echo "│  • Per-iteration cost tracking (actual tokens from JSONL)   │"
      echo "│  • Enhanced ntfy notifications with titles & priorities     │"
      echo "│  • Session IDs passed to Claude for precise tracking        │"
      echo "│  • ralph-costs shows ✓ actual vs ~ estimated data           │"
      ;;
    "1.2.0")
      echo "│  • Smart model routing (US→Sonnet, V→Haiku, etc.)           │"
      echo "│  • Config-based model assignment via config.json            │"
      echo "│  • Cost tracking infrastructure                             │"
      ;;
    *)
      echo "│  • Updated to v${RALPH_VERSION}                                      │"
      ;;
  esac

  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""

  # Save current version
  echo "$RALPH_VERSION" > "$last_version_file"
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

    return 0
  fi
  return 1
}

# Get model for a story based on smart routing
# Usage: _ralph_get_model_for_story "US-001"
# Returns: model name (haiku, sonnet, opus, gemini, kiro)
_ralph_get_model_for_story() {
  local story_id="$1"
  local cli_primary="$2"   # CLI override for primary model
  local cli_verify="$3"    # CLI override for verify model

  # Extract prefix (everything before the dash and number)
  local prefix="${story_id%%-*}"

  # CLI flags always win if specified
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
    echo "   US  → ${RALPH_MODEL_US:-sonnet}"
    echo "   V   → ${RALPH_MODEL_V:-haiku}"
    echo "   TEST→ ${RALPH_MODEL_TEST:-haiku}"
    echo "   BUG → ${RALPH_MODEL_BUG:-sonnet}"
    echo "   AUDIT→${RALPH_MODEL_AUDIT:-opus}"
    echo "   ???→ ${RALPH_UNKNOWN_TASK_MODEL:-sonnet}"
  else
    echo "🧠 Single Model: ${RALPH_DEFAULT_MODEL_CFG:-opus}"
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
     .totals.byModel[$model] = ((.totals.byModel[$model] // 0) + 1)' \
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
  echo "${BOLD}Total Cost:${NC} \$$(printf '%.2f' $total_cost)"
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

# Send enhanced ntfy notification with rich context
# Usage: _ralph_ntfy "topic" "event_type" "message" ["story_id" "model" "iteration" "remaining" "cost"]
_ralph_ntfy() {
  local topic="$1"
  local event="$2"  # complete, blocked, error, iteration, max_iterations
  local message="$3"
  local story_id="${4:-}"
  local model="${5:-}"
  local iteration="${6:-}"
  local remaining="${7:-}"
  local cost="${8:-}"

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

  # Append message if present
  [[ -n "$message" ]] && body+="\n\n$message"

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

  # Valid app names for app-specific mode (parsed from space-separated config)
  local valid_apps=(${=RALPH_VALID_APPS})

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

  echo "🚀 Starting Ralph - Max $MAX iterations"
  if [[ -n "$app_mode" ]]; then
    echo "📱 App: $app_mode (branch: $target_branch)"
  fi
  echo "📂 Working in: $(pwd)"

  # Show routing config (smart vs single)
  if [[ -z "$primary_model" && -z "$verify_model" ]]; then
    # No CLI override - show config-based routing
    _ralph_show_routing
  fi
  # Count and display based on mode
  if [[ "$use_json_mode" == "true" ]]; then
    local pending=$(jq -r '.stats.pending // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
    local completed=$(jq -r '.stats.completed // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
    local blocked=$(jq -r '.stats.blocked // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
    local total=$(jq -r '.stats.total // 0' "$PRD_JSON_DIR/index.json" 2>/dev/null)
    # Count total criteria across all pending stories
    local total_criteria=0
    for story_file in "$PRD_JSON_DIR/stories"/*.json; do
      if [[ -f "$story_file" ]]; then
        local unchecked=$(jq '[.acceptanceCriteria[] | select(.checked == false)] | length' "$story_file" 2>/dev/null || echo 0)
        total_criteria=$((total_criteria + unchecked))
      fi
    done
    echo "📋 PRD: $pending stories ($total_criteria criteria) remaining | $completed done | $blocked blocked"
  else
    local task_count=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
    echo "📋 PRD: $task_count tasks remaining"
  fi
  local pm="${primary_model:-opus}"
  local vm="${verify_model:-haiku}"
  echo "🧠 Models: $pm (main) / $vm (verify)"
  if $notify_enabled; then
    echo "🔔 Notifications: ON (topic: $ntfy_topic)"
  else
    echo "🔕 Notifications: OFF"
  fi
  echo ""

  for ((i=1; i<=$MAX; i++)); do
    # Determine current story and model to use
    local current_story=""
    local effective_model=""

    if [[ "$use_json_mode" == "true" ]]; then
      current_story=$(_ralph_json_next_story "$PRD_JSON_DIR")
    fi

    # Determine effective model using smart routing
    local routed_model=$(_ralph_get_model_for_story "$current_story" "$primary_model" "$verify_model")
    effective_model="$routed_model"

    # Track iteration start time for cost logging
    local iteration_start_time=$(date +%s)

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔄 ITERATION $i of $MAX"
    echo "  ⏱️  $(date '+%H:%M:%S')"
    [[ -n "$current_story" ]] && echo "  📖 Story: $current_story"
    echo "  🧠 Model: $effective_model"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Retry logic for transient API errors like "No messages returned"
    local max_retries=5
    local retry_count=0
    local claude_success=false

    while [[ "$retry_count" -lt "$max_retries" ]]; do
      # Build CLI command as array (safer than string concatenation)
      # V-* stories ALWAYS use Claude Haiku for browser verification
      local -a cli_cmd_arr
      local prompt_flag="-p"  # Claude uses -p, Kiro uses positional arg

      # Determine which model to use based on story type
      local active_model=""
      if [[ "$current_story" == V-* ]]; then
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
      echo "  [DEBUG] Running: ${cli_cmd_arr[*]} (output → $RALPH_TMP)"
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

      # Debug: show exit code and output info
      echo ""
      echo "  [DEBUG] Exit code: $exit_code"
      echo "  [DEBUG] Output file: $RALPH_TMP"
      echo "  [DEBUG] Output size: $(wc -c < "$RALPH_TMP" 2>/dev/null || echo 0) bytes"
      echo "  [DEBUG] Output lines: $(wc -l < "$RALPH_TMP" 2>/dev/null || echo 0)"
      [[ -f "$RALPH_TMP" ]] && echo "  [DEBUG] First line: $(head -1 "$RALPH_TMP" 2>/dev/null | cut -c1-80)"

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

      # Debug: show error detection
      echo "  [DEBUG] has_error: $has_error, retry_count: $retry_count"

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
          echo "--- Last 30 lines of output ---"
          [[ -f "$RALPH_TMP" ]] && tail -30 "$RALPH_TMP"
          echo ""
          echo "--- Error patterns searched ---"
          echo "$error_patterns"
          echo ""
          echo "--- Pattern matches found ---"
          [[ -f "$RALPH_TMP" ]] && grep -iE "$error_patterns" "$RALPH_TMP" 2>/dev/null || echo "(none)"
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
        } > "$error_log"

        if [[ "$retry_count" -lt "$max_retries" ]]; then
          echo ""
          echo "  ⚠️  Error detected (exit code: $exit_code) - Retrying ($retry_count/$max_retries)..."
          echo "  📝 Error log: $error_log"
          [[ -f "$RALPH_TMP" ]] && tail -3 "$RALPH_TMP" 2>/dev/null | head -2
          echo "  ⏳ Waiting 15 seconds before retry..."
          sleep 15
          continue
        else
          echo ""
          echo "  ❌ Error persisted after $max_retries retries. Skipping iteration."
          echo "  📝 Full error log: $error_log"
          if $notify_enabled; then
            _ralph_ntfy "$ntfy_topic" "error" "Failed after $max_retries retries" "$current_story" "$routed_model" "$i"
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
      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "  ✅ ALL TASKS COMPLETE after $i iterations!"
      echo "  ⏱️  $(date '+%H:%M:%S')"
      echo "═══════════════════════════════════════════════════════════════"
      # Send notification if enabled
      if $notify_enabled; then
        local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
        _ralph_ntfy "$ntfy_topic" "complete" "All tasks done!" "" "" "$i" "0 0" "$total_cost"
      fi
      rm -f "$RALPH_TMP"
      return 0
    fi

    # Check if all remaining tasks are blocked (search anywhere in output, not just on own line)
    if grep -q "<promise>ALL_BLOCKED</promise>" "$RALPH_TMP" 2>/dev/null; then
      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "  ⏹️  ALL REMAINING TASKS BLOCKED after $i iterations"
      echo "  ⏱️  $(date '+%H:%M:%S')"
      echo ""
      echo "  Review PRD.md for stories marked ⏹️ BLOCKED"
      echo "  Address blockers (Figma access, Linear issues, etc.)"
      echo "  Then run 'ralph' again to continue"
      echo "═══════════════════════════════════════════════════════════════"
      # Send notification if enabled
      if $notify_enabled; then
        local blocked_stats
        if [[ "$use_json_mode" == "true" ]]; then
          blocked_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
        else
          blocked_stats="? ?"
        fi
        local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
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

    # Show remaining tasks
    local remaining
    local remaining_stats
    if [[ "$use_json_mode" == "true" ]]; then
      remaining=$(_ralph_json_remaining_count "$PRD_JSON_DIR")
      remaining_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
    else
      remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo "?")
      remaining_stats="? ?"
    fi
    echo "───────────────────────────────────────────────────────────────"
    echo "  📋 Remaining: $remaining"
    echo "  ⏳ Pausing ${SLEEP}s before next iteration..."
    echo "───────────────────────────────────────────────────────────────"

    # Per-iteration notification if enabled
    if $notify_enabled; then
      _ralph_ntfy "$ntfy_topic" "iteration" "" "$current_story" "$routed_model" "$i" "$remaining_stats"
    fi

    sleep $SLEEP
  done

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  ⚠️  REACHED MAX ITERATIONS ($MAX)"
  # Apply queued updates, auto-unblock, and count remaining for final message
  if [[ "$use_json_mode" == "true" ]]; then
    _ralph_apply_update_queue "$PRD_JSON_DIR"
    _ralph_auto_unblock "$PRD_JSON_DIR"
  fi
  local final_remaining
  local final_remaining_stats
  if [[ "$use_json_mode" == "true" ]]; then
    final_remaining=$(_ralph_json_remaining_count "$PRD_JSON_DIR")
    final_remaining_stats=$(_ralph_json_remaining_stats "$PRD_JSON_DIR")
  else
    final_remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
    final_remaining_stats="? ?"
  fi
  echo "  📋 Remaining: $final_remaining"
  echo "═══════════════════════════════════════════════════════════════"
  # Send notification if enabled
  if $notify_enabled; then
    local total_cost=$(jq -r '.totals.cost // 0' "$RALPH_COSTS_FILE" 2>/dev/null | xargs printf "%.2f")
    _ralph_ntfy "$ntfy_topic" "max_iterations" "Limit reached" "" "" "$MAX" "$final_remaining_stats" "$total_cost"
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

# ralph-whatsnew - Show current version changelog
function ralph-whatsnew() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────┐"
  echo "│  🆕 Ralph v${RALPH_VERSION}                                          │"
  echo "├─────────────────────────────────────────────────────────────┤"
  echo "│  • Per-iteration cost tracking (actual tokens from JSONL)   │"
  echo "│  • Enhanced ntfy notifications with titles & priorities     │"
  echo "│  • Session IDs passed to Claude for precise tracking        │"
  echo "│  • ralph-costs shows ✓ actual vs ~ estimated data           │"
  echo "├─────────────────────────────────────────────────────────────┤"
  echo "│  v1.2.0: Smart model routing, config.json support           │"
  echo "│  v1.1.0: JSON mode, auto-unblock, brave-manager             │"
  echo "│  v1.0.0: Initial release                                    │"
  echo "└─────────────────────────────────────────────────────────────┘"
  echo ""
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
          echo "--- Last error output ---"
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
