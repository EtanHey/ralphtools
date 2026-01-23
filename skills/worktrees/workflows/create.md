# Create Worktree

Create an isolated git worktree for a new branch.

---

## Quick Workflow

### Step 1: Verify you're in a git repository

```bash
git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: Not in a git repository"; exit 1; }
```

### Step 2: Ensure on main branch

```bash
git checkout main 2>/dev/null || git checkout master 2>/dev/null || echo "Already on working branch"
```

### Step 3: Create the worktree

Replace `feature-name` with your branch name:

```bash
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
BRANCH_NAME="feature-name"
WORKTREE_PATH="$HOME/worktrees/$REPO_NAME/$BRANCH_NAME"

# Ensure parent directory exists
mkdir -p "$HOME/worktrees/$REPO_NAME"

# Create worktree with new branch
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"

echo "Worktree created at: $WORKTREE_PATH"
echo "Run: cd $WORKTREE_PATH"
```

---

## Full Automated Script

Copy and run (replace branch name):

```bash
#!/bin/bash
set -e

BRANCH_NAME="${1:-feature-new-branch}"
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")
WORKTREE_PATH="$HOME/worktrees/$REPO_NAME/$BRANCH_NAME"

# Verify in git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository"
  exit 1
fi

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Branch '$BRANCH_NAME' already exists."
  echo "Creating worktree from existing branch..."
  git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
  echo "Creating new branch and worktree..."
  mkdir -p "$HOME/worktrees/$REPO_NAME"
  git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

echo ""
echo "Worktree created successfully!"
echo "Path: $WORKTREE_PATH"
echo ""
echo "Run: cd $WORKTREE_PATH"
```

---

## Branch Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<description>` | `feature/user-auth` |
| Bug fix | `fix/<description>` | `fix/login-redirect` |
| Refactor | `refactor/<description>` | `refactor/api-client` |
| Docs | `docs/<description>` | `docs/readme-update` |

---

## Options

### Create from remote branch

If working on someone else's branch:

```bash
git fetch origin
git worktree add "$HOME/worktrees/$REPO_NAME/their-branch" origin/their-branch
```

### Create from specific commit

```bash
git worktree add "$HOME/worktrees/$REPO_NAME/detached" -d abc123
```

---

## Next Steps

After creating worktree:
1. `cd ~/worktrees/<repo>/<branch>`
2. Install dependencies (`npm install`, `pip install -r requirements.txt`, etc.)
3. Start development

When done, use [cleanup.md](cleanup.md) to remove the worktree.
