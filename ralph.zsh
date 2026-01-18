#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH - Autonomous Coding Loop (Original Concept)
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph [app] [max_iterations] [sleep_seconds] [-QN] [-S]
# Examples:
#   ralph 30 5 -QN         # Classic mode: ./PRD.md, current branch
#   ralph expo 300         # App mode: apps/expo/PRD.md, feat/expo-work branch
#   ralph public 300 -QN   # App mode with notifications
#   ralph 100 -S           # Run with Sonnet model (faster, cheaper)
#
# Options:
#   app  : Optional app name (expo, public, admin) - uses apps/{app}/PRD.md
#   -QN  : Enable quiet notifications via ntfy app
#   -S   : Use Sonnet model (default: Opus)
#   (no flag) : No notifications, Opus model (default)
#
# App Mode:
#   - PRD: apps/{app}/PRD.md
#   - Branch: feat/{app}-work (creates if needed)
#   - Notifications: {project}-{app} topic
#   - Multiple can run simultaneously on different branches
#
# Prerequisites:
# 1. Create PRD.md with user stories (use /prd skill or manually)
# 2. Each story should be small (completable in one context window)
# 3. Run `ralph` from project root
#
# This is the ORIGINAL Ralph concept - a bash loop spawning FRESH
# Claude instances. Unlike the plugin, each iteration gets clean context.
# Output streams in REAL-TIME so you can watch Claude work.
# ═══════════════════════════════════════════════════════════════════

function ralph() {
  local MAX=10
  local SLEEP=2
  local notify_enabled=false
  local use_sonnet=false
  local RALPH_TMP="/tmp/ralph_output_$$.txt"
  local REPO_ROOT=$(pwd)
  local PRD_PATH="$REPO_ROOT/PRD.md"
  local project_key="ralph"
  local ntfy_topic="etans-ralph"
  local app_mode=""
  local target_branch=""
  local original_branch=""

  # Valid app names for app-specific mode
  local valid_apps=("expo" "public" "admin")

  # Parse arguments - check for app name first
  local args_to_parse=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -QN|--quiet-notify)
        notify_enabled=true
        shift
        ;;
      -S|--sonnet)
        use_sonnet=true
        shift
        ;;
      expo|public|admin)
        # App-specific mode
        app_mode="$1"
        PRD_PATH="$REPO_ROOT/apps/$app_mode/PRD.md"
        target_branch="feat/${app_mode}-work"
        # Get project name from directory for ntfy topic
        local project_name=$(basename "$REPO_ROOT")
        ntfy_topic="etans-${project_name}-${app_mode}"
        shift
        ;;
      *)
        # Positional args: numbers for MAX/SLEEP
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          if [[ "$MAX" -eq 10 ]]; then
            MAX="$1"
          else
            SLEEP="$1"
          fi
        fi
        shift
        ;;
    esac
  done

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

  if [[ ! -f "$PRD_PATH" ]]; then
    echo "❌ No PRD.md found in current directory"
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
  echo "📋 PRD: $(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?') tasks remaining"
  if $use_sonnet; then
    echo "🧠 Model: Sonnet (faster)"
  else
    echo "🧠 Model: Opus (default)"
  fi
  if $notify_enabled; then
    echo "🔔 Notifications: ON (topic: $ntfy_topic)"
  else
    echo "🔕 Notifications: OFF"
  fi
  echo ""

  for ((i=1; i<=$MAX; i++)); do
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔄 ITERATION $i of $MAX"
    echo "  ⏱️  $(date '+%H:%M:%S')"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Retry logic for transient API errors like "No messages returned"
    local max_retries=3
    local retry_count=0
    local claude_success=false

    while [[ "$retry_count" -lt "$max_retries" ]]; do
      # Build claude command as array (safer than string concatenation)
      local -a claude_cmd_arr=(claude --chrome --dangerously-skip-permissions)
      if $use_sonnet; then
        claude_cmd_arr+=(--model sonnet)
      fi

      # Stream output in real-time with tee, also save to temp file
      "${claude_cmd_arr[@]}" -p "You are Ralph, an autonomous coding agent. Do exactly ONE task per iteration.

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
9. **CRITICAL**: Commit PRD.md AND progress.txt together
10. Verify commit succeeded before ending iteration

