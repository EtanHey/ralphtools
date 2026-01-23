# Live Progress Updates System

Ralph can update progress bars in real-time during Claude execution. This document explains how the system works.

## Overview

The live updates system has three components:

1. **File Watcher** (`_ralph_start_watcher`): Monitors `prd-json/stories/` and `prd-json/index.json` for changes
2. **Polling Loop** (`_ralph_start_polling_loop`): Reads file change events and triggers display updates
3. **Display Updaters** (`_ralph_update_*_display_at_row`): Use ANSI escape codes to update progress bars in-place

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Main Process                                │
│                                                                          │
│  1. Start iteration                                                      │
│  2. Draw iteration header (stores row positions)                         │
│  3. _ralph_start_polling_loop(story, dir, criteria_row, stories_row)    │
│  4. Run Claude (blocked until completion)                                │
│  5. _ralph_stop_polling_loop()                                           │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               │ fork
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Background Polling Loop                         │
│                                                                          │
│  - Receives row positions as parameters (critical!)                      │
│  - Reads from FIFO with 0.2s timeout                                     │
│  - On file change: calls _ralph_handle_file_change_with_rows()           │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               │ read from FIFO
                               │
┌─────────────────────────────────────────────────────────────────────────┐
│                        File Watcher Process                              │
│                                                                          │
│  - fswatch (macOS) or inotifywait (Linux)                                │
│  - Writes changed filenames to FIFO                                      │
│  - Runs in background, started once per Ralph session                    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Implementation Details

### Subshell Variable Isolation (Critical Bug Fix)

When ZSH creates a background subshell with `{ ... } &`, variables are **copied at fork time**. This means:

```zsh
# WRONG - subshell has stale row values
RALPH_CRITERIA_ROW=0
{
  # This sees RALPH_CRITERIA_ROW=0 even if parent updates it later
  while true; do
    _ralph_update_criteria_display "$story" "$dir"  # Uses global, sees 0
  done
} &
RALPH_CRITERIA_ROW=42  # Parent updates, but subshell already forked!
```

**Solution**: Pass row positions as function parameters, which become local variables in the subshell:

```zsh
# CORRECT - row positions passed as parameters
_ralph_start_polling_loop "$story" "$dir" "$RALPH_CRITERIA_ROW" "$RALPH_STORIES_ROW"

# Inside the function:
_ralph_start_polling_loop() {
  local criteria_row="${3:-0}"  # Captured at function call time
  local stories_row="${4:-0}"

  {
    # Subshell has correct values via the outer function's locals
    local local_criteria_row="$criteria_row"
    ...
  } &
}
```

### Row Position Calculation

Row positions are calculated using ANSI escape sequences after drawing the iteration header:

```zsh
# Get current cursor row
current_row=$(_ralph_get_cursor_row)

# Calculate where progress bars were drawn (counting backwards)
RALPH_CRITERIA_ROW=$((current_row - criteria_line_offset))
RALPH_STORIES_ROW=$((current_row - stories_line_offset))
```

### FIFO Communication

- File watcher writes changed filenames to a FIFO (named pipe)
- Polling loop reads from FIFO with non-blocking timeout
- This allows efficient event-driven updates without spinning

```
fswatch → FIFO → polling loop → display update
```

## Debug Logging

Enable debug logging with:

```bash
RALPH_DEBUG_LIVE=true ralph -i1 -p prd-json/
```

Debug logs are written to `/tmp/ralph-live-debug.log`:

```
[LIVE-DEBUG] 14:32:01 start_watcher: tool=fswatch, stories_dir=/path/to/prd-json/stories
[LIVE-DEBUG] 14:32:01 start_watcher: FIFO created at /tmp/ralph_watcher_12345_fifo
[LIVE-DEBUG] 14:32:01 start_watcher: SUCCESS, PID=12346
[LIVE-DEBUG] 14:32:05 start_polling_loop: story=US-001, criteria_row=15, stories_row=17
[LIVE-DEBUG] 14:32:05 polling_loop: STARTED in subshell, criteria_row=15, stories_row=17
[LIVE-DEBUG] 14:32:10 polling_loop: file changed: /path/to/prd-json/stories/US-001.json
[LIVE-DEBUG] 14:32:10 update_criteria: story=US-001, checked=1/5, row=15
```

## Requirements

- **fswatch** (macOS): `brew install fswatch`
- **inotifywait** (Linux): Usually in `inotify-tools` package

If neither is available, live updates are disabled gracefully and Ralph runs without real-time progress indicators.

## Configuration

Live updates are enabled by default. To disable:

```bash
RALPH_LIVE_ENABLED=false ralph -i1 -p prd-json/
```

## Troubleshooting

### Progress bars not updating?

1. Check if fswatch is installed: `which fswatch`
2. Enable debug logging: `RALPH_DEBUG_LIVE=true`
3. Verify row positions are non-zero in the debug log
4. Check FIFO exists: `ls -la /tmp/ralph_watcher_*`

### Debug log shows row=0?

This means the cursor position query failed. May happen in:
- Non-interactive shells
- Terminal emulators that don't support `\e[6n`
- When stdout is redirected

In these cases, live updates are disabled automatically.
