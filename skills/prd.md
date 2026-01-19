---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for autonomous AI implementation via the Ralph loop.

---

## The Job

1. Receive a feature description from the user
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate a structured PRD based on answers
4. **Find git root**: `git rev-parse --show-toplevel`
5. **Create JSON output** at git root:
   - `prd-json/index.json` - Story order and stats
   - `prd-json/stories/{US-XXX}.json` - One file per story
   - `prd-json/metadata.json` - Project metadata (optional)
6. Create `progress.txt` at git root
7. **STOP and tell user: "PRD ready. Run Ralph to execute."**

---

## 🛑 CRITICAL: DO NOT IMPLEMENT 🛑

**After saving PRD.md and progress.txt, YOU ARE DONE.**

| ❌ DO NOT | ✅ DO |
|-----------|-------|
| Spawn subagents to implement stories | Tell user "PRD ready, run Ralph" |
| Use Task tool to start coding | Wait for user to run Ralph externally |
| Begin "let me start with US-001..." | Stop completely after saving files |
| Offer to "help implement" | Let Ralph handle implementation |

**Ralph is an EXTERNAL tool** the user runs separately. Your job is ONLY to create the PRD document. Implementation happens in a completely different process.

**Ralph's Iteration Style:** Ralph is configured to provide expressive summaries at the end of each iteration, describing what was completed and what's coming next in conversational language. This is built into the ralph function, not the PRD.

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?
- **Figma/Design:** Is there a Figma link or design reference?
- **Working Directory:** Which app/package should be modified?

### Use the AskUserQuestion Tool

**Use `AskUserQuestion` tool for clarifying questions.** This provides a proper UI with selectable options instead of manual text responses.

Example questions to ask:
- What is the primary goal? (options: onboarding, retention, reduce support)
- Is there a Figma design? (options: yes, no, partial)
- Which app/package should be modified?

---

## Step 2: Story Sizing (THE NUMBER ONE RULE)

**Each story must be completable in ONE context window (~10 min of AI work).**

Ralph spawns a fresh instance per iteration with no memory of previous work. If a story is too big, the AI runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a single UI component to an existing page
- Update a server action with new logic
- Fix a specific visual bug with clear Figma reference

### Too big (MUST split):
| Too Big | Split Into |
|---------|-----------|
| "Build the dashboard" | Schema, queries, UI components, filters |
| "Add authentication" | Schema, middleware, login UI, session handling |
| "Add drag and drop" | Drag events, drop zones, state update, persistence |
| "Build the modal flow" | Modal 1, Modal 2, Success state, Cancelled state, Wiring |

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Step 3: Story Ordering (Dependencies First)

Stories execute in priority order. Earlier stories must NOT depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Modal states (each state = separate story)
5. Wiring/integration stories
6. Verification stories (V-XXX)

---

## Step 4: Acceptance Criteria (Must Be Verifiable)

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Button appears at END of screen" (use START/END, not DOM order)
- "Modal shows property address, contact name, phone"
- "Typecheck passes"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Proper RTL support" (too vague - specify exact positions)

### Always include as final criteria:
```
- [ ] Typecheck passes
- [ ] Verify changes work in browser
```

---

## 🚨 CRITICAL: ITERATION RULES SECTION

**Every PRD MUST include this section at the top:**

