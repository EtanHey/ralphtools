#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH - Autonomous Coding Loop
# ═══════════════════════════════════════════════════════════════════
# Thin wrapper that delegates to bun ralph-ui --run
#
# Usage: ralph [iterations] [options]
# Examples:
#   ralph 30              # Run 30 iterations
#   ralph 300 -S          # Run with Sonnet model
#   ralph 100 -QN         # Run with notifications
#
# Options:
#   -O   : Opus model (default)
#   -S   : Sonnet model (faster, cheaper)
#   -H   : Haiku model (fastest, cheapest)
#   -QN  : Enable ntfy notifications
#   -q   : Quiet mode (no UI)
#   -v   : Verbose mode
#
# The iteration loop runs in TypeScript (ralph-ui). This wrapper:
# - Sources lib modules for helper commands
# - Parses args and sets environment variables
# - Delegates to bun ralph-ui --run
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# VERSION
# ═══════════════════════════════════════════════════════════════════
# Get script directory (works when sourced)
if [[ -n "${BASH_SOURCE[0]}" ]]; then
  RALPH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${(%):-%x}" ]]; then
  RALPH_SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  RALPH_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
RALPH_VERSION_FILE="${RALPH_SCRIPT_DIR}/VERSION"
if [[ -f "$RALPH_VERSION_FILE" ]]; then
  RALPH_VERSION=$(head -1 "$RALPH_VERSION_FILE")
else
  RALPH_VERSION="0.0.0"
fi

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
RALPH_CONFIG_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}"
RALPH_USER_PREFS_FILE="${RALPH_USER_PREFS_FILE:-$RALPH_CONFIG_DIR/user-prefs.json}"
[[ -f "$RALPH_CONFIG_DIR/ralph-config.local" ]] && source "$RALPH_CONFIG_DIR/ralph-config.local"

# Load from config.json (primary config file)
RALPH_CONFIG_FILE="${RALPH_CONFIG_DIR}/config.json"
if [[ -f "$RALPH_CONFIG_FILE" ]]; then
  _ralph_cfg_model=$(jq -r '.defaultModel // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
  _ralph_cfg_ntfy_topic=$(jq -r '.notifications.ntfyTopic // empty' "$RALPH_CONFIG_FILE" 2>/dev/null)
  _ralph_cfg_ntfy_enabled=$(jq -r '.notifications.enabled // false' "$RALPH_CONFIG_FILE" 2>/dev/null)
  [[ -n "$_ralph_cfg_model" ]] && RALPH_DEFAULT_MODEL="$_ralph_cfg_model"
  [[ -n "$_ralph_cfg_ntfy_topic" && "$_ralph_cfg_ntfy_topic" != "null" ]] && RALPH_NTFY_TOPIC="${RALPH_NTFY_TOPIC:-$_ralph_cfg_ntfy_topic}"
  [[ "$_ralph_cfg_ntfy_enabled" == "true" ]] && RALPH_NOTIFY_ENABLED=1
  unset _ralph_cfg_model _ralph_cfg_ntfy_topic _ralph_cfg_ntfy_enabled
fi

# Fallback: Load from user-prefs.json (legacy)
if [[ -f "$RALPH_USER_PREFS_FILE" ]]; then
  _ralph_prefs_model=$(jq -r '.defaultModel // empty' "$RALPH_USER_PREFS_FILE" 2>/dev/null)
  _ralph_prefs_ntfy=$(jq -r '.ntfyTopic // empty' "$RALPH_USER_PREFS_FILE" 2>/dev/null)
  [[ -n "$_ralph_prefs_model" ]] && RALPH_DEFAULT_MODEL="$_ralph_prefs_model"
  [[ -n "$_ralph_prefs_ntfy" && "$_ralph_prefs_ntfy" != "null" ]] && RALPH_NTFY_TOPIC="${RALPH_NTFY_TOPIC:-$_ralph_prefs_ntfy}"
  unset _ralph_prefs_model _ralph_prefs_ntfy
fi

# Defaults (applied after user prefs)
RALPH_NTFY_PREFIX="${RALPH_NTFY_PREFIX:-etanheys-ralph}"
RALPH_DEFAULT_MODEL="${RALPH_DEFAULT_MODEL:-opus}"
RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-100}"
RALPH_SLEEP_SECONDS="${RALPH_SLEEP_SECONDS:-5}"
RALPH_UI_PATH="${RALPH_SCRIPT_DIR}/ralph-ui/src/index.tsx"

