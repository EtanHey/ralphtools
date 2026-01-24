#!/bin/bash
# create-pr.sh - Push current branch and create a pull request
# Usage: ./create-pr.sh [--title "title"] [--body "body"] [--base main]

set -e

# Parse arguments
TITLE=""
BODY=""
BASE="main"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title)
            TITLE="$2"
            shift 2
            ;;
        --title=*)
            TITLE="${1#*=}"
            shift
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --body=*)
            BODY="${1#*=}"
            shift
            ;;
        --base)
            BASE="$2"
            shift 2
            ;;
        --base=*)
            BASE="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo "## Error"
    echo ""
    echo "Not in a git repository."
    exit 1
}

# Check if on protected branch
case "$CURRENT_BRANCH" in
    main|master|dev|develop)
        echo "## Warning"
        echo ""
        echo "Cannot create PR from protected branch: \`$CURRENT_BRANCH\`"
        echo ""
        echo "Please checkout a feature/fix branch first:"
        echo "\`\`\`bash"
        echo "git checkout -b feature/my-feature"
        echo "\`\`\`"
        exit 1
        ;;
esac

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "## Warning"
    echo ""
    echo "You have uncommitted changes:"
    echo ""
    echo "\`\`\`"
    git status --short
    echo "\`\`\`"
    echo ""
    echo "Please commit or stash your changes before creating a PR."
    exit 1
fi

# Check for untracked files that might be important
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -5)
if [[ -n "$UNTRACKED" ]]; then
    UNTRACKED_COUNT=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
    echo "## Note"
    echo ""
    echo "You have $UNTRACKED_COUNT untracked file(s). Make sure nothing important is missing from the commit."
    echo ""
fi

# Check if PR already exists for this branch
EXISTING_PR=$(gh pr view "$CURRENT_BRANCH" --json url,title,state 2>/dev/null) || EXISTING_PR=""

if [[ -n "$EXISTING_PR" ]]; then
    PR_URL=$(echo "$EXISTING_PR" | jq -r '.url')
    PR_TITLE=$(echo "$EXISTING_PR" | jq -r '.title')
    PR_STATE=$(echo "$EXISTING_PR" | jq -r '.state')

    echo "## Existing PR Found"
    echo ""
    echo "A pull request already exists for this branch:"
    echo ""
    echo "**Title:** $PR_TITLE"
    echo "**URL:** $PR_URL"
    echo "**State:** $PR_STATE"
    echo ""
    echo "To update the PR, just push your changes:"
    echo "\`\`\`bash"
    echo "git push"
    echo "\`\`\`"
    exit 0
fi

# Generate title from branch name if not provided
if [[ -z "$TITLE" ]]; then
    # Convert branch name to title: feature/add-login -> Add login
    # Remove prefixes like feature/, fix/, etc.
    TITLE=$(echo "$CURRENT_BRANCH" | sed -E 's/^(feature|fix|feat|bugfix|hotfix|chore|refactor)\///' | tr '-' ' ' | tr '_' ' ')
    # Capitalize first letter
    TITLE="$(echo "${TITLE:0:1}" | tr '[:lower:]' '[:upper:]')${TITLE:1}"
fi

# Generate body if not provided
if [[ -z "$BODY" ]]; then
    # Get commits that are ahead of base branch
    COMMITS=$(git log "$BASE"..HEAD --oneline 2>/dev/null | head -10) || COMMITS=""

    BODY="## Summary

<!-- Describe your changes here -->

## Changes

\`\`\`
$COMMITS
\`\`\`

## Test Plan

- [ ] Manual testing completed
- [ ] All existing tests pass

---
Generated with [Claude Code](https://claude.ai/claude-code)"
fi

# Push branch to origin
echo "## Pushing Branch"
echo ""
echo "Pushing \`$CURRENT_BRANCH\` to origin..."
echo ""

if git push -u origin HEAD 2>&1; then
    echo ""
    echo "Branch pushed successfully."
    echo ""
else
    echo ""
    echo "**Error:** Failed to push branch."
    exit 1
fi

# Create PR
echo "## Creating Pull Request"
echo ""
echo "Creating PR: \`$CURRENT_BRANCH\` -> \`$BASE\`"
echo ""

PR_URL=$(gh pr create --base "$BASE" --title "$TITLE" --body "$BODY" 2>&1) || {
    echo "**Error:** Failed to create PR"
    echo ""
    echo "\`\`\`"
    echo "$PR_URL"
    echo "\`\`\`"
    exit 1
}

# Get PR number from URL
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')

echo ""
echo "## PR Created Successfully"
echo ""
echo "**Title:** $TITLE"
echo "**URL:** $PR_URL"
echo "**Base:** $BASE <- $CURRENT_BRANCH"
echo ""
echo "### Summary"
echo ""
echo "- Pushed branch to origin"
echo "- Created PR #$PR_NUMBER"
