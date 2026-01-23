# Centralized Project/MCP Registry with 1Password Integration

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Single source of truth for project MCPs, secrets, and configuration - used by both interactive Claude sessions and Ralph automation.

**Architecture:** A `~/.config/ralphtools/registry.json` defines all projects, their MCPs, and 1Password secret references. Ralph and `{project}Claude` functions both read from this registry. A gum-based wizard (`ralph setup`) provides interactive configuration.

**Tech Stack:** zsh, jq, gum (interactive CLI), 1Password CLI (op), Claude Code MCP system

---

## Current State Analysis

### What Exists:
1. `~/.config/ralphtools/projects.json` - basic project list (name, path, mcps array)
2. `~/.claude/shared-project-mcps.json` - global MCPs (tempmail, Context7)
3. Manual `domicaClaude()`, `songClaude()` functions in `.zshrc` with hardcoded MCP logic
4. `_ralph_setup_mcps()` function in ralph.zsh
5. US-019 completed: 1Password organization with project/service nesting
6. US-020, US-022 blocked: waiting for registry architecture

### Problems:
1. **Duplication**: Each `{project}Claude` function duplicates MCP setup logic
2. **Ralph ignores project MCPs**: Just runs `claude --chrome` without project context
3. **No single source of truth**: MCPs scattered across .zshrc, projects.json, shared-project-mcps.json
4. **Manual maintenance**: Adding a project requires editing multiple files

---

## Target Architecture

### Registry Schema (`~/.config/ralphtools/registry.json`)

```json
{
  "$schema": "https://ralph.dev/schemas/registry.schema.json",
  "version": "1.0.0",
  "global": {
    "mcps": {
      "tempmail": {
        "command": "npx",
        "args": ["-y", "mcp-server-tempmail"],
        "secrets": {
          "TEMPMAIL_API_KEY": "op://Dev/_global/tempmail/api_key"
        }
      },
      "context7": {
        "command": "npx",
        "args": ["-y", "@upstash/context7-mcp"]
      }
    }
  },
  "projects": {
    "domica": {
      "path": "~/Desktop/Gits/domica",
      "mcps": ["supabase", "browser-tools"],
      "secrets": {
        "SUPABASE_URL": "op://Dev/domica/supabase/url",
        "SUPABASE_ANON_KEY": "op://Dev/domica/supabase/anon_key"
      },
      "ntfy_topic": "etans-domicaClaude"
    },
    "rudy": {
      "path": "~/Desktop/Gits/rudy-monorepo",
      "mcps": ["firebase"],
      "secrets": {
        "FIREBASE_PROJECT_ID": "op://Dev/rudy/firebase/project_id"
      }
    },
    "ralphtools": {
      "path": "~/Desktop/Gits/ralphtools",
      "mcps": [],
      "secrets": {}
    }
  },
  "mcpDefinitions": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server"],
      "requiredSecrets": ["SUPABASE_URL", "SUPABASE_ANON_KEY"]
    },
    "firebase": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-firebase"],
      "requiredSecrets": ["FIREBASE_PROJECT_ID"]
    },
    "browser-tools": {
      "command": "node",
      "args": ["~/Desktop/Gits/browser-tools-mcp/browser-tools-server/dist/index.js"]
    }
  }
}
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    ~/.config/ralphtools/registry.json           │
│                         (Single Source of Truth)                │
└─────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌───────────┐   ┌───────────┐   ┌───────────┐
            │   ralph   │   │ {project} │   │  ralph    │
            │  (loop)   │   │  Claude   │   │  setup    │
            └───────────┘   └───────────┘   └───────────┘
                    │               │               │
                    ▼               ▼               ▼
            ┌─────────────────────────────────────────┐
            │     _ralph_get_project_config()        │
            │     _ralph_build_mcp_env()             │
            │     _ralph_inject_secrets()            │
            └─────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌───────────┐   ┌───────────┐   ┌───────────┐
            │  Claude   │   │ 1Password │   │   .mcp    │
            │   Code    │   │   (op)    │   │   .json   │
            └───────────┘   └───────────┘   └───────────┘
```

