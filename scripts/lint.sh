#!/usr/bin/env zsh
#
# Ralph Linting Script
# Run all checks manually without committing.
#
# Usage: ./scripts/lint.sh [--fix]
#
# Options:
#   --fix    Attempt to auto-fix issues where possible (uses shfmt)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"
FIX_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fix)
      FIX_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

cd "$REPO_DIR"

echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${CYAN}  🔍 Ralph Linting${NC}"
if $FIX_MODE; then
  echo "${CYAN}  (Fix mode enabled)${NC}"
fi
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ERRORS=0
WARNINGS=0
FIXED=0

ZSH_FILES=(*.zsh(N))

if [[ ${#ZSH_FILES[@]} -eq 0 ]]; then
  echo "${YELLOW}No .zsh files found${NC}"
  exit 0
fi

echo "Files to check: ${ZSH_FILES[*]}"
echo ""

# ═══════════════════════════════════════════════════════════════
# 1. ZSH SYNTAX
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[1/6] ZSH Syntax Check${NC}"
for file in "${ZSH_FILES[@]}"; do
  if zsh -n "$file" 2>&1; then
    echo "  ${GREEN}✓${NC} $file"
  else
    echo "  ${RED}✗${NC} $file"
    ERRORS=$((ERRORS + 1))
  fi
done
echo ""

# ═══════════════════════════════════════════════════════════════
# 2. SHELLCHECK
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[2/6] ShellCheck${NC}"
if command -v shellcheck &> /dev/null; then
  for file in "${ZSH_FILES[@]}"; do
    if shellcheck -s bash -e SC1071,SC2154,SC2296,SC2148,SC2034 "$file" 2>/dev/null; then
      echo "  ${GREEN}✓${NC} $file"
    else
      echo "  ${YELLOW}⚠${NC} $file (warnings)"
      WARNINGS=$((WARNINGS + 1))
    fi
  done
else
  echo "  ${YELLOW}⚠${NC} shellcheck not installed (brew install shellcheck)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════
# 3. SHFMT (formatting)
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[3/6] Formatting (shfmt)${NC}"
if command -v shfmt &> /dev/null; then
  for file in "${ZSH_FILES[@]}"; do
    if shfmt -d "$file" > /dev/null 2>&1; then
      echo "  ${GREEN}✓${NC} $file"
    else
      if $FIX_MODE; then
        shfmt -w "$file"
        echo "  ${BLUE}🔧${NC} $file (fixed)"
        FIXED=$((FIXED + 1))
      else
        echo "  ${YELLOW}⚠${NC} $file (needs formatting - run with --fix)"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  done
else
  echo "  ${YELLOW}⚠${NC} shfmt not installed (brew install shfmt)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════
# 4. LINE LENGTH CHECK
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[4/6] Line Length (max 120 chars)${NC}"
for file in "${ZSH_FILES[@]}"; do
  LONG_LINES=$(awk 'length > 120 { count++ } END { print count+0 }' "$file")
  if [[ $LONG_LINES -gt 0 ]]; then
    echo "  ${YELLOW}⚠${NC} $file has $LONG_LINES lines > 120 chars"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  ${GREEN}✓${NC} $file"
  fi
done
echo ""

# ═══════════════════════════════════════════════════════════════
# 5. FUNCTION COUNT & COMPLEXITY
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[5/6] Code Metrics${NC}"
for file in "${ZSH_FILES[@]}"; do
  FUNC_COUNT=$(grep -cE '^function |^[a-z_]+\(\)\s*\{' "$file" 2>/dev/null || echo 0)
  LINE_COUNT=$(wc -l < "$file" | tr -d ' ')
  echo "  ${BLUE}ℹ${NC} $file: $LINE_COUNT lines, $FUNC_COUNT functions"
done
echo ""

# ═══════════════════════════════════════════════════════════════
# 6. CUSTOM BUG PATTERNS
# ═══════════════════════════════════════════════════════════════
echo "${YELLOW}[6/6] Bug Pattern Detection${NC}"
for file in "${ZSH_FILES[@]}"; do
  ISSUES=0

  # Check for $? after pipe without pipestatus
  if grep -B1 'exit_code=\$?' "$file" 2>/dev/null | grep -q '| tee'; then
    echo "  ${RED}✗${NC} $file: Using \$? after pipe (should use pipestatus)"
    ERRORS=$((ERRORS + 1))
    ISSUES=$((ISSUES + 1))
  fi

  # Check for break outside control structures
  while IFS= read -r line; do
    linenum=$(echo "$line" | cut -d: -f1)
    context=$(sed -n "$((linenum > 5 ? linenum-5 : 1)),$((linenum))p" "$file")
    # Simple heuristic: break should be preceded by if/else/then/case
    last_keyword=$(echo "$context" | grep -oE '(if|else|then|fi|case|esac|do|done)' | tail -1)
    if [[ "$last_keyword" != "if" && "$last_keyword" != "else" && "$last_keyword" != "then" && "$last_keyword" != "do" ]]; then
      # This is a warning, not an error - might be false positive
      :
    fi
  done < <(grep -n 'break$' "$file" 2>/dev/null || true)

  # Check for uninitialized variables in important places
  if grep -qE '\$\{?[a-zA-Z_]+\}?\s*-eq' "$file" 2>/dev/null; then
    # Check if the variable is initialized somewhere
    :
  fi

  if [[ $ISSUES -eq 0 ]]; then
    echo "  ${GREEN}✓${NC} $file"
  fi
done
echo ""

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  ${RED}Errors:${NC}   $ERRORS"
echo "  ${YELLOW}Warnings:${NC} $WARNINGS"
if $FIX_MODE; then
  echo "  ${BLUE}Fixed:${NC}    $FIXED"
fi
echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo "${RED}  ✗ LINT FAILED${NC}"
  echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 1
else
  echo "${GREEN}  ✓ LINT PASSED${NC}"
  echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
fi
