---
name: context-audit
description: Use to diagnose missing contexts in a project. Compares what contexts SHOULD be loaded vs what IS loaded. Covers context check, missing contexts, setup audit. NOT for: listing skills (use /skills), detecting tools (use /project-context).
user-invocable: true
---

# Context Audit

Diagnoses what contexts a project SHOULD have vs what it currently HAS.

## Quick Audit

Run the audit script to see gaps:

```bash
bash ~/.claude/commands/golem-powers/context-audit/scripts/audit.sh
```

## What This Audits

1. **Available contexts** - What's in `~/.claude/contexts/` or repo `contexts/`
2. **Project tech stack** - Detected from package.json, file patterns
3. **Current CLAUDE.md** - What `@context:` refs exist
4. **Gap analysis** - What's missing

## Manual Audit Steps

If the script isn't available, follow these steps:

### Step 1: Check Available Contexts

```bash
find ~/.claude/contexts -name "*.md" -o -name "*.md" 2>/dev/null | sort
# Or in repo:
find contexts -name "*.md" 2>/dev/null | sort
```

### Step 2: Detect Project Needs

| If Project Has | Should Include |
|----------------|----------------|
| Any project | `base`, `skill-index` |
| Interactive Claude | `workflow/interactive` |
| Ralph/PRD work | `workflow/ralph` |
| Next.js (package.json) | `tech/nextjs` |
| React Native/Expo | `tech/react-native` |
| Convex (convex/) | `tech/convex` |
| Supabase (supabase/) | `tech/supabase` |
| Hebrew/Arabic UI | `workflow/rtl` |
| Dual-language / i18n UI | `workflow/i18n` |
| UI components | `workflow/design-system` |
| Test files | `workflow/testing` |

### Step 3: Check CLAUDE.md

```bash
grep -E "@context:|contexts/" CLAUDE.md 2>/dev/null || echo "No @context: refs found"
```

### Step 4: Report Gaps

Compare Step 2 (needed) vs Step 3 (has). Missing = gap.

## Output Format

The audit produces:

```
=== CONTEXT AUDIT ===

AVAILABLE CONTEXTS:
  base.md
  skill-index.md
  tech/nextjs.md
  ...

DETECTED TECH STACK:
  [x] Next.js (found next in package.json)
  [x] RTL (found Hebrew text)
  [ ] Convex (no convex/ dir)

CURRENT CLAUDE.md CONTEXTS:
  (none found)

RECOMMENDED @context: BLOCK:
  ## Contexts
  @context: base
  @context: skill-index
  @context: tech/nextjs
  @context: workflow/rtl
  @context: workflow/i18n
  @context: workflow/interactive

GAP SUMMARY:
  Missing 5 contexts. Add the block above to CLAUDE.md.
```

## Self-Improvement Loop

If you find gaps:
1. **Ask the user** if they want to fix it
2. **Create a PRD story** with `/golem-powers:prd` if it's a systemic issue
3. **Fix immediately** if it's a simple CLAUDE.md update

This is how claude-golem improves itself.
