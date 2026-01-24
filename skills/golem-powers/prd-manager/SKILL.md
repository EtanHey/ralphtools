---
name: prd-manager
description: Manage PRD stories - add, update, bulk operations on prd-json/
execute: scripts/run.sh
---

# PRD Manager

Manage PRD stories without manual jq commands.

## Actions

```bash
# Add story to index
./scripts/run.sh --action=add-to-index --story=US-099

# Add criterion to all pending stories
./scripts/run.sh --action=add-criterion --text="Commit changes" --scope=pending

# Add criterion to specific story
./scripts/run.sh --action=add-criterion --text="Run tests" --story=US-001

# List pending stories
./scripts/run.sh --action=list --scope=pending

# Show story details
./scripts/run.sh --action=show --story=US-099

# Set next story
./scripts/run.sh --action=set-next --story=US-100
```

## Scope Options

- `pending` - All pending stories
- `blocked` - All blocked stories
- `all` - Both pending and blocked

## Examples

### Add new story and update index
```bash
# Create story file first, then:
./scripts/run.sh --action=add-to-index --story=BUG-020
```

### Bulk add criterion
```bash
./scripts/run.sh --action=add-criterion \
  --text="Run CodeRabbit before commit" \
  --scope=pending
```

### Check story count
```bash
./scripts/run.sh --action=stats
```
