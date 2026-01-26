#!/bin/bash
# scripts/create-worktree.sh
# Purpose: Create a git worktree from a Linear issue using Linear's auto-generated branch name
# Usage: bash create-worktree.sh ISSUE_ID [--path PATH] [--update-state]

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
    echo "Usage: create-worktree.sh ISSUE_ID [options]"
    echo ""
    echo "Arguments:"
    echo "  ISSUE_ID              Linear issue identifier (e.g., ENG-123)"
    echo ""
    echo "Options:"
    echo "  --path PATH           Custom worktree path (default: ../PROJECT-ISSUE_ID)"
    echo "  --update-state        Also update issue to 'In Progress'"
    echo "  --branch-format FMT   Branch format: 'linear' (default), 'feat', 'fix'"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Branch formats:"
    echo "  linear    Use Linear's auto-generated branch name"
    echo "  feat      feat/ISSUE_ID-sanitized-title"
    echo "  fix       fix/ISSUE_ID-sanitized-title"
    echo ""
    echo "Examples:"
    echo "  bash create-worktree.sh ENG-123"
    echo "  bash create-worktree.sh ENG-123 --update-state"
    echo "  bash create-worktree.sh ENG-123 --branch-format feat"
}

# Parse arguments
ISSUE_ID=""
CUSTOM_PATH=""
UPDATE_STATE=false
BRANCH_FORMAT="linear"

while [[ $# -gt 0 ]]; do
    case $1 in
        --path) CUSTOM_PATH="$2"; shift 2 ;;
        --update-state) UPDATE_STATE=true; shift ;;
        --branch-format) BRANCH_FORMAT="$2"; shift 2 ;;
        -h|--help) show_help; exit 0 ;;
        -*) echo -e "${RED}ERROR: Unknown option: $1${NC}"; show_help; exit 1 ;;
        *)
            if [ -z "$ISSUE_ID" ]; then
                ISSUE_ID="$1"
            else
                echo -e "${RED}ERROR: Unexpected argument: $1${NC}"
                exit 1
            fi
            shift ;;
    esac
done

# Validate issue ID
if [ -z "$ISSUE_ID" ]; then
    echo -e "${RED}ERROR: Issue ID is required${NC}"
    echo ""
    show_help
    exit 1
fi

# Check we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Not in a git repository${NC}"
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

# Fetch issue details
echo -e "${BLUE}Fetching issue $ISSUE_ID from Linear...${NC}"
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: $LINEAR_KEY" \
    --data "{
        \"query\": \"query GetIssue(\$id: String!) { issue(id: \$id) { id identifier title branchName } }\",
        \"variables\": { \"id\": \"$ISSUE_ID\" }
    }" \
    https://api.linear.app/graphql)

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo -e "${RED}ERROR: GraphQL error${NC}"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

# Extract fields
IDENTIFIER=$(echo "$RESPONSE" | jq -r '.data.issue.identifier')
TITLE=$(echo "$RESPONSE" | jq -r '.data.issue.title')
LINEAR_BRANCH=$(echo "$RESPONSE" | jq -r '.data.issue.branchName')
ISSUE_UUID=$(echo "$RESPONSE" | jq -r '.data.issue.id')

if [ "$IDENTIFIER" = "null" ]; then
    echo -e "${RED}ERROR: Issue $ISSUE_ID not found${NC}"
    exit 1
fi

echo -e "  Issue: ${GREEN}$IDENTIFIER${NC} - $TITLE"

# Determine branch name based on format
case $BRANCH_FORMAT in
    linear)
        if [ "$LINEAR_BRANCH" = "null" ] || [ -z "$LINEAR_BRANCH" ]; then
            echo -e "${YELLOW}WARNING: Linear's branchName is empty, generating one${NC}"
            SANITIZED=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 40)
            BRANCH_NAME="$(echo "$IDENTIFIER" | tr '[:upper:]' '[:lower:]')-$SANITIZED"
        else
            BRANCH_NAME="$LINEAR_BRANCH"
        fi
        ;;
    feat)
        SANITIZED=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 30)
        BRANCH_NAME="feat/$IDENTIFIER-$SANITIZED"
        ;;
    fix)
        SANITIZED=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 30)
        BRANCH_NAME="fix/$IDENTIFIER-$SANITIZED"
        ;;
    *)
        echo -e "${RED}ERROR: Unknown branch format: $BRANCH_FORMAT${NC}"
        exit 1
        ;;
esac

echo -e "  Branch: ${BLUE}$BRANCH_NAME${NC}"

# Determine worktree path
PROJECT_NAME=$(basename "$(pwd)")
if [ -n "$CUSTOM_PATH" ]; then
    WORKTREE_PATH="$CUSTOM_PATH"
else
    WORKTREE_PATH="../${PROJECT_NAME}-${IDENTIFIER}"
fi

echo -e "  Path: ${BLUE}$WORKTREE_PATH${NC}"
echo ""

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo -e "${YELLOW}Branch already exists, checking out without -b flag${NC}"
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
    echo -e "${BLUE}Creating new worktree with branch...${NC}"
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

# Optionally update issue state to "In Progress"
if [ "$UPDATE_STATE" = true ]; then
    echo ""
    echo -e "${BLUE}Updating issue state to 'In Progress'...${NC}"

    # Get "In Progress" state ID
    STATES=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_KEY" \
        --data '{"query": "{ workflowStates(filter: { type: { eq: \"started\" } }) { nodes { id name } } }"}' \
        https://api.linear.app/graphql)

    STATE_ID=$(echo "$STATES" | jq -r '.data.workflowStates.nodes[0].id')
    STATE_NAME=$(echo "$STATES" | jq -r '.data.workflowStates.nodes[0].name')

    if [ "$STATE_ID" != "null" ] && [ -n "$STATE_ID" ]; then
        UPDATE_RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{
                \"query\": \"mutation UpdateIssue(\$id: String!, \$input: IssueUpdateInput!) { issueUpdate(id: \$id, input: \$input) { success } }\",
                \"variables\": {
                    \"id\": \"$ISSUE_UUID\",
                    \"input\": { \"stateId\": \"$STATE_ID\" }
                }
            }" \
            https://api.linear.app/graphql)

        if echo "$UPDATE_RESPONSE" | jq -e '.data.issueUpdate.success == true' > /dev/null 2>&1; then
            echo -e "${GREEN}Issue updated to '$STATE_NAME'${NC}"
        else
            echo -e "${YELLOW}WARNING: Could not update issue state${NC}"
        fi
    else
        echo -e "${YELLOW}WARNING: Could not find 'started' workflow state${NC}"
    fi
fi

echo ""
echo -e "${GREEN}SUCCESS: Worktree created${NC}"
echo ""
echo "To start working:"
echo "  cd $WORKTREE_PATH"
echo ""
echo "When done:"
echo "  git worktree remove \"$WORKTREE_PATH\""
