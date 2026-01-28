#!/bin/bash
# tests/fixtures/context-audit/generate-fixtures.sh
# Purpose: Generate test fixtures for context-audit script testing
# Usage: bash generate-fixtures.sh <output-dir> <scenario>
#
# Scenarios:
#   nextjs - Next.js project with package.json
#   react-native - React Native/Expo project
#   monorepo - Monorepo with packages/ui
#   supabase - Project with supabase/ directory
#   full-stack - Project with all tech stacks
#   empty - Minimal project with no CLAUDE.md
#   with-contexts - Project with @context: refs in CLAUDE.md
#   missing-setup - Project with contexts but no setup header

set -e

OUTPUT_DIR="${1:-$(mktemp -d)}"
SCENARIO="${2:-nextjs}"

mkdir -p "$OUTPUT_DIR"

# Create mock contexts directory (simulates ~/.claude/contexts)
MOCK_CONTEXTS="$OUTPUT_DIR/.mock-contexts"
mkdir -p "$MOCK_CONTEXTS/tech" "$MOCK_CONTEXTS/workflow"

# Create available context files
echo "# Base context" > "$MOCK_CONTEXTS/base.md"
echo "# Skill index" > "$MOCK_CONTEXTS/skill-index.md"
echo "# Next.js context" > "$MOCK_CONTEXTS/tech/nextjs.md"
echo "# React Native context" > "$MOCK_CONTEXTS/tech/react-native.md"
echo "# Supabase context" > "$MOCK_CONTEXTS/tech/supabase.md"
echo "# Convex context" > "$MOCK_CONTEXTS/tech/convex.md"
echo "# RTL workflow" > "$MOCK_CONTEXTS/workflow/rtl.md"
echo "# i18n workflow" > "$MOCK_CONTEXTS/workflow/i18n.md"
echo "# Interactive workflow" > "$MOCK_CONTEXTS/workflow/interactive.md"
echo "# Testing workflow" > "$MOCK_CONTEXTS/workflow/testing.md"
echo "# Design system" > "$MOCK_CONTEXTS/workflow/design-system.md"

# Create project directory
PROJECT_DIR="$OUTPUT_DIR/project"
mkdir -p "$PROJECT_DIR"

case "$SCENARIO" in
    nextjs)
        # Next.js project
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-nextjs",
  "dependencies": {
    "next": "14.0.0",
    "react": "18.0.0"
  }
}
EOF
        mkdir -p "$PROJECT_DIR/src/components"
        touch "$PROJECT_DIR/src/components/Button.tsx"
        ;;

    react-native)
        # React Native / Expo project
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-rn-app",
  "dependencies": {
    "react-native": "0.72.0",
    "expo": "49.0.0"
  }
}
EOF
        ;;

    monorepo)
        # Monorepo with packages/ui
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-monorepo",
  "workspaces": ["packages/*", "apps/*"]
}
EOF
        mkdir -p "$PROJECT_DIR/packages/ui/src"
        touch "$PROJECT_DIR/packages/ui/src/index.ts"

        # Create nested package.json with React Native
        mkdir -p "$PROJECT_DIR/apps/mobile"
        cat > "$PROJECT_DIR/apps/mobile/package.json" << 'EOF'
{
  "name": "mobile",
  "dependencies": {
    "react-native": "0.72.0"
  }
}
EOF
        ;;

    supabase)
        # Project with Supabase
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-supabase",
  "dependencies": {
    "next": "14.0.0"
  }
}
EOF
        mkdir -p "$PROJECT_DIR/supabase/migrations"
        touch "$PROJECT_DIR/supabase/config.toml"
        ;;

    full-stack)
        # Full stack project with everything
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-full-stack",
  "dependencies": {
    "next": "14.0.0",
    "react-native": "0.72.0"
  }
}
EOF
        mkdir -p "$PROJECT_DIR/supabase"
        mkdir -p "$PROJECT_DIR/convex"
        mkdir -p "$PROJECT_DIR/src/components"
        mkdir -p "$PROJECT_DIR/tests"
        ;;

    empty)
        # Minimal project - no CLAUDE.md, basic package.json
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-empty",
  "dependencies": {}
}
EOF
        # No CLAUDE.md
        ;;

    with-contexts)
        # Project with @context: refs in CLAUDE.md
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-with-contexts",
  "dependencies": {
    "next": "14.0.0"
  }
}
EOF
        mkdir -p "$PROJECT_DIR/src/components"

        cat > "$PROJECT_DIR/CLAUDE.md" << 'EOF'
# Test Project

## SETUP (AI: Read This First)

This is a test project with contexts already configured.

## Contexts

@context: base
@context: skill-index
@context: tech/nextjs
@context: workflow/interactive
@context: workflow/design-system
EOF
        ;;

    missing-setup)
        # Project with contexts but missing setup header
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-missing-setup",
  "dependencies": {
    "next": "14.0.0"
  }
}
EOF

        cat > "$PROJECT_DIR/CLAUDE.md" << 'EOF'
# Test Project

Just some documentation.

## Contexts

@context: base
@context: skill-index
EOF
        ;;

    partial-contexts)
        # Has some contexts but missing others
        cat > "$PROJECT_DIR/package.json" << 'EOF'
{
  "name": "test-partial",
  "dependencies": {
    "next": "14.0.0"
  }
}
EOF
        mkdir -p "$PROJECT_DIR/supabase"

        cat > "$PROJECT_DIR/CLAUDE.md" << 'EOF'
# Test Project

## SETUP (AI: Read This First)

Test project.

## Contexts

@context: base
EOF
        # Missing: skill-index, tech/nextjs, tech/supabase, workflow/interactive
        ;;

    *)
        echo "Unknown scenario: $SCENARIO"
        exit 1
        ;;
esac

# Return paths for test to use
echo "MOCK_CONTEXTS=$MOCK_CONTEXTS"
echo "PROJECT_DIR=$PROJECT_DIR"
