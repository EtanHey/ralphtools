#!/usr/bin/env zsh
#
# check-personal-info.sh - Uses Claude Code to detect personal info before pushing
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
echo "${CYAN}  🔐 Secrets Scan (Claude Haiku)${NC}"
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

# Run Claude Haiku with the file contents directly
RESULT=$(echo "$CONTENT" | claude --print --model haiku -p "You are a security scanner checking code for SENSITIVE DATA that could compromise security.

FLAG these security risks:
- API keys, tokens, secrets (real ones like 'sk_live_...', 'ghp_...', bearer tokens)
- Passwords (actual passwords, not placeholders)
- SSN, credit card numbers, bank account numbers
- Private SSH keys, PEM file contents
- Database connection strings with real credentials
- Real file paths that expose system structure (like /Users/realname/.ssh/, /home/user/.config/secrets/)
- Internal network IPs, server hostnames that reveal infrastructure

DO NOT FLAG (these are SAFE):
- Author names, usernames, GitHub usernames (attribution is normal)
- Notification topic names (etans-projectClaude is just an identifier)
- Project paths in COMMENTS or DOCUMENTATION showing examples
- Paths inside the repo itself (./scripts/, ./tests/)
- Example/placeholder values (YOUR_KEY_HERE, sk-1234...)
- Public clone URLs (github.com/...)
- Credits sections, personal branding

KEY DISTINCTION for paths:
- FLAG: Real paths to sensitive dirs like ~/.ssh, ~/.aws, ~/.config/secrets
- OK: Project paths in docs showing structure, /Users/name/Desktop/Gits/reponame is fine (just shows where repo lives)

The goal is SECURITY - preventing actual exploitation, not anonymity.

OUTPUT FORMAT - be very concise:
If security risks found:
FOUND: [filename]: [brief description of risk]
RESULT: FAIL

If clean:
RESULT: PASS

Here are the files:" 2>&1)

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
