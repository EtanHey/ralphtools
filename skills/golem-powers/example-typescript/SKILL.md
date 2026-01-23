---
name: example-typescript
description: Example TypeScript skill demonstrating Pattern B (Bun runtime with actions)
execute: scripts/run.sh --action=default
---

# Example TypeScript Skill

> Demonstrates the TypeScript/Bun pattern for golem-powers skills.

This is a working example of **Pattern B** - a TypeScript skill using Bun runtime with action-based CLI.

## What It Does

When you invoke `/golem-powers:example-typescript`, the script runs with `--action=default` and outputs:

1. Action being executed
2. Runtime information (Bun version, etc.)
3. Example of structured data processing
4. A demonstration of TypeScript capabilities

## Actions

| Action | Description |
|--------|-------------|
| `--action=default` | Show skill info and demo |
| `--action=random` | Generate random data |
| `--action=env` | Show environment info |

## Usage

Default action runs automatically when loaded.

To run specific actions manually:

```bash
bash ~/.claude/commands/golem-powers/example-typescript/scripts/run.sh --action=random
bash ~/.claude/commands/golem-powers/example-typescript/scripts/run.sh --action=env
```

## Why Use TypeScript Pattern?

Choose TypeScript (Pattern B) when your skill:

- Has complex business logic
- Needs type safety
- Makes API calls or handles async operations
- Processes structured data (JSON, etc.)
- Benefits from npm ecosystem

## Requirements

- Bun runtime: `brew install oven-sh/bun/bun`

## See Also

- [example-bash](../example-bash/) - For simple script pattern
- [writing-skills](../writing-skills/) - Meta-skill for creating new skills
