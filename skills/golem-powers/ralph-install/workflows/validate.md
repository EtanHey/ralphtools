# Validate Installation Workflow

Verify the full ralphtools installation works end-to-end.

---

## Quick Validation

Run this comprehensive check:

```bash
#!/bin/bash
echo "Validating ralphtools installation..."
echo ""

PASS=0
FAIL=0
WARN=0

check() {
  if eval "$2" &>/dev/null; then
    echo "[PASS] $1"
    ((PASS++))
  else
    echo "[FAIL] $1"
    ((FAIL++))
  fi
}

check_warn() {
  if eval "$2" &>/dev/null; then
    echo "[PASS] $1"
    ((PASS++))
  else
    echo "[WARN] $1 (optional)"
    ((WARN++))
  fi
}

# Core Dependencies
echo "=== Core Dependencies ==="
check "gh installed" "command -v gh"
check "op installed" "command -v op"
check "gum installed" "command -v gum"
check "fswatch installed" "command -v fswatch"
check "jq installed" "command -v jq"
check "git installed" "command -v git"
echo ""

# TypeScript Skills Dependencies
echo "=== TypeScript Skills Dependencies ==="
check "bun installed" "command -v bun"
check_warn "cr (CodeRabbit) installed" "command -v cr"
echo ""

# 1Password
echo "=== 1Password ==="
check "op signed in" "op account list"
check_warn "GitHub token exists" "op read 'op://Private/github-token/credential'"
echo ""

# Golem-Powers API Keys (claude-golem item)
echo "=== Golem-Powers API Keys ==="
check_warn "Context7 API key" "op read 'op://Private/claude-golem/context7/API_KEY'"
check_warn "Linear API key" "op read 'op://Private/claude-golem/linear/API_KEY'"
echo ""

# Directories
echo "=== Directories ==="
check "~/.config/ralphtools exists" "test -d ~/.config/ralphtools"
check "~/.claude/commands exists" "test -d ~/.claude/commands"
echo ""

# Golem-Powers Symlink
echo "=== Golem-Powers Symlink ==="
check "golem-powers symlink exists" "test -L ~/.claude/commands/golem-powers"
check "golem-powers symlink is valid" "test -d ~/.claude/commands/golem-powers"
check "golem-powers/1password skill exists" "test -e ~/.claude/commands/golem-powers/1password/SKILL.md"
check "golem-powers/convex skill exists" "test -e ~/.claude/commands/golem-powers/convex/SKILL.md"
check "golem-powers/context7 skill exists" "test -e ~/.claude/commands/golem-powers/context7/SKILL.md"
check "golem-powers/github skill exists" "test -e ~/.claude/commands/golem-powers/github/SKILL.md"
echo ""

# Summary
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "Installation validated successfully!"
  if [ $WARN -gt 0 ]; then
    echo "(Some optional components are missing - see warnings above)"
  fi
else
  echo ""
  echo "Some checks failed. Review and fix issues above."
fi
```

---

## Individual Validations

### 1. Test Core CLIs

```bash
gh --version
op --version
gum --version
fswatch --version
jq --version
git --version
```

### 2. Test Bun (TypeScript Runtime)

```bash
bun --version
```

Expected: Version number (e.g., 1.0.0).

### 3. Test CodeRabbit CLI (Optional)

```bash
cr --version
```

Expected: Version number.

### 4. Test 1Password Access

```bash
op account list
op vault list
```

Expected: Shows account and vaults.

### 5. Test Golem-Powers API Keys

```bash
# Context7 API Key
op read "op://Private/claude-golem/context7/API_KEY"

# Linear API Key
op read "op://Private/claude-golem/linear/API_KEY"
```

Expected: Returns the API key value (starts with ctx7sk_ for Context7, lin_api_ for Linear).

### 6. Test Golem-Powers Symlink

```bash
# Check symlink exists and is valid
ls -la ~/.claude/commands/golem-powers

# List skills
ls ~/.claude/commands/golem-powers/

# Test a skill file is readable
cat ~/.claude/commands/golem-powers/github/SKILL.md | head -5
```

Expected: Shows symlink pointing to ralphtools, lists all skills.

### 7. Test Interactive Tools

```bash
# Quick gum test
echo "test" | gum filter

# Should show interactive filter
```

---

## Test Ralph (if installed)

```bash
# Source ralph
source ~/.config/ralphtools/ralph.zsh

# Check ralph is available
type ralph

# Show help
ralph --help
```

---

## Common Issues

### "Not signed in" for op

```bash
op signin
```

### API key not found

Check the claude-golem item exists:
```bash
op item get "claude-golem" --vault "Private"
```

If missing, create it:
```bash
op item create --category "API Credential" --vault "Private" --title "claude-golem"
```

### Symlink points to wrong location

```bash
# Check where it points
readlink -f ~/.claude/commands/golem-powers

# Fix it
rm ~/.claude/commands/golem-powers
ln -sf /correct/path/to/ralphtools/skills/golem-powers ~/.claude/commands/golem-powers
```

### Skills not loading in Claude

1. Restart Claude Code
2. Check skill format (needs frontmatter with name/description)
3. Verify file permissions

---

## Post-Validation

Once all checks pass:

1. **Restart Claude Code** to load skills
2. **Test a skill**: Type `/golem-powers:skills` in Claude
3. **Ready to use**: All golem-powers skills available

---

## Success Criteria

All these should be true:
- [ ] All 8 CLIs installed (gh, op, gum, fswatch, jq, git, bun, cr)
- [ ] 1Password signed in with vault access
- [ ] Context7 and Linear API keys stored in claude-golem item
- [ ] ~/.config/ralphtools/ exists
- [ ] golem-powers symlink created in ~/.claude/commands/
- [ ] `/golem-powers:skills` command works in Claude Code
