#!/bin/bash
# Claude Code Stop notification - per-project topics
# Called by: ~/.claude/hooks/notify_stop.sh
# Topic format: {user}-{ralph|claude}-{project}
#
# Usage: echo '{"cwd":"/path/to/project"}' | ./notify-stop.sh
#    or: ./notify-stop.sh (uses PWD)

set -euo pipefail

# Config location
CONFIG_FILE="${RALPH_CONFIG_FILE:-$HOME/.config/ralphtools/config.json}"

# Check if notifications enabled
check_enabled() {
    if [ -f "$CONFIG_FILE" ]; then
        grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$CONFIG_FILE" 2>/dev/null
    else
        return 1
    fi
}

# Get project name from path
get_project_name() {
    local path="$1"
    basename "$path" 2>/dev/null || echo "unknown"
}

# Detect mode (ralph vs claude)
get_mode() {
    if [ -n "${RALPH_SESSION:-}" ]; then
        echo "ralph"
    else
        echo "claude"
    fi
}

# Get username (configurable)
get_user() {
    echo "${NTFY_USER:-etanheys}"
}

# Build human-readable summary from transcript
get_summary() {
    local transcript="$1"
    [ -z "$transcript" ] || [ ! -f "$transcript" ] && return

    local summary=""

    # Check for git commit (most meaningful action)
    local commit_msg
    commit_msg=$(grep -o 'git commit.*-m[[:space:]]*"[^"]*"' "$transcript" 2>/dev/null | tail -1 | sed 's/.*-m[[:space:]]*"//' | sed 's/"$//' | head -c 50)
    if [ -n "$commit_msg" ]; then
        echo "Committed: $commit_msg"
        return
    fi

    # Check for git push
    if grep -q 'git push' "$transcript" 2>/dev/null; then
        summary="Pushed to remote"
    fi

    # Get edited files (unique basenames)
    local files
    files=$(grep -o '"file_path":"[^"]*"' "$transcript" 2>/dev/null | cut -d'"' -f4 | xargs -I{} basename {} 2>/dev/null | sort -u | head -3 | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$files" ]; then
        if [ -n "$summary" ]; then
            echo "$summary ($files)"
        else
            echo "Edited: $files"
        fi
        return
    fi

    # Fallback to counts
    local edits writes
    edits=$(grep -c '"name":"Edit"' "$transcript" 2>/dev/null || echo 0)
    writes=$(grep -c '"name":"Write"' "$transcript" 2>/dev/null || echo 0)

    if [ "$edits" -gt 0 ] || [ "$writes" -gt 0 ]; then
        echo "Made $edits edits, $writes new files"
        return
    fi

    echo "Session complete"
}

# Check if Claude is waiting for user input, return type and context
check_waiting_for_input() {
    local transcript="$1"
    [ -z "$transcript" ] || [ ! -f "$transcript" ] && return 1

    # Check for AskUserQuestion tool - extract the question
    if tail -200 "$transcript" 2>/dev/null | grep -q '"name":"AskUserQuestion"'; then
        local question
        question=$(tail -200 "$transcript" 2>/dev/null | grep -o '"question":"[^"]*"' | tail -1 | cut -d'"' -f4 | head -c 60)
        if [ -n "$question" ]; then
            echo "question:$question"
        else
            echo "question:Needs your input"
        fi
        return 0
    fi

    # Check for ExitPlanMode (waiting for plan approval)
    if tail -100 "$transcript" 2>/dev/null | grep -q '"name":"ExitPlanMode"'; then
        echo "plan:Review implementation plan"
        return 0
    fi

    # Check if last assistant message ends with question mark - extract it
    local last_question
    last_question=$(tail -100 "$transcript" 2>/dev/null | grep -o '"text":"[^"]*\?"' | tail -1 | cut -d'"' -f4 | head -c 80)
    if [ -n "$last_question" ]; then
        echo "question:$last_question"
        return 0
    fi

    return 1
}

# Get last action summary from transcript
get_last_action() {
    local transcript="$1"
    [ -z "$transcript" ] || [ ! -f "$transcript" ] && return

    # Try to find the last meaningful tool use
    local last_edit last_file
    last_file=$(grep -o '"file_path":"[^"]*"' "$transcript" 2>/dev/null | tail -1 | cut -d'"' -f4)

    if [ -n "$last_file" ]; then
        echo "$(basename "$last_file")"
        return
    fi

    # Check for commit
    if tail -50 "$transcript" 2>/dev/null | grep -q 'git commit'; then
        echo "committed"
        return
    fi
}

# Send notification
send_ntfy() {
    local topic="$1"
    local title="$2"
    local body="$3"
    local tags="${4:-robot}"
    local priority="${5:-default}"

    curl -s \
        -H "Title: $title" \
        -H "Tags: $tags" \
        -H "Priority: $priority" \
        -d "$body" \
        "ntfy.sh/$topic" > /dev/null 2>&1
}

# Main
main() {
    # Check enabled
    check_enabled || exit 0

    # Read hook data from stdin (if piped)
    local hook_data=""
    if [ ! -t 0 ]; then
        hook_data=$(cat)
    fi

    # Get cwd from hook data or PWD
    local cwd
    cwd=$(echo "$hook_data" | grep -o '"cwd":"[^"]*"' 2>/dev/null | cut -d'"' -f4 || true)
    [ -z "$cwd" ] && cwd="$PWD"

    # Get transcript path if available
    local transcript
    transcript=$(echo "$hook_data" | grep -o '"transcript_path":"[^"]*"' 2>/dev/null | cut -d'"' -f4 || true)

    # Build components
    local user mode project topic
    user=$(get_user)
    mode=$(get_mode)
    project=$(get_project_name "$cwd")
    topic="${user}-${mode}-${project}"

    # Check if waiting for input (returns "type:context")
    local waiting_result waiting_type waiting_context
    waiting_result=$(check_waiting_for_input "$transcript" || true)
    waiting_type="${waiting_result%%:*}"
    waiting_context="${waiting_result#*:}"

    local tags priority title body
    tags="${mode},robot"
    priority="default"

    # Build message based on state
    if [ "$waiting_type" = "question" ]; then
        title="[$mode] $project - WAITING"
        body="$waiting_context"
        tags="question,${mode}"
        priority="high"
    elif [ "$waiting_type" = "plan" ]; then
        title="[$mode] $project - PLAN READY"
        body="$waiting_context"
        tags="clipboard,${mode}"
        priority="high"
    else
        # Get human-readable summary
        local summary
        summary=$(get_summary "$transcript")
        title="[$mode] $project"
        body="$summary"
    fi

    # Send
    send_ntfy "$topic" "$title" "$body" "$tags" "$priority"
}

main "$@"
