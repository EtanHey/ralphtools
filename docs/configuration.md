# Configuration Reference

## Personal Config File

Copy `ralph-config.local.example` to `ralph-config.local` and customize:

```bash
cp ~/.config/ralph/ralph-config.local.example ~/.config/ralph/ralph-config.local
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_NTFY_PREFIX` | Prefix for per-project topics | `etanheys-ralph` |
| `RALPH_NTFY_TOPIC` | Override topic (bypasses per-project) | (none) |
| `CLAUDE_NTFY_TOPIC` | Claude's notification topic | `etanheys-ralphclaude-notify` |
| `RALPH_DEFAULT_MODEL` | Default model | `opus` |
| `RALPH_MAX_ITERATIONS` | Default iteration limit | `10` |
| `RALPH_SLEEP_SECONDS` | Seconds between iterations | `2` |
| `RALPH_VALID_APPS` | Valid app names (space-separated) | `frontend backend mobile expo public admin` |

## File Structure

```
~/.config/ralph/
├── ralph.zsh                   # Main script (source this)
├── ralph-config.local          # Your personal config (gitignored)
├── ralph-config.local.example  # Config template
├── skills/
│   ├── prd.md                  # /prd command
│   └── critique-waves.md
├── configs/                    # Rule configs (RTL, modals, etc.)
├── scripts/                    # Helper scripts
├── tests/                      # Test scripts
└── .githooks/                  # Pre-commit hooks
```

## Notifications

Enable with `-QN` flag. Uses [ntfy.sh](https://ntfy.sh) for push notifications.

Configure in `ralph-config.local`:
```bash
# Per-project topics (default): etanheys-ralph-{project}-notify
export RALPH_NTFY_PREFIX="etanheys-ralph"

# Or override with fixed topic:
export RALPH_NTFY_TOPIC="my-custom-topic"

# Claude notifications (separate from Ralph):
export CLAUDE_NTFY_TOPIC="etanheys-ralphclaude-notify"
```

See [docs/notifications.md](notifications.md) for full details.

Notifications sent:
- Iteration complete (with remaining task count)
- All tasks complete
- All tasks blocked
- Max iterations reached

## App-Specific Mode (Monorepos)

```bash
ralph frontend 30    # apps/frontend/prd-json/
ralph backend 30     # apps/backend/prd-json/
ralph mobile 30      # apps/mobile/prd-json/
```

Features:
- Auto-creates/switches to `feat/<app>-work` branch
- Uses app-specific PRD path
- Returns to original branch when done

Configure valid app names:
```bash
export RALPH_VALID_APPS="frontend backend mobile expo"
```

## Debug Output Auditing

To check for unguarded debug output in `ralph.zsh`:

```bash
# Find potential debug echo statements that might leak to terminal
# (Excludes echo | awk/cut pipes which are legitimate parsing, not debug output)
grep -En '^\s*echo.*debug|^\s*echo.*DEBUG|^\s*echo.*remaining' ralph.zsh | grep -v '/dev/null' | grep -v '>> /tmp' | grep -v 'echo "\$'

# Count noxtrace guards in ralph.zsh (should be 10+)
grep -c 'noxtrace' ralph.zsh
```

**Rules for debug output:**
- All debug echo statements must be guarded with `[[ "$RALPH_DEBUG" == "true" ]]`
- Or redirected to log file: `>> /tmp/ralph-debug.log`
- Add comment `# DEBUG OUTPUT - guard with RALPH_DEBUG` above each debug line
- All helper functions that process stats should have `setopt localoptions noxtrace`

## Pre-Commit Hooks

Safety hooks prevent common bugs.

### Pre-Commit
- ZSH syntax check (`zsh -n`)
- Custom bug pattern detection
- Retry logic integrity
- Brace/bracket balance

### Pre-Push
- Dry run test
- Function completeness
- Critical pattern validation
- Documentation check
