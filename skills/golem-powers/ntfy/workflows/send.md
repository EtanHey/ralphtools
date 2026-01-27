# Send Notification

Send a push notification via ntfy.

## Basic Send

```bash
curl -d "MESSAGE" ntfy.sh/TOPIC
```

## With All Options

```bash
curl \
  -H "Title: TITLE" \
  -H "Priority: PRIORITY" \
  -H "Tags: TAG1,TAG2" \
  -H "Click: URL" \
  -d "MESSAGE" \
  ntfy.sh/TOPIC
```

## Examples

### Success notification
```bash
curl -H "Title: Build Complete" \
     -H "Tags: white_check_mark,rocket" \
     -d "Deployment to production successful" \
     ntfy.sh/my-alerts
```

### Error notification
```bash
curl -H "Title: Build Failed" \
     -H "Priority: high" \
     -H "Tags: x,skull" \
     -d "Tests failed on main branch" \
     ntfy.sh/my-alerts
```

### With link
```bash
curl -H "Title: PR Ready" \
     -H "Click: https://github.com/user/repo/pull/123" \
     -H "Tags: bell" \
     -d "PR #123 ready for review" \
     ntfy.sh/my-alerts
```

## From Script

```bash
notify() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  local tags="${4:-bell}"

  curl -s \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$message" \
    "ntfy.sh/${NTFY_TOPIC:-my-topic}"
}

# Usage
notify "Alert" "Something happened" "high" "warning"
```
