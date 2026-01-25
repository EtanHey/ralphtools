/**
 * usePTYOutput Hook - React hook for PTY event subscription
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * Provides React state for PTY output with:
 * - Batched updates for performance
 * - Line buffer for scrolling output
 * - ANSI/stripped variants
 */

import { useState, useCallback, useRef, useEffect } from "react";
import type { PTYEvent } from "../runner/pty/index";

// AIDEV-NOTE: This hook bridges PTY events to React state.
// It implements the batching strategy: 50 lines OR 100ms.

export interface PTYOutputState {
  lines: string[];
  strippedLines: string[];
  isRunning: boolean;
  exitCode: number | null;
  error: string | null;
}

export interface UsePTYOutputOptions {
  maxLines?: number; // Maximum lines to keep in buffer (default: 1000)
  batchMs?: number; // Max delay before flush (default: 100)
  batchLines?: number; // Max lines before flush (default: 50)
}

const DEFAULT_MAX_LINES = 1000;
const DEFAULT_BATCH_MS = 100;
const DEFAULT_BATCH_LINES = 50;

export function usePTYOutput(options: UsePTYOutputOptions = {}): {
  state: PTYOutputState;
  pushEvent: (event: PTYEvent) => void;
  pushEvents: (events: PTYEvent[]) => void;
  clear: () => void;
  setRunning: (running: boolean) => void;
} {
  const maxLines = options.maxLines ?? DEFAULT_MAX_LINES;
  const batchMs = options.batchMs ?? DEFAULT_BATCH_MS;
  const batchLines = options.batchLines ?? DEFAULT_BATCH_LINES;

  const [state, setState] = useState<PTYOutputState>({
    lines: [],
    strippedLines: [],
    isRunning: false,
    exitCode: null,
    error: null,
  });

  // Buffer for batching
  const lineBuffer = useRef<string[]>([]);
  const strippedBuffer = useRef<string[]>([]);
  const flushTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Flush buffer to state
  const flushBuffer = useCallback(() => {
    if (flushTimeoutRef.current) {
      clearTimeout(flushTimeoutRef.current);
      flushTimeoutRef.current = null;
    }

    if (lineBuffer.current.length === 0) return;

    const newLines = lineBuffer.current;
    const newStripped = strippedBuffer.current;
    lineBuffer.current = [];
    strippedBuffer.current = [];

    setState((prev) => {
      // Append new lines and trim to max
      const allLines = [...prev.lines, ...newLines].slice(-maxLines);
      const allStripped = [...prev.strippedLines, ...newStripped].slice(
        -maxLines
      );

      return {
        ...prev,
        lines: allLines,
        strippedLines: allStripped,
      };
    });
  }, [maxLines]);

  // Schedule flush
  const scheduleFlush = useCallback(() => {
    // Flush immediately if buffer is full
    if (
      lineBuffer.current.length >= batchLines ||
      strippedBuffer.current.length >= batchLines
    ) {
      flushBuffer();
      return;
    }

    // Schedule delayed flush
    if (!flushTimeoutRef.current) {
      flushTimeoutRef.current = setTimeout(flushBuffer, batchMs);
    }
  }, [batchLines, batchMs, flushBuffer]);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (flushTimeoutRef.current) {
        clearTimeout(flushTimeoutRef.current);
      }
    };
  }, []);

  // Strip ANSI codes for stripped lines
  const stripAnsi = (text: string): string => {
    return text.replace(
      /\x1b\[[0-9;]*[a-zA-Z]|\x1b\].*?(?:\x07|\x1b\\)/g,
      ""
    );
  };

  // Push a single event
  const pushEvent = useCallback(
    (event: PTYEvent) => {
      switch (event.type) {
        case "data":
          if (event.data) {
            // Split into lines and add to buffer
            const lines = event.data.split("\n");
            for (const line of lines) {
              if (line) {
                lineBuffer.current.push(line);
                strippedBuffer.current.push(stripAnsi(line));
              }
            }
            scheduleFlush();
          }
          break;

        case "exit":
          // Flush any pending data
          flushBuffer();
          setState((prev) => ({
            ...prev,
            isRunning: false,
            exitCode: event.exitCode ?? null,
          }));
          break;

        case "error":
          flushBuffer();
          setState((prev) => ({
            ...prev,
            error: event.data ?? "Unknown error",
          }));
          break;
      }
    },
    [scheduleFlush, flushBuffer]
  );

  // Push multiple events (from batcher)
  const pushEvents = useCallback(
    (events: PTYEvent[]) => {
      for (const event of events) {
        pushEvent(event);
      }
    },
    [pushEvent]
  );

  // Clear output
  const clear = useCallback(() => {
    lineBuffer.current = [];
    strippedBuffer.current = [];
    if (flushTimeoutRef.current) {
      clearTimeout(flushTimeoutRef.current);
      flushTimeoutRef.current = null;
    }
    setState({
      lines: [],
      strippedLines: [],
      isRunning: false,
      exitCode: null,
      error: null,
    });
  }, []);

  // Set running state
  const setRunning = useCallback((running: boolean) => {
    setState((prev) => ({
      ...prev,
      isRunning: running,
      exitCode: running ? null : prev.exitCode,
      error: running ? null : prev.error,
    }));
  }, []);

  return {
    state,
    pushEvent,
    pushEvents,
    clear,
    setRunning,
  };
}
