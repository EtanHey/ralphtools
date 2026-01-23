# Data Export Workflow

Export data from your Convex database.

---

## Prerequisites

### Step 1: Verify Convex project

Run:
```bash
[ -d "convex" ] && echo "Convex project found" || echo "ERROR: No convex/ directory"
```

---

## Export All Data

### Step 1: Export to zip file

Run:
```bash
npx convex export --path ./convex-backup.zip
```

This exports:
- All tables and their documents
- File storage metadata
- Does NOT export the actual files in storage

### Step 2: Verify export

Run:
```bash
ls -la ./convex-backup.zip
unzip -l ./convex-backup.zip | head -20
```

---

## Export with Timestamp

Best practice for backups - include date in filename:

Run:
```bash
npx convex export --path "./backup-$(date +%Y%m%d-%H%M%S).zip"
```

---

## Export from Production

By default, exports from dev deployment.

### Export production data

Run:
```bash
npx convex export --path ./prod-backup.zip --prod
```

**Note:** For CI/CD, use `CONVEX_DEPLOY_KEY`:
```bash
CONVEX_DEPLOY_KEY=$(op read "op://Private/convex/deploy-key")
npx convex export --path ./backup.zip
```

---

## Inspect Exported Data

### Step 1: Unzip the export

Run:
```bash
unzip ./convex-backup.zip -d ./backup-contents
```

### Step 2: View table structure

Run:
```bash
ls ./backup-contents/
```

Each table is a separate JSON file.

### Step 3: View table data

Run:
```bash
cat ./backup-contents/messages.json | jq '.' | head -50
```

---

## Export Specific Tables

The CLI exports all tables. To get specific tables, export all then extract:

Run:
```bash
npx convex export --path ./full-backup.zip
unzip ./full-backup.zip -d ./temp-backup
cp ./temp-backup/users.json ./users-only.json
rm -rf ./temp-backup
```

---

## Automated Backup Script

For regular backups, create a script:

```bash
#!/bin/bash
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
FILENAME="$BACKUP_DIR/convex-$(date +%Y%m%d-%H%M%S).zip"
npx convex export --path "$FILENAME" --prod
echo "Backup created: $FILENAME"
# Keep only last 7 backups
ls -t "$BACKUP_DIR"/*.zip | tail -n +8 | xargs rm -f 2>/dev/null
```

---

## Troubleshooting

**"Not logged in" error?**
```bash
npx convex login
```

**"Permission denied" on path?**
- Check write permissions on target directory
- Use absolute path if relative path fails

**Export is empty?**
- Verify you're exporting from correct deployment (dev vs prod)
- Check if database has data: `npx convex dashboard`

**Large export timing out?**
- For very large databases, export may take time
- Ensure stable network connection
- Consider exporting during low-traffic periods