```markdown
## 🚨 ITERATION RULES (READ THIS FIRST) 🚨

**CRITICAL: Each user story = ONE iteration. NO EXCEPTIONS.**

**📊 CHECK PROGRESS FIRST:**
- See **PROGRESS SUMMARY** section below for current status
- Only stories with `- [ ]` unchecked criteria need work
- **DO NOT re-do completed stories** - check if archived

**🚨 VERIFICATION STORIES ARE NOT OPTIONAL 🚨**
The PRD is NOT complete until ALL V-* stories are done. Do NOT skip them. Do NOT output `<promise>COMPLETE</promise>` until every single `[ ]` checkbox in the ENTIRE PRD file is marked `[x]`.

**🚫 DO NOT STOP AT "EPIC COMPLETE" MARKERS**
If you see text like "ALL STORIES COMPLETE" or "EPIC COMPLETE" in the middle of the PRD, IGNORE IT and keep scanning for unchecked `[ ]` boxes. Only output `<promise>COMPLETE</promise>` when there are ZERO unchecked boxes in the entire file.

1. **ONE STORY PER ITERATION**: Complete exactly ONE user story, then STOP. Do not continue to the next story.

2. **TYPECHECK IS MANDATORY**: Run typecheck BEFORE marking complete.

4. **VERIFY BEFORE MARKING COMPLETE**: Check visually in browser.

5. **DO NOT BATCH**: Even if stories seem related, they are SEPARATE iterations.

6. **FRESH CONTEXT**: Each iteration starts fresh. Re-read target files.

7. **VERIFICATION STORIES ARE MANDATORY**: V-* stories MUST be executed. They are NOT optional. The PRD is incomplete without them.

8. **🚨 UPDATE CHECKBOXES IN THIS FILE 🚨**: After completing acceptance criteria:
   - Change `- [ ]` to `- [x]` in PRD.md for EVERY criterion you completed
   - Save PRD.md
   - Commit: `git add PRD.md progress.txt && git commit -m "feat: [story-id] [description]"`
   - **If you don't update checkboxes, the next iteration will re-do your work**

9. **🚨 COMMIT STATE CHANGES 🚨**: You MUST commit PRD.md after marking checkboxes:
   - Why: Git history is the audit trail
   - Why: Next Ralph instance needs to see updated checkboxes
   - Why: Without commits, you create infinite loops (same story repeats forever)
   - Verify commit: `git log -1` after committing
```

---

## 🚨 CRITICAL: STOP MARKERS

**Every story MUST end with a STOP marker:**

```markdown
**⏹️ STOP - END OF US-001. Do not continue to US-002.**
```

This prevents Ralph from batching multiple stories into one iteration.

---

## 🌍 RTL/LTR LAYOUT RULES (CRITICAL FOR HEBREW/ARABIC)

**⚠️ RTL IS ONE OF THE MOST COMMON SOURCES OF BUGS ⚠️**

Every Hebrew/Arabic UI task MUST consider RTL. This is not optional.

### Rule 1: Use START/END, not LEFT/RIGHT

```markdown
## CRITICAL LAYOUT CLARIFICATION

Use direction-agnostic terms:
- "START" = Beginning of reading direction (RIGHT in RTL, LEFT in LTR)
- "END" = End of reading direction (LEFT in RTL, RIGHT in LTR)

When you must use screen position:
- "LEFT side" = Left side of the screen (END in RTL)
- "RIGHT side" = Right side of the screen (START in RTL)

**DO NOT use DOM order language like "first child" or "second in DOM".**
AI gets confused by RTL flex behavior. Use START/END or visual screen position.
```

### Rule 2: RTL Must Propagate to ALL Children

**Common bug:** Parent has `dir="rtl"` but inner flex children don't inherit direction.

```tsx
// ❌ WRONG - RTL doesn't propagate to inner flex
<div dir="rtl">
  <div className="flex">  {/* Still renders LTR! */}
    <span>לחודש</span>    {/* Appears RIGHT */}
    <span>₪7,200</span>   {/* Appears LEFT */}
  </div>
</div>

// ✅ CORRECT - Explicit RTL on inner containers
<div dir="rtl">
  <div className="flex items-end text-right" dir="rtl">
    <span>₪7,200</span>   {/* Appears RIGHT */}
    <span>לחודש</span>    {/* Appears LEFT */}
  </div>
</div>
```

### Rule 3: Text Alignment in RTL

- Hebrew text should be `text-right` (aligns to right edge)
- Use `items-end` for flex column alignment in RTL
- Check that text doesn't have unexpected left padding/gaps

### Rule 4: Button Icons - Use START/END Thinking

