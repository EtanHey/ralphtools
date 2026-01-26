#!/bin/bash
# scripts/create-issue.sh
# Purpose: Create a new issue in Linear via GraphQL API
# Usage: bash create-issue.sh --team TEAM_ID --title "Title" [options]

set -e

# REQUIRED: Self-detect script location (works from any cwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help text
show_help() {
    echo "Usage: create-issue.sh [options]"
    echo ""
    echo "Required:"
    echo "  --team TEAM_ID      Team ID to create issue in"
    echo "  --title \"Title\"     Issue title"
    echo ""
    echo "Optional:"
    echo "  --description TEXT  Issue description"
    echo "  --priority N        Priority: 0=None, 1=Urgent, 2=High, 3=Medium, 4=Low"
    echo "  --labels ID,ID      Comma-separated label IDs"
    echo "  --assignee USER_ID  Assignee user ID"
    echo "  --parent ISSUE_ID   Parent issue ID for sub-issues"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Example:"
    echo "  bash create-issue.sh --team abc123 --title \"Fix login bug\" --priority 2"
}

# Parse arguments
TEAM_ID=""
TITLE=""
DESCRIPTION=""
PRIORITY=""
LABELS=""
ASSIGNEE=""
PARENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --team) TEAM_ID="$2"; shift 2 ;;
        --title) TITLE="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --priority) PRIORITY="$2"; shift 2 ;;
        --labels) LABELS="$2"; shift 2 ;;
        --assignee) ASSIGNEE="$2"; shift 2 ;;
        --parent) PARENT="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}ERROR: Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# Validate required fields
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}ERROR: --team is required${NC}"
    echo ""
    echo "To list available teams, run:"
    echo "  bash list-issues.sh --teams"
    exit 1
fi

if [ -z "$TITLE" ]; then
    echo -e "${RED}ERROR: --title is required${NC}"
    exit 1
fi

# Get Linear API key from 1Password
echo -e "${BLUE}Loading Linear API key from 1Password...${NC}"
LINEAR_KEY=$(op read "op://Private/linear/api-key" 2>/dev/null) || {
    echo -e "${RED}ERROR: Linear API key not found in 1Password${NC}"
    echo ""
    echo "Add it with:"
    echo "  op item create --category \"API Credential\" --title \"linear\" --vault \"Private\" \"api-key=lin_api_...\""
    exit 1
}

# Build input JSON
INPUT="{\"teamId\": \"$TEAM_ID\", \"title\": \"$TITLE\""

if [ -n "$DESCRIPTION" ]; then
    INPUT="$INPUT, \"description\": \"$DESCRIPTION\""
fi

if [ -n "$PRIORITY" ]; then
    INPUT="$INPUT, \"priority\": $PRIORITY"
fi

if [ -n "$LABELS" ]; then
    # Convert comma-separated to JSON array
    LABELS_JSON=$(echo "$LABELS" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
    INPUT="$INPUT, \"labelIds\": $LABELS_JSON"
fi

if [ -n "$ASSIGNEE" ]; then
    INPUT="$INPUT, \"assigneeId\": \"$ASSIGNEE\""
fi

if [ -n "$PARENT" ]; then
    INPUT="$INPUT, \"parentId\": \"$PARENT\""
fi

INPUT="$INPUT}"

# Create issue via GraphQL
echo -e "${BLUE}Creating issue...${NC}"

RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: $LINEAR_KEY" \
    --data "{
        \"query\": \"mutation CreateIssue(\$input: IssueCreateInput!) { issueCreate(input: \$input) { success issue { id identifier title priority url } } }\",
        \"variables\": { \"input\": $INPUT }
    }" \
    https://api.linear.app/graphql)

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo -e "${RED}ERROR: GraphQL error${NC}"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueCreate.success')
if [ "$SUCCESS" != "true" ]; then
    echo -e "${RED}ERROR: Issue creation failed${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

# Extract issue details
IDENTIFIER=$(echo "$RESPONSE" | jq -r '.data.issueCreate.issue.identifier')
URL=$(echo "$RESPONSE" | jq -r '.data.issueCreate.issue.url')

echo -e "${GREEN}SUCCESS: Issue created${NC}"
echo ""
echo "  Identifier: $IDENTIFIER"
echo "  URL: $URL"
echo ""
echo "$RESPONSE" | jq '.data.issueCreate.issue'
