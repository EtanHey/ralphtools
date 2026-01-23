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

## CRITICAL: Clean Before Starting

**ALWAYS run this before starting Convex dev server:**

```bash
rm -f convex/*.js 2>/dev/null; npx convex dev
```

### Why This Is Required

The error `Two output files share the same path but have different contents: out/filename.js` occurs when:
1. **Git worktrees** copy compiled .js files alongside .ts source files
2. **Convex crashes** mid-compilation leaving orphan .js files
3. **Manual file operations** accidentally create .js duplicates

The Convex bundler (esbuild) finds BOTH `.ts` and `.js` files with the same name and fails because they'd both output to the same path.

**Prevention:** The `rm -f convex/*.js` is safe - only `.ts` files belong in convex/. Any `.js` files are compilation artifacts that should be deleted.

---

## Start Dev Server

### Option A: Standard start (with auto-clean)

Run:
```bash
rm -f convex/*.js 2>/dev/null; npx convex dev
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
