# Data Import Workflow

Import data into your Convex database.

---

## Prerequisites

### Step 1: Verify Convex project

Run:
```bash
[ -d "convex" ] && echo "Convex project found" || echo "ERROR: No convex/ directory"
```

### Step 2: IMPORTANT - Backup current data first

Run:
```bash
npx convex export --path "./pre-import-backup-$(date +%Y%m%d-%H%M%S).zip"
```

**Always backup before importing!** Import operations can overwrite existing data.

---

## Import from Backup

### Step 1: Verify import file exists

Run:
```bash
ls -la ./backup.zip
unzip -l ./backup.zip | head -10
```

### Step 2: Import data

Run:
```bash
npx convex import --path ./backup.zip
```

This will:
- Import all tables from the zip
- Merge with existing data (doesn't delete existing documents)
- Preserve document IDs from the export

---

## Import Modes

### Default (Append mode)

```bash
npx convex import --path ./backup.zip
```
- Adds new documents
- Fails on ID conflicts

### Replace mode

```bash
npx convex import --path ./backup.zip --replace
```
- **Deletes all existing data in imported tables**
- Then imports the backup data
- Use with extreme caution

---

## Import to Production

### Step 1: Double-check you want to import to prod

**Warning:** This modifies production data!

### Step 2: Import with --prod flag

Run:
```bash
npx convex import --path ./backup.zip --prod
```

Or with deploy key for CI/CD:
```bash
CONVEX_DEPLOY_KEY=$(op read "op://Private/convex/deploy-key")
npx convex import --path ./backup.zip
```

---

## Import Single Table

The CLI imports all tables in the zip. To import specific tables:

### Step 1: Extract the table you want

Run:
```bash
unzip ./full-backup.zip -d ./temp
mkdir ./single-table-import
cp ./temp/users.json ./single-table-import/
```

### Step 2: Create a zip with just that table

Run:
```bash
cd ./single-table-import && zip ../users-only.zip *.json && cd ..
```

### Step 3: Import the single-table zip

Run:
```bash
npx convex import --path ./users-only.zip
```

### Step 4: Cleanup

Run:
```bash
rm -rf ./temp ./single-table-import ./users-only.zip
```

---

## Import JSON Files Directly

For custom data, create JSON files in the export format:

### Step 1: Create table JSON file

```json
[
  {"_id": "k97abc123", "name": "User 1", "email": "user1@example.com"},
  {"_id": "k97def456", "name": "User 2", "email": "user2@example.com"}
]
```

### Step 2: Zip and import

Run:
```bash
zip ./custom-data.zip users.json
npx convex import --path ./custom-data.zip
```

---

## Troubleshooting

**"Schema validation failed" error?**
- Imported data must match your current schema
- Check field types match: `convex/schema.ts`

**"Document already exists" error?**
- Document IDs conflict with existing data
- Use `--replace` to overwrite (dangerous!)
- Or modify IDs in the import file

**"Not logged in" error?**
```bash
npx convex login
```

**Import seems stuck?**
- Large imports take time
- Check network connection
- View progress in Convex dashboard

**Wrong deployment?**
- By default imports to dev
- Use `--prod` for production
- Verify with `npx convex dashboard` before importing
