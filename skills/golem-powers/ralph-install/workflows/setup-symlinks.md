# Setup Symlinks Workflow

Create symlinks in ~/.claude/commands/ to enable golem-powers skills for Claude Code.

---

## Prerequisites

- claude-golem repository cloned
- ~/.claude/commands/ directory exists

---

## Create Commands Directory

```bash
mkdir -p ~/.claude/commands
```

---

## Symlink Golem-Powers (Recommended)

All skills are now under the `golem-powers` namespace. Create a single symlink:

```bash
#!/bin/bash
RALPHTOOLS_DIR="${RALPHTOOLS_DIR:-$HOME/path/to/claude-golem}"
COMMANDS_DIR="$HOME/.claude/commands"

echo "Creating golem-powers symlink..."
echo "Source: $RALPHTOOLS_DIR/skills/golem-powers"
echo "Target: $COMMANDS_DIR/golem-powers"
echo ""

# Create commands directory if missing
mkdir -p "$COMMANDS_DIR"

# Remove old individual skill symlinks if they exist
OLD_SKILLS=(1password archive brave coderabbit convex context7 critique-waves github linear prd ralph-install skills test-plan worktrees)
for skill in "${OLD_SKILLS[@]}"; do
  if [ -L "$COMMANDS_DIR/$skill" ] || [ -L "$COMMANDS_DIR/$skill.md" ]; then
    rm -f "$COMMANDS_DIR/$skill" "$COMMANDS_DIR/$skill.md"
    echo "[REMOVED] old symlink: $skill"
  fi
done

# Create the golem-powers symlink
ln -sf "$RALPHTOOLS_DIR/skills/golem-powers" "$COMMANDS_DIR/golem-powers"
echo "[OK] golem-powers symlink created"

echo ""
echo "Skills now available as /golem-powers:skill-name"
echo "Example: /golem-powers:1password, /golem-powers:convex, /golem-powers:github"
```

---

## Quick Setup (One-liner)

Replace `/path/to/claude-golem` with your actual path:

```bash
mkdir -p ~/.claude/commands && ln -sf /path/to/claude-golem/skills/golem-powers ~/.claude/commands/golem-powers
```

---

## Verify Symlink

Check that the symlink is correctly pointing:

```bash
ls -la ~/.claude/commands/golem-powers
```

Expected output:
```
golem-powers -> /Users/.../claude-golem/skills/golem-powers
```

List available skills:
```bash
ls ~/.claude/commands/golem-powers/
```

Expected:
```
1password/  archive/  brave/  coderabbit/  context7/  convex/  ...
```

---

## Test Skill Discovery

In a new Claude Code session, run:
```
/golem-powers:skills
```

Should list all available golem-powers skills.

---

## Remove Old Individual Symlinks

If you have old individual skill symlinks, remove them:

```bash
# List old symlinks
ls -la ~/.claude/commands/ | grep -E "1password|linear|convex|github|prd|skills"

# Remove old symlinks (one by one)
rm ~/.claude/commands/1password
rm ~/.claude/commands/linear
rm ~/.claude/commands/convex
# etc.
```

Or use this cleanup script:
```bash
#!/bin/bash
COMMANDS_DIR="$HOME/.claude/commands"
OLD_SKILLS=(1password archive brave coderabbit convex context7 critique-waves github linear prd ralph-install skills test-plan worktrees)

for skill in "${OLD_SKILLS[@]}"; do
  if [ -L "$COMMANDS_DIR/$skill" ]; then
    rm -f "$COMMANDS_DIR/$skill"
    echo "Removed: $skill"
  fi
  if [ -L "$COMMANDS_DIR/$skill.md" ]; then
    rm -f "$COMMANDS_DIR/$skill.md"
    echo "Removed: $skill.md"
  fi
done

echo "Old symlinks cleaned up"
```

---

## Troubleshooting

### Symlink broken (red in ls -la)

The source directory was moved. Recreate with correct path:
```bash
rm ~/.claude/commands/golem-powers
ln -sf /correct/path/to/claude-golem/skills/golem-powers ~/.claude/commands/golem-powers
```

### Skills not appearing in Claude

1. Check Claude Code version supports skills
2. Verify symlink target exists: `ls $(readlink ~/.claude/commands/golem-powers)`
3. Restart Claude Code session

### Permission denied

Fix permissions:
```bash
chmod 755 ~/.claude/commands
chmod -R 755 ~/.claude/commands/golem-powers
```

---

## Next Steps

After creating symlinks:
1. Run [validate](validate.md) to test the full installation
2. Try `/golem-powers:skills` in Claude Code to see available skills
