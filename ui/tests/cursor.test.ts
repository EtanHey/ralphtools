import { describe, test, expect } from 'bun:test';
import { ANSI } from '../src/hooks/useCursor';

describe('ANSI escape codes', () => {
  test('up moves cursor up N rows', () => {
    expect(ANSI.up(1)).toBe('\x1b[1A');
    expect(ANSI.up(5)).toBe('\x1b[5A');
    expect(ANSI.up(10)).toBe('\x1b[10A');
  });

  test('down moves cursor down N rows', () => {
    expect(ANSI.down(1)).toBe('\x1b[1B');
    expect(ANSI.down(5)).toBe('\x1b[5B');
  });

  test('right moves cursor right N columns', () => {
    expect(ANSI.right(1)).toBe('\x1b[1C');
    expect(ANSI.right(10)).toBe('\x1b[10C');
  });

  test('left moves cursor left N columns', () => {
    expect(ANSI.left(1)).toBe('\x1b[1D');
    expect(ANSI.left(5)).toBe('\x1b[5D');
  });

  test('moveTo positions cursor at specific row and column', () => {
    expect(ANSI.moveTo(1, 1)).toBe('\x1b[1;1H');
    expect(ANSI.moveTo(10, 20)).toBe('\x1b[10;20H');
  });

  test('savePosition saves cursor position', () => {
    expect(ANSI.savePosition).toBe('\x1b[s');
  });

  test('restorePosition restores cursor position', () => {
    expect(ANSI.restorePosition).toBe('\x1b[u');
  });

  test('clearLine clears entire line', () => {
    expect(ANSI.clearLine).toBe('\x1b[2K');
  });

  test('clearToEndOfLine clears from cursor to end of line', () => {
    expect(ANSI.clearToEndOfLine).toBe('\x1b[K');
  });

  test('clearScreen clears entire screen', () => {
    expect(ANSI.clearScreen).toBe('\x1b[2J');
  });

  test('hideCursor hides cursor', () => {
    expect(ANSI.hideCursor).toBe('\x1b[?25l');
  });

  test('showCursor shows cursor', () => {
    expect(ANSI.showCursor).toBe('\x1b[?25h');
  });
});
