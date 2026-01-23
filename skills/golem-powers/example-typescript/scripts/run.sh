#!/usr/bin/env bash
set -euo pipefail

# run.sh - Wrapper for TypeScript skill execution
# Usage: run.sh --action=xxx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Run the TypeScript file with Bun
bun run src/index.ts "$@"
