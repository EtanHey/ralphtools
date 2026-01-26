#!/bin/bash
#
# CPU Monitor - Human-readable view of what's using CPU
# Uses in-place updates (no flicker)
#
# Usage: ./scripts/cpu-monitor.sh [refresh_seconds]
#

REFRESH="${1:-2}"

# Hide cursor, restore on exit
tput civis
trap 'tput cnorm; exit' INT TERM

clear

while true; do
    # Move cursor to top-left without clearing
    tput home

    # Build output in variable for atomic write
    OUTPUT="═══════════════════════════════════════════════════════════════
  CPU Monitor - $(date '+%H:%M:%S')  |  Refresh: ${REFRESH}s  |  Ctrl+C exit
═══════════════════════════════════════════════════════════════

📊 LOAD: $(uptime | sed 's/.*load averages*: *//')

🔥 CPU:  $(top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | sed 's/CPU usage: //' || echo 'measuring...')

💾 MEM:  $(vm_stat 2>/dev/null | awk '
    /Pages free/ { free=$3 }
    /Pages active/ { active=$3 }
    /Pages inactive/ { inactive=$3 }
    /Pages wired/ { wired=$4 }
    END {
        gsub(/\./, "", free); gsub(/\./, "", active)
        gsub(/\./, "", inactive); gsub(/\./, "", wired)
        total = (free + active + inactive + wired) * 16384 / 1024 / 1024 / 1024
        used = (active + wired) * 16384 / 1024 / 1024 / 1024
        printf "%.1fG used / %.1fG total", used, total
    }')

───────────────────────────────────────────────────────────────
🏃 TOP PROCESSES
───────────────────────────────────────────────────────────────
$(printf '%-6s %-6s %-8s %s\n' 'CPU%' 'MEM%' 'PID' 'COMMAND')
$(ps aux 2>/dev/null | sort -nrk 3 | head -6 | awk '{printf "%-6.1f %-6.1f %-8s %s\n", $3, $4, $2, $11}')
"

    # Add Ollama section if running
    if pgrep -q ollama 2>/dev/null; then
        OUTPUT+="
───────────────────────────────────────────────────────────────
🦙 OLLAMA
───────────────────────────────────────────────────────────────
$(ps aux 2>/dev/null | grep -E 'ollama|qwen|llama' | grep -v grep | head -3 | awk '{printf "%-6.1f%% CPU  %-6.1f%% MEM  %s\n", $3, $4, $11}')
"
    fi

    # Add AI processes section if running
    if pgrep -q -E 'claude|aider|bun' 2>/dev/null; then
        AI_PROCS=$(ps aux 2>/dev/null | grep -E 'claude|aider|bun.*ralph' | grep -v grep | head -3)
        if [[ -n "$AI_PROCS" ]]; then
            OUTPUT+="
───────────────────────────────────────────────────────────────
🤖 AI AGENTS
───────────────────────────────────────────────────────────────
$(echo "$AI_PROCS" | awk '{printf "%-6.1f%% CPU  %-6.1f%% MEM  %s\n", $3, $4, $11}')
"
        fi
    fi

    OUTPUT+="
═══════════════════════════════════════════════════════════════"

    # Print and clear to end of screen (removes stale lines)
    echo "$OUTPUT"
    tput ed

    sleep "$REFRESH"
done
