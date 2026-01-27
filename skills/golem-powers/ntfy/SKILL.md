# ntfy - Push Notifications

Simple HTTP-based pub-sub notification service. Send notifications to your phone/desktop with a single curl command.

## Quick Reference

```bash
# Basic notification
curl -d "Your message here" ntfy.sh/your-topic

# With title and priority
curl -H "Title: Alert Title" \
     -H "Priority: high" \
     -H "Tags: warning,skull" \
     -d "Message body" \
     ntfy.sh/your-topic

# Delayed notification
curl -H "Delay: 30m" -d "Reminder message" ntfy.sh/your-topic

# With clickable link
curl -H "Click: https://example.com" -d "Click to open" ntfy.sh/your-topic
```

## Headers Reference

| Header | Description | Example |
|--------|-------------|---------|
| `Title` | Notification title | `Title: Server Alert` |
| `Priority` | `min`, `low`, `default`, `high`, `urgent` | `Priority: high` |
| `Tags` | Comma-separated, supports emojis | `Tags: warning,skull` |
| `Delay` | Delayed delivery | `Delay: 30m` or `Delay: 1h` |
| `Click` | URL to open on click | `Click: https://...` |
| `Icon` | Custom icon URL | `Icon: https://.../icon.png` |
| `Email` | Also send to email | `Email: you@example.com` |
| `Attach` | Attachment URL | `Attach: https://.../file.pdf` |
| `Filename` | Name for attachment | `Filename: report.pdf` |

## Priority Levels

| Level | Use Case |
|-------|----------|
| `min` | Background info, low importance |
| `low` | Informational |
| `default` | Normal notifications |
| `high` | Important, needs attention |
| `urgent` | Critical, bypasses Do Not Disturb |

## Common Tag Emojis

| Tag | Emoji | Tag | Emoji |
|-----|-------|-----|-------|
| `white_check_mark` | ✅ | `x` | ❌ |
| `warning` | ⚠️ | `skull` | 💀 |
| `rocket` | 🚀 | `tada` | 🎉 |
| `bug` | 🐛 | `fire` | 🔥 |
| `hourglass` | ⏳ | `bell` | 🔔 |

Full list: https://docs.ntfy.sh/emojis/

## Workflows

| Workflow | Purpose |
|----------|---------|
| [send](workflows/send.md) | Send a notification |
| [subscribe](workflows/subscribe.md) | Subscribe to a topic |

## Setup

1. **Install app** on phone: [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347)
2. **Subscribe** to your topic in the app
3. **Send** notifications via curl

No account required for public topics on ntfy.sh.

## Self-Hosting

```bash
# Docker
docker run -p 80:80 binwiederhier/ntfy serve

# Then use your host instead of ntfy.sh
curl -d "Test" http://localhost/mytopic
```

## Integration with Ralph

Ralph uses ntfy for story completion notifications:

```bash
# Set topic in ralph config
export RALPH_NTFY_TOPIC="your-topic-name"

# Or in ralph-ui
ralph -ui 50 --notify
```

## API Docs

- Official docs: https://docs.ntfy.sh/
- Publish API: https://docs.ntfy.sh/publish/