---

## Implementation Tasks

### Task 1: Create Registry Schema and Migration

**Files:**
- Create: `~/.config/ralphtools/registry.json`
- Create: `schemas/registry.schema.json` (for validation)
- Modify: `ralph.zsh` - add registry loading

**Step 1: Create schema file**

```bash
# schemas/registry.schema.json
```

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "global", "projects", "mcpDefinitions"],
  "properties": {
    "version": { "type": "string" },
    "global": {
      "type": "object",
      "properties": {
        "mcps": { "type": "object" }
      }
    },
    "projects": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["path"],
        "properties": {
          "path": { "type": "string" },
          "mcps": { "type": "array", "items": { "type": "string" } },
          "secrets": { "type": "object" },
          "ntfy_topic": { "type": "string" }
        }
      }
    },
    "mcpDefinitions": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["command"],
        "properties": {
          "command": { "type": "string" },
          "args": { "type": "array" },
          "requiredSecrets": { "type": "array" }
        }
      }
    }
  }
}
```

**Step 2: Create initial registry from existing data**

```zsh
# Run this to migrate existing projects.json → registry.json
_ralph_migrate_to_registry() {
  local old_projects="$HOME/.config/ralphtools/projects.json"
  local shared_mcps="$HOME/.claude/shared-project-mcps.json"
  local registry="$HOME/.config/ralphtools/registry.json"

  # Build registry JSON
  jq -n \
    --argjson projects "$(cat "$old_projects")" \
    --argjson shared "$(cat "$shared_mcps")" \
    '{
      version: "1.0.0",
      global: { mcps: $shared.mcpServers },
      projects: ($projects.projects | map({(.name): {path: .path, mcps: .mcps, secrets: {}}}) | add),
      mcpDefinitions: {}
    }' > "$registry"
}
```

**Step 3: Commit**

```bash
git add schemas/registry.schema.json
git commit -m "feat: add registry schema for centralized MCP config"
```

---

### Task 2: Core Registry Functions

**Files:**
- Modify: `ralph.zsh` - add registry functions

**Step 1: Add registry loading function**

```zsh
# ═══════════════════════════════════════════════════════════════════
# REGISTRY - Centralized Project/MCP Configuration
# ═══════════════════════════════════════════════════════════════════

RALPH_REGISTRY_FILE="${RALPH_CONFIG_DIR}/registry.json"

# Load registry into memory (cached)
_ralph_load_registry() {
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "Registry not found. Run 'ralph setup' to initialize." >&2
    return 1
  fi
  cat "$RALPH_REGISTRY_FILE"
}

# Get project config by path (auto-detects current project)
# Usage: _ralph_get_project_config [path]
_ralph_get_project_config() {
  local search_path="${1:-$(pwd)}"
  search_path="${search_path:A}"  # Resolve to absolute

  local registry=$(_ralph_load_registry) || return 1

  # Find project matching this path
  echo "$registry" | jq -r --arg path "$search_path" '
    .projects | to_entries[] |
    select(($path | startswith(.value.path | gsub("~"; env.HOME)))) |
    {name: .key, config: .value}
  ' | head -1
}

