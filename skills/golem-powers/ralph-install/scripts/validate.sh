#!/bin/bash
# scripts/validate.sh
# Purpose: Validate full ralphtools installation
# Usage: bash validate.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help text
show_help() {
    echo "Usage: validate.sh [options]"
    echo ""
    echo "Options:"
    echo "  --quick     Quick check (dependencies only)"
    echo "  --json      Output as JSON"
    echo "  -h, --help  Show this help"
    echo ""
    echo "Validates:"
    echo "  - All CLI dependencies installed"
    echo "  - 1Password signed in with vault access"
    echo "  - API tokens accessible"
    echo "  - Config directories exist"
    echo "  - Skill symlinks valid"
}

QUICK=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK=true; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}ERROR: Unknown option: $1${NC}"; exit 1 ;;
    esac
done

echo -e "${BLUE}Validating ralphtools installation...${NC}"
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"

    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $name"
        ((PASS++))
    else
        echo -e "${RED}[FAIL]${NC} $name"
        ((FAIL++))
    fi
}

check_warn() {
    local name="$1"
    local cmd="$2"

    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $name"
        ((PASS++))
    else
        echo -e "${YELLOW}[WARN]${NC} $name"
        # Warnings don't count as failures
    fi
}

# Section: Core Dependencies
echo "=== Core Dependencies ==="
check "gh (GitHub CLI)" "command -v gh"
check "op (1Password CLI)" "command -v op"
check "gum (Interactive prompts)" "command -v gum"
check "fswatch (File watching)" "command -v fswatch"
check "jq (JSON processing)" "command -v jq"
check "git (Version control)" "command -v git"
echo ""

# Section: TypeScript Skills Dependencies
echo "=== TypeScript Skills Dependencies ==="
check "bun (TypeScript runtime)" "command -v bun"
check_warn "cr (CodeRabbit CLI)" "command -v cr"
echo ""

if [ "$QUICK" = true ]; then
    echo "=== Summary ==="
    echo "Passed: $PASS"
    echo "Failed: $FAIL"

    if [ $FAIL -eq 0 ]; then
        echo -e "\n${GREEN}All dependency checks passed${NC}"
        exit 0
    else
        echo -e "\n${RED}$FAIL checks failed${NC}"
        exit 1
    fi
fi

# Section: 1Password
echo "=== 1Password ==="
check "op signed in" "op account list 2>/dev/null | grep -q ."
check_warn "GitHub token accessible" "op read 'op://Private/github-token/credential' 2>/dev/null"
echo ""

# Section: Skills API Keys
echo "=== Skills API Keys (claude-golem) ==="
check_warn "Context7 API key" "op read 'op://Private/claude-golem/context7/API_KEY' 2>/dev/null | grep -q '^ctx7sk'"
check_warn "Linear API key" "op read 'op://Private/claude-golem/linear/API_KEY' 2>/dev/null | grep -vq 'PLACEHOLDER'"
echo ""

# Section: Directories
echo "=== Directories ==="
check "~/.config/ralphtools exists" "test -d ~/.config/ralphtools"
check "~/.claude/commands exists" "test -d ~/.claude/commands"
check_warn "~/.claude/CLAUDE.md exists" "test -f ~/.claude/CLAUDE.md"
check_warn "~/.claude/contexts exists" "test -d ~/.claude/contexts"
check_warn "~/.claude/contexts/base.md exists" "test -f ~/.claude/contexts/base.md"
echo ""

# Section: Skills
echo "=== Skill Symlinks ==="
check "golem-powers directory" "test -d ~/.claude/commands/golem-powers"
check "github skill" "test -e ~/.claude/commands/golem-powers/github/SKILL.md"
check "linear skill" "test -e ~/.claude/commands/golem-powers/linear/SKILL.md"
check "1password skill" "test -e ~/.claude/commands/golem-powers/1password/SKILL.md"
check "context7 skill" "test -e ~/.claude/commands/golem-powers/context7/SKILL.md"
check "coderabbit skill" "test -e ~/.claude/commands/golem-powers/coderabbit/SKILL.md"
echo ""

# Section: Ralph (optional)
echo "=== Ralph (Optional) ==="
if [ -f ~/.config/ralphtools/ralph.zsh ]; then
    check "ralph.zsh exists" "test -f ~/.config/ralphtools/ralph.zsh"
    # Can't source in subshell effectively, just check file exists
else
    echo -e "${YELLOW}[SKIP]${NC} ralph.zsh not installed"
fi
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$JSON_OUTPUT" = true ]; then
    echo ""
    echo "{"
    echo "  \"passed\": $PASS,"
    echo "  \"failed\": $FAIL,"
    echo "  \"complete\": $([ $FAIL -eq 0 ] && echo true || echo false)"
    echo "}"
fi

if [ $FAIL -eq 0 ]; then
    echo ""
    echo -e "${GREEN}SUCCESS: Installation validated${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Restart Claude Code to load skills"
    echo "  2. Test with: /golem-powers:skills"
    exit 0
else
    echo ""
    echo -e "${RED}$FAIL checks failed - see above for details${NC}"
    exit 1
fi
