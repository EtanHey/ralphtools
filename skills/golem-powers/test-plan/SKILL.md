---
name: test-plan
description: Analyze git diff and generate a manual testing checklist for QA before merging PRs
execute: scripts/generate.sh
---

# Generate Test Plan

Analyze changes in the current Git branch and generate a manual testing checklist organized by page/feature.

## Quick Start

The skill auto-runs on load. Override the base branch:

```bash
./scripts/generate.sh --base main
./scripts/generate.sh --base dev
./scripts/generate.sh --base origin/staging
```

## What It Does

1. Gets the diff against the base branch (default: main)
2. Categorizes changed files by type (UI, API, DB, Config, etc.)
3. Generates a Markdown checklist grouped by feature/component
4. Includes regression test suggestions for related areas

## Output Format

```markdown
## Test Plan

### [Feature/Component Name]
- [ ] Test: Description of what to verify
- [ ] Test: Another thing to check

### API Changes
- [ ] Test: Verify endpoint returns expected shape
- [ ] Test: Error responses have correct status codes

### Database/Schema
- [ ] Test: Verify migrations run cleanly
- [ ] Test: Data integrity after changes

### Configuration
- [ ] Test: Verify env vars are documented
- [ ] Test: Config changes don't break existing deploys

### General
- [ ] No console errors during testing
- [ ] No TypeScript/build errors
- [ ] Mobile responsive (if UI changes)
```

## Guidelines

- **Be specific**: "Verify user can submit form" not "Test form"
- **Include edge cases**: Empty states, error states, loading states
- **Consider permissions**: Test as different user roles if auth-related
- **Note regressions**: If touching shared code, note areas that could regress
- **Prioritize**: Put most critical tests first within each section

## Usage

Run this skill before creating a PR to generate the test plan section for your PR description.
