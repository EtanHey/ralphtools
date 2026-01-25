#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════
# RALPH-REGISTRY.ZSH - Project registry and launcher generation
# ═══════════════════════════════════════════════════════════════════
# Part of the Ralph modular architecture.
# Contains: Registry management, project config, MCP building, launchers.
#
# Dependencies: Requires RALPH_CONFIG_DIR, RALPH_REGISTRY_FILE to be set.
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# REGISTRY - Centralized Project/MCP Configuration
# ═══════════════════════════════════════════════════════════════════

RALPH_REGISTRY_FILE="${RALPH_CONFIG_DIR}/registry.json"

# Migrate existing configs to registry.json
# Sources: projects.json, shared-project-mcps.json, repo-claude-v2.zsh
# Usage: _ralph_migrate_to_registry [--force]
_ralph_migrate_to_registry() {
  setopt localoptions noxtrace  # Suppress debug output

  local force=false
  [[ "$1" == "--force" ]] && force=true

  local old_projects="$HOME/.config/ralphtools/projects.json"
  local shared_mcps="$HOME/.claude/shared-project-mcps.json"
  local repo_claude_v2="$HOME/.config/ralphtools/repo-claude-v2.zsh"
  local registry="$RALPH_REGISTRY_FILE"

  # Check if registry already exists
  if [[ -f "$registry" ]] && ! $force; then
    echo "Registry already exists at $registry"
    echo "Use --force to recreate from source configs"
    return 0
  fi

  # Initialize result variables
  local projects_json="{}"
  local global_mcps="{}"
  local mcp_definitions="{}"
  local has_sources=false

  echo "Migrating to registry.json..."

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 1: repo-claude-v2.zsh (REPO_CONFIGS_V2, SUPABASE_TOKENS, LINEAR_TOKENS)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$repo_claude_v2" ]]; then
    has_sources=true
    echo "  Found repo-claude-v2.zsh"

    # Source the file to get associative arrays
    # Create a subshell to avoid polluting current environment
    local v2_data
    v2_data=$(zsh -c "
      source '$repo_claude_v2' 2>/dev/null

      # Output MCP_UNIVERSAL as JSON
      echo '===MCP_UNIVERSAL==='
      for key val in \"\${(@kv)MCP_UNIVERSAL}\"; do
        # val can be JSON or command string
        if [[ \"\$val\" == '{'* ]]; then
          printf '%s\t%s\n' \"\$key\" \"\$val\"
        else
          # Convert command string to JSON (e.g., '--transport http figma ...')
          printf '%s\t{\"transport\": \"command\", \"value\": \"%s\"}\n' \"\$key\" \"\$val\"
        fi
      done

      # Output REPO_CONFIGS_V2 as JSON
      echo '===REPO_CONFIGS_V2==='
      for key val in \"\${(@kv)REPO_CONFIGS_V2}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done

      # Output SUPABASE_TOKENS
      echo '===SUPABASE_TOKENS==='
      for key val in \"\${(@kv)SUPABASE_TOKENS}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done

      # Output LINEAR_TOKENS
      echo '===LINEAR_TOKENS==='
      for key val in \"\${(@kv)LINEAR_TOKENS}\"; do
        printf '%s\t%s\n' \"\$key\" \"\$val\"
      done
    " 2>/dev/null)

    # Parse MCP_UNIVERSAL into mcpDefinitions
    local in_section=""
    local mcp_u_count=0
    local proj_count=0
    local sb_tokens=""
    local linear_tokens=""
    local repo_configs=""

    while IFS= read -r line; do
      case "$line" in
        "===MCP_UNIVERSAL===") in_section="mcp_universal" ;;
        "===REPO_CONFIGS_V2===") in_section="repo_configs" ;;
        "===SUPABASE_TOKENS===") in_section="supabase" ;;
        "===LINEAR_TOKENS===") in_section="linear" ;;
        *)
          [[ -z "$line" ]] && continue
          case "$in_section" in
            mcp_universal)
              local key="${line%%	*}"
              local val="${line#*	}"
              if [[ "$val" == '{'* ]]; then
                mcp_definitions=$(echo "$mcp_definitions" | jq --arg k "$key" --argjson v "$val" '.[$k] = $v')
                ((mcp_u_count++))
              fi
              ;;
            repo_configs)
              repo_configs+="$line"$'\n'
              ;;
            supabase)
              sb_tokens+="$line"$'\n'
              ;;
            linear)
              linear_tokens+="$line"$'\n'
              ;;
          esac
          ;;
      esac
    done <<< "$v2_data"

    echo "    Imported $mcp_u_count MCP definitions from MCP_UNIVERSAL"

    # Parse REPO_CONFIGS_V2 into projects
    # Format: "key|name|path|mcps_light|mcps_full"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local key="${line%%	*}"
      local config="${line#*	}"

      # Parse pipe-delimited config
      local proj_key=$(echo "$config" | cut -d'|' -f1)
      local proj_name=$(echo "$config" | cut -d'|' -f2)
      local proj_path=$(echo "$config" | cut -d'|' -f3)
      local mcps_light=$(echo "$config" | cut -d'|' -f4)
      local mcps_full=$(echo "$config" | cut -d'|' -f5)

      # Expand $HOME in path
      proj_path="${proj_path/\$HOME/$HOME}"

      # Convert comma-separated MCPs to JSON array
      local mcps_array="[]"
      if [[ -n "$mcps_full" ]]; then
        mcps_array=$(echo "$mcps_full" | tr ',' '\n' | jq -R . | jq -s .)
      fi

      # Build project entry
      local proj_entry=$(jq -n \
        --arg path "$proj_path" \
        --arg name "$proj_name" \
        --argjson mcps "$mcps_array" \
        --arg light "$mcps_light" \
        '{
          path: $path,
          displayName: $name,
          mcps: $mcps,
          mcpsLight: ($light | split(",") | map(select(. != ""))),
          secrets: {},
          created: (now | todate)
        }' 2>/dev/null)

      projects_json=$(echo "$projects_json" | jq --arg k "$proj_key" --argjson v "$proj_entry" '.[$k] = $v')
      ((proj_count++))
    done <<< "$repo_configs"

    echo "    Imported $proj_count projects from REPO_CONFIGS_V2"

    # Add SUPABASE_TOKENS to project secrets
    local sb_count=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local proj="${line%%	*}"
      local token="${line#*	}"

      # Add to project's secrets if project exists
      if echo "$projects_json" | jq -e --arg p "$proj" '.[$p]' >/dev/null 2>&1; then
        projects_json=$(echo "$projects_json" | jq --arg p "$proj" --arg t "$token" \
          '.[$p].secrets.SUPABASE_ACCESS_TOKEN = $t')
        ((sb_count++))
      fi
    done <<< "$sb_tokens"

    [[ $sb_count -gt 0 ]] && echo "    Added $sb_count Supabase tokens to project secrets"

    # Add LINEAR_TOKENS to project secrets
    local linear_count=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local proj="${line%%	*}"
      local token="${line#*	}"

      # Add to project's secrets if project exists
      if echo "$projects_json" | jq -e --arg p "$proj" '.[$p]' >/dev/null 2>&1; then
        projects_json=$(echo "$projects_json" | jq --arg p "$proj" --arg t "$token" \
          '.[$p].secrets.LINEAR_API_TOKEN = $t')
        ((linear_count++))
      fi
    done <<< "$linear_tokens"

    [[ $linear_count -gt 0 ]] && echo "    Added $linear_count Linear tokens to project secrets"
  fi

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 2: projects.json (legacy format)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$old_projects" ]]; then
    has_sources=true
    echo "  Found projects.json"

    # Convert projects array to object format, merge with existing
    local legacy_projects
    legacy_projects=$(jq -r '
      .projects // [] | map({(.name): {path: .path, mcps: (.mcps // []), secrets: {}, created: .created}}) | add // {}
    ' "$old_projects" 2>/dev/null)

    if [[ -n "$legacy_projects" && "$legacy_projects" != "null" ]]; then
      # Merge with priority to existing (from repo-claude-v2.zsh)
      projects_json=$(echo "$projects_json" "$legacy_projects" | jq -s '.[1] * .[0]')
      echo "    Merged projects from projects.json"
    fi
  fi

  # ═══════════════════════════════════════════════════════════════
  # SOURCE 3: shared-project-mcps.json (global MCPs)
  # ═══════════════════════════════════════════════════════════════
  if [[ -f "$shared_mcps" ]]; then
    has_sources=true
    echo "  Found shared-project-mcps.json"

    local shared_mcp_servers
    shared_mcp_servers=$(jq '.mcpServers // {}' "$shared_mcps" 2>/dev/null)

    if [[ -n "$shared_mcp_servers" && "$shared_mcp_servers" != "null" ]]; then
      global_mcps="$shared_mcp_servers"
      local mcp_count=$(echo "$global_mcps" | jq 'keys | length')
      echo "    Imported $mcp_count global MCPs"
    fi
  fi

  # ═══════════════════════════════════════════════════════════════
  # CREATE REGISTRY
  # ═══════════════════════════════════════════════════════════════
  if ! $has_sources; then
    echo "  No source configs found. Creating minimal registry."
  fi

  mkdir -p "$RALPH_CONFIG_DIR"
  jq -n \
    --arg version "1.0.0" \
    --argjson global_mcps "$global_mcps" \
    --argjson projects "$projects_json" \
    --argjson mcp_defs "$mcp_definitions" \
    '{
      version: $version,
      global: {
        mcps: $global_mcps
      },
      projects: $projects,
      mcpDefinitions: $mcp_defs
    }' > "$registry"

  local total_projects=$(echo "$projects_json" | jq 'keys | length')
  local total_mcps=$(echo "$mcp_definitions" | jq 'keys | length')

  echo ""
  echo "  Registry created at $registry"
  echo "     Projects: $total_projects | MCP Definitions: $total_mcps"
  return 0
}

