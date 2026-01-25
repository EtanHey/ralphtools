#!/bin/bash
# tests/fixtures/prd-manager/generate-fixtures.sh
# Purpose: Generate test fixtures for prd-manager script testing
# Usage: bash generate-fixtures.sh <output-dir> <scenario>
#
# Scenarios:
#   basic - Basic PRD with pending/completed stories
#   empty - Empty PRD with no stories
#   blocked - PRD with some blocked stories
#   all-completed - All stories completed (passes=true)

set -e

OUTPUT_DIR="${1:-$(mktemp -d)}"
SCENARIO="${2:-basic}"

mkdir -p "$OUTPUT_DIR"

# Create prd-json directory structure
PRD_DIR="$OUTPUT_DIR/prd-json"
mkdir -p "$PRD_DIR/stories"

case "$SCENARIO" in
    basic)
        # Basic PRD with mix of stories
        cat > "$PRD_DIR/index.json" << 'EOF'
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-25T12:00:00Z",
  "nextStory": "US-002",
  "storyOrder": ["US-001", "US-002", "US-003", "BUG-001"],
  "pending": ["US-002", "US-003"],
  "blocked": [],
  "completed": ["US-001", "BUG-001"],
  "stats": {
    "total": 4,
    "completed": 2,
    "pending": 2,
    "blocked": 0
  }
}
EOF

        # US-001 - completed story
        cat > "$PRD_DIR/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "Add login button",
  "description": "Add login button to the header",
  "priority": "high",
  "acceptanceCriteria": [
    {"text": "Button visible in header", "checked": true},
    {"text": "Button navigates to /login", "checked": true}
  ],
  "passes": true,
  "completedAt": "2026-01-25T10:00:00Z"
}
EOF

        # US-002 - pending story with partial progress
        cat > "$PRD_DIR/stories/US-002.json" << 'EOF'
{
  "id": "US-002",
  "title": "User profile page",
  "description": "Create user profile page",
  "priority": "medium",
  "acceptanceCriteria": [
    {"text": "Profile page exists at /profile", "checked": true},
    {"text": "Shows user avatar", "checked": false},
    {"text": "Shows user name", "checked": false}
  ],
  "passes": false
}
EOF

        # US-003 - pending story with no progress
        cat > "$PRD_DIR/stories/US-003.json" << 'EOF'
{
  "id": "US-003",
  "title": "Settings page",
  "description": "Create settings page",
  "priority": "low",
  "acceptanceCriteria": [
    {"text": "Settings page exists", "checked": false},
    {"text": "Theme toggle works", "checked": false}
  ],
  "passes": false
}
EOF

        # BUG-001 - completed bug fix
        cat > "$PRD_DIR/stories/BUG-001.json" << 'EOF'
{
  "id": "BUG-001",
  "title": "Fix crash on logout",
  "description": "App crashes when logging out",
  "priority": "critical",
  "acceptanceCriteria": [
    {"text": "Logout works without crash", "checked": true}
  ],
  "passes": true,
  "completedAt": "2026-01-25T11:00:00Z"
}
EOF
        ;;

    empty)
        # Empty PRD
        cat > "$PRD_DIR/index.json" << 'EOF'
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-25T12:00:00Z",
  "nextStory": null,
  "storyOrder": [],
  "pending": [],
  "blocked": [],
  "completed": [],
  "stats": {
    "total": 0,
    "completed": 0,
    "pending": 0,
    "blocked": 0
  }
}
EOF
        ;;

    blocked)
        # PRD with blocked stories
        cat > "$PRD_DIR/index.json" << 'EOF'
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-25T12:00:00Z",
  "nextStory": "US-002",
  "storyOrder": ["US-001", "US-002"],
  "pending": ["US-002"],
  "blocked": ["US-001"],
  "completed": [],
  "stats": {
    "total": 2,
    "completed": 0,
    "pending": 1,
    "blocked": 1
  }
}
EOF

        # US-001 - blocked story
        cat > "$PRD_DIR/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "External API integration",
  "description": "Integrate with external API",
  "priority": "high",
  "blockedBy": "API credentials not configured",
  "acceptanceCriteria": [
    {"text": "API calls work", "checked": false}
  ],
  "passes": false
}
EOF

        # US-002 - pending story
        cat > "$PRD_DIR/stories/US-002.json" << 'EOF'
{
  "id": "US-002",
  "title": "Local feature",
  "description": "Feature that does not depend on API",
  "priority": "medium",
  "acceptanceCriteria": [
    {"text": "Feature works", "checked": false}
  ],
  "passes": false
}
EOF
        ;;

    all-completed)
        # All stories completed
        cat > "$PRD_DIR/index.json" << 'EOF'
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-25T12:00:00Z",
  "nextStory": "COMPLETE",
  "storyOrder": ["US-001", "US-002"],
  "pending": [],
  "blocked": [],
  "completed": ["US-001", "US-002"],
  "stats": {
    "total": 2,
    "completed": 2,
    "pending": 0,
    "blocked": 0
  }
}
EOF

        cat > "$PRD_DIR/stories/US-001.json" << 'EOF'
{
  "id": "US-001",
  "title": "First feature",
  "description": "First completed feature",
  "priority": "high",
  "acceptanceCriteria": [
    {"text": "Feature works", "checked": true}
  ],
  "passes": true,
  "completedAt": "2026-01-25T10:00:00Z"
}
EOF

        cat > "$PRD_DIR/stories/US-002.json" << 'EOF'
{
  "id": "US-002",
  "title": "Second feature",
  "description": "Second completed feature",
  "priority": "medium",
  "acceptanceCriteria": [
    {"text": "Feature works", "checked": true}
  ],
  "passes": true,
  "completedAt": "2026-01-25T11:00:00Z"
}
EOF
        ;;

    *)
        echo "Unknown scenario: $SCENARIO"
        exit 1
        ;;
esac

# Return paths for test to use
echo "PRD_DIR=$PRD_DIR"