**Use START/END instead of LEFT/RIGHT for direction-agnostic code:**
- **START** = RIGHT in RTL, LEFT in LTR (beginning of reading direction)
- **END** = LEFT in RTL, RIGHT in LTR (end of reading direction)

**For buttons, icons typically go at END (after text in reading order):**

```tsx
// Button props use left/right (DOM position), but THINK in start/end:
// leftIcon = icon at START (RIGHT in RTL) - usually WRONG for RTL
// rightIcon = icon at END (LEFT in RTL) - usually CORRECT for RTL

// ❌ WRONG - Icon at START (RIGHT in RTL)
<PrimaryButton leftIcon={<Phone />}>חיוג לבעל הדירה</PrimaryButton>

// ✅ CORRECT - Icon at END (LEFT in RTL)
<PrimaryButton rightIcon={<Phone />}>חיוג לבעל הדירה</PrimaryButton>
```

**Mental model:** "Icon comes at the END of reading direction" → use `rightIcon` in RTL

### Rule 5: Components May Not Accept `dir` Prop

**Typography and other components often don't accept `dir` prop. Use wrapper:**

```tsx
// ❌ WRONG - Typography ignores dir prop
<Typography dir="ltr">{formatPrice(price)}</Typography>

// ✅ CORRECT - Wrap in span with dir
<span dir="ltr">
  <Typography>{formatPrice(price)}</Typography>
</span>
```

**Use `dir="ltr"` for prices** to prevent "₪ 7,200" from displaying as "7,200 ₪"

### Rule 6: `justify-end` Pushes to LEFT in RTL

```tsx
// In RTL: justify-end = push to LEFT (end in RTL)
// Remove justify-end for natural RTL flow from RIGHT

// ❌ Content appears on LEFT (may be wrong)
<div className="flex justify-end" dir="rtl">

// ✅ Content starts from RIGHT naturally
<div className="flex" dir="rtl">
```

### Rule 7: `min-w-0` Prevents Flex Overflow

**Always add to flex items that might overflow (especially inputs):**

```tsx
// ❌ Flex items can overflow container
<div className="flex gap-4">
  <input className="flex-1" />
</div>

// ✅ min-w-0 allows flex item to shrink below content size
<div className="flex gap-4">
  <input className="flex-1 min-w-0" />
</div>
```

### Include in PRDs with Hebrew/Arabic UI:

```markdown
**🚨 RTL RULES:**
1. Think in START/END, not LEFT/RIGHT:
   - START = RIGHT in RTL (beginning of reading)
   - END = LEFT in RTL (end of reading)
2. RTL must propagate to ALL inner flex containers
3. Text should be `text-right`, flex columns should be `items-end`
4. Button icons: Use `rightIcon` for icon at END (LEFT in RTL)
5. Prices: Wrap in `<span dir="ltr">` to prevent symbol reversal
6. Flex items: Add `min-w-0` to prevent overflow
7. Verify visually: Hebrew text flows right-to-left
```

### Include this rule in PRDs with UI:

```markdown
**RTL/LTR Note (think START/END, not LEFT/RIGHT):**
- START = beginning of reading direction (RIGHT in RTL, LEFT in LTR)
- END = end of reading direction (LEFT in RTL, RIGHT in LTR)
- In flex: First child → START, Last child → END
- Always verify visual position matches acceptance criteria
```

---

## 🎭 MODAL/DYNAMIC STATE TESTING

**When PRD includes modals, dropdowns, or dynamic states:**

### Add this rule:

```markdown
**🔴 DYNAMIC STATE TESTING RULE**: When verifying a modal or dynamic state:
1. Trigger the action that opens/shows the state
2. Take screenshot WITH the state visible
3. Compare against design
4. Do NOT just verify the code exists - verify it RENDERS correctly
```

### Each modal state = separate story:

```markdown
US-005: Create Contact Modal
US-006: Create Message Form Modal
US-007: Create Success State Modal
US-008: Create Cancelled State Modal
US-009: Wire up modal flow (state management)
```