# Load registry into memory (cached)
# Usage: _ralph_load_registry
_ralph_load_registry() {
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "Registry not found. Run '_ralph_migrate_to_registry' to initialize." >&2
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
    select(($path | startswith(.value.path | gsub("~"; env.HOME) | gsub("^~"; env.HOME)))) |
    {name: .key, config: .value}
  ' | head -1
}

# Get project name from current directory
# Usage: _ralph_current_project
_ralph_current_project() {
  local config=$(_ralph_get_project_config)
  [[ -n "$config" ]] && echo "$config" | jq -r '.name'
}

# Resolve op:// references in MCP env vars
# Usage: _ralph_resolve_mcp_secrets <mcp_json>
# Returns: MCP JSON with resolved secrets
_ralph_resolve_mcp_secrets() {
  local mcp_json="$1"

  # If op CLI not available, return as-is
  if ! command -v op &>/dev/null; then
    echo "$mcp_json"
    return 0
  fi

  # Check if there are any op:// references in env vars
  if ! echo "$mcp_json" | grep -q 'op://'; then
    echo "$mcp_json"
    return 0
  fi

  # Iterate through each MCP server and resolve op:// references in env
  local result="$mcp_json"
  local mcp_names=$(echo "$mcp_json" | jq -r 'keys[]')

  for mcp_name in ${(f)mcp_names}; do
    local env_vars=$(echo "$result" | jq -r --arg m "$mcp_name" '.[$m].env // {} | to_entries[] | "\(.key)=\(.value)"')
    for env_var in ${(f)env_vars}; do
      [[ -z "$env_var" ]] && continue
      local key="${env_var%%=*}"
      local val="${env_var#*=}"

      # Check if value is an op:// reference
      if [[ "$val" == op://* ]]; then
        local resolved=$(op read "$val" 2>/dev/null)
        if [[ -n "$resolved" ]]; then
          result=$(echo "$result" | jq --arg m "$mcp_name" --arg k "$key" --arg v "$resolved" '.[$m].env[$k] = $v')
        fi
      fi
    done
  done

  echo "$result"
}

# Build MCP config for a project (merges global + project MCPs)
# Usage: _ralph_build_mcp_config [project_name]
_ralph_build_mcp_config() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Get global MCPs and resolve op:// references
  local global_mcps=$(echo "$registry" | jq '.global.mcps // {}')
  global_mcps=$(_ralph_resolve_mcp_secrets "$global_mcps")

  # Get project-specific MCPs
  local project_mcps=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].mcps // [] | .[]
  ')

  # Get MCP definitions and resolve op:// references
  local mcp_defs=$(echo "$registry" | jq '.mcpDefinitions // {}')
  mcp_defs=$(_ralph_resolve_mcp_secrets "$mcp_defs")
  local project_secrets=$(echo "$registry" | jq --arg proj "$project_name" '
    .projects[$proj].secrets // {}
  ')

  # Merge: global + (project MCPs resolved from definitions)
  local result="$global_mcps"

  for mcp in ${(f)project_mcps}; do
    local mcp_def=$(echo "$mcp_defs" | jq --arg m "$mcp" '.[$m] // empty')

    # Handle special MCPs that require project-specific tokens
    if [[ -z "$mcp_def" ]]; then
      case "$mcp" in
        linear)
          # Build linear MCP config using project's LINEAR_API_TOKEN
          local linear_token=$(echo "$project_secrets" | jq -r '.LINEAR_API_TOKEN // empty')
          # Resolve op:// references via 1Password
          if [[ "$linear_token" == op://* ]] && command -v op &>/dev/null; then
            linear_token=$(op read "$linear_token" 2>/dev/null)
          fi
          if [[ -n "$linear_token" && "$linear_token" != "null" ]]; then
            mcp_def=$(jq -n --arg token "$linear_token" '{
              "command": "npx",
              "args": ["-y", "@tacticlaunch/mcp-linear"],
              "env": {"LINEAR_API_TOKEN": $token}
            }')
          fi
          ;;
        supabase)
          # Build supabase MCP config using project's SUPABASE_ACCESS_TOKEN
          local supabase_token=$(echo "$project_secrets" | jq -r '.SUPABASE_ACCESS_TOKEN // empty')
          # Resolve op:// references via 1Password
          if [[ "$supabase_token" == op://* ]] && command -v op &>/dev/null; then
            supabase_token=$(op read "$supabase_token" 2>/dev/null)
          fi
          if [[ -n "$supabase_token" && "$supabase_token" != "null" ]]; then
            mcp_def=$(jq -n --arg token "$supabase_token" '{
              "command": "npx",
              "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", $token]
            }')
          fi
          ;;
      esac
    fi

    if [[ -n "$mcp_def" ]]; then
      result=$(echo "$result" | jq --arg m "$mcp" --argjson def "$mcp_def" '.[$m] = $def')
    fi
  done

  echo "{\"mcpServers\": $result}"
}

# Inject secrets from 1Password into environment
# Usage: _ralph_inject_secrets [project_name]
_ralph_inject_secrets() {
  local project_name="${1:-$(_ralph_current_project)}"
  local registry=$(_ralph_load_registry) || return 1

  # Check if op CLI is available
  if ! command -v op &> /dev/null; then
    return 0  # No 1Password, skip silently
  fi

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

# Generate .env.1password file with op:// references for 1Password Environments
# Usage: _ralph_generate_env_1password [project_name] [output_path]
# This is used with 'op run --env-file' for secure secret injection
_ralph_generate_env_1password() {
  local project_name="${1:-$(_ralph_current_project)}"
  local output_path="${2:-/tmp/ralph-${project_name}.env.1password}"
  local registry=$(_ralph_load_registry) || return 1

  # Get project secrets (op:// references)
  local secrets=$(echo "$registry" | jq -r --arg proj "$project_name" '
    .projects[$proj].secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Also get global MCP secrets if any
  local global_secrets=$(echo "$registry" | jq -r '
    .global.mcps // {} | to_entries[] |
    .value.secrets // {} | to_entries[] |
    "\(.key)=\(.value)"
  ')

  # Write .env.1password file
  # Format: KEY=op://vault/item/field (already in registry)
  {
    echo "# Generated by Ralph for 1Password Environments"
    echo "# Use with: op run --env-file $output_path -- command"
    echo "# Project: $project_name"
    echo ""

    # Write project secrets
    if [[ -n "$secrets" ]]; then
      echo "# Project Secrets"
      echo "$secrets"
      echo ""
    fi

    # Write global secrets
    if [[ -n "$global_secrets" ]]; then
      echo "# Global MCP Secrets"
      echo "$global_secrets"
    fi
  } > "$output_path"

  echo "$output_path"
}

# Run parallel verification for V-* stories
# Spawns multiple agents with different viewport/focus prompts
# Usage: _ralph_run_parallel_verification "V-001" "/path/to/prd-json" "prompt_text"
_ralph_run_parallel_verification() {
  local story_id="$1"
  local prd_json_dir="$2"
  local base_prompt="$3"
  local num_agents="${RALPH_PARALLEL_AGENTS:-2}"

  # Temp directory for parallel agent results
  local temp_dir="/tmp/ralph_parallel_${story_id}_$$"
  mkdir -p "$temp_dir"

  local pids=()
  local agent_prompts=()

  # Define agent-specific prompts based on focus area
  # Agent 1: Desktop viewport (1920x1080)
  agent_prompts[1]="VIEWPORT FOCUS: Desktop (1920x1080). Verify all acceptance criteria at desktop resolution. Check layout, spacing, and interactions at full width.\n\n$base_prompt"

  # Agent 2: Mobile viewport (375x812)
  agent_prompts[2]="VIEWPORT FOCUS: Mobile (375x812 iPhone X). Verify all acceptance criteria at mobile resolution. Check responsive behavior, touch targets, and mobile-specific issues.\n\n$base_prompt"

  # Agent 3: Accessibility focus (if parallelAgents >= 3)
  agent_prompts[3]="ACCESSIBILITY FOCUS: Verify keyboard navigation, screen reader compatibility, color contrast, and ARIA labels. Check all acceptance criteria with accessibility in mind.\n\n$base_prompt"

  echo "  Running parallel verification with $num_agents agents..."

  # Spawn agents in parallel
  for ((agent=1; agent<=num_agents && agent<=3; agent++)); do
    local agent_prompt="${agent_prompts[$agent]}"
    local agent_output="$temp_dir/agent_${agent}.txt"

    (
      claude --chrome --dangerously-skip-permissions --model haiku \
        -p "$agent_prompt" > "$agent_output" 2>&1
    ) &
    pids+=($!)
    echo "    Agent $agent spawned (PID: ${pids[-1]})"
  done

  # Wait for all agents to complete
  echo "  Waiting for all agents to complete..."
  local failed_pids=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed_pids++))
    fi
  done

  # Aggregate results using dedicated function
  _ralph_aggregate_parallel_results "$temp_dir" "$num_agents" "$story_id" "$prd_json_dir"
  local result=$?

  # Cleanup temp directory
  rm -rf "$temp_dir"

  return $result
}

# Aggregate results from parallel verification agents
# Reads temp files, collects pass/fail status and failure reasons, logs to progress.txt
# Usage: _ralph_aggregate_parallel_results "/tmp/dir" num_agents "V-001" "/path/to/prd-json"
_ralph_aggregate_parallel_results() {
  local temp_dir="$1"
  local num_agents="$2"
  local story_id="$3"
  local prd_json_dir="$4"
  local progress_file="$prd_json_dir/../progress.txt"

  echo "  Aggregating parallel agent results..."

  local all_pass=true
  local agent_results=()
  local failure_reasons=()

  # Read results from each agent's temp file
  for ((agent=1; agent<=num_agents && agent<=3; agent++)); do
    local agent_output="$temp_dir/agent_${agent}.txt"

    if [[ -f "$agent_output" ]]; then
      if grep -q "<promise>COMPLETE</promise>" "$agent_output" 2>/dev/null; then
        echo "    Agent $agent: PASSED"
        agent_results+=("Agent $agent: PASSED")
      else
        echo "    Agent $agent: FAILED"
        agent_results+=("Agent $agent: FAILED")
        all_pass=false

        # Extract failure reason (look for BLOCKED or error messages)
        local reason=""
        if grep -q "BLOCKED" "$agent_output" 2>/dev/null; then
          reason=$(grep -o "BLOCKED:.*" "$agent_output" | head -1)
        elif grep -q "Error:" "$agent_output" 2>/dev/null; then
          reason=$(grep -o "Error:.*" "$agent_output" | head -1)
        else
          reason="No completion promise found"
        fi
        failure_reasons+=("Agent $agent: $reason")
      fi
    else
      echo "    Agent $agent: No output file"
      agent_results+=("Agent $agent: NO OUTPUT")
      all_pass=false
      failure_reasons+=("Agent $agent: Output file missing")
    fi
  done

  # Log which agents passed/failed to progress.txt
  if [[ -f "$progress_file" ]]; then
    echo "" >> "$progress_file"
    echo "### Parallel Verification Results for $story_id" >> "$progress_file"
    echo "- Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "$progress_file"
    echo "- Agents: $num_agents" >> "$progress_file"
    for result in "${agent_results[@]}"; do
      echo "  - $result" >> "$progress_file"
    done
    if [[ ${#failure_reasons[@]} -gt 0 ]]; then
      echo "- Failure Reasons:" >> "$progress_file"
      for reason in "${failure_reasons[@]}"; do
        echo "  - $reason" >> "$progress_file"
      done
    fi
  fi

  if $all_pass; then
    echo "  All parallel verification agents passed"
    return 0
  else
    echo "  Some parallel verification agents failed"
    # Display collected failure reasons
    if [[ ${#failure_reasons[@]} -gt 0 ]]; then
      echo "  Failure reasons:"
      for reason in "${failure_reasons[@]}"; do
        echo "    - $reason"
      done
    fi
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# REPOGENOM - Project launcher generator
# ═══════════════════════════════════════════════════════════════════

function repoGolem() {
  local name="$1"
  local path="$2"
  shift 2
  local mcps=("$@")

  # Validate inputs
  if [[ -z "$name" || -z "$path" ]]; then
    echo "Usage: repoGolem <name> <path> [mcp1 mcp2 ...]" >&2
    return 1
  fi

  # Expand ~ in path
  path="${path/#\~/$HOME}"

  # Capitalize first letter: domica -> Domica
  local capitalized_name="${(C)name[1]}${name[2,-1]}"
  # Lowercase: Domica -> domica
  local lowercase_name="${(L)name}"

  # Convert mcps array to JSON for _ralph_setup_mcps (no jq dependency)
  local mcps_json="[]"
  if [[ ${#mcps[@]} -gt 0 ]]; then
    local quoted_mcps=()
    for mcp in "${mcps[@]}"; do
      quoted_mcps+=("\"$mcp\"")
    done
    mcps_json="[${(j:,:)quoted_mcps}]"
  fi

  # Create run{Name} function
  eval "function run${capitalized_name}() {
    cd \"$path\" || return 1
    if [[ -f \"package.json\" ]]; then
      if [[ -f \"bun.lockb\" ]] || command -v bun &>/dev/null && grep -q '\"bun\"' package.json 2>/dev/null; then
        bun run dev
      else
        npm run dev
      fi
    else
      echo \"No package.json found in $path\"
      return 1
    fi
  }"

  # Create open{Name} function
  eval "function open${capitalized_name}() {
    cd \"$path\" || return 1
    echo \"Changed to: \$(pwd)\"
  }"

  # Create {name}Claude function with flag shortcuts
  eval "function ${lowercase_name}Claude() {
    local should_update=false
    local notify_mode=\"\"
    local claude_args=()
    local project_key=\"$lowercase_name\"
    local ntfy_topic=\"etans-${lowercase_name}Claude\"

    while [[ \$# -gt 0 ]]; do
      case \"\$1\" in
        -u|--update)
          should_update=true
          shift
          ;;
        -s|--skip-permissions)
          claude_args+=(\"--dangerously-skip-permissions\")
          shift
          ;;
        -c|--continue)
          claude_args+=(\"--continue\")
          shift
          ;;
        -QN|--quiet-notify)
          notify_mode=\"quiet\"
          shift
          ;;
        -SN|--simple-notify)
          notify_mode=\"simple\"
          shift
          ;;
        -VN|--verbose-notify)
          notify_mode=\"verbose\"
          shift
          ;;
        *)
          claude_args+=(\"\$1\")
          shift
          ;;
      esac
    done

    cd \"$path\" || return 1

    # Setup notifications
    rm -f \"/tmp/.claude_notify_config_\${project_key}.json\" 2>/dev/null
    if [[ -n \"\$notify_mode\" ]]; then
      local quiet_val=\"false\"
      local verbose_val=\"false\"
      [[ \"\$notify_mode\" == \"quiet\" ]] && quiet_val=\"true\"
      [[ \"\$notify_mode\" == \"verbose\" ]] && verbose_val=\"true\"
      echo \"{\\\"name\\\":\\\"${capitalized_name} Claude\\\",\\\"topic\\\":\\\"\${ntfy_topic}\\\",\\\"quiet\\\":\${quiet_val},\\\"verbose\\\":\${verbose_val},\\\"cwd\\\":\\\"$path\\\"}\" > \"/tmp/.claude_notify_config_\${project_key}.json\"
    fi

    if \$should_update; then
      echo \"Updating Claude Code...\"
      claude update
    fi

    _ralph_setup_mcps '$mcps_json'

    # Load contexts from registry
    local contexts_dir=\"\$HOME/.claude/contexts\"
    local registry=\"\$RALPH_REGISTRY_FILE\"
    if [[ -f \"\$registry\" ]]; then
      local ctx_list
      ctx_list=\$(jq -r --arg proj \"$lowercase_name\" '.projects[\$proj].contexts // [] | .[]' \"\$registry\" 2>/dev/null)
      for ctx in \${(f)ctx_list}; do
        local ctx_file=\"\${contexts_dir}/\${ctx}.md\"
        if [[ -f \"\$ctx_file\" ]]; then
          claude_args+=(\"--append-system-prompt\" \"\$(cat \"\$ctx_file\")\")
        fi
      done

      # Check if Chrome should be disabled for this project
      local disable_chrome
      disable_chrome=\$(jq -r --arg proj \"$lowercase_name\" '.projects[\$proj].disableChrome // false' \"\$registry\" 2>/dev/null)
      if [[ \"\$disable_chrome\" == \"true\" ]]; then
        claude_args+=(\"--no-chrome\")
      fi
    fi

    claude \"\${claude_args[@]}\"
  }"
}

# Generate launchers from registry (new registry-based function)
function _ralph_generate_launchers_from_registry() {
  local launchers_file="$HOME/.config/ralphtools/launchers.zsh"
  local GREEN='\033[0;32m'
  local NC='\033[0m'

  # Create config directory if needed
  /bin/mkdir -p "$HOME/.config/ralphtools"

  # Start with header
  cat > "$launchers_file" << 'HEADER'
# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED by Ralph - do not edit manually
# Regenerate with: _ralph_generate_launchers_from_registry
# ═══════════════════════════════════════════════════════════════════

HEADER

  # If no registry, create empty launchers
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    echo "# No registry found" >> "$launchers_file"
    return 0
  fi

  local project_count=$(jq '.projects | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
  if [[ "$project_count" -eq 0 ]]; then
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  # Generate repoGolem calls for each project
  jq -r '.projects | to_entries[] | "\(.key)|\(.value.path)|\(.value.mcps | join(" "))"' "$RALPH_REGISTRY_FILE" 2>/dev/null | while IFS='|' read -r name path mcps; do
    # Expand ~ in path
    path="${path/#\~/$HOME}"
    echo "repoGolem $name \"$path\" $mcps" >> "$launchers_file"
  done

  echo "${GREEN}Launchers regenerated: $launchers_file${NC}"
}

# First-run detection for ralph-setup
function _ralph_setup_first_run_check() {
  # Check if registry exists and has projects
  if [[ ! -f "$RALPH_REGISTRY_FILE" ]]; then
    return 0  # Needs setup
  fi

  local project_count=$(jq '.projects | length' "$RALPH_REGISTRY_FILE" 2>/dev/null || echo "0")
  if [[ "$project_count" -eq 0 ]]; then
    return 0  # Needs setup
  fi

  return 1  # Already set up
}

# Show first-run welcome and guide through setup
function _ralph_setup_welcome() {
  local GREEN='\033[0;32m'
  local YELLOW='\033[0;33m'
  local CYAN='\033[0;36m'
  local NC='\033[0m'

  echo ""
  echo "Welcome to Ralph!"
  echo ""
  echo "Let's set up your first project."
  echo ""

  if [[ $RALPH_HAS_GUM -eq 0 ]]; then
    if gum confirm "Would you like to run the setup wizard?"; then
      ralph-setup
    else
      echo ""
      echo "${YELLOW}You can run 'ralph-setup' later to configure Ralph.${NC}"
      echo ""
    fi
  else
    echo -n "Would you like to run the setup wizard? [Y/n]: "
    read setup_choice
    if [[ "$setup_choice" != [Nn]* ]]; then
      ralph-setup
    else
      echo ""
      echo "${YELLOW}You can run 'ralph-setup' later to configure Ralph.${NC}"
      echo ""
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════
# LAUNCHER GENERATION - Auto-generate project launcher functions
# ═══════════════════════════════════════════════════════════════════
# Generates: run{Name}(), open{Name}(), {name}Claude() for each project
# Output: ~/.config/ralphtools/launchers.zsh
# ═══════════════════════════════════════════════════════════════════

function _ralph_generate_launchers() {
  local projects_file="$HOME/.config/ralphtools/projects.json"
  local launchers_file="$HOME/.config/ralphtools/launchers.zsh"
  local GREEN='\033[0;32m'
  local NC='\033[0m'

  # Create config directory if needed
  /bin/mkdir -p "$HOME/.config/ralphtools"

  # Start with header
  cat > "$launchers_file" << 'HEADER'
# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED by Ralph - do not edit manually
# Regenerate with: _ralph_generate_launchers
# ═══════════════════════════════════════════════════════════════════

HEADER

  # If no projects file, create empty one
  if [[ ! -f "$projects_file" ]]; then
    echo '{"projects": []}' > "$projects_file"
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  local count=$(/usr/bin/jq '.projects | length' "$projects_file" 2>/dev/null || echo "0")
  if [[ "$count" -eq 0 ]]; then
    echo "# No projects registered" >> "$launchers_file"
    return 0
  fi

  # Generate functions for each project
  /usr/bin/jq -r '.projects[] | "\(.name)|\(.path)|\(.mcps | @json)"' "$projects_file" 2>/dev/null | while IFS='|' read -r name path mcps_json; do
    # Capitalize first letter for function names: myProject -> MyProject
    local capitalized_name="${(C)name[1]}${name[2,-1]}"
    # Lowercase name for {name}Claude: MyProject -> myproject
    local lowercase_name="${(L)name}"

    # run{Name}: cd to path and run dev server
    /bin/cat >> "$launchers_file" << EOF
# Project: $name
# Path: $path
# MCPs: $mcps_json

function run${capitalized_name}() {
  cd "$path" || return 1
  if [[ -f "package.json" ]]; then
    if [[ -f "bun.lockb" ]] || command -v bun &>/dev/null && grep -q '"bun"' package.json 2>/dev/null; then
      bun run dev
    else
      npm run dev
    fi
  else
    echo "No package.json found in $path"
    return 1
  fi
}

function open${capitalized_name}() {
  cd "$path" || return 1
  echo "Changed to: \$(pwd)"
}

function ${lowercase_name}Claude() {
  cd "$path" || return 1
  # Set up project-specific MCPs
  _ralph_setup_mcps '$mcps_json'
  claude "\$@"
}

EOF
  done

  echo "${GREEN}Launchers regenerated: $launchers_file${NC}"
}

# Source launchers on load
[[ -f "$HOME/.config/ralphtools/launchers.zsh" ]] && source "$HOME/.config/ralphtools/launchers.zsh"