# Get project name from current directory
_ralph_current_project() {
  local config=$(_ralph_get_project_config)
  [[ -n "$config" ]] && echo "$config" | jq -r '.name'
}
```

**Step 2: Add MCP building function**

```zsh
# Build MCP config for a project (merges global + project MCPs)
# Returns JSON suitable for .mcp.json or --mcp-config
_ralph_build_mcp_config() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Get global MCPs
  local global_mcps=$(echo "$registry" | jq '.global.mcps // {}')

  # Get project-specific MCPs
  local project_mcps=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].mcps // [] | .[]
  ')

  # Get MCP definitions and build final config
  local mcp_defs=$(echo "$registry" | jq '.mcpDefinitions // {}')
  local project_secrets=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].secrets // {}
  ')

  # Merge: global + (project MCPs resolved from definitions)
  local result="$global_mcps"

  for mcp in ${(f)project_mcps}; do
    local mcp_def=$(echo "$mcp_defs" | jq --arg m "$mcp" '.[$m] // empty')
    if [[ -n "$mcp_def" ]]; then
      result=$(echo "$result" | jq --arg m "$mcp" --argjson def "$mcp_def" '.[$m] = $def')
    fi
  done

  echo "{\"mcpServers\": $result}"
}
```

**Step 3: Add secret injection function**

```zsh
# Inject secrets from 1Password into environment
# Usage: _ralph_inject_secrets [project_name]
_ralph_inject_secrets() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Get project secrets (op:// references)
  local secrets=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Resolve each secret via op
  local resolved=()
  for secret in ${(f)secrets}; do
    local key="${secret%%=*}"
    local op_ref="${secret#*=}"

    if [[ "$op_ref" == op://* ]]; then
      local value=$(op read "$op_ref" 2>/dev/null)
      if [[ -n "$value" ]]; then
        resolved+=("$key=$value")
      else
        echo "Warning: Could not resolve $key from 1Password" >&2
      fi
    else
      resolved+=("$key=$op_ref")  # Plain value, not op://
    fi
  done

  # Export resolved secrets
  for kv in "${resolved[@]}"; do
    export "${kv%%=*}=${kv#*=}"
  done
}
```

**Step 4: Commit**

```bash
git add ralph.zsh
git commit -m "feat: add core registry functions for project/MCP lookup"
```

---

### Task 3: Update Ralph to Use Registry

**Files:**
- Modify: `ralph.zsh` - update main loop to use registry

**Step 1: Add project detection to ralph()**

Find the section where `cli_cmd_arr` is built and add registry integration:

```zsh
# In ralph() function, after determining the model, before building CLI command:

# Detect current project from registry
local current_project=$(_ralph_current_project)
if [[ -n "$current_project" ]]; then
  echo "📦 Project: $current_project"

  # Build project-specific MCP config
  local mcp_config=$(_ralph_build_mcp_config "$current_project")

  # Write temporary .mcp.json for this session
  local temp_mcp_file="/tmp/ralph-mcp-${current_project}-$$.json"
  echo "$mcp_config" > "$temp_mcp_file"

  # Inject secrets from 1Password (if configured)
  _ralph_inject_secrets "$current_project"
fi
```

**Step 2: Update CLI command to use MCP config**

```zsh
# When building cli_cmd_arr, add MCP config if available:
if [[ -n "$temp_mcp_file" && -f "$temp_mcp_file" ]]; then
  cli_cmd_arr+=(--mcp-config "$temp_mcp_file")
fi
```

**Step 3: Commit**

```bash
git add ralph.zsh
git commit -m "feat: Ralph uses registry for project-specific MCPs"
```

---

### Task 4: Create `ralph setup` Wizard

**Files:**
- Modify: `ralph.zsh` - add `ralph-setup` function

**Step 1: Create interactive setup function**

```zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH SETUP - Interactive Project/MCP Configuration Wizard
# ═══════════════════════════════════════════════════════════════════

ralph-setup() {
  _ralph_check_gum || return 1

  local registry_file="$RALPH_REGISTRY_FILE"

  echo ""
  gum style --border normal --padding "1 2" --border-foreground 212 \
    "🔧 Ralph Setup Wizard" \
    "Configure projects, MCPs, and 1Password integration"
  echo ""

  # Menu
  local choice=$(gum choose \
    "Add new project" \
    "Configure existing project" \
    "Manage MCP definitions" \
    "Setup 1Password integration" \
    "View current registry" \
    "Exit")

  case "$choice" in
    "Add new project")
      _ralph_setup_add_project
      ;;
    "Configure existing project")
      _ralph_setup_configure_project
      ;;
    "Manage MCP definitions")
      _ralph_setup_manage_mcps
      ;;
    "Setup 1Password integration")
      _ralph_setup_1password
      ;;
    "View current registry")
      _ralph_setup_view_registry
      ;;
    *)
      return 0
      ;;
  esac
}

