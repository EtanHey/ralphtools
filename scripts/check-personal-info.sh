#!/usr/bin/env zsh
#
# check-personal-info.sh - Uses Kiro CLI to detect personal info before pushing
#
# Usage: ./scripts/check-personal-info.sh
# Returns: 0 if clean, 1 if personal info found
#

set -e

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

cd "$REPO_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${CYAN}  🔍 Personal Info Check (Kiro CLI)${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Build content from files to check
CONTENT=""
FILE_COUNT=0

for pattern in "*.zsh" "*.md" "*.sh" "scripts/*.sh" "tests/*.sh" "skills/*.md"; do
  for file in ${~pattern}(N); do
    [[ -f "$file" ]] || continue
    [[ "$file" == *".githooks/"* ]] && continue
    [[ "$file" == "ralph-config.local" ]] && continue
    [[ "$file" == *".example" ]] && continue

    # Skip large files and binary files
    [[ $(wc -c < "$file") -gt 50000 ]] && continue

    CONTENT="${CONTENT}
=== FILE: $file ===
$(cat "$file")
"
    FILE_COUNT=$((FILE_COUNT + 1))
  done
done

if [[ $FILE_COUNT -eq 0 ]]; then
  echo "${GREEN}✓ No files to check${NC}"
  exit 0
fi

echo "Checking $FILE_COUNT files..."
echo ""

# Create temporary file with content, filtering out current working directory paths
TEMP_FILE=$(mktemp)
CURRENT_USER=$(whoami)
echo "$CONTENT" | sed "s|/Users/$CURRENT_USER|/Users/USERNAME|g" | sed "s|$CURRENT_USER|USERNAME|g" > "$TEMP_FILE"

# Run Kiro CLI with the file contents
RESULT=$(kiro-cli chat --no-interactive "You are checking code files for personal information before public release.

I will provide file contents. Check for ANY personal/private information:
- Personal names, usernames (real names or nicknames that identify a person)
- Email addresses (any @domain patterns that look real, not placeholders)
- Personal notification topics (like 'username-projectname' patterns)
- Hardcoded paths with usernames (/Users/realname/, /home/person/)
- Personal project references that identify the owner
- API keys, tokens, secrets (even if they look fake)

IGNORE (these are OK for public release):
- Placeholders like 'YOUR_USERNAME', '{project}', '{app}'
- Generic defaults like 'ralph-notifications'
- Example patterns meant for documentation
- GitHub clone URLs (git clone https://github.com/...) - these are public repo URLs
- Public attributions and credits (original concept authors, contributors)
- Example API keys in documentation (like 'sk-1234...' shown as examples)
- File paths in code comments showing example structure
- Dynamic path variables like SCRIPT_DIR, REPO_DIR that resolve at runtime

OUTPUT FORMAT - be concise:
If personal info found:
FOUND: [filename]: [brief description]
RESULT: FAIL

If clean:
RESULT: PASS

Here are the files:

$(cat "$TEMP_FILE")" 2>&1)

# Clean up
rm -f "$TEMP_FILE"

echo "$RESULT"
echo ""

# Check result
if echo "$RESULT" | grep -q "RESULT: PASS"; then
  echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${GREEN}  ✓ No personal info detected${NC}"
  echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
elif echo "$RESULT" | grep -q "RESULT: FAIL"; then
  echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${RED}  ✗ Personal info found - fix before pushing${NC}"
  echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 1
else
  echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${RED}  ✗ Could not parse result - blocking for safety${NC}"
  echo "${RED}    (Claude may have found issues but output was unclear)${NC}"
  echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 1
fi
