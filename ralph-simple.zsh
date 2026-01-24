#!/usr/bin/env zsh
# Ralph Simple - The AI Coding Loop (Simplified)
# ~500 lines vs 4000+ in original ralph.zsh
#
# Usage: ralph [-QN]
# Runs until COMPLETE or max iterations (default 100)

# NOTE: No set -euo pipefail here - kills shell when sourced!

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

RALPH_VERSION="2.0.0-simple"
RALPH_CONFIG_DIR="${RALPH_CONFIG_DIR:-$HOME/.config/ralphtools}"
RALPH_CONFIG_FILE="$RALPH_CONFIG_DIR/config.json"
RALPH_COSTS_FILE="$RALPH_CONFIG_DIR/costs.jsonl"

# Defaults (overridden by config.json)
RALPH_MAX_ITERATIONS=100
RALPH_DEFAULT_MODEL="sonnet"
RALPH_MODEL_STRATEGY="smart"

# Model routing defaults
RALPH_MODEL_US="sonnet"
RALPH_MODEL_V="haiku"
RALPH_MODEL_TEST="haiku"
RALPH_MODEL_BUG="sonnet"
RALPH_MODEL_AUDIT="opus"
RALPH_MODEL_MP="opus"

# ═══════════════════════════════════════════════════════════════════════════════
# LOAD CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_load_config() {
  [[ ! -f "$RALPH_CONFIG_FILE" ]] && return

  RALPH_MODEL_STRATEGY=$(jq -r '.modelStrategy // "smart"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_DEFAULT_MODEL=$(jq -r '.defaultModel // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MAX_ITERATIONS=$(jq -r '.defaults.maxIterations // 100' "$RALPH_CONFIG_FILE" 2>/dev/null)

  # Model routing
  RALPH_MODEL_US=$(jq -r '.models.US // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MODEL_V=$(jq -r '.models.V // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MODEL_TEST=$(jq -r '.models.TEST // "haiku"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MODEL_BUG=$(jq -r '.models.BUG // "sonnet"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MODEL_AUDIT=$(jq -r '.models.AUDIT // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)
  RALPH_MODEL_MP=$(jq -r '.models.MP // "opus"' "$RALPH_CONFIG_FILE" 2>/dev/null)
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL ROUTING
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_get_model() {
  local story_id="$1"
  local prefix="${story_id%%-*}"

  # Story-level override in JSON
  local story_file="prd-json/stories/${story_id}.json"
  if [[ -f "$story_file" ]]; then
    local override=$(jq -r '.model // empty' "$story_file" 2>/dev/null)
    [[ -n "$override" ]] && echo "$override" && return
  fi

  # Prefix-based routing
  case "$prefix" in
    US)    echo "$RALPH_MODEL_US" ;;
    V)     echo "$RALPH_MODEL_V" ;;
    TEST)  echo "$RALPH_MODEL_TEST" ;;
    BUG)   echo "$RALPH_MODEL_BUG" ;;
    AUDIT) echo "$RALPH_MODEL_AUDIT" ;;
    MP)    echo "$RALPH_MODEL_MP" ;;
    *)     echo "$RALPH_DEFAULT_MODEL" ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# COST TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_log_cost() {
  local story="$1" model="$2" duration="$3"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Estimate tokens (rough: 1 token per 4 chars of context)
  local input_tokens=$((50000))  # Estimate
  local output_tokens=$((10000)) # Estimate

  # Pricing per million tokens
  local -A prices=(
    [haiku_in]=0.25 [haiku_out]=1.25
    [sonnet_in]=3 [sonnet_out]=15
    [opus_in]=15 [opus_out]=75
  )

  local in_price=${prices[${model}_in]:-3}
  local out_price=${prices[${model}_out]:-15}
  local cost=$(echo "scale=4; ($input_tokens * $in_price + $output_tokens * $out_price) / 1000000" | bc)

  mkdir -p "$RALPH_CONFIG_DIR"
  echo "{\"timestamp\":\"$timestamp\",\"story\":\"$story\",\"model\":\"$model\",\"duration\":$duration,\"cost\":$cost}" >> "$RALPH_COSTS_FILE"

  echo "  💰 ~\$${cost} (${model})"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRD HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_get_next_story() {
  local index_file="prd-json/index.json"
  [[ ! -f "$index_file" ]] && return 1

  # Get first pending story
  jq -r '.pending[0] // empty' "$index_file" 2>/dev/null
}

_ralph_get_stats() {
  local index_file="prd-json/index.json"
  [[ ! -f "$index_file" ]] && echo "0 0" && return

  local pending=$(jq -r '.stats.pending // 0' "$index_file" 2>/dev/null)
  local completed=$(jq -r '.stats.completed // 0' "$index_file" 2>/dev/null)
  echo "$pending $completed"
}

