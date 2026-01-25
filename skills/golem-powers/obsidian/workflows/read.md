# Read a Note

Read note content from the vault.

## By Full Path

```bash
cat "/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/NoteName.md"
```

## By Relative Path

```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
cat "$VAULT/Ralph/Ralph Ideas.md"
cat "$VAULT/Diary/01-24-2026.md"
```

## Common Notes

| Note | Command |
|------|---------|
| Ralph Ideas | `cat "$VAULT/Ralph/Ralph Ideas.md"` |
| Today's Diary | `cat "$VAULT/Diary/$(date +%m-%d-%Y).md"` |
| Domica Notes | `cat "$VAULT/Domica notes.md"` |
| Memos | `cat "$VAULT/מזכרות.md"` |

## Using Read Tool

Prefer the Read tool over cat for better formatting:
```
Read tool with file_path: /Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal/Ralph/Ralph Ideas.md
```