## Blocked Task Rules (CRITICAL - Prevents Infinite Loops)

**FIRST: Try to use available MCPs!**
You have access to: Figma, Linear, Supabase, browser-tools, Context7.
- For Figma tasks: Try mcp__figma__ or mcp__figma-remote__ tools
- For Linear tasks: Use mcp__linear__ to create issues yourself
- For database: Use mcp__supabase__ for migrations

A task is BLOCKED only when MCP tools FAIL or return errors:
- Figma: node not found, permission denied, MCP timeout
- Linear: API error, missing permissions
- Manual device testing (needs iOS/Android simulator - no MCP for this)
- User decision required (ambiguous requirements)
- External API unavailable

**When you find a BLOCKED task:**
1. In PRD.md, add to the story: \`**Status:** ⏹️ BLOCKED: [specific reason]\`
2. Add note to progress.txt: \"[STORY-ID] BLOCKED: [reason]. Moving to next story.\"
3. Move to the NEXT incomplete task (do NOT keep trying the blocked one)
4. Commit the blocker note

**When ALL remaining tasks are BLOCKED:**
1. List all blocked stories and their blockers in progress.txt
2. Output: \`<promise>ALL_BLOCKED</promise>\`
3. This stops the Ralph loop so the user can address blockers

**Do NOT:**
- Keep retrying a blocked task iteration after iteration
- Output the same \"all tasks blocked\" message without the ALL_BLOCKED promise
- Wait for external resources that won't appear

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

## Completion Rules (CRITICAL)

**🚨 YOU DIE AFTER THIS ITERATION 🚨**
The next Ralph is a FRESH instance with NO MEMORY of your work. The ONLY way the next Ralph knows what you did is by reading PRD.md checkboxes and git commits.

**If you complete work but DON'T update checkboxes:**
→ Next Ralph sees [ ] unchecked
→ Next Ralph thinks work is incomplete
→ Next Ralph re-does the EXACT SAME STORY
→ Infinite loop forever

**If typecheck PASSES:**
1. **UPDATE PRD.md**: Change [ ] to [x] for EVERY criterion you completed
2. **UPDATE progress.txt**: Add iteration summary
3. **COMMIT BOTH**: git add PRD.md progress.txt && git commit -m \"feat: [story-id] [description]\"
4. **VERIFY**: git log -1 (confirm commit succeeded)
5. If commit fails, STOP and report error

**If typecheck FAILS:**
- Do NOT mark complete in PRD.md
- Do NOT commit
- Append failure to progress.txt
- Create blocker story (US-NNN-A) if infrastructure issue

**Remember:** Git commits = audit trail. PRD.md checkboxes = what next Ralph sees.

## Progress Format

## Iteration - [Task Name]
- What was done
- Learnings for next iteration
---


## Iteration Summary (REQUIRED)

At the end of EVERY iteration, provide an expressive summary:
- \"I completed [story ID] which was about [what it accomplished/changed]\"
- \"Next I think I should work on \[next story ID\] which is \[what it will do\]. I'm planning to \[specific actions X, Y, Z\]\"
- Be descriptive and conversational about what you did and what's next, not just checkboxes

## End Condition

After completing task, check PRD.md:
- ALL [x]: output <promise>COMPLETE</promise>
- ALL remaining [ ] are BLOCKED: output <promise>ALL_BLOCKED</promise>
- Some [ ] actionable: end response (next iteration continues)" 2>&1 | stdbuf -oL tee "$RALPH_TMP"

      # Capture exit code of claude command (not tee)
      # In zsh, pipestatus is lowercase and 1-indexed
      local exit_code=${pipestatus[1]}

      # Check for transient API errors (in output OR non-zero exit)
      if grep -qE "No messages returned|EAGAIN|ECONNRESET|fetch failed|API error" "$RALPH_TMP" 2>/dev/null || [[ "$exit_code" -ne 0 ]]; then
        retry_count=$((retry_count + 1))
        if [[ "$retry_count" -lt "$max_retries" ]]; then
          echo ""
          echo "  ⚠️  Error detected (exit code: $exit_code) - Retrying ($retry_count/$max_retries)..."
          echo "  ⏳ Waiting 10 seconds before retry..."
          sleep 10
          continue
        else
          echo ""
          echo "  ❌ Error persisted after $max_retries retries. Skipping iteration."
          if $notify_enabled; then
            curl -s -d "Ralph ❌ Error after $max_retries retries on iteration $i" "ntfy.sh/${ntfy_topic}" > /dev/null
          fi
          break  # Only break after exhausting retries
        fi
      else
        claude_success=true
        break  # Success - break out of retry loop
      fi
    done

    echo ""

    # Check if all tasks complete
    if grep -qE "^<promise>COMPLETE</promise>$" "$RALPH_TMP" 2>/dev/null; then
      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "  ✅ ALL TASKS COMPLETE after $i iterations!"
      echo "  ⏱️  $(date '+%H:%M:%S')"
      echo "═══════════════════════════════════════════════════════════════"
      # Send notification if enabled
      if $notify_enabled; then
        curl -s -d "Ralph ✅ All tasks complete after $i iterations" "ntfy.sh/${ntfy_topic}" > /dev/null
      fi
      rm -f "$RALPH_TMP"
      return 0
    fi

    # Check if all remaining tasks are blocked
    if grep -qE "^<promise>ALL_BLOCKED</promise>$" "$RALPH_TMP" 2>/dev/null; then
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
        curl -s -d "Ralph ⏹️ All tasks BLOCKED after $i iterations - needs user action" "ntfy.sh/${ntfy_topic}" > /dev/null
      fi
      rm -f "$RALPH_TMP"
      return 2  # Different exit code for blocked vs complete
    fi

    # Show remaining tasks
    local remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo "?")
    echo "───────────────────────────────────────────────────────────────"
    echo "  📋 Tasks remaining: $remaining"
    echo "  ⏳ Pausing ${SLEEP}s before next iteration..."
    echo "───────────────────────────────────────────────────────────────"

    # Per-iteration notification if enabled
    if $notify_enabled; then
      curl -s -d "Ralph 🔄 Iteration $i done. $remaining tasks left" "ntfy.sh/${ntfy_topic}" > /dev/null
    fi

    sleep $SLEEP
  done

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  ⚠️  REACHED MAX ITERATIONS ($MAX)"
  echo "  📋 Tasks remaining: $(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')"
  echo "═══════════════════════════════════════════════════════════════"
  # Send notification if enabled
  local remaining=$(grep -c '\- \[ \]' "$PRD_PATH" 2>/dev/null || echo '?')
  if $notify_enabled; then
    curl -s -d "Ralph ⚠️ Max iterations ($MAX). $remaining tasks remaining" "ntfy.sh/${ntfy_topic}" > /dev/null
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
  local NC='\033[0m'

  echo ""
  echo "${CYAN}${BOLD}Ralph Commands${NC}"
  echo ""
  echo "  ${BOLD}ralph [N] [sleep]${NC}     Run N iterations (default 10) on PRD.md"
  echo "  ${BOLD}ralph <app> N${NC}         Run on apps/<app>/PRD.md with auto branch"
  echo ""
  echo "  ${BOLD}ralph-init [app]${NC}      Create PRD template (root or apps/<app>/)"
  echo "  ${BOLD}ralph-archive [app]${NC}   Archive completed stories to docs.local/"
  echo "  ${BOLD}ralph-status${NC}          Show PRD progress, blocked stories, next story"
  echo "  ${BOLD}ralph-learnings${NC}       Manage learnings in docs.local/learnings/"
  echo "  ${BOLD}ralph-watch${NC}           Live tail of current Ralph output"
  echo "  ${BOLD}ralph-stop${NC}            Kill all running Ralph processes"
  echo ""
  echo "${GRAY}Flags:${NC}"
  echo "  ${BOLD}-QN${NC}                   Enable ntfy notifications"
  echo "  ${BOLD}-S${NC}                    Use Sonnet model (faster)"
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
  local prd_path

  # Help text
  if [[ "$app" == "-h" || "$app" == "--help" ]]; then
    echo "Usage: ralph-init [app]"
    echo ""
    echo "Create a PRD template file."
    echo "  No args:     Creates PRD.md in current directory"
    echo "  With app:    Creates apps/<app>/PRD.md"
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
    prd_path="apps/$app/PRD.md"
    mkdir -p "apps/$app"
  else
    prd_path="PRD.md"
  fi

  if [[ -f "$prd_path" ]]; then
    echo "❌ PRD already exists: $prd_path"
    read -q "REPLY?Overwrite? (y/n) "
    echo ""
    if [[ "$REPLY" != "y" ]]; then
      return 1
    fi
  fi

  cat > "$prd_path" << 'EOF'
# PRD: [Project/Feature Name]

**Working Directory:** `apps/[app]`
**Created:** $(date +%Y-%m-%d)

---

## User Stories

### US-001: [Story Title]

**Description:** [What this story accomplishes]

**Acceptance Criteria:**
- [ ] First criterion
- [ ] Second criterion
- [ ] Typecheck passes

---

### US-002: [Next Story]

**Description:** [What this story accomplishes]

**Acceptance Criteria:**
- [ ] First criterion
- [ ] Typecheck passes

EOF

  # Replace date placeholder
  sed -i '' "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/" "$prd_path"

  echo "✅ Created PRD template: $prd_path"
  echo "   Edit the file to add your user stories"
}

# ralph-archive [app] - Archive completed stories to docs.local
function ralph-archive() {
  local app="$1"
  local prd_path
  local archive_dir="docs.local/prd-archive"

  if [[ -n "$app" ]]; then
    prd_path="apps/$app/PRD.md"
  else
    prd_path="PRD.md"
  fi

  if [[ ! -f "$prd_path" ]]; then
    echo "❌ PRD not found: $prd_path"
    return 1
  fi

  # Create archive directory
  mkdir -p "$archive_dir"

  # Generate archive filename
  local date_suffix=$(date +%Y%m%d-%H%M%S)
  local app_prefix=""
  [[ -n "$app" ]] && app_prefix="${app}-"
  local archive_file="$archive_dir/${app_prefix}completed-${date_suffix}.md"

  # Extract completed stories (sections with all [x] checkboxes)
  echo "# Archived PRD Stories" > "$archive_file"
  echo "" >> "$archive_file"
  echo "**Archived:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$archive_file"
  [[ -n "$app" ]] && echo "**App:** $app" >> "$archive_file"
  echo "" >> "$archive_file"
  echo "---" >> "$archive_file"
  echo "" >> "$archive_file"

  # Copy the entire PRD for archival (keeps context)
  cat "$prd_path" >> "$archive_file"

  echo "✅ Archived to: $archive_file"

  # Ask if user wants to clear completed stories from PRD
  read -q "REPLY?Clear PRD.md for next sprint? (y/n) "
  echo ""
  if [[ "$REPLY" == "y" ]]; then
    # Create fresh PRD with just header
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

  # Helper function to show PRD status for a single file
  _ralph_show_prd() {
    local prd_file="$1"
    local label="$2"

    [[ ! -f "$prd_file" ]] && return

    local pending=$(grep -c '\- \[ \]' "$prd_file" 2>/dev/null || echo 0)
    local done=$(grep -c '\- \[x\]' "$prd_file" 2>/dev/null || echo 0)
    local total=$((pending + done))
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
    echo "   ${GREEN}✅ $done${NC} completed  │  ${YELLOW}⏳ $pending${NC} pending  │  📊 $total total"
    echo ""

    # Count stories (not just criteria)
    local story_count=$(grep -cE '^### (US|V)-' "$prd_file" 2>/dev/null || echo 0)

    # Find BLOCKED stories
    local blocked_stories=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && blocked_stories+=("$line")
    done < <(grep -B3 'BLOCKED' "$prd_file" 2>/dev/null | grep -oE '(US|V)-[A-Z0-9-]+' | sort -u | head -5)

    if [[ ${#blocked_stories[@]} -gt 0 ]]; then
      echo "   ${RED}🚫 BLOCKED (${#blocked_stories[@]}):${NC}"
      for story in "${blocked_stories[@]}"; do
        echo "      ${RED}•${NC} $story"
      done
      echo ""
    fi

    # Find next story (first with pending criteria, not blocked)
    local next_found=0
    while IFS= read -r story_line; do
      local story_id=$(echo "$story_line" | sed 's/^### //' | cut -d: -f1)
      # Get story section and check for pending + not blocked
      local has_pending=$(sed -n "/^### ${story_id}:/,/^### /p" "$prd_file" 2>/dev/null | grep -c '\- \[ \]')
      local is_blocked=$(sed -n "/^### ${story_id}:/,/^### /p" "$prd_file" 2>/dev/null | grep -c 'BLOCKED')
      if [[ "$has_pending" -gt 0 && "$is_blocked" -eq 0 ]]; then
        local story_title=$(echo "$story_line" | sed 's/^### //')
        echo "   ${GREEN}▶ NEXT STORY:${NC}"
        echo "      ${BOLD}$story_title${NC}"
        local criteria_pending=$(sed -n "/^### ${story_id}:/,/^### /p" "$prd_file" 2>/dev/null | grep -c '\- \[ \]')
        echo "      ${GRAY}($criteria_pending acceptance criteria remaining)${NC}"
        echo ""
        next_found=1
        break
      fi
    done < <(grep -E '^### (US|V)-' "$prd_file" 2>/dev/null)

    # List pending stories (up to 8)
    echo "   ${YELLOW}📝 Pending Stories:${NC}"
    local story_num=0
    while IFS= read -r story_line; do
      local story_id=$(echo "$story_line" | sed 's/^### //' | cut -d: -f1)
      local has_pending=$(sed -n "/^### ${story_id}:/,/^### /p" "$prd_file" 2>/dev/null | grep -c '\- \[ \]')
      local is_blocked=$(sed -n "/^### ${story_id}:/,/^### /p" "$prd_file" 2>/dev/null | grep -c 'BLOCKED')
      if [[ "$has_pending" -gt 0 ]]; then
        story_num=$((story_num + 1))
        local story_title=$(echo "$story_line" | sed 's/^### //' | cut -d: -f2- | sed 's/^ *//')
        local prefix="${GRAY}$story_num.${NC}"
        if [[ "$is_blocked" -gt 0 ]]; then
          prefix="${RED}⏹${NC}"
          story_title="${GRAY}$story_title (BLOCKED)${NC}"
        fi
        if [[ "$story_num" -le 8 ]]; then
          echo "      $prefix $story_id: $story_title ${GRAY}[$has_pending]${NC}"
        fi
      fi
    done < <(grep -E '^### (US|V)-' "$prd_file" 2>/dev/null)

    if [[ "$story_num" -gt 8 ]]; then
      echo "      ${GRAY}... and $((story_num - 8)) more pending stories${NC}"
    fi
    [[ "$story_num" -eq 0 ]] && echo "      ${GREEN}🎉 All stories complete!${NC}"
    echo ""
  }

  # Check root PRD
  _ralph_show_prd "PRD.md" "📁 Root PRD.md"

  # Check app-specific PRDs
  for app in expo public admin frontend backend mobile; do
    if [[ -f "apps/$app/PRD.md" ]]; then
      local branch_info=""
      if git show-ref --verify --quiet "refs/heads/feat/${app}-work" 2>/dev/null; then
        branch_info="  ${GREEN}🌿 feat/${app}-work${NC}"
      fi
      _ralph_show_prd "apps/$app/PRD.md" "📱 apps/$app/PRD.md$branch_info"
    fi
  done

  # Current Iteration - find story with progress OR show next if Ralph is running
  echo "${BLUE}───────────────────────────────────────────────────────────────${NC}"

  # Check if Ralph is currently running
  local ralph_running=$(pgrep -f "tee /tmp/ralph_output" 2>/dev/null | head -1)

  if [[ -f "PRD.md" ]]; then
    local current_story=""
    local current_done=0
    local current_pending=0
    local show_as_running=false

    # First, find story that's in progress (has both [x] and [ ])
    while IFS= read -r story_line; do
      local story_id=$(echo "$story_line" | sed 's/^### //' | cut -d: -f1)
      local story_section=$(sed -n "/^### ${story_id}:/,/^### /p" PRD.md 2>/dev/null)
      local done_count=$(echo "$story_section" | grep '\- \[x\]' | wc -l | tr -d ' ')
      local pending_count=$(echo "$story_section" | grep '\- \[ \]' | wc -l | tr -d ' ')
      local is_blocked=$(echo "$story_section" | grep -c 'BLOCKED' | tr -d ' ')

      # In progress = has some done AND some pending, not blocked
      if [[ "$done_count" -gt 0 && "$pending_count" -gt 0 && "$is_blocked" -eq 0 ]]; then
        current_story="$story_id"
        current_done="$done_count"
        current_pending="$pending_count"
        show_as_running=true
        break
      fi
    done < <(grep -E '^### (US|V)-' PRD.md 2>/dev/null)

    # If no in-progress story but Ralph is running, show next story
    if [[ -z "$current_story" && -n "$ralph_running" ]]; then
      while IFS= read -r story_line; do
        local story_id=$(echo "$story_line" | sed 's/^### //' | cut -d: -f1)
        local story_section=$(sed -n "/^### ${story_id}:/,/^### /p" PRD.md 2>/dev/null)
        local pending_count=$(echo "$story_section" | grep '\- \[ \]' | wc -l | tr -d ' ')
        local is_blocked=$(echo "$story_section" | grep -c 'BLOCKED' | tr -d ' ')

        if [[ "$pending_count" -gt 0 && "$is_blocked" -eq 0 ]]; then
          current_story="$story_id"
          current_done=0
          current_pending="$pending_count"
          show_as_running=true
          break
        fi
      done < <(grep -E '^### (US|V)-' PRD.md 2>/dev/null)
    fi

    if [[ -n "$current_story" && "$show_as_running" == "true" ]]; then
      local current_total=$((current_done + current_pending))
      local story_title=$(grep "^### ${current_story}:" PRD.md | sed 's/^### //')
      local story_section=$(sed -n "/^### ${current_story}:/,/^### /p" PRD.md 2>/dev/null)

      # Get last completed task and next pending task
      local last_done=$(echo "$story_section" | grep '\- \[x\]' | tail -1 | sed 's/.*\[x\] //')
      local next_pending=$(echo "$story_section" | grep '\- \[ \]' | head -1 | sed 's/.*\[ \] //')

      echo "${CYAN}🔄 Current Iteration:${NC} ${GREEN}● Ralph running${NC}"
      echo "   ${YELLOW}${BOLD}$current_story${NC} ${YELLOW}$current_done/$current_total done${NC} ${GRAY}(updates on commit)${NC}"
      [[ -n "$last_done" ]] && echo "   ${GREEN}✓ $last_done${NC}"
      [[ -n "$next_pending" ]] && echo "   ${GRAY}○ $next_pending${NC}"
      echo ""
    fi
  fi

  # Last completed (from git)
  local last_story=$(git log --oneline -n 20 2>/dev/null | grep -oE '(US|V)-[A-Z0-9-]+' | head -1)
  if [[ -n "$last_story" ]]; then
    local last_commit=$(git log --oneline -n 20 2>/dev/null | grep "$last_story" | head -1)
    local last_hash=$(echo "$last_commit" | cut -d' ' -f1)
    local last_msg=$(echo "$last_commit" | cut -d' ' -f2-)
    local last_time=$(git log -1 --format="%ar" "$last_hash" 2>/dev/null)
    echo "${CYAN}✅ Last Completed:${NC}"
    echo "   ${GREEN}${BOLD}$last_story${NC} ${GRAY}($last_time)${NC}"
    echo "   ${GRAY}$last_msg${NC}"
    echo ""
  fi

  # Recently completed stories (from commits with story IDs)
  echo "${CYAN}✅ Recently Completed:${NC}"
  local completed_lines=$(git log --oneline -n 20 2>/dev/null | grep -E '(US|V)-[A-Z0-9-]+' | head -5)
  echo "$completed_lines" | while read -r line; do
    [[ -z "$line" ]] && continue
    local hash=$(echo "$line" | cut -d' ' -f1)
    local story_id=$(echo "$line" | grep -oE '(US|V)-[A-Z0-9-]+' | head -1)
    local msg=$(echo "$line" | cut -d' ' -f2- | sed -E 's/feat\([^)]+\): //' | sed -E 's/verify\([^)]+\): //')
    printf "   ${GRAY}%s${NC} ${GREEN}%-15s${NC} %s\n" "$hash" "$story_id" "$msg"
  done
  echo ""

  # Unset helper function
  unset -f _ralph_show_prd
}