# ═══════════════════════════════════════════════════════════════════
# SOURCE MODULAR LIB FILES
# ═══════════════════════════════════════════════════════════════════
RALPH_LIB_DIR="${RALPH_SCRIPT_DIR}/lib"
if [[ -d "$RALPH_LIB_DIR" ]]; then
  # Source modules in dependency order
  [[ -f "$RALPH_LIB_DIR/ralph-ui.zsh" ]] && source "$RALPH_LIB_DIR/ralph-ui.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-watcher.zsh" ]] && source "$RALPH_LIB_DIR/ralph-watcher.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-commands.zsh" ]] && source "$RALPH_LIB_DIR/ralph-commands.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-models.zsh" ]] && source "$RALPH_LIB_DIR/ralph-models.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-registry.zsh" ]] && source "$RALPH_LIB_DIR/ralph-registry.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-worktrees.zsh" ]] && source "$RALPH_LIB_DIR/ralph-worktrees.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-secrets.zsh" ]] && source "$RALPH_LIB_DIR/ralph-secrets.zsh"
  [[ -f "$RALPH_LIB_DIR/ralph-setup.zsh" ]] && source "$RALPH_LIB_DIR/ralph-setup.zsh"
fi

# ═══════════════════════════════════════════════════════════════════
# MAIN RALPH FUNCTION - Thin wrapper for bun ralph-ui --run
# ═══════════════════════════════════════════════════════════════════
function ralph() {
  # Parse arguments
  local iterations="$RALPH_MAX_ITERATIONS"
  local model="$RALPH_DEFAULT_MODEL"
  local gap="$RALPH_SLEEP_SECONDS"
  # Use config file setting as default, can be overridden by --notify flag
  local notify=""
  [[ -n "$RALPH_NOTIFY_ENABLED" ]] && notify="--notify"
  local quiet=""
  local verbose=""
  local prd_path="$(pwd)/prd-json"

  # Handle --version early
  case "$1" in
    --version|-V)
      echo "ralphtools v${RALPH_VERSION}"
      return 0
      ;;
    --help|-h)
      echo "Ralph v${RALPH_VERSION} - Autonomous Coding Loop"
      echo ""
      echo "Usage: ralph [iterations] [options]"
      echo ""
      echo "Options:"
      echo "  -O, --opus      Use Opus model (default)"
      echo "  -S, --sonnet    Use Sonnet model"
      echo "  -H, --haiku     Use Haiku model"
      echo "  -K, --kiro      Use Kiro model (kiro-cli)"
      echo "  -G, --gemini    Use Gemini Flash model"
      echo "  -L, --local     Use local Ollama model (via Aider)"
      echo "  -QN, --notify   Enable ntfy notifications"
      echo "  -q, --quiet     Quiet mode (no UI)"
      echo "  -v, --verbose   Verbose output"
      echo "  -V, --version   Show version"
      echo "  --help          Show this help"
      return 0
      ;;
  esac

  # Parse remaining args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -O|--opus)
        model="opus"
        shift
        ;;
      -S|--sonnet)
        model="sonnet"
        shift
        ;;
      -H|--haiku)
        model="haiku"
        shift
        ;;
      -K|--kiro)
        model="kiro"
        shift
        ;;
      -G|--gemini)
        model="gemini-flash"
        shift
        ;;
      -L|--local)
        model="ollama"
        shift
        ;;
      -QN|--notify)
        notify="--notify"
        shift
        ;;
      -q|--quiet)
        quiet="--quiet"
        shift
        ;;
      -v|--verbose)
        verbose="--verbose"
        shift
        ;;
      [0-9]*)
        iterations="$1"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  # Check for prd-json
  if [[ ! -d "$prd_path" ]]; then
    echo "Error: No prd-json/ directory found in current directory"
    echo "Run '/prd' in Claude to create a PRD first"
    return 1
  fi

  # Check for bun
  if ! command -v bun &> /dev/null; then
    echo "Error: bun is required but not installed"
    echo "Install: curl -fsSL https://bun.sh/install | bash"
    return 1
  fi

  # Check for ralph-ui
  if [[ ! -f "$RALPH_UI_PATH" ]]; then
    echo "Error: ralph-ui not found at $RALPH_UI_PATH"
    return 1
  fi

  # Set ntfy topic (use user-configured topic or construct from prefix)
  local project_name=$(basename "$(pwd)")
  local ntfy_topic="${RALPH_NTFY_TOPIC:-${RALPH_NTFY_PREFIX}-${project_name}-notify}"

  # Export environment for TypeScript runner
  export RALPH_MODEL="$model"
  export RALPH_ITERATIONS="$iterations"
  export RALPH_SLEEP_SECONDS="$gap"
  export RALPH_NTFY_TOPIC="$ntfy_topic"
  [[ -n "$notify" ]] && export RALPH_NOTIFY=1
  
  # Generate and export session ID for SessionContext
  export RALPH_SESSION="ralph-$(date +%s)-$$"

  # Run TypeScript iteration loop
  echo "🚀 Ralph v${RALPH_VERSION} | Model: $model | Iterations: $iterations"
  echo ""

  bun "$RALPH_UI_PATH" --run \
    --iterations "$iterations" \
    --model "$model" \
    --gap "$gap" \
    --prd-path "$prd_path" \
    $notify $quiet $verbose
}

