# Run Function Workflow

Execute Convex queries, mutations, and actions from the CLI.

---

## Prerequisites

### Step 1: Verify Convex project

Run:
```bash
[ -d "convex" ] && echo "Convex project found" || echo "ERROR: No convex/ directory"
```

### Step 2: List available functions

Run:
```bash
ls convex/*.ts | xargs grep -l "export const" | head -10
```

---

## Run a Query

Queries are read-only and don't modify data.

### Basic query (no arguments)

Run (replace with your function path):
```bash
npx convex run api:listMessages
```

Function path format: `filename:functionName` (no `.ts` extension)

### Query with arguments

Run:
```bash
npx convex run api:getMessage --arg '{"messageId": "k97abc123def456"}'
```

Arguments must be valid JSON.

---

## Run a Mutation

Mutations modify data in the database.

### Basic mutation

Run:
```bash
npx convex run api:createMessage --arg '{"body": "Hello world", "channelId": "k97xyz789"}'
```

### Mutation with complex arguments

Run:
```bash
npx convex run api:updateUser --arg '{
  "userId": "k97abc123",
  "updates": {
    "name": "New Name",
    "email": "new@email.com"
  }
}'
```

---

## Run an Action

Actions can have side effects like calling external APIs.

Run:
```bash
npx convex run api:sendEmail --arg '{"to": "user@example.com", "subject": "Test"}'
```

---

## Run Against Production

By default, `convex run` uses your dev deployment.

### Run against production

Run:
```bash
npx convex run api:functionName --prod
```

**Warning:** This executes against live production data. Use with caution.

---

## Internal Functions

Internal functions (not exposed to clients) can also be run:

Run:
```bash
npx convex run internal:cleanupOldData
```

---

## Common Patterns

### Get a document by ID

```bash
npx convex run api:getDocument --arg '{"id": "k97documentid"}'
```

### List with pagination

```bash
npx convex run api:listItems --arg '{"limit": 10, "cursor": null}'
```

### Search

```bash
npx convex run api:search --arg '{"query": "search term"}'
```

---

## Troubleshooting

**"Function not found" error?**
- Check function is exported: `export const functionName = ...`
- Verify path format: `filename:functionName`
- Ensure file is in `convex/` directory

**"Invalid arguments" error?**
- Arguments must be valid JSON (use double quotes)
- Check argument types match function definition

**"Unauthorized" error?**
- Run `npx convex login`
- Or provide deploy key for production access

**Viewing function output?**
- Output is printed to terminal
- For more details, use `npx convex logs`
