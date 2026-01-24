---
name: archive
description: Archive completed PRD stories to docs.local/. Use when planning a sprint transition, archiving completed work, or resetting the PRD for a fresh start.
---

# Archive PRD Stories

> Archive completed stories to `docs.local/prd-archive/` with full history preservation. Optionally reset the working PRD for a fresh start.

## Available Scripts

Run these directly - standalone, no ralph.zsh dependency:

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/archive-snapshot.sh` | Create archive snapshot | `bash ~/.claude/commands/archive/scripts/archive-snapshot.sh` |
| `scripts/cleanup-completed.sh` | Archive + remove completed | `bash ~/.claude/commands/archive/scripts/cleanup-completed.sh` |

---

## Quick Actions

| What you want to do | Workflow |
|---------------------|----------|
| Archive current PRD state (snapshot) | [workflows/archive-snapshot.md](workflows/archive-snapshot.md) |
| Remove completed stories (cleanup) | [workflows/cleanup-completed.md](workflows/cleanup-completed.md) |

---

## CLI Command (Requires ralph.zsh)

```bash
source ~/.config/ralphtools/ralph.zsh && ralph-archive [app] [flags]
```

### Flags

| Flag | Description |
|------|-------------|
| `--keep` | Archive only, skip cleanup prompt |
| `--clean` | Archive and auto-cleanup without prompt |
| (none) | Archive and prompt for cleanup decision |

### Examples

```bash
# Archive with interactive cleanup prompt
ralph-archive

# Archive app-specific PRD
ralph-archive frontend

# Archive only, keep working PRD intact
ralph-archive --keep

# Archive and auto-cleanup for fresh start
ralph-archive --clean
```

---

## What Gets Archived

Each archive creates a timestamped directory:

```
docs.local/prd-archive/20260123-153000/
├── index.json           # PRD index at time of archive
├── stories/             # All story files (completed + pending)
│   ├── US-001.json
│   ├── US-002.json
│   └── ...
└── progress.txt         # Ralph progress log
```

---

## Cleanup Behavior

When cleanup is triggered (via `--clean` or confirming prompt):

1. **Completed stories deleted** - All `*.json` files where `passes=true`
2. **Index reset** - Stats reset, pending array rebuilt from remaining stories
3. **Progress cleared** - `progress.txt` replaced with fresh start header

**History is always preserved** - The archive contains full state before cleanup.

---

## Safety Notes

1. **Always archives first** - Cleanup only happens after successful archive
2. **Blocked stories preserved** - Stories in blocked array are kept
3. **Pending stories preserved** - Only completed (passes=true) stories removed
4. **Reversible** - Full state available in `docs.local/prd-archive/`