# ═══════════════════════════════════════════════════════════════════
# HELPER COMMANDS
# ═══════════════════════════════════════════════════════════════════
# These provide quick access to common operations

function ralph-version() {
  echo "ralphtools v${RALPH_VERSION}"
}

# ralph-help is defined in lib/ralph-commands.zsh with comprehensive documentation
# We don't override it here so the full help is shown

# Alias for the -V flag
alias ralph-V='ralph --version'

# Farther-steps: deferred actions queue
alias fsteps='$RALPH_HOME/scripts/farther-steps.sh'
alias fs='fsteps'  # Short alias

function ralph-ui() {
  local prd_path="${1:-$(pwd)/prd-json}"
  if [[ ! -f "$RALPH_UI_PATH" ]]; then
    echo "Error: ralph-ui not found at $RALPH_UI_PATH"
    return 1
  fi
  bun "$RALPH_UI_PATH" --mode=live --prd-path="$prd_path"
}

function ralph-live() {
  ralph-ui "$@"
}

function ralph-status() {
  local prd_path="${1:-$(pwd)/prd-json}"
  if [[ ! -f "$RALPH_UI_PATH" ]]; then
    echo "Error: ralph-ui not found at $RALPH_UI_PATH"
    return 1
  fi
  bun "$RALPH_UI_PATH" --mode=startup --prd-path="$prd_path"
}

function ralph-stop() {
  # Create stop file that watchdog checks
  touch "$HOME/.ralph-stop"
  echo "Stop signal sent. Ralph will exit after current iteration."
}

# ═══════════════════════════════════════════════════════════════════
# repoGolem - Uses full implementation from lib/ralph-registry.zsh
# which supports -QN notifications, MCP setup, and all flags
# ═══════════════════════════════════════════════════════════════════

# Generate launchers from registry if it exists
if [[ -f "$RALPH_CONFIG_DIR/config.json" ]]; then
  projects=$(jq -r '.projects // {} | to_entries[] | "\(.key)|\(.value.path)"' "$RALPH_CONFIG_DIR/config.json" 2>/dev/null)
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    name="${entry%%|*}"
    path="${entry#*|}"
    [[ -n "$name" && -n "$path" ]] && repoGolem "$name" "$path"
  done <<< "$projects"
fi
