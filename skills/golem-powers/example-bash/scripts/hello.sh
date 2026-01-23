#!/usr/bin/env bash
set -euo pipefail

# hello.sh - Example bash skill script
# Demonstrates Pattern A: simple bash execution

echo "## Example Bash Skill"
echo ""
echo "This skill executed successfully!"
echo ""

# Show some useful context
echo "### Context"
echo ""
echo "| Info | Value |"
echo "|------|-------|"
echo "| Timestamp | $(date '+%Y-%m-%d %H:%M:%S') |"
echo "| Working Directory | $(pwd) |"

# Show git info if available
if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    echo "| Git Branch | $branch |"
fi

echo ""
echo "### How This Works"
echo ""
echo "1. You invoked \`/golem-powers:example-bash\`"
echo "2. Claude loaded \`SKILL.md\` and saw \`execute: scripts/hello.sh\`"
echo "3. Claude ran this script via Bash"
echo "4. This Markdown output was returned"
echo ""
echo "### Pattern A: Bash"
echo ""
echo "This is the simplest skill pattern:"
echo ""
echo "- No dependencies"
echo "- Direct bash execution"
echo "- Markdown output"
echo "- Exit code indicates success/failure"
echo ""
echo "To create your own: \`/golem-powers:writing-skills\`"
