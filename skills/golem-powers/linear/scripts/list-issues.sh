#!/bin/bash
# scripts/list-issues.sh
# Purpose: List and search issues in Linear via GraphQL API
# Usage: bash list-issues.sh [options]

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
    echo "Usage: list-issues.sh [options]"
    echo ""
    echo "Modes:"
    echo "  (default)           List first 50 issues"
    echo "  --my                List issues assigned to you"
    echo "  --team TEAM_ID      List issues for a specific team"
    echo "  --search \"query\"    Search issues by title/description"
    echo "  --issue ID          Get single issue by identifier (e.g., ENG-123)"
    echo "  --teams             List all teams (to get team IDs)"
    echo "  --labels            List all labels (to get label IDs)"
    echo "  --users             List all users (to get user IDs)"
    echo ""
    echo "Filters (combine with modes):"
    echo "  --state \"name\"      Filter by state name (e.g., \"In Progress\")"
    echo "  --priority N        Filter by priority (1=Urgent, 2=High, 3=Medium, 4=Low)"
    echo "  --label \"name\"      Filter by label name"
    echo "  --limit N           Limit results (default: 50)"
    echo ""
    echo "Output:"
    echo "  --compact           Compact table format"
    echo "  --json              Raw JSON output"
    echo ""
    echo "Examples:"
    echo "  bash list-issues.sh --my"
    echo "  bash list-issues.sh --team abc123 --state \"In Progress\""
    echo "  bash list-issues.sh --search \"login bug\" --compact"
    echo "  bash list-issues.sh --issue ENG-123"
}

# Parse arguments
MODE="all"
TEAM_ID=""
SEARCH_QUERY=""
ISSUE_ID=""
STATE_FILTER=""
PRIORITY_FILTER=""
LABEL_FILTER=""
LIMIT=50
OUTPUT="pretty"

while [[ $# -gt 0 ]]; do
    case $1 in
        --my) MODE="my"; shift ;;
        --team) MODE="team"; TEAM_ID="$2"; shift 2 ;;
        --search) MODE="search"; SEARCH_QUERY="$2"; shift 2 ;;
        --issue) MODE="single"; ISSUE_ID="$2"; shift 2 ;;
        --teams) MODE="teams"; shift ;;
        --labels) MODE="labels"; shift ;;
        --users) MODE="users"; shift ;;
        --state) STATE_FILTER="$2"; shift 2 ;;
        --priority) PRIORITY_FILTER="$2"; shift 2 ;;
        --label) LABEL_FILTER="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --compact) OUTPUT="compact"; shift ;;
        --json) OUTPUT="json"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}ERROR: Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# Get Linear API key from 1Password
LINEAR_KEY=$(op read "op://Private/linear/api-key" 2>/dev/null) || {
    echo -e "${RED}ERROR: Linear API key not found in 1Password${NC}"
    echo ""
    echo "Add it with:"
    echo "  op item create --category \"API Credential\" --title \"linear\" --vault \"Private\" \"api-key=lin_api_...\""
    exit 1
}

