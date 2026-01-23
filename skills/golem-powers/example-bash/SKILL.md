---
name: example-bash
description: Example bash skill demonstrating Pattern A (simple bash script execution)
execute: scripts/hello.sh
---

# Example Bash Skill

> Demonstrates the bash script pattern for golem-powers skills.

This is a working example of **Pattern A** - a simple bash skill that executes immediately when loaded.

## What It Does

When you invoke `/golem-powers:example-bash`, the script `scripts/hello.sh` runs automatically and outputs:

1. Current timestamp
2. Working directory
3. Git branch (if in a repo)
4. A friendly message

## Usage

This skill runs automatically when loaded. No additional input needed.

## Why Use Bash Pattern?

Choose bash (Pattern A) when your skill:

- Wraps existing CLI tools
- Needs no external dependencies
- Has simple, linear logic
- Outputs text/Markdown directly

## See Also

- [example-typescript](../example-typescript/) - For complex logic pattern
- [writing-skills](../writing-skills/) - Meta-skill for creating new skills