### Modal Back Navigation Pattern

**Back buttons should navigate to previous modal, NOT just close:**

```tsx
// ❌ WRONG - Just closes, loses context
<button onClick={() => setCurrentModalOpen(false)}>
  <ChevronLeft />
</button>

// ✅ CORRECT - Goes back to previous modal
<button onClick={() => {
  setCurrentModalOpen(false);
  setPreviousModalOpen(true);
}}>
  <ChevronLeft />
</button>
```

### Modal Header RTL Layout

**In RTL modal headers: Title at START, Back button at END**

```tsx
// RTL: START = RIGHT, END = LEFT
// First in DOM = START (RIGHT), Last in DOM = END (LEFT)
<div className="flex items-center justify-between">
  <Typography>Modal Title</Typography>  {/* START (RIGHT in RTL) */}
  <button><ChevronLeft /></button>       {/* END (LEFT in RTL) - back button */}
</div>
```

---

## 🔧 RALPH'S MCP CAPABILITIES

**Ralph has access to these MCP tools - leverage them in PRDs:**

### Figma MCP
- `mcp__figma__get_screenshot` - Get screenshot of any Figma node
- `mcp__figma__get_design_context` - Get code/specs from Figma node
- **Use for:** Visual comparison, extracting exact colors/spacing

### Browser Tools MCP
- `mcp__browser-tools__takeScreenshot` - Screenshot current browser tab
- `mcp__browser-tools__getConsoleLogs` - Check for errors
- `mcp__browser-tools__getConsoleErrors` - Get JS errors
- `mcp__browser-tools__runAccessibilityAudit` - A11y checks
- **Use for:** Visual verification, debugging, accessibility

### Context7 MCP
- `mcp__Context7__resolve-library-id` - Find library docs
- `mcp__Context7__query-docs` - Get up-to-date documentation
- **Use for:** Checking latest API usage for libraries

### Claude in Chrome MCP (if available)
- `mcp__claude-in-chrome__computer` - Click, type, screenshot
- `mcp__claude-in-chrome__navigate` - Go to URLs
- `mcp__claude-in-chrome__read_page` - Read page accessibility tree
- **Use for:** Interactive testing, filling forms, triggering modals

### Include in PRD when relevant:

```markdown
## MCP Tools Available

Ralph can use these tools for verification:
- **Figma MCP**: Compare implementation vs design (`mcp__figma__get_screenshot`)
- **Browser Tools**: Take screenshots, check console errors
- **Context7**: Look up library documentation if needed
```

---

## 🎨 FIGMA INTEGRATION

**When Figma designs exist, include node IDs for verification:**

```markdown
**Figma References:**
- Main view: node `481-4599`
- Modal: node `687-6234`
- Success state: node `600-12561`

**Figma Link:** https://figma.com/design/XXX?node-id=YYY
```

### In acceptance criteria:

```markdown
- [ ] Layout matches Figma node `600-12561`
- [ ] Use Figma MCP to compare screenshot vs design
```

---

## 🚫 NEVER USE "ALL STORIES COMPLETE" MID-DOCUMENT

**🚨 CRITICAL BUG PREVENTION 🚨**

**NEVER put "ALL STORIES COMPLETE" or similar completion markers anywhere in the PRD except at the VERY END after the last story.**

Ralph reads the PRD top-to-bottom. If it sees "COMPLETE" after an epic, it will stop there even if more stories exist below.

```markdown
// ❌ WRONG - Causes Ralph to stop prematurely
## Verification Stories
V-001: ...
V-008: ...

**⏹️ STOP - ALL STORIES COMPLETE**   // ← Ralph stops HERE!

## Future Enhancement Epic         // ← NEVER REACHED
US-FUT-001: ...
```

