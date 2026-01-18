#!/usr/bin/env zsh
#
# Setup Git Hooks for Ralph
# Run this script once after cloning the repo.
#
# Usage: ./scripts/setup-hooks.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BLUE}  🔧 Ralph Git Hooks Setup${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd "$REPO_DIR"

# Configure git to use our hooks directory
echo "${YELLOW}Configuring git hooks path...${NC}"
git config core.hooksPath .githooks
echo "  ${GREEN}✓${NC} Set core.hooksPath to .githooks"

# Make hooks executable
echo ""
echo "${YELLOW}Making hooks executable...${NC}"
chmod +x .githooks/pre-commit 2>/dev/null && echo "  ${GREEN}✓${NC} pre-commit" || echo "  ${YELLOW}⚠${NC} pre-commit not found"
chmod +x .githooks/pre-push 2>/dev/null && echo "  ${GREEN}✓${NC} pre-push" || echo "  ${YELLOW}⚠${NC} pre-push not found"

# Check for recommended tools
echo ""
echo "${YELLOW}Checking recommended tools...${NC}"

if command -v shellcheck &> /dev/null; then
  SHELLCHECK_VERSION=$(shellcheck --version | head -2 | tail -1)
  echo "  ${GREEN}✓${NC} shellcheck installed ($SHELLCHECK_VERSION)"
else
  echo "  ${YELLOW}⚠${NC} shellcheck not installed"
  echo "    Install with: brew install shellcheck"
fi

if command -v shfmt &> /dev/null; then
  SHFMT_VERSION=$(shfmt --version)
  echo "  ${GREEN}✓${NC} shfmt installed ($SHFMT_VERSION)"
else
  echo "  ${YELLOW}⚠${NC} shfmt not installed (optional)"
  echo "    Install with: brew install shfmt"
fi

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}  ✓ Setup complete!${NC}"
echo ""
echo "  Hooks will now run automatically:"
echo "  • ${YELLOW}pre-commit${NC}: Runs on every commit"
echo "  • ${YELLOW}pre-push${NC}: Runs before pushing to remote"
echo ""
echo "  To run checks manually: ${CYAN}./scripts/lint.sh${NC}"
echo "  To bypass hooks: ${CYAN}git commit --no-verify${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
