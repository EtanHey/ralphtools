#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH COMMANDS - Helper commands for Ralph operations
# ═══════════════════════════════════════════════════════════════════
# Part of the Ralph modular system. Sourced by ralph.zsh
# Contains: ralph-stop, ralph-help, ralph-whatsnew, ralph-watch,
#           ralph-session, ralph-logs, ralph-kill-orphans, etc.
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# ralph-session - Show current Ralph session state and data locations
# ═══════════════════════════════════════════════════════════════════
# Usage: ralph-session [--paths]
#   --paths : Show all data file paths
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

# ralph-stop - Stop any running Ralph loops
ralph-stop() {
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
ralph-help() {
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
ralph-whatsnew() {
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
ralph-watch() {
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
