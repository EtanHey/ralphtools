import { useEffect, useRef } from 'react';
import { useStdout } from 'ink';

/**
 * ANSI escape codes for cursor control
 */
export const ANSI = {
  // Cursor movement
  up: (n: number) => `\x1b[${n}A`,
  down: (n: number) => `\x1b[${n}B`,
  right: (n: number) => `\x1b[${n}C`,
  left: (n: number) => `\x1b[${n}D`,

  // Cursor position
  moveTo: (row: number, col: number) => `\x1b[${row};${col}H`,
  savePosition: '\x1b[s',
  restorePosition: '\x1b[u',

  // Line control
  clearLine: '\x1b[2K',
  clearToEndOfLine: '\x1b[K',
  clearScreen: '\x1b[2J',

  // Hide/show cursor
  hideCursor: '\x1b[?25l',
  showCursor: '\x1b[?25h',
};

/**
 * Hook for managing cursor position for in-place updates
 * Prevents scrolling by moving cursor back up before re-rendering
 */
export function useCursor() {
  const { stdout } = useStdout();
  const linesRenderedRef = useRef(0);

  const saveLines = (lineCount: number) => {
    linesRenderedRef.current = lineCount;
  };

  const moveUp = () => {
    if (stdout && linesRenderedRef.current > 0) {
      stdout.write(ANSI.up(linesRenderedRef.current));
    }
  };

  const clearAndMoveUp = () => {
    if (stdout && linesRenderedRef.current > 0) {
      // Move to start of rendered content and clear each line
      for (let i = 0; i < linesRenderedRef.current; i++) {
        stdout.write(ANSI.clearLine);
        if (i < linesRenderedRef.current - 1) {
          stdout.write(ANSI.down(1));
        }
      }
      // Move back up
      stdout.write(ANSI.up(linesRenderedRef.current));
    }
  };

  const hideCursor = () => {
    stdout?.write(ANSI.hideCursor);
  };

  const showCursor = () => {
    stdout?.write(ANSI.showCursor);
  };

  return {
    saveLines,
    moveUp,
    clearAndMoveUp,
    hideCursor,
    showCursor,
    linesRendered: linesRenderedRef.current,
  };
}

/**
 * Hook for in-place rendering (no scroll)
 * Automatically manages cursor position to update content in place
 */
export function useInPlaceRender(lineCount: number) {
  const { stdout } = useStdout();
  const initializedRef = useRef(false);
  const previousLineCountRef = useRef(0);

  useEffect(() => {
    if (!stdout) return;

    if (initializedRef.current && previousLineCountRef.current > 0) {
      // Move cursor back up to overwrite previous content
      stdout.write(ANSI.up(previousLineCountRef.current));
    }

    initializedRef.current = true;
    previousLineCountRef.current = lineCount;

    return () => {
      // Show cursor on unmount
      stdout.write(ANSI.showCursor);
    };
  }, [lineCount, stdout]);

  return {
    hideCursor: () => stdout?.write(ANSI.hideCursor),
    showCursor: () => stdout?.write(ANSI.showCursor),
  };
}

/**
 * Write directly to a specific row (for row-based updates like ralph-live)
 */
export function useRowUpdate() {
  const { stdout } = useStdout();

  const updateRow = (row: number, content: string) => {
    if (!stdout) return;

    // Save current position
    stdout.write(ANSI.savePosition);

    // Move to target row and clear it
    stdout.write(ANSI.moveTo(row, 1));
    stdout.write(ANSI.clearLine);

    // Write new content
    stdout.write(content);

    // Restore position
    stdout.write(ANSI.restorePosition);
  };

  return { updateRow };
}