# Execute query based on mode
case $MODE in
    teams)
        echo -e "${BLUE}Fetching teams...${NC}"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data '{"query": "{ teams { nodes { id name } } }"}' \
            https://api.linear.app/graphql)
        echo "$RESPONSE" | jq '.data.teams.nodes'
        exit 0
        ;;
    labels)
        echo -e "${BLUE}Fetching labels...${NC}"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data '{"query": "{ issueLabels { nodes { id name color } } }"}' \
            https://api.linear.app/graphql)
        echo "$RESPONSE" | jq '.data.issueLabels.nodes'
        exit 0
        ;;
    users)
        echo -e "${BLUE}Fetching users...${NC}"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data '{"query": "{ users { nodes { id name email } } }"}' \
            https://api.linear.app/graphql)
        echo "$RESPONSE" | jq '.data.users.nodes'
        exit 0
        ;;
    single)
        echo -e "${BLUE}Fetching issue $ISSUE_ID...${NC}"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{
                \"query\": \"query GetIssue(\$id: String!) { issue(id: \$id) { id identifier title description state { name } priority assignee { name } labels { nodes { name } } comments { nodes { body user { name } createdAt } } url createdAt updatedAt branchName } }\",
                \"variables\": { \"id\": \"$ISSUE_ID\" }
            }" \
            https://api.linear.app/graphql)

        if echo "$RESPONSE" | jq -e '.data.issue == null' > /dev/null 2>&1; then
            echo -e "${RED}ERROR: Issue $ISSUE_ID not found${NC}"
            exit 1
        fi

        echo "$RESPONSE" | jq '.data.issue'
        exit 0
        ;;
    my)
        echo -e "${BLUE}Fetching your assigned issues...${NC}"
        QUERY="{ viewer { assignedIssues(first: $LIMIT) { nodes { identifier title state { name } priority dueDate url } } } }"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{\"query\": \"$QUERY\"}" \
            https://api.linear.app/graphql)
        ISSUES=$(echo "$RESPONSE" | jq '.data.viewer.assignedIssues.nodes')
        ;;
    team)
        if [ -z "$TEAM_ID" ]; then
            echo -e "${RED}ERROR: --team requires a team ID${NC}"
            echo "Run: bash list-issues.sh --teams"
            exit 1
        fi
        echo -e "${BLUE}Fetching team issues...${NC}"
        QUERY="query TeamIssues(\$teamId: String!) { team(id: \$teamId) { issues(first: $LIMIT) { nodes { identifier title state { name } priority assignee { name } url } } } }"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{\"query\": \"$QUERY\", \"variables\": {\"teamId\": \"$TEAM_ID\"}}" \
            https://api.linear.app/graphql)
        ISSUES=$(echo "$RESPONSE" | jq '.data.team.issues.nodes')
        ;;
    search)
        if [ -z "$SEARCH_QUERY" ]; then
            echo -e "${RED}ERROR: --search requires a query${NC}"
            exit 1
        fi
        echo -e "${BLUE}Searching issues for \"$SEARCH_QUERY\"...${NC}"
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{
                \"query\": \"query SearchIssues(\$query: String!) { issueSearch(query: \$query, first: $LIMIT) { nodes { identifier title state { name } priority url } } }\",
                \"variables\": { \"query\": \"$SEARCH_QUERY\" }
            }" \
            https://api.linear.app/graphql)
        ISSUES=$(echo "$RESPONSE" | jq '.data.issueSearch.nodes')
        ;;
    all)
        echo -e "${BLUE}Fetching all issues...${NC}"

        # Build filter if specified
        FILTER=""
        if [ -n "$STATE_FILTER" ]; then
            FILTER="filter: { state: { name: { eq: \\\"$STATE_FILTER\\\" } } }"
        elif [ -n "$PRIORITY_FILTER" ]; then
            FILTER="filter: { priority: { eq: $PRIORITY_FILTER } }"
        elif [ -n "$LABEL_FILTER" ]; then
            FILTER="filter: { labels: { name: { eq: \\\"$LABEL_FILTER\\\" } } }"
        fi

        if [ -n "$FILTER" ]; then
            QUERY="{ issues(first: $LIMIT, $FILTER) { nodes { identifier title state { name } priority assignee { name } url } } }"
        else
            QUERY="{ issues(first: $LIMIT) { nodes { identifier title state { name } priority assignee { name } url } } }"
        fi

        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_KEY" \
            --data "{\"query\": \"$QUERY\"}" \
            https://api.linear.app/graphql)
        ISSUES=$(echo "$RESPONSE" | jq '.data.issues.nodes')
        ;;
esac

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo -e "${RED}ERROR: GraphQL error${NC}"
    echo "$RESPONSE" | jq '.errors'
    exit 1
fi

# Output results
COUNT=$(echo "$ISSUES" | jq 'length')
echo -e "${GREEN}SUCCESS: Found $COUNT issues${NC}"
echo ""

case $OUTPUT in
    json)
        echo "$ISSUES"
        ;;
    compact)
        echo "$ISSUES" | jq -r '.[] | "\(.identifier)\t\(.state.name // "?")\t\(.title)"' | column -t -s $'\t'
        ;;
    pretty)
        echo "$ISSUES" | jq '.'
        ;;
esac
