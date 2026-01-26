---
name: github-research
description: Systematically explore and document Git repositories and GitHub projects
---

# GitHub Research Skill

Use this skill to thoroughly explore Git repositories, understand their structure, and document findings.

## When to Use

- Auditing a codebase for undocumented features
- Understanding a new project's architecture
- Finding configuration issues or gaps
- Comparing related projects

## Research Protocol

### Phase 1: Structure Discovery

```bash
# Get directory tree (2 levels, ignore node_modules)
tree -L 2 -I 'node_modules|.git|dist|build' .

# Find all config files
find . -maxdepth 2 -name "*.json" -o -name "*.yaml" -o -name "*.toml" | head -20

# Find all markdown docs
find . -name "*.md" -not -path "*/node_modules/*" | head -20

# Check for monorepo structure
ls -la packages/ 2>/dev/null || ls -la apps/ 2>/dev/null || echo "Not a monorepo"
```

### Phase 2: Entry Points

```bash
# Find main entry points
cat package.json 2>/dev/null | grep -A5 '"main"\|"bin"\|"scripts"' | head -30

# For shell projects
head -50 *.zsh 2>/dev/null || head -50 *.sh 2>/dev/null

# For TypeScript
find . -name "index.ts" -not -path "*/node_modules/*" | head -10
```

### Phase 3: Key Files (READ THESE)

Always read these files if they exist:
1. `README.md` - Official docs
2. `CLAUDE.md` or `GEMINI.md` - AI context
3. `package.json` - Dependencies and scripts
4. Main entry file (from Phase 2)

### Phase 4: Function/Command Discovery

```bash
# Find exported functions (TypeScript)
grep -r "export function\|export const\|export async" --include="*.ts" . | grep -v node_modules | head -30

# Find shell functions (zsh/bash)
grep -r "^function \|^[a-z_]*() {" --include="*.zsh" --include="*.sh" . | head -30

# Find CLI commands
grep -r "\.command(\|addCommand\|yargs\." --include="*.ts" --include="*.js" . | grep -v node_modules | head -20
```

### Phase 5: Related Projects

If researching a monorepo or related projects:

```bash
# Check git remotes for related repos
git remote -v

# Look for workspace references
cat package.json | grep -A10 '"workspaces"' 2>/dev/null
cat pnpm-workspace.yaml 2>/dev/null

# Check for local path dependencies
grep -r "file:\.\." package.json 2>/dev/null
```

## Output Format

Create structured findings in `docs.local/`:

```
docs.local/
├── {project}-structure.md      # Directory tree + key files
├── {project}-commands.md       # All commands/functions found
├── {project}-config-issues.md  # Misconfigurations found
└── {project}-gaps.md           # Documentation gaps
```

## Related Projects Context

When researching claude-golem, also check these related projects:

| Project | Path | Purpose |
|---------|------|---------|
| zikaron | `~/Gits/zikaron` | Vector embeddings for conversation memory |
| ralph-ui | `./ralph-ui/` | React Ink dashboard (subdir) |
| bun/ | `./bun/` | TypeScript story management (subdir) |

## Integration with Context7

For library documentation lookup:
```bash
# If context7 MCP available, use it
# Otherwise fall back to web search
./scripts/web-search.sh "ink react cli documentation"
```

## Critique Waves Pattern

For thorough research, run multiple passes:

1. **Wave 1**: Structure discovery (tree, find)
2. **Wave 2**: Read key files (README, package.json, main entry)
3. **Wave 3**: Function/command extraction (grep patterns)
4. **Wave 4**: Cross-reference with docs (find gaps)
5. **Wave 5**: Verify findings (re-read files, confirm)

Each wave writes to separate files, then consolidate.