_ralph_setup_add_project() {
  echo ""

  # Auto-detect from current directory
  local detected_path=$(pwd)
  local detected_name=$(basename "$detected_path")

  gum style --foreground 212 "Detected: $detected_name ($detected_path)"
  echo ""

  # Confirm or change
  local project_name=$(gum input --placeholder "$detected_name" --prompt "Project name: " --value "$detected_name")
  local project_path=$(gum input --placeholder "$detected_path" --prompt "Project path: " --value "$detected_path")

  # Select MCPs
  local available_mcps=$(jq -r '.mcpDefinitions | keys[]' "$RALPH_REGISTRY_FILE" 2>/dev/null)
  if [[ -n "$available_mcps" ]]; then
    echo ""
    gum style --foreground 212 "Select MCPs for this project:"
    local selected_mcps=$(echo "$available_mcps" | gum choose --no-limit)
  fi

  # Check for .env file
  local secrets="{}"
  if [[ -f "$project_path/.env" ]]; then
    echo ""
    if gum confirm "Found .env file. Migrate secrets to 1Password?"; then
      secrets=$(_ralph_setup_scan_env "$project_path/.env" "$project_name")
    fi
  fi

  # Build project config
  local mcps_json="[]"
  [[ -n "$selected_mcps" ]] && mcps_json=$(echo "$selected_mcps" | jq -R -s 'split("\n") | map(select(. != ""))')

  # Add to registry
  local registry=$(cat "$RALPH_REGISTRY_FILE")
  echo "$registry" | jq --arg name "$project_name" \
    --arg path "$project_path" \
    --argjson mcps "$mcps_json" \
    --argjson secrets "$secrets" \
    '.projects[$name] = {path: $path, mcps: $mcps, secrets: $secrets}' \
    > "$RALPH_REGISTRY_FILE"

  echo ""
  gum style --foreground 46 "✓ Added project: $project_name"
}

