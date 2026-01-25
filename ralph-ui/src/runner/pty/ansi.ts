/**
 * ANSI Utilities - ANSI escape code handling
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * Provides:
 * - ANSI code stripping for clean log files
 * - ANSI code detection for event tagging
 */

// AIDEV-NOTE: This regex handles a wide range of ANSI escape sequences:
// - SGR (Select Graphic Rendition) for colors/styles: \x1b[...m
// - Cursor movement: \x1b[...A/B/C/D/H/J/K etc
// - OSC (Operating System Commands) for hyperlinks: \x1b]...\x07 or \x1b]...\x1b\\
// - DCS/PM/APC sequences: \x1b[PX^_]...\x1b\\
// - Simple escape sequences: \x1b followed by single char

// Comprehensive ANSI escape code pattern
const ANSI_REGEX =
  /\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?(?:\x07|\x1b\\)|\x1b[PX^_].*?\x1b\\|\x1b./g;

// Simple pattern for detection (faster, checks for common CSI sequences)
const ANSI_DETECT_REGEX = /\x1b\[[0-9;]*[a-zA-Z]/;

/**
 * Strips all ANSI escape codes from text
 * Used for creating clean log files
 *
 * @param text - Text potentially containing ANSI codes
 * @returns Text with all ANSI codes removed
 */
export function stripAnsi(text: string): string {
  return text.replace(ANSI_REGEX, "");
}

/**
 * Checks if text contains any ANSI escape codes
 * Used for tagging events with `ansi: true/false`
 *
 * @param text - Text to check
 * @returns True if text contains ANSI codes
 */
export function hasAnsiCodes(text: string): boolean {
  return ANSI_DETECT_REGEX.test(text);
}