_ralph_get_criteria_count() {
  local total=0 checked=0
  for f in prd-json/stories/*.json; do
    [[ -f "$f" ]] || continue
    local t=$(jq '[.acceptanceCriteria[]] | length' "$f" 2>/dev/null || echo 0)
    local c=$(jq '[.acceptanceCriteria[] | select(.checked == true)] | length' "$f" 2>/dev/null || echo 0)
    total=$((total + t))
    checked=$((checked + c))
  done
  echo "$checked $total"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NOTIFICATIONS (ntfy.sh)
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_ntfy() {
  local topic="$1" event="$2" story="$3" model="$4" iteration="$5"
  [[ -z "$topic" ]] && return

  local title emoji
  case "$event" in
    iteration) emoji="🔄"; title="Iteration $iteration: $story" ;;
    complete)  emoji="✅"; title="Ralph Complete!" ;;
    error)     emoji="❌"; title="Error: $story" ;;
    blocked)   emoji="🚫"; title="All Blocked" ;;
  esac

  curl -s -d "$title ($model)" "ntfy.sh/$topic" \
    -H "Title: $emoji Ralph" \
    -H "Priority: default" >/dev/null 2>&1 &
}

# ═══════════════════════════════════════════════════════════════════════════════
# THE PROMPT
# ═══════════════════════════════════════════════════════════════════════════════

_ralph_build_prompt() {
  local story="$1"

  # Try to load prompt from shared file
  local prompt_file="${RALPH_PROMPT_FILE:-$RALPH_CONFIG_DIR/../ralphtools/prompts/ralph-prompt.md}"

  # Also check relative to script location (for development)
  if [[ ! -f "$prompt_file" ]]; then
    local script_dir="${0:a:h}"
    prompt_file="$script_dir/prompts/ralph-prompt.md"
  fi

  # Also check in ~/.config/ralph/prompts/
  if [[ ! -f "$prompt_file" ]]; then
    prompt_file="$HOME/.config/ralph/prompts/ralph-prompt.md"
  fi

  if [[ -f "$prompt_file" ]]; then
    # Read prompt and substitute placeholders
    local prompt_content
    prompt_content=$(cat "$prompt_file")

    # Substitute template variables
    prompt_content="${prompt_content//\{\{MODEL\}\}/$RALPH_DEFAULT_MODEL}"
    prompt_content="${prompt_content//\{\{PRD_JSON_DIR\}\}/prd-json}"
    prompt_content="${prompt_content//\{\{WORKING_DIR\}\}/$(pwd)}"
    prompt_content="${prompt_content//\{\{ISO_TIMESTAMP\}\}/$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

    echo "$prompt_content"
  else
    # Fallback to inline prompt if file not found
    cat << 'PROMPT'
You are Ralph, an autonomous AI coding agent. You implement PRD stories one at a time.

## Your Task

1. Read prd-json/index.json to find the current story
2. Read the story file from prd-json/stories/{id}.json
3. Implement ALL acceptance criteria
4. Mark criteria as checked in the JSON as you complete them
5. Commit your changes with a descriptive message
6. Update AGENTS.md if you discover reusable patterns

## Rules

- Implement ONE story completely before stopping
- Check criteria boxes as you complete them: {"text": "...", "checked": true}
- Run typecheck/tests if criteria require it
- For UI changes, verify in browser if Claude-in-Chrome is available
- COMMIT your changes before finishing

## AGENTS.md Updates

If you discover a reusable pattern that future work should know about:
- Check if AGENTS.md exists in project root
- Add patterns like: "This codebase uses X for Y"
- Only add genuinely reusable knowledge

## CodeRabbit Integration

Before committing, run: cr review --prompt-only --type uncommitted
- If issues found: fix or create BUG-xxx story
- Log results in progress.txt

## Completion Signals

When done, output exactly one of:
- <promise>COMPLETE</promise> - All stories done (pending array empty)
- <promise>ALL_BLOCKED</promise> - Only blocked stories remain
- (no tag) - More stories remain, next iteration will continue

## Important

- Do NOT keep retrying blocked tasks
- Do NOT implement multiple stories
- Do NOT skip committing
PROMPT
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

ralph() {
  _ralph_load_config

  # Parse flags
  local notify_topic=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -QN)
        local project=$(basename "$(pwd)")
        notify_topic="ralph-${project}"
        shift ;;
      -h|--help)
        echo "Usage: ralph [-QN]"
        echo "  -QN  Enable ntfy notifications"
        echo ""
        echo "Runs until COMPLETE or $RALPH_MAX_ITERATIONS iterations"
        return 0 ;;
      --version)
        echo "Ralph $RALPH_VERSION"
        return 0 ;;
      *) shift ;;
    esac
  done

  # Check for prd-json
  if [[ ! -d "prd-json" ]]; then
    echo "❌ No prd-json/ directory found"
    echo "   Run /prd to create a PRD first"
    return 1
  fi

  # Show startup info
  local stats=($(_ralph_get_stats))
  local criteria=($(_ralph_get_criteria_count))

  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║  🚀 RALPH $RALPH_VERSION                                      "
  echo "╠───────────────────────────────────────────────────────────────╣"
  echo "║  📂 $(pwd)"
  echo "║  📋 ${stats[1]} pending │ ${stats[2]} completed"
  echo "║  📝 ${criteria[1]}/${criteria[2]} criteria checked"
  [[ -n "$notify_topic" ]] && echo "║  🔔 Notifications: $notify_topic"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo ""

  # Show model routing
  echo "🧠 Model Routing:"
  echo "   US→$RALPH_MODEL_US  V→$RALPH_MODEL_V  TEST→$RALPH_MODEL_TEST"
  echo "   BUG→$RALPH_MODEL_BUG  AUDIT→$RALPH_MODEL_AUDIT  MP→$RALPH_MODEL_MP"
  echo ""

  # Main loop
  local iteration=0
  local max_retries=3
  local output_file="/tmp/ralph_output_$$.txt"

  while [[ $iteration -lt $RALPH_MAX_ITERATIONS ]]; do
    iteration=$((iteration + 1))

    # Get next story
    local story=$(_ralph_get_next_story)
    if [[ -z "$story" ]]; then
      echo "✅ No pending stories - all done!"
      [[ -n "$notify_topic" ]] && _ralph_ntfy "$notify_topic" "complete" "" "" "$iteration"
      rm -f "$output_file"
      return 0
    fi

    # Get model for this story
    local model=$(_ralph_get_model "$story")
    local start_time=$(date +%s)

    echo "────────────────────────────────────────────────────────────────"
    echo "🔄 Iteration $iteration/$RALPH_MAX_ITERATIONS"
    echo "📖 Story: $story"
    echo "🧠 Model: $model"
    echo "────────────────────────────────────────────────────────────────"

    # Build and run prompt
    local prompt=$(_ralph_build_prompt "$story")
    local retry=0
    local success=false

    while [[ $retry -lt $max_retries ]]; do
      # Run Claude
      if claude --model "$model" \
                --dangerously-skip-permissions \
                -p "$prompt" 2>&1 | tee "$output_file"; then

        # Check for completion signals
        if grep -q "<promise>COMPLETE</promise>" "$output_file"; then
          echo ""
          echo "✅ All stories complete!"
          local duration=$(($(date +%s) - start_time))
          _ralph_log_cost "$story" "$model" "$duration"
          [[ -n "$notify_topic" ]] && _ralph_ntfy "$notify_topic" "complete" "$story" "$model" "$iteration"
          rm -f "$output_file"
          return 0
        fi

        if grep -q "<promise>ALL_BLOCKED</promise>" "$output_file"; then
          echo ""
          echo "🚫 All remaining stories are blocked"
          [[ -n "$notify_topic" ]] && _ralph_ntfy "$notify_topic" "blocked" "$story" "$model" "$iteration"
          rm -f "$output_file"
          return 2
        fi

        # Success - story implemented, continue to next
        success=true
        local duration=$(($(date +%s) - start_time))
        _ralph_log_cost "$story" "$model" "$duration"
        [[ -n "$notify_topic" ]] && _ralph_ntfy "$notify_topic" "iteration" "$story" "$model" "$iteration"
        break
      fi

      # Retry on failure
      retry=$((retry + 1))
      echo "⚠️  Error (attempt $retry/$max_retries) - retrying in 15s..."
      sleep 15
    done

    if ! $success; then
      echo "❌ Failed after $max_retries retries, skipping story"
      [[ -n "$notify_topic" ]] && _ralph_ntfy "$notify_topic" "error" "$story" "$model" "$iteration"
    fi

    echo ""
  done

  echo "⚠️  Reached max iterations ($RALPH_MAX_ITERATIONS)"
  rm -f "$output_file"
  return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER COMMANDS
# ═══════════════════════════════════════════════════════════════════════════════

ralph-status() {
  if [[ ! -d "prd-json" ]]; then
    echo "❌ No prd-json/ directory"
    return 1
  fi

  local stats=($(_ralph_get_stats))
  local criteria=($(_ralph_get_criteria_count))
  local next=$(_ralph_get_next_story)

  echo "📋 PRD Status"
  echo "   Pending: ${stats[1]}"
  echo "   Completed: ${stats[2]}"
  echo "   Criteria: ${criteria[1]}/${criteria[2]}"
  echo "   Next: ${next:-none}"
}

ralph-stop() {
  local pids=$(pgrep -f "ralph_output" 2>/dev/null)
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill 2>/dev/null
    echo "🛑 Stopped Ralph processes"
  else
    echo "No Ralph processes running"
  fi
}

# Load config on source
_ralph_load_config
