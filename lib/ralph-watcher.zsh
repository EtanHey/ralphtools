#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH WATCHER - Live file watching, orphan tracking, crash logging
# ═══════════════════════════════════════════════════════════════════
# Part of the Ralph modular system. Sourced by ralph.zsh
# Contains: fswatch/inotifywait integration, PID tracking, crash logs
# ═══════════════════════════════════════════════════════════════════

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
