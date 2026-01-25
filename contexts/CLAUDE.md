# Contexts Directory - Sync Rules

**This is the SOURCE OF TRUTH for shared contexts.**

## When editing files here, ADD TO FARTHER-STEPS.JSON

Instead of syncing immediately, add an entry to `~/.claude/farther-steps.json` for tracking.

### How to Add a Farther Step

After creating/editing a file here, add to `~/.claude/farther-steps.json`:

```json
{
  "id": "step-XXX",
  "created": "ISO_TIMESTAMP",
  "type": "sync",
  "source": "~/Gits/claude-golem/contexts/path/to/file.md",
  "target": "~/.claude/contexts/path/to/file.md",
  "reason": "Detailed explanation of what changed and why",
  "story": "US-XXX or BUG-XXX if applicable",
  "criteria": "Which acceptance criteria this relates to",
  "status": "pending",
  "priority": "high|medium|low"
}
```

### Quick Sync (when approved)

```bash
# Copy single file to installed location:
cp ~/Gits/claude-golem/contexts/path/to/file.md ~/.claude/contexts/path/to/file.md

# Or sync entire directory:
rsync -av --exclude='CLAUDE.md' ~/Gits/claude-golem/contexts/ ~/.claude/contexts/
```

### Directory Structure

```
contexts/
├── base.md              # Core rules for all projects
├── golem-system.md      # Golem-specific rules
├── skill-index.md       # Available skills (auto-generated)
├── skill-descriptions.md # Skill descriptions
├── tech/                # Technology-specific contexts
│   ├── convex.md
│   ├── ink.md           # Ink CLI - critical stdin setup rules
│   ├── nextjs.md
│   ├── react-native.md
│   └── supabase.md
├── workflow/            # Workflow contexts
│   ├── interactive.md   # Interactive session rules
│   └── ralph.md         # Ralph autonomous execution
└── templates/           # Templates for new contexts
```

### Why Both Locations?

- **This repo**: Version controlled, shareable, canonical source
- **~/.claude/**: Where Ralph/Claude actually loads contexts from

Changes must be in BOTH places to work AND be preserved.
