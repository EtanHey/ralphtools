#!/usr/bin/env bash
# Setup CodeRabbit as a pre-commit hook
# Usage: ./setup-coderabbit-hook.sh [project-dir]

set -euo pipefail

PROJECT_DIR="${1:-.}"
HOOKS_DIR="$PROJECT_DIR/.git/hooks"

# Check if git repo
if [[ ! -d "$PROJECT_DIR/.git" ]]; then
  echo "❌ Not a git repository: $PROJECT_DIR"
  exit 1
fi

# Check if CodeRabbit CLI installed
if ! command -v cr &>/dev/null; then
  echo "❌ CodeRabbit CLI not found"
  echo "   Install: npm install -g coderabbit"
  exit 1
fi

# Create hooks directory if needed
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# CodeRabbit pre-commit hook
# Runs AI code review on staged changes

set -euo pipefail

# Skip if no staged changes
if git diff --cached --quiet; then
  exit 0
fi

# Skip if CR_SKIP is set (for emergency commits)
if [[ "${CR_SKIP:-}" == "1" ]]; then
  echo "⚠️  Skipping CodeRabbit (CR_SKIP=1)"
  exit 0
fi

echo "🐰 Running CodeRabbit review..."

# Run CodeRabbit on staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

# Create temp file for review output
REVIEW_OUTPUT=$(mktemp)
trap "rm -f $REVIEW_OUTPUT" EXIT

# Run review
if cr review --staged > "$REVIEW_OUTPUT" 2>&1; then
  # Check for critical/high issues
  if grep -qiE "(CRITICAL|HIGH)" "$REVIEW_OUTPUT"; then
    echo ""
    echo "❌ CodeRabbit found issues:"
    echo "────────────────────────────────────────"
    cat "$REVIEW_OUTPUT"
    echo "────────────────────────────────────────"
    echo ""
    echo "Fix issues and try again, or skip with: CR_SKIP=1 git commit"
    exit 1
  fi

  # Show review if any output
  if [[ -s "$REVIEW_OUTPUT" ]]; then
    echo "✅ CodeRabbit review passed"
    grep -iE "(MEDIUM|LOW|INFO)" "$REVIEW_OUTPUT" 2>/dev/null || true
  fi
else
  echo "⚠️  CodeRabbit review failed (continuing anyway)"
  cat "$REVIEW_OUTPUT" 2>/dev/null || true
fi

exit 0
HOOK

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ CodeRabbit pre-commit hook installed"
echo "   Location: $HOOKS_DIR/pre-commit"
echo ""
echo "   To skip for a single commit: CR_SKIP=1 git commit"
echo "   To uninstall: rm $HOOKS_DIR/pre-commit"