_ralph_setup_scan_env() {
  local env_file="$1"
  local project_name="$2"
  local secrets="{}"

  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue

    # Detect service from key prefix
    local service=$(_ralph_detect_service "$key")
    local normalized=$(_ralph_normalize_key "$key")

    # Build op:// reference
    local op_ref="op://Dev/${project_name}/${service}/${normalized}"

    secrets=$(echo "$secrets" | jq --arg k "$key" --arg v "$op_ref" '.[$k] = $v')
  done < "$env_file"

  echo "$secrets"
}
```

**Step 2: Add MCP definition management**

```zsh
_ralph_setup_manage_mcps() {
  echo ""
  gum style --foreground 212 "Manage MCP Definitions"
  echo ""

  local choice=$(gum choose "Add new MCP" "View definitions" "Back")

  case "$choice" in
    "Add new MCP")
      local mcp_name=$(gum input --prompt "MCP name: " --placeholder "supabase")
      local mcp_command=$(gum input --prompt "Command: " --placeholder "npx")
      local mcp_args=$(gum input --prompt "Args (comma-separated): " --placeholder "-y,@supabase/mcp-server")

      # Convert args to JSON array
      local args_json=$(echo "$mcp_args" | tr ',' '\n' | jq -R -s 'split("\n") | map(select(. != ""))')

      # Add to registry
      local registry=$(cat "$RALPH_REGISTRY_FILE")
      echo "$registry" | jq --arg name "$mcp_name" \
        --arg cmd "$mcp_command" \
        --argjson args "$args_json" \
        '.mcpDefinitions[$name] = {command: $cmd, args: $args}' \
        > "$RALPH_REGISTRY_FILE"

      gum style --foreground 46 "✓ Added MCP: $mcp_name"
      ;;
    "View definitions")
      jq '.mcpDefinitions' "$RALPH_REGISTRY_FILE" | gum pager
      ;;
  esac
}
```

**Step 3: Commit**

```bash
git add ralph.zsh
git commit -m "feat: add ralph-setup wizard for interactive configuration"
```

---

### Task 5: Generate Unified `{project}Claude` Functions

**Files:**
- Modify: `ralph.zsh` - update `_ralph_generate_launchers`

**Step 1: Update launcher generation to use registry**

```zsh
_ralph_generate_launchers() {
  local launchers_file="$HOME/.config/ralphtools/launchers.zsh"
  local registry=$(_ralph_load_registry) || return 1

  cat > "$launchers_file" << 'HEADER'
# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED by Ralph Registry - do not edit manually
# Regenerate with: _ralph_generate_launchers
# ═══════════════════════════════════════════════════════════════════

HEADER

  # Generate function for each project
  local projects=$(echo "$registry" | jq -r '.projects | keys[]')

  for project in ${(f)projects}; do
    local config=$(echo "$registry" | jq --arg p "$project" '.projects[$p]')
    local path=$(echo "$config" | jq -r '.path' | sed "s|~|$HOME|")
    local ntfy=$(echo "$config" | jq -r '.ntfy_topic // empty')

    cat >> "$launchers_file" << EOF

# ═══════════════════════════════════════════════════════════════════
# ${project}Claude - Auto-generated from registry
# ═══════════════════════════════════════════════════════════════════
function ${project}Claude() {
  cd "$path" || return 1

  # Load project MCPs from registry
  local mcp_config=\$(_ralph_build_mcp_config "$project")
  local temp_mcp="/tmp/${project}-mcp-\$\$.json"
  echo "\$mcp_config" > "\$temp_mcp"

  # Inject secrets from 1Password
  _ralph_inject_secrets "$project"

  # Run Claude with project config
  claude --mcp-config "\$temp_mcp" "\$@"

  # Cleanup
  rm -f "\$temp_mcp"
}

function open${project^}() {
  cd "$path" || return 1
  echo "Changed to: \$(pwd)"
}

function run${project^}() {
  cd "$path" || return 1
  if [[ -f "package.json" ]]; then
    npm run dev
  else
    echo "No package.json found"
  fi
}
EOF
  done

  echo "✓ Generated launchers for $(echo "$projects" | wc -l | tr -d ' ') projects"
}
```

**Step 2: Commit**

```bash
git add ralph.zsh
git commit -m "feat: auto-generate {project}Claude functions from registry"
```

---

### Task 6: Update Stories and Dependencies

**Files:**
- Modify: `prd-json/stories/US-022.json` - update to reference this plan
- Create: `prd-json/stories/US-025.json` through `US-028.json`

**Step 1: Create implementation stories**

```json
// US-025.json
{
  "id": "US-025",
  "title": "Create registry schema and migration",
  "description": "Create registry.json schema and migrate existing projects.json + shared-project-mcps.json into unified registry format.",
  "acceptanceCriteria": [
    { "text": "Create schemas/registry.schema.json with validation rules", "checked": false },
    { "text": "Create _ralph_migrate_to_registry() function", "checked": false },
    { "text": "Migration preserves all existing project data", "checked": false },
    { "text": "Registry includes version field for future migrations", "checked": false },
    { "text": "Typecheck passes (zsh -n ralph.zsh)", "checked": false }
  ],
  "passes": false,
  "blockedBy": null
}
```

```json
// US-026.json
{
  "id": "US-026",
  "title": "Core registry functions",
  "description": "Add _ralph_load_registry, _ralph_get_project_config, _ralph_build_mcp_config, _ralph_inject_secrets functions.",
  "acceptanceCriteria": [
    { "text": "_ralph_load_registry() loads and caches registry.json", "checked": false },
    { "text": "_ralph_get_project_config() finds project by path", "checked": false },
    { "text": "_ralph_current_project() returns project name for cwd", "checked": false },
    { "text": "_ralph_build_mcp_config() merges global + project MCPs", "checked": false },
    { "text": "_ralph_inject_secrets() resolves op:// refs and exports", "checked": false },
    { "text": "Typecheck passes (zsh -n ralph.zsh)", "checked": false }
  ],
  "passes": false,
  "blockedBy": "US-025"
}
```

```json
// US-027.json
{
  "id": "US-027",
  "title": "Ralph uses registry for MCPs",
  "description": "Update ralph() main loop to detect project, build MCP config, inject secrets before spawning Claude.",
  "acceptanceCriteria": [
    { "text": "Ralph detects current project from registry", "checked": false },
    { "text": "Ralph builds project-specific .mcp.json", "checked": false },
    { "text": "Ralph passes --mcp-config to claude CLI", "checked": false },
    { "text": "Ralph calls _ralph_inject_secrets before each iteration", "checked": false },
    { "text": "Shows '📦 Project: {name}' in startup output", "checked": false },
    { "text": "Typecheck passes (zsh -n ralph.zsh)", "checked": false }
  ],
  "passes": false,
  "blockedBy": "US-026"
}
```

```json
// US-028.json
{
  "id": "US-028",
  "title": "ralph-setup wizard with gum",
  "description": "Interactive wizard for adding projects, configuring MCPs, and setting up 1Password integration.",
  "acceptanceCriteria": [
    { "text": "ralph-setup command launches gum menu", "checked": false },
    { "text": "Add new project: auto-detects path, name from cwd", "checked": false },
    { "text": "Configure project: select MCPs from mcpDefinitions", "checked": false },
    { "text": "Scan .env: offers to migrate to 1Password refs", "checked": false },
    { "text": "Manage MCPs: add new MCP definitions", "checked": false },
    { "text": "View registry: pretty-print current config", "checked": false },
    { "text": "Typecheck passes (zsh -n ralph.zsh)", "checked": false }
  ],
  "passes": false,
  "blockedBy": "US-026"
}
```

**Step 2: Update US-022 to reference this plan**

```json
{
  "id": "US-022",
  "title": "Plan 1Password wizard architecture",
  "description": "COMPLETED - See docs/plans/2026-01-23-centralized-mcp-registry.md",
  "passes": true,
  "blockedBy": null
}
```

**Step 3: Commit**

```bash
git add prd-json/stories/*.json docs/plans/
git commit -m "feat: add centralized MCP registry implementation stories"
```

---

## Story Dependency Graph

```
US-025 (Registry schema)
    │
    ▼
US-026 (Core functions)
    │
    ├──────────┬──────────┐
    ▼          ▼          ▼
US-027     US-028     US-020
(Ralph)    (Wizard)   (list/search)
                          │
                          ▼
                      V-006
                    (verify)
```

## Migration Path

1. **US-025**: Create registry, migrate existing data
2. **US-026**: Core functions work with registry
3. **US-027**: Ralph uses registry (MCPs work in automation)
4. **US-028**: Wizard for easy setup (users can configure)
5. **US-020**: List/search secrets (was blocked, now unblocked)
6. **Deprecate**: Remove old `projects.json`, update `shared-project-mcps.json` to just be a symlink or auto-generated

## What Changes for Users

**Before:**
```bash
# Manual setup in .zshrc
function domicaClaude() {
  # 50+ lines of boilerplate per project
}
```

**After:**
```bash
# One-time setup
$ ralph setup
? Project name: domica
? Select MCPs: [x] supabase  [x] browser-tools
? Migrate .env to 1Password? Yes
✓ Added project: domica

# Now works everywhere
$ cd ~/Desktop/Gits/domica
$ domicaClaude        # Uses registry
$ ralph               # Uses same registry
```
