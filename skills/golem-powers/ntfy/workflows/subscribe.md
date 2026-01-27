# Subscribe to Topic

Receive notifications from an ntfy topic.

## Mobile App (Recommended)

1. Install ntfy app:
   - [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [iOS](https://apps.apple.com/app/ntfy/id1625396347)

2. Open app → "+" → Enter topic name

3. Done! You'll receive push notifications.

## Command Line

### Stream notifications (foreground)
```bash
# Simple stream
curl -s ntfy.sh/TOPIC/raw

# JSON stream with metadata
curl -s ntfy.sh/TOPIC/json

# With Server-Sent Events
curl -s ntfy.sh/TOPIC/sse
```

### Background listener
```bash
# Listen and log
while true; do
  curl -s ntfy.sh/TOPIC/raw
done >> ~/ntfy.log &
```

### With action on receive
```bash
#!/bin/bash
while IFS= read -r message; do
  echo "[$(date)] Received: $message"
  # Do something with $message
done < <(curl -sN ntfy.sh/TOPIC/raw)
```

## Web UI

Open in browser: `https://ntfy.sh/TOPIC`

## Filter by Priority

```bash
# Only high priority and above
curl -s "ntfy.sh/TOPIC/json?priority=high"

# Specific priorities
curl -s "ntfy.sh/TOPIC/json?priority=high,urgent"
```

## Historical Messages

```bash
# Last hour
curl -s "ntfy.sh/TOPIC/json?since=1h"

# Since specific time
curl -s "ntfy.sh/TOPIC/json?since=1640000000"

# All cached messages
curl -s "ntfy.sh/TOPIC/json?since=all"
```