```markdown
// ✅ CORRECT - Only mark complete at the VERY END
## Verification Stories
V-001: ...

**⏹️ STOP - END OF V-001**   // ← Story-level stop

## Future Enhancement Epic
US-FUT-001: ...

**⏹️ STOP - END OF LAST STORY**

// Only at VERY END of PRD file:
// (Ralph's <promise>COMPLETE</promise> is triggered by having NO unchecked [ ] boxes)
```

**Rule:** Use `⏹️ STOP - END OF [STORY-ID]` for individual stories. NEVER use "ALL COMPLETE" mid-document.

---

## ✅ VERIFICATION STORIES (MANDATORY)

**🚨 VERIFICATION STORIES ARE NOT OPTIONAL 🚨**

Every implementation story MUST have a corresponding verification story. Ralph MUST execute ALL V-* stories before the PRD is complete.

**After implementation stories, add verification stories:**

```markdown
## Verification Stories

**🚨 THESE ARE MANDATORY - NOT OPTIONAL 🚨**
Do NOT output `<promise>COMPLETE</promise>` until ALL V-* stories are done.

### V-001: Verify US-001
- [ ] Take screenshot
- [ ] Compare with Figma node `XXX`
- [ ] Confirm [specific visual criteria]

**⏹️ STOP**

### V-002: Verify US-002
...
```

Verification stories run critique-waves or manual checks to ensure implementation matches design.

**Why verification matters:**
- Implementation stories can be marked complete without actually fixing the issue
- Ralph may claim "already correct" without verifying
- Only visual verification confirms the fix actually worked

---

## 📁 WORKING DIRECTORY

**Always specify where Ralph should work:**

```markdown
**Working Directory:** `apps/public`
```

Or for monorepos:

```markdown
**Working Directory:** `packages/ui`

**Related files:**
- Main component: `src/components/MyComponent.tsx`
- Styles: `src/styles/globals.css`
```

---

## 🌐 BROWSER SETUP SECTION

**For UI work, include test context:**

```markdown
## Browser Setup

A browser instance should be open with:
- Mobile viewport (375px) OR Desktop (1440px)
- App running at localhost:3000
- Test page open

**Test URL:** `http://localhost:3000/path/to/test`

