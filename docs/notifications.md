# Notification Topics

Ralph uses [ntfy](https://ntfy.sh) for push notifications. This document explains the topic naming convention.

## Topic Separation

Ralph and Claude use **separate ntfy topics** to avoid mixing notifications:

| Source | Topic Pattern | Example |
|--------|---------------|---------|
| Ralph | `{prefix}-{project}-notify` | `etanheys-ralph-ralphtools-notify` |
| Claude | Fixed topic | `etanheys-ralphclaude-notify` |

## Ralph Topics

Ralph topics are **per-project**. Multiple Ralph instances running on the same project share the same topic.

```
RALPH_NTFY_PREFIX = "etanheys-ralph"  # Configurable prefix
project_name = basename(pwd)          # e.g., "ralphtools"
topic = "{prefix}-{project}-notify"   # e.g., "etanheys-ralph-ralphtools-notify"
```

### Examples

| Working Directory | Topic |
|-------------------|-------|
| `/code/ralphtools` | `etanheys-ralph-ralphtools-notify` |
| `/code/my-app` | `etanheys-ralph-my-app-notify` |
| `/code/other-project` | `etanheys-ralph-other-project-notify` |

### Why Per-Project?

- **Same project, same topic**: Multiple Ralph instances on `ralphtools` all send to `etanheys-ralph-ralphtools-notify`
- **Different projects, different topics**: Work on `my-app` doesn't clutter `ralphtools` notifications
- **Subscribe to what matters**: Only subscribe to projects you're actively working on

## Claude Topic

Claude notifications always go to a **single fixed topic**: `etanheys-ralphclaude-notify`

This ensures:
- Claude notifications never mix with Ralph iteration updates
- You can mute Ralph iterations while keeping Claude alerts

## Configuration

### Config File (ralph-config.json)

The config file's `ntfyTopic` setting controls topic behavior:

| `ntfyTopic` Value | Behavior |
|-------------------|----------|
| `""` (empty) | **Per-project topics** (recommended) - `{prefix}-{project}-notify` |
| `"auto"` | Same as empty - per-project topics |
| `"my-topic"` | **Fixed topic** - all projects use this topic |

**Example config for per-project topics:**
```json
{
  "notifications": {
    "enabled": true,
    "ntfyTopic": ""
  }
}
```

**Example config for fixed topic:**
```json
{
  "notifications": {
    "enabled": true,
    "ntfyTopic": "my-fixed-topic"
  }
}
```

Run `ralph-setup` to configure interactively.

### Environment Variables

```bash
# In ~/.config/claude-golem/ralph-config.local or shell profile

# Ralph topic prefix (default: "etanheys-ralph")
export RALPH_NTFY_PREFIX="etanheys-ralph"

# Override Ralph topic entirely (bypasses prefix-project pattern)
export RALPH_NTFY_TOPIC="my-custom-topic"

# Claude topic (default: "etanheys-ralphclaude-notify")
export CLAUDE_NTFY_TOPIC="etanheys-ralphclaude-notify"
```

### Notification Message Format

All Ralph notifications include a `[Ralph]` prefix in the title for easy identification:

- `[Ralph] 🔄 Progress` - Iteration completed
- `[Ralph] ✅ Complete` - All stories done
- `[Ralph] ⏹️ Blocked` - Awaiting user action
- `[Ralph] ❌ Error` - Iteration failed
- `[Ralph] ⚠️ Limit Hit` - Max iterations reached

## Subscribing in ntfy App

1. Open the ntfy app (iOS/Android)
2. Tap "+" to add a subscription
3. Enter your topic name (e.g., `etanheys-ralph-ralphtools-notify`)
4. Repeat for each project you want notifications for
5. Add `etanheys-ralphclaude-notify` for Claude notifications

## Testing

Send a test notification:

```bash
curl -d "Test notification from Ralph" ntfy.sh/etanheys-ralph-ralphtools-notify
```
