---
name: obsidian
description: Use when accessing Obsidian vault notes - reading, searching, listing, or organizing notes. Covers obsidian, notes, vault, ideas, diary, memos. NOT for: general file operations outside the vault.
---

# Obsidian Vault Access

> Direct filesystem access to Obsidian vault. Use this when the Obsidian MCP is unavailable or unreliable.

## Vault Location

```
/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal
```

**Note:** This is the iCloud-synced vault. Changes sync across devices.

---

## Quick Actions

| What you want to do | How |
|---------------------|-----|
| List recent notes | [workflows/recent.md](workflows/recent.md) |
| Search notes | [workflows/search.md](workflows/search.md) |
| Read a note | [workflows/read.md](workflows/read.md) |
| Create/update note | [workflows/write.md](workflows/write.md) |

---

## Vault Structure

```
personal/
├── Diary/              # Daily entries (MM-DD-YYYY.md)
├── Ralph/              # Ralph-related ideas and notes
├── Domica notes.md     # Project notes
├── מזכרות.md           # Memos (Hebrew)
└── *.md                # Other notes
```

---

## Common Commands

### List Recent Notes (last 7 days)
```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
find "$VAULT" -name "*.md" -mtime -7 -type f
```

### Search Note Content
```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
grep -r -l "search term" "$VAULT" --include="*.md"
```

### List All Notes
```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
find "$VAULT" -name "*.md" -type f | head -30
```

### Read a Note
```bash
cat "/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/Ralph/Ralph Ideas.md"
```

---

## Key Notes Reference

| Note | Purpose |
|------|---------|
| `Ralph/Ralph Ideas.md` | Ideas for Ralph improvements |
| `Diary/MM-DD-YYYY.md` | Daily diary entries |
| `Domica notes.md` | Domica project notes |
| `מזכרות.md` | General memos |

---

## Safety Rules

1. **Don't delete notes** - Only create or update
2. **Preserve formatting** - Keep existing markdown structure
3. **Respect Hebrew content** - Some notes are in Hebrew, preserve encoding
4. **Backup before bulk changes** - iCloud syncs, but be careful with mass edits
