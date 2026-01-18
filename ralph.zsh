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
          if [[ $MAX -eq 10 ]]; then
            MAX=$1
          else
            SLEEP=$1
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
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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

    while [[ $retry_count -lt $max_retries ]]; do
      # Build claude command with optional model flag
      local claude_cmd="claude --chrome --dangerously-skip-permissions"
      if $use_sonnet; then
        claude_cmd="$claude_cmd --model sonnet"
      fi

      # Stream output in real-time with tee, also save to temp file
      eval "$claude_cmd" -p "You are Ralph, an autonomous coding agent. Do exactly ONE task per iteration.

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

**TWO browser tabs are ALREADY open: desktop (1440px) and mobile (375px). Do NOT change viewport settings.**

When verifying in browser:
1. Call tabs_context_mcp FIRST to see both tabs
2. CHOOSE the correct tab (desktop or mobile based on what you're testing)
3. Navigate to the test URL if needed
4. Take screenshot with: mcp__claude-in-chrome__computer action='screenshot' tabId=<chosen_tab_id>
5. Describe what you see in the screenshot

**Click rules:**
- ALWAYS use action='left_click' - NEVER 'right_click'
- Use ref='ref_X' from read_page, or coordinate=[x,y] from screenshot
- ALWAYS include tabId parameter

**Do NOT:**
- Create new tabs (two already exist - reuse them)
- Resize window or change viewport
- Open DevTools (already configured)
- Right-click anything

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
- Create blocker story (US-XXX-A) if infrastructure issue

**Remember:** Git commits = audit trail. PRD.md checkboxes = what next Ralph sees.

## Progress Format

## Iteration - [Task Name]
- What was done
- Learnings for next iteration
---


## Iteration Summary (REQUIRED)

At the end of EVERY iteration, provide an expressive summary:
- \"I completed [story ID] which was about [what it accomplished/changed]\"
- \"Next I think I should work on [next story ID] which is [what it will do]. I'm planning to [specific actions X, Y, Z]\"
- Be descriptive and conversational about what you did and what's next, not just checkboxes

## End Condition

After completing task, check PRD.md:
- ALL [x]: output <promise>COMPLETE</promise>
- ALL remaining [ ] are BLOCKED: output <promise>ALL_BLOCKED</promise>
- Some [ ] actionable: end response (next iteration continues)" 2>&1 | tee "$RALPH_TMP"

      # Check for transient API errors
      if grep -q "No messages returned" "$RALPH_TMP" 2>/dev/null; then
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
          echo ""
          echo "  ⚠️  API Error: 'No messages returned' - Retrying ($retry_count/$max_retries)..."
          echo "  ⏳ Waiting 5 seconds before retry..."
          sleep 5
          continue
        else
          echo ""
          echo "  ❌ API Error persisted after $max_retries retries. Skipping iteration."
          if $notify_enabled; then
            curl -s -d "Ralph ❌ API error after $max_retries retries on iteration $i" "ntfy.sh/${ntfy_topic}" > /dev/null
          fi
        fi
      else
        claude_success=true
      fi
      break
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

# Ralph cancel - stop any running ralph loops
alias ralph-stop='pkill -f "claude --dangerously-skip-permissions"'

# ═══════════════════════════════════════════════════════════════════
# Ralph Helper Commands
# ═══════════════════════════════════════════════════════════════════

# ralph-init [app] - Create PRD from template for an app
function ralph-init() {
  local app="$1"
  local prd_path

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

# ralph-learnings - Archive learnings when they get too long (>300 lines)
function ralph-learnings() {
  local learnings_file="docs.local/learnings.md"
  local archive_dir="docs.local/learnings-archive"
  local max_lines=300

  if [[ ! -f "$learnings_file" ]]; then
    echo "ℹ️  No learnings file found at $learnings_file"
    echo "   Create one with: mkdir -p docs.local && touch docs.local/learnings.md"
    return 0
  fi

  local line_count=$(wc -l < "$learnings_file" | tr -d ' ')

  if [[ $line_count -gt $max_lines ]]; then
    echo "📚 Learnings file has $line_count lines (max: $max_lines)"

    # Create archive directory
    mkdir -p "$archive_dir"

    # Generate archive filename
    local month=$(date +%Y-%m)
    local archive_file="$archive_dir/${month}-learnings.md"

    # If archive for this month exists, append
    if [[ -f "$archive_file" ]]; then
      echo "" >> "$archive_file"
      echo "---" >> "$archive_file"
      echo "" >> "$archive_file"
      echo "## Archived $(date '+%Y-%m-%d %H:%M')" >> "$archive_file"
      cat "$learnings_file" >> "$archive_file"
    else
      echo "# Learnings Archive - $month" > "$archive_file"
      echo "" >> "$archive_file"
      cat "$learnings_file" >> "$archive_file"
    fi

    # Keep only the most recent ~100 lines in learnings.md
    local keep_lines=100
    echo "# Learnings" > "$learnings_file.new"
    echo "" >> "$learnings_file.new"
    echo "(Older learnings archived to $archive_dir/)" >> "$learnings_file.new"
    echo "" >> "$learnings_file.new"
    echo "---" >> "$learnings_file.new"
    echo "" >> "$learnings_file.new"
    tail -n $keep_lines "$learnings_file" >> "$learnings_file.new"
    mv "$learnings_file.new" "$learnings_file"

    echo "✅ Archived to: $archive_file"
    echo "   Kept last $keep_lines lines in $learnings_file"
  else
    echo "✅ Learnings file OK: $line_count lines (max: $max_lines)"
  fi
}

# ralph-status - Show status of all Ralph PRDs
function ralph-status() {
  echo "📋 Ralph PRD Status"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # Check root PRD
  if [[ -f "PRD.md" ]]; then
    local root_pending=$(grep -c '\- \[ \]' PRD.md 2>/dev/null || echo 0)
    local root_done=$(grep -c '\- \[x\]' PRD.md 2>/dev/null || echo 0)
    echo "📁 Root PRD.md:"
    echo "   ✅ Completed: $root_done"
    echo "   ⏳ Pending: $root_pending"
    echo ""
  fi

  # Check app-specific PRDs
  for app in expo public admin; do
    if [[ -f "apps/$app/PRD.md" ]]; then
      local pending=$(grep -c '\- \[ \]' "apps/$app/PRD.md" 2>/dev/null || echo 0)
      local done=$(grep -c '\- \[x\]' "apps/$app/PRD.md" 2>/dev/null || echo 0)
      echo "📱 apps/$app/PRD.md:"
      echo "   ✅ Completed: $done"
      echo "   ⏳ Pending: $pending"

      # Check if branch exists
      if git show-ref --verify --quiet "refs/heads/feat/${app}-work" 2>/dev/null; then
        echo "   🌿 Branch: feat/${app}-work (exists)"
      else
        echo "   🌱 Branch: feat/${app}-work (will be created)"
      fi
      echo ""
    fi
  done
}
