# Deploy Workflow

Deploy your Convex backend to production.

---

## Prerequisites

### Step 1: Verify Convex project

Run:
```bash
[ -d "convex" ] && echo "Convex project found" || echo "ERROR: No convex/ directory"
```

### Step 2: Check login status

Run:
```bash
npx convex dashboard 2>&1 | head -5
```

If not logged in: `npx convex login`

---

## Interactive Deployment (Manual)

### Step 1: Deploy with prompts

Run:
```bash
npx convex deploy
```

This will:
- Push all functions to production
- Apply schema changes (may prompt for confirmation)
- Generate fresh types

### Step 2: Verify deployment

Run:
```bash
npx convex logs --name prod
```

---

## CI/CD Deployment (Automated)

For automated deployments, use `CONVEX_DEPLOY_KEY`.

### Step 1: Get deploy key from 1Password

Run:
```bash
CONVEX_DEPLOY_KEY=$(op read "op://Private/convex/deploy-key" 2>/dev/null)
[ -z "$CONVEX_DEPLOY_KEY" ] && echo "ERROR: Deploy key not found in 1Password"
```

If missing, create in Convex dashboard: Settings > Deploy Keys > Generate

Store in 1Password:
```bash
op item create --category "API Credential" --title "convex" --vault "Private" "deploy-key=prod:..."
```

### Step 2: Deploy with key

Run:
```bash
CONVEX_DEPLOY_KEY=$(op read "op://Private/convex/deploy-key")
npx convex deploy --cmd 'npm run build'
```

The `--cmd` flag runs your build command before deploying.

---

## Deploy with Environment Variables

### Step 1: Set production env vars first

Run:
```bash
npx convex env set VARIABLE_NAME=value
```

### Step 2: Then deploy

Run:
```bash
npx convex deploy
```

---

## Schema Migration Safety

**Warning:** Schema changes can be destructive.

Before deploying schema changes:

1. Export current data as backup:
```bash
npx convex export --path ./backup-$(date +%Y%m%d).zip
```

2. Review schema diff:
```bash
git diff convex/schema.ts
```

3. Deploy with caution - Convex will prompt for destructive changes.

---

## Troubleshooting

**"Schema validation failed" error?**
- Check `convex/schema.ts` for syntax errors
- Run `npx convex codegen` to see type errors

**"Unauthorized" with deploy key?**
- Verify key is for production: should start with `prod:`
- Regenerate key in dashboard if expired

**"Function not found" after deploy?**
- Ensure function is exported from a file in `convex/` directory
- Check function name matches: `filename:functionName`
