#!/bin/bash
#
# Explore related projects in the claude-golem ecosystem
# Usage: ./explore-related.sh [output_dir]
#
# Explores:
# - ./ralph-ui/     (React Ink dashboard)
# - ./bun/          (TypeScript story management)
# - ~/Gits/zikaron  (Vector embeddings - if exists)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${1:-$REPO_ROOT/docs.local}"

echo "=== Related Projects Explorer ==="
echo "Repo root: $REPO_ROOT"
echo "Output: $OUTPUT_DIR/"
echo ""

mkdir -p "$OUTPUT_DIR"

# ─────────────────────────────────────────────────────────────
# ralph-ui (React Ink Dashboard)
# ─────────────────────────────────────────────────────────────
if [ -d "$REPO_ROOT/ralph-ui" ]; then
    echo ">>> Exploring ralph-ui..."
    "$SCRIPT_DIR/explore.sh" "$REPO_ROOT/ralph-ui" "$OUTPUT_DIR"
else
    echo ">>> ralph-ui not found, skipping"
fi

# ─────────────────────────────────────────────────────────────
# bun/ (TypeScript story management)
# ─────────────────────────────────────────────────────────────
if [ -d "$REPO_ROOT/bun" ]; then
    echo ">>> Exploring bun/..."
    "$SCRIPT_DIR/explore.sh" "$REPO_ROOT/bun" "$OUTPUT_DIR"
else
    echo ">>> bun/ not found, skipping"
fi

# ─────────────────────────────────────────────────────────────
# zikaron (Vector embeddings - external repo)
# ─────────────────────────────────────────────────────────────
ZIKARON_PATH="$HOME/Gits/zikaron"
if [ -d "$ZIKARON_PATH" ]; then
    echo ">>> Exploring zikaron..."
    "$SCRIPT_DIR/explore.sh" "$ZIKARON_PATH" "$OUTPUT_DIR"
else
    echo ">>> zikaron not found at $ZIKARON_PATH, skipping"
fi

# ─────────────────────────────────────────────────────────────
# Summary Report
# ─────────────────────────────────────────────────────────────
SUMMARY_FILE="$OUTPUT_DIR/related-projects-summary.md"
cat > "$SUMMARY_FILE" << EOF
# Related Projects Summary

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Projects Explored

| Project | Path | Status |
|---------|------|--------|
| ralph-ui | ./ralph-ui/ | $([ -d "$REPO_ROOT/ralph-ui" ] && echo "Explored" || echo "Not found") |
| bun | ./bun/ | $([ -d "$REPO_ROOT/bun" ] && echo "Explored" || echo "Not found") |
| zikaron | ~/Gits/zikaron | $([ -d "$ZIKARON_PATH" ] && echo "Explored" || echo "Not found") |

## Output Files

\`\`\`
$(ls -la "$OUTPUT_DIR"/*-structure.md "$OUTPUT_DIR"/*-commands.md "$OUTPUT_DIR"/*-keyfiles.md 2>/dev/null || echo "No files generated")
\`\`\`

## Next Steps

1. Read the generated files
2. Compare against main project (claude-golem)
3. Identify integration points
4. Document cross-project dependencies
EOF

echo ""
echo "=== Summary ==="
cat "$SUMMARY_FILE"
