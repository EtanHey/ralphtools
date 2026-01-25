# Create or Update a Note

Write content to the Obsidian vault.

## Create New Note

```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"

# Use Write tool:
# file_path: $VAULT/NewNote.md
# content: Your markdown content
```

## Append to Existing Note

```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
echo "

## New Section
Content here" >> "$VAULT/ExistingNote.md"
```

## Update Note (Edit tool)

Use the Edit tool with:
- `file_path`: Full path to note
- `old_string`: Text to replace
- `new_string`: New text

## Create Diary Entry

```bash
VAULT="/Users/etanheyman/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal"
TODAY=$(date +%m-%d-%Y)

# Use Write tool with file_path: $VAULT/Diary/$TODAY.md
```

## Safety

- **Read first** before editing to understand structure
- **Preserve Hebrew** content and encoding
- **Don't overwrite** without confirmation
