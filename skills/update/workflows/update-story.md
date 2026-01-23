---
name: update-story
description: Modify an existing story in the PRD
---

# Update an Existing Story

> Modify an existing story's metadata, criteria, or status. Handles both active Ralph and manual scenarios.

## Step 1: Detect Ralph Status

```bash
# Check if Ralph is running
if [[ -f /tmp/ralph_pid_* ]]; then
    echo "Ralph ACTIVE - use update.json method"
else
    echo "Ralph NOT active - use direct edit method"
fi
```

## Step 2: Identify the Story

```bash
# List all stories with their status
for f in prd-json/stories/*.json; do
    id=$(jq -r '.id' "$f")
    title=$(jq -r '.title' "$f")
    status=$(jq -r '.status' "$f")
    echo "$id [$status]: $title"
done
```

## Step 3a: Ralph Active - Use update.json

When Ralph is running, create `prd-json/update.json` with `updateStories` array:

```json
{
  "updateStories": [
    {
      "id": "US-042",
      "priority": "critical",
      "description": "Updated description with more detail",
      "acceptanceCriteria": [
        {"text": "Updated criterion 1", "checked": false},
        {"text": "New criterion added", "checked": false}
      ]
    }
  ]
}
```

**IMPORTANT:** Fields go at top level with `id` - do NOT nest under a `changes` key.

**Supported fields:**
- `title` - Story title
- `description` - Full description
- `priority` - critical/high/medium/low
- `storyPoints` - Effort estimate (1-5)
- `status` - pending/blocked
- `acceptanceCriteria` - Full replacement of criteria array
- `dependencies` - Array of story IDs this depends on
- `blockedBy` - Story ID blocking this one

**What happens:**
1. Ralph detects `update.json` at START of next iteration
2. Merges changes into existing story file
3. Recalculates stats if status changed
4. Deletes `update.json`

## Step 3b: Ralph Not Active - Direct Edit

### Edit the story file directly:

```bash
# Update a specific field
jq '.priority = "critical"' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json

# Update multiple fields
jq '.priority = "critical" | .storyPoints = 5' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json
```

### Add acceptance criteria:

```bash
# Add a new criterion
jq '.acceptanceCriteria += [{"text": "New criterion here", "checked": false}]' \
    prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json
```

### Mark criteria as checked:

```bash
# Mark first criterion as checked (0-indexed)
jq '.acceptanceCriteria[0].checked = true' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json

# Mark all criteria as checked
jq '.acceptanceCriteria |= map(.checked = true)' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json
```

### Block a story:

```bash
# Move to blocked status with reason
jq '.status = "blocked" | .blockedBy = "US-041"' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json

# Update index.json: move from pending to blocked
jq '.pending -= ["US-042"] | .blocked += ["US-042"] | .stats.pending -= 1 | .stats.blocked += 1' \
    prd-json/index.json > /tmp/index.tmp && mv /tmp/index.tmp prd-json/index.json
```

### Unblock a story:

```bash
# Remove blocked status
jq 'del(.blockedBy) | .status = "pending"' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json

# Update index.json: move from blocked to pending
jq '.blocked -= ["US-042"] | .pending += ["US-042"] | .stats.blocked -= 1 | .stats.pending += 1' \
    prd-json/index.json > /tmp/index.tmp && mv /tmp/index.tmp prd-json/index.json
```

### Mark story complete:

```bash
# Set passes to true
jq '.passes = true | .status = "completed"' prd-json/stories/US-042.json > /tmp/story.tmp \
    && mv /tmp/story.tmp prd-json/stories/US-042.json

# Update index.json: remove from pending, update stats
jq '.pending -= ["US-042"] | .stats.pending -= 1 | .stats.completed += 1' \
    prd-json/index.json > /tmp/index.tmp && mv /tmp/index.tmp prd-json/index.json
```

## Common Update Scenarios

### Scenario 1: Add Missing Criterion

```json
{
  "updateStories": [
    {
      "id": "US-042",
      "acceptanceCriteria": [
        {"text": "Existing criterion 1", "checked": true},
        {"text": "Existing criterion 2", "checked": false},
        {"text": "NEW: Additional criterion", "checked": false}
      ]
    }
  ]
}
```

### Scenario 2: Increase Priority

```json
{
  "updateStories": [
    {
      "id": "BUG-011",
      "priority": "critical",
      "description": "Escalated due to customer impact"
    }
  ]
}
```

### Scenario 3: Add Blocker

```json
{
  "updateStories": [
    {
      "id": "US-043",
      "status": "blocked",
      "blockedBy": "US-042",
      "description": "Updated: blocked until US-042 completes"
    }
  ]
}
```

### Scenario 4: Add Dependencies

```json
{
  "updateStories": [
    {
      "id": "V-012",
      "dependencies": ["US-042", "US-043"]
    }
  ]
}
```

## Validation

After updating, verify:

```bash
# Validate JSON syntax
jq empty prd-json/stories/US-042.json && echo "JSON valid"

# Check the story
jq '.' prd-json/stories/US-042.json

# Verify stats are consistent
completed=$(ls prd-json/stories/*.json | xargs -I{} jq -r 'select(.passes == true) | .id' {} | wc -l)
pending=$(jq '.pending | length' prd-json/index.json)
blocked=$(jq '.blocked | length' prd-json/index.json)
echo "Completed: $completed, Pending: $pending, Blocked: $blocked"
```

## Warning: Criteria Format

When updating `acceptanceCriteria`, always use object format:

**CORRECT:**
```json
"acceptanceCriteria": [
  {"text": "Criterion text", "checked": false}
]
```

**WRONG (breaks live progress):**
```json
"acceptanceCriteria": [
  "Criterion text"
]
```

Ralph auto-converts string criteria to objects, but it's best to use the correct format from the start.
