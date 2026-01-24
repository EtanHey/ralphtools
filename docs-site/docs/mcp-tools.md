---
sidebar_position: 8
title: MCP Tools
---

# MCP Tools Reference

Ralph can use MCP (Model Context Protocol) tools for enhanced verification. MCPs are optional but recommended for visual/browser testing.

## Available Tools

| Tool | Use Case | Source |
|------|----------|--------|
| **Claude in Chrome** | Browser automation, screenshots, clicking, form filling | [Claude Code Docs](https://code.claude.com/docs/en/chrome) |
| **Browser Tools** | Console logs, network errors, accessibility audits | [AgentDeskAI/browser-tools-mcp](https://github.com/AgentDeskAI/browser-tools-mcp) |
| **Context7** | Up-to-date library documentation lookup | [upstash/context7](https://github.com/upstash/context7) |
| **Figma MCP** | Compare implementation vs Figma designs | [Figma MCP Guide](https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server) |
| **Brave Manager** | Fallback browser automation (Local) | `scripts/brave-manager.js` |

## Setup Instructions

### Claude in Chrome (built into Claude Code)

1. Install the [Claude in Chrome extension](https://chromewebstore.google.com/detail/claude-in-chrome/) from Chrome Web Store
2. Open Chrome and Claude Code - they connect automatically
3. See [full docs](https://code.claude.com/docs/en/chrome) for details

### Browser Tools (console logs, audits)

```bash
# Install the Chrome extension from:
# https://github.com/AgentDeskAI/browser-tools-mcp

# Add to Claude Code:
claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@latest
```

### Context7 (library documentation)

```bash
# Add to Claude Code (requires API key from upstash.com):
claude mcp add context7 -- npx -y @upstash/context7-mcp

# Usage: Add "use context7" to prompts for up-to-date docs
```

### Figma MCP (design comparison)

```bash
# Add Figma's official remote server:
claude mcp add --transport http figma https://mcp.figma.com/mcp

# Or install the plugin:
claude plugin install figma@claude-plugins-official

# Requires Figma account - see setup guide above
```

### Brave Browser Manager (Internal Fallback)

This tool is a repository-local fallback for when standard browser MCPs (like `claude-in-chrome`) are unavailable or incompatible. It uses Puppeteer to control a live Brave browser.

**Requirements:**
- Brave Browser installed at `/Applications/Brave Browser.app`
- Node.js and `puppeteer` installed (`npm install` in project root)

**How to use:**
Ralph is automatically configured to use this tool via the `Skill: Brave Browser Management` injected into the system prompt. It can perform:
- Tab switching
- DOM inspection (`html`)
- Interactions (`click`, `type`, `hover`)
- Auditing (Console logs + Network activity)
- Screenshots

## Browser Verification Protocol

### Setup

Open two Chrome tabs before running Ralph:
- **Tab 1:** Desktop viewport (1440px+)
- **Tab 2:** Mobile viewport (375px)

### How It Works

At each iteration start, Ralph:
1. Calls `mcp__claude-in-chrome__tabs_context_mcp`
2. Reports: "✓ Browser tabs available" or "⚠️ Not available"
3. If not available: marks browser steps as BLOCKED, continues other work

### Rules

- **Never resize viewport** — use the correct tab
- **Always `left_click`** — never `right_click`
- **Take screenshots** to verify visual changes
- **Check console** for errors

:::note
Ralph works without MCPs, but browser verification stories (V-XXX) require Claude in Chrome or Browser Tools to take screenshots and verify UI.
:::

## Troubleshooting

### Claude in Chrome "Not Connected" (Claude Desktop Conflict)

**Symptom:** `tabs_context_mcp` fails with "extension not connected" even though the extension is installed.

**Cause:** Claude Desktop and Claude Code both register Chrome Native Messaging hosts. Desktop's config takes precedence alphabetically, blocking CLI access.

**Fix:**
```bash
cd ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/
mv com.anthropic.claude_browser_extension.json com.anthropic.claude_browser_extension.json.bak
# Restart Claude Code and browser
```

**To restore Desktop:** Rename `.bak` back to `.json`.
