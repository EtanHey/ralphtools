# Skill: Brave Browser Management

You have access to a custom browser management tool.
**Tool Path:** `node $HOME/.config/ralph/scripts/brave-manager.js` (Absolute Path)

### Available Commands
- **tabs**: List URLs of all open tabs.
- **switch <index>**: Focus a specific tab.
- **audit <url>**: Full page load with console logs and network requests.
- **screenshot <url>**: Save full-page visual to `screenshot.png`.
- **click <selector>**: Click element on current page.
- **type <selector> <text>**: Input text.
- **html**: Output the full DOM structure.
- **hover <selector>**: Trigger hover state.
- **scroll <up|down>**: Move viewport.

### Usage Rule
Use these commands via `run_shell_command` when you need to verify UI, logs, or network in Brave. The tool is globally accessible via the absolute path above.