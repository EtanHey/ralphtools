# OpenCode Golem Instructions

> This is the equivalent of CLAUDE.md for OpenCode.
> Auto-loaded as context when OpenCode runs in this directory.

## About This Project

This is **Ralph** (claude-golem) - an autonomous AI coding loop.

Core loop:
```
while stories remain:
  spawn fresh AI -> read prd-json/ -> implement story -> review -> commit
done
```

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `ralph.zsh` | Main entry - ALL COMMANDS |
| `lib/` | Modular zsh library |
| `ralph-ui/` | React Ink dashboard |
| `bun/` | TypeScript story management |
| `skills/golem-powers/` | Skills for Claude (reference only) |
| `contexts/` | Shared context rules |
| `prd-json/` | PRD stories |

## Available Commands

Run `./ralph.zsh --help` for full list. Key ones:

| Command | Purpose |
|---------|---------|
| `ralph N` | Run N iterations |
| `ralph -G` | Gemini mode |
| `ralph -ui` | Dashboard mode |
| `ralph --prd path/` | Use specific PRD |

## JQ Escaping Workaround

Use double quotes with escaped inner quotes:
```bash
# Correct:
jq ".pending | map(select(. != \"FOO\"))" file.json

# Use jqf helper for complex filters:
jqf '.pending | map(select(. != "FOO"))' file.json -i
```

## Testing

Always run tests before committing:
```bash
./tests/test-ralph.zsh
```

## Commit Rules

- NEVER push without explicit permission
- NEVER commit unless explicitly told
- Use conventional commits: feat/fix/docs/refactor

## Skills Reference

Skills are in `skills/golem-powers/`. Key ones:
- `prd` - Create/manage PRDs
- `coderabbit` - Code review
- `commit` - Atomic commits
- `context-audit` - Verify context references

To use: Read the SKILL.md file and follow instructions.

## Files to Never Edit

- `~/.claude/*` - Claude Code config (separate system)
- `node_modules/`
- `*.lock` files (unless fixing deps)