**DO NOT resize browser or change viewport.** Just refresh to see changes.
```

---

## 🚫 COMMON PITFALLS TO DOCUMENT

**Include relevant warnings based on the tech stack:**

### For Tailwind projects:
```markdown
### Layout Rules
- Use `flex` + `gap-*` for spacing, NOT margin classes (`mb-*`, `mt-*`)
- Exception: `mx-auto` for centering is allowed
```

### For component libraries:
```markdown
### Component Rules
- CHECK existing components before creating new ones
- Import from shared library: `import { Button } from '@mylib/ui'`
- Do NOT create inline/duplicate components
```

---

## PRD JSON Templates

### index.json Template

```json
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-19T12:00:00Z",
  "projectName": "[Feature Name]",
  "workingDirectory": "[path]",
  "stats": {
    "total": 4,
    "completed": 0,
    "pending": 4,
    "blocked": 0
  },
  "nextStory": "US-001",
  "storyOrder": ["US-001", "US-002", "V-001", "V-002"],
  "blocked": [],
  "pending": ["US-001", "US-002", "V-001", "V-002"],
  "browserSetup": {
    "viewport": "mobile 375px",
    "testUrl": "http://localhost:3000/[path]"
  },
  "figmaLink": "[optional figma link]"
}
```

### Story JSON Template (prd-json/stories/US-XXX.json)

```json
{
  "id": "US-001",
  "title": "[Story Title]",
  "description": "[What and why - brief description]",
  "figmaNode": "XXX-YYY",
  "acceptanceCriteria": [
    {"text": "[Specific, verifiable criterion]", "checked": false},
    {"text": "[Use START/END for layout positions]", "checked": false},
    {"text": "Typecheck passes", "checked": false},
    {"text": "Verify changes work in browser", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
```

### Verification Story Template (prd-json/stories/V-XXX.json)

```json
{
  "id": "V-001",
  "title": "Verify US-001",
  "description": "Visual verification that US-001 matches design",
  "acceptanceCriteria": [
    {"text": "Take screenshot of implemented feature", "checked": false},
    {"text": "Compare with Figma node XXX", "checked": false},
    {"text": "[Specific visual criteria]", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
```

### metadata.json Template (Optional)

```json
{
  "projectName": "[Feature Name]",
  "description": "[Brief description]",
  "workingDirectory": "[path]",
  "figmaLink": "[link if available]",
  "rules": {
    "rtl": false,
    "noInlineColors": true,
    "noArbitraryPixels": true
  },
  "nonGoals": ["[What this will NOT include]"]
}
```

---

## Output

**🚨 CRITICAL: Output JSON to `prd-json/` at REPOSITORY ROOT.**

```bash
# Find git root
git rev-parse --show-toplevel
```

### JSON File Structure

```
repo-root/
├── prd-json/
│   ├── index.json        # Story order, stats, pending list
│   ├── metadata.json     # Project metadata (optional)
│   └── stories/
│       ├── US-001.json   # One file per story
│       ├── US-002.json
│       ├── V-001.json    # Verification stories too
│       └── ...
├── progress.txt          # Learning log
└── PRD.md                # Legacy (optional, for human reading)
```

### index.json Format

```json
{
  "$schema": "https://ralph.dev/schemas/prd-index.schema.json",
  "generatedAt": "2026-01-19T12:00:00Z",
  "stats": {
    "total": 10,
    "completed": 0,
    "pending": 10,
    "blocked": 0
  },
  "nextStory": "US-001",
  "storyOrder": ["US-001", "US-002", "V-001", "V-002"],
  "blocked": [],
  "pending": ["US-001", "US-002", "V-001", "V-002"]
}
```

### Story JSON Format

```json
{
  "id": "US-001",
  "title": "Story Title",
  "description": "What this story does and why",
  "acceptanceCriteria": [
    {"text": "Criterion 1 (specific, verifiable)", "checked": false},
    {"text": "Typecheck passes", "checked": false},
    {"text": "Verify in browser", "checked": false}
  ],
  "passes": false,
  "blockedBy": null
}
```

### Also create `progress.txt`:
```markdown
# Progress Log

## Learnings
(Mark with [DONE] when promoted to CLAUDE.md)

- NO INLINE COLORS: Use Tailwind preset tokens, never arbitrary hex
- NO ARBITRARY PIXELS: Use Tailwind scale or @theme CSS variables

---

## Current Iteration
(Continue from here)
```

### Legacy PRD.md (Optional)

For human readability, you may also generate a `PRD.md` markdown file. But Ralph reads from `prd-json/` for execution.

**Documentation:** See `docs.local/README.md` for branch folder conventions, progress tracking, and cross-branch learning search patterns.

**Then say this EXACT message and STOP:**

> ✅ PRD saved to `prd-json/` with X stories + X verification stories.
>
> Run Ralph to execute. I will not implement - that's Ralph's job.

---

## Checklist Before Saving

- [ ] **prd-json/ folder created at REPOSITORY ROOT**
- [ ] **index.json has valid JSON** with stats, storyOrder, pending, nextStory
- [ ] **Each story has its own JSON file** in prd-json/stories/
- [ ] Asked clarifying questions (including Figma/design)
- [ ] Stories ordered by dependency in storyOrder array
- [ ] All criteria are verifiable (screen positions, not DOM order)
- [ ] Every story has "Typecheck passes" criterion
- [ ] UI stories have "Verify changes work in browser" criterion
- [ ] Modal states are separate stories (not one big "build modal" story)
- [ ] **VERIFICATION STORIES INCLUDED** - Every US-XXX has a V-XXX (MANDATORY)
- [ ] Working directory specified in index.json
- [ ] Figma node IDs included (if designs exist)
- [ ] RTL/LTR rules in metadata.json (if applicable)
- [ ] Created progress.txt at repo root
