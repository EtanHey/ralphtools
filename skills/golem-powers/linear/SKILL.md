---
name: linear
description: Use when working with Linear issues, tasks, or project management. Covers creating, listing, updating issues, Linear to worktree. NOT for: general git operations (use github), non-Linear issue trackers (GitHub Issues, Jira).
---

# Linear Operations

> Issue tracking skill using Linear's GraphQL API via curl. Routes to workflows for specific operations.

## Prerequisites Check

Run first:
```bash
LINEAR_KEY=$(op read "op://Private/linear/api-key" 2>/dev/null)
[ -z "$LINEAR_KEY" ] && echo "ERROR: Linear API key not found in 1Password" && exit 1
echo "Linear API key loaded successfully"
```

If error: See [1Password troubleshooting](../1password/workflows/troubleshoot.md) or add key with:
```bash
op item create --category "API Credential" --title "linear" --vault "Private" "api-key=lin_api_..."
```

---

## Available Scripts

Run these directly - they handle errors and authentication:

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/create-issue.sh` | Create new issue | `bash ~/.claude/commands/linear/scripts/create-issue.sh --team ID --title "Title"` |
| `scripts/list-issues.sh` | List/search issues | `bash ~/.claude/commands/linear/scripts/list-issues.sh --my` |
| `scripts/create-worktree.sh` | Worktree from issue | `bash ~/.claude/commands/linear/scripts/create-worktree.sh ENG-123` |

---

## Quick Actions

| What you want to do | Workflow |
|---------------------|----------|
| Create a new issue | [workflows/create-issue.md](workflows/create-issue.md) |
| List/search issues | [workflows/list-issues.md](workflows/list-issues.md) |
| Update issue status/assignee | [workflows/update-issue.md](workflows/update-issue.md) |
| Create git worktree from issue | [workflows/create-worktree.md](workflows/create-worktree.md) |

---

## API Reference

**Endpoint:** `https://api.linear.app/graphql`

**Auth header:** `Authorization: <API_KEY>` (no Bearer prefix for API keys)

**Basic request pattern:**
```bash
LINEAR_KEY=$(op read "op://Private/linear/api-key")
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_KEY" \
  --data '{"query": "{ viewer { id name } }"}' \
  https://api.linear.app/graphql
```

---

## Safety Rules

1. **Never log API keys** - Use op read inline, don't export
2. **Check for errors** - GraphQL returns 200 even on partial failures
3. **Rate limits** - 1,500 requests/hour with API key auth
4. **Test queries first** - Use viewer query to verify auth works
