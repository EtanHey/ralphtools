# Skill: Brave Browser Management (Advanced v2.2.0)

> **Primary tool for Kiro and Gemini CLI.** Claude Code should prefer Claude-in-Chrome MCP first, then use brave-manager as fallback if needed.

You have access to a custom browser management tool.
**Global Command:** `brave-manager <command> [args]`

### Navigation & State
- **tabs**: List URLs of all open tabs.
- **switch <index>**: Focus a specific tab.
- **navigate <url>**: Go directly to a page.
- **back / forward**: Navigate through browser history.
- **eval "<code>"**: Run JS to check `localStorage`, `sessionStorage`, or page state.
- **errors**: Show only the last 5 network/console errors (4xx/5xx).

### Inspection & Interaction (ID-BASED)
- **inspect**: (REQUIRED FIRST) Get a numbered list of all interactive elements. Draws red labels on the page.
- **click <id>**: Click element by its ID (e.g., `click 5`).
- **type <id> "<text>"`: Type into element by its ID.
- **hover <id>**: Trigger hover state on an element.
- **scroll <up|down|id>**: Scroll the page. Use an ID to scroll a specific element into view.
- **press <key>**: Press a keyboard key (e.g., `Enter`, `Escape`, `Tab`).
- **drag <from_id> <to_id>**: Drag one element onto another.
- **screenshot**: Save visual state to `screenshot.png` (labels included).

### Advanced Workflow
1. **Always `inspect`**: Before any interaction, run `inspect` to map the current UI IDs.
2. **Handle Lists**: If an element is off-screen, use `scroll <id>` to bring it to the center.
3. **Complex Forms**: Type into multiple fields, then `press Enter` or `click` the submit ID.
4. **Drag & Drop**: Use `drag` for reordering lists or moving items if the UI supports it.
5. **Verify Deeply**: After an action, use `eval` to check if backend-driven state (like cookies or storage) updated correctly.