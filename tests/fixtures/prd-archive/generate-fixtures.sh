#!/bin/bash
# tests/fixtures/prd-archive/generate-fixtures.sh
# Purpose: Generate valid PRD fixtures for testing archive scripts
# Usage: bash generate-fixtures.sh <output-dir>
#
# Creates a realistic PRD structure with:
# - index.json matching current schema
# - Mix of completed, pending, and blocked stories

set -e

OUTPUT_DIR="${1:-$(mktemp -d)}"
mkdir -p "$OUTPUT_DIR/prd-json/stories"

# Generate timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create index.json with realistic structure
cat > "$OUTPUT_DIR/prd-json/index.json" << EOF
{
  "\$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "$TIMESTAMP",
  "nextStory": "US-002",
  "storyOrder": ["US-001", "US-002", "US-003", "BUG-001"],
  "pending": ["US-002", "US-003"],
  "blocked": ["BUG-001"],
  "completed": ["US-001"],
  "newStories": []
}
EOF

# US-001: Completed story (passes=true)
cat > "$OUTPUT_DIR/prd-json/stories/US-001.json" << EOF
{
  "id": "US-001",
  "title": "Completed feature",
  "description": "A feature that was already completed",
  "priority": "high",
  "acceptanceCriteria": [
    { "text": "Criterion 1", "checked": true },
    { "text": "Criterion 2", "checked": true }
  ],
  "passes": true,
  "completedAt": "$TIMESTAMP",
  "completedBy": "opus",
  "failedAttempts": 0
}
EOF

# US-002: Pending story (passes=false, no blockedBy)
cat > "$OUTPUT_DIR/prd-json/stories/US-002.json" << EOF
{
  "id": "US-002",
  "title": "Pending feature",
  "description": "A feature still to be done",
  "priority": "high",
  "acceptanceCriteria": [
    { "text": "Criterion 1", "checked": false },
    { "text": "Criterion 2", "checked": false }
  ],
  "passes": false,
  "failedAttempts": 0
}
EOF

# US-003: Another pending story
cat > "$OUTPUT_DIR/prd-json/stories/US-003.json" << EOF
{
  "id": "US-003",
  "title": "Another pending feature",
  "description": "Another feature to do",
  "priority": "medium",
  "acceptanceCriteria": [
    { "text": "Criterion 1", "checked": false }
  ],
  "passes": false,
  "failedAttempts": 0
}
EOF

# BUG-001: Blocked story (passes=false, has blockedBy)
cat > "$OUTPUT_DIR/prd-json/stories/BUG-001.json" << EOF
{
  "id": "BUG-001",
  "title": "Blocked bug fix",
  "description": "A bug that is blocked",
  "priority": "high",
  "acceptanceCriteria": [
    { "text": "Fix the bug", "checked": false }
  ],
  "passes": false,
  "blockedBy": "Waiting for external API fix",
  "failedAttempts": 1
}
EOF

# Create progress.txt
cat > "$OUTPUT_DIR/progress.txt" << EOF
# Ralph Progress
Started: $(date)

## Iteration 1 - US-001: Completed feature
- Model: opus
- Completed successfully
EOF

echo "$OUTPUT_DIR"
