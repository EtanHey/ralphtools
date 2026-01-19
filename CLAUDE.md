# Ralph Tooling

## 🚨 CRITICAL: Always Commit & Push Changes

**After ANY edit to files in this repo:**

1. `git add -A`
2. `git commit -m "type: description"` (use feat/fix/docs/refactor)
3. `git push`
4. If significant change: `git tag vX.Y.Z && git push --tags`

**Why:** This repo is version-controlled to track regressions. Uncommitted changes are invisible to future sessions.

---

## Files

| File | Purpose |
|------|---------|
| `ralph.zsh` | Main Ralph function + helpers |
| `README.md` | Docs with changelog |
| `CLAUDE.md` | This file - instructions for Claude |

## Versioning

- **Patch** (v1.0.X): Bug fixes, minor tweaks
- **Minor** (v1.X.0): New features, new commands
- **Major** (vX.0.0): Breaking changes to command interface

## Testing Changes

After editing `ralph.zsh`, reload in current shell:
```bash
source ~/.config/ralph/ralph.zsh
```

# My personal notes
ntfy_topic=etans-ralph
email: etan@example.com
path: /Users/etanheyman/projects/

