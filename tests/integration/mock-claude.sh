#!/usr/bin/env bash
# Mock Claude CLI for integration testing
# Simulates Claude responses for predictable testing

set -euo pipefail

# Parse arguments to determine what response to return
ARGS="$*"

# Default response - simulate successful iteration
default_response() {
  cat << 'EOF'
I've completed the task successfully.

All acceptance criteria have been checked.
EOF
}

# Response when all tasks are complete
complete_response() {
  cat << 'EOF'
All tasks in the PRD have been completed.

<promise>COMPLETE</promise>
EOF
}

# Response when blocked
blocked_response() {
  cat << 'EOF'
I'm unable to proceed with this task due to a blocker.

<promise>ALL_BLOCKED</promise>
EOF
}

# Check for specific mock scenarios via env vars
if [[ "${MOCK_CLAUDE_RESPONSE:-}" == "complete" ]]; then
  complete_response
elif [[ "${MOCK_CLAUDE_RESPONSE:-}" == "blocked" ]]; then
  blocked_response
elif [[ "${MOCK_CLAUDE_RESPONSE:-}" == "error" ]]; then
  echo "Error: Simulated error response" >&2
  exit 1
else
  default_response
fi

exit 0
