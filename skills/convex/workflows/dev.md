# Dev Server Workflow

Start the Convex development server with hot reload.

---

## Prerequisites

### Step 1: Verify Convex project

Run:
```bash
[ -d "convex" ] && echo "Convex project found" || echo "ERROR: No convex/ directory - run 'npx convex init' first"
```

### Step 2: Check for package.json

Run:
```bash
[ -f "package.json" ] && echo "package.json found" || echo "ERROR: No package.json found"
```

---

## Start Dev Server

### Option A: Standard start

Run:
```bash
npx convex dev
```

This will:
- Connect to your Convex deployment
- Watch for file changes in `convex/` directory
- Auto-regenerate types on schema changes
- Show function logs in terminal

### Option B: Start with specific deployment

Run (replace DEPLOYMENT_NAME):
```bash
npx convex dev --deployment DEPLOYMENT_NAME
```

### Option C: Start without type generation

Run:
```bash
npx convex dev --no-codegen
```

---

## Common Issues

**"Not logged in" error?**
```bash
npx convex login
```

**"Project not linked" error?**
```bash
npx convex init
# Or link to existing project:
npx convex dev --configure
```

**Port conflict?**
The Convex dev server doesn't use a local port - it connects to Convex cloud. If you see connection issues, check your network.

**Types not updating?**
```bash
npx convex codegen
```

---

## Running Alongside Frontend

Typically run in a separate terminal from your frontend dev server:

```bash
# Terminal 1: Convex backend
npx convex dev

# Terminal 2: Frontend (e.g., Next.js)
npm run dev
```

Or use a process manager like `concurrently`:
```bash
npx concurrently "npx convex dev" "npm run dev"
```
