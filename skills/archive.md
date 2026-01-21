---
name: archive
description: Archive completed PRD stories to docs.local/
---

# Archiving Completed Stories

To archive completed PRD stories, run this shell command:

```bash
ralph-archive        # Archive from prd-json/
ralph-archive <app>  # Archive from apps/<app>/prd-json/ (monorepo)
```

This moves completed stories to `docs.local/prd-archive/` with a timestamped folder.

**Note:** This is a shell command, not something Claude executes. Run it in your terminal when you're ready to archive a completed PRD.
