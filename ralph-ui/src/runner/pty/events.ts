/**
 * PTY Event System - Structured events for UI communication
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * Events are JSON objects that enable:
 * - Decoupled PTY-to-UI communication
 * - Batching for performance
 * - Type-safe event handling
 */

import { EventEmitter } from "events";
import type {
  PTYEvent,
  DataEvent,
  ExitEvent,
  ErrorEvent,
  PTYEventType,
} from "./types";
import { hasAnsiCodes } from "./ansi";

// AIDEV-NOTE: This event emitter follows the research spec for structured events.
// All events have: type, timestamp, and type-specific fields.
// Events can be serialized to JSON for logging or IPC.

/**
 * PTY Event Emitter - emits structured events for PTY output
 * Uses the standard EventEmitter API without type overloads
 */
export class PTYEventEmitter extends EventEmitter {
  /**
   * Emit a PTY event
   */
  emitPtyEvent(payload: PTYEvent): boolean {
    return this.emit("pty-event", payload);
  }

  /**
   * Listen for PTY events
   */
  onPtyEvent(listener: (payload: PTYEvent) => void): this {
    return this.on("pty-event", listener);
  }

  /**
   * Listen for PTY event once
   */
  oncePtyEvent(listener: (payload: PTYEvent) => void): this {
    return this.once("pty-event", listener);
  }

  /**
   * Emits a data event for process output
   */
  emitData(data: string): void {
    const event: DataEvent = {
      type: "data",
      timestamp: new Date().toISOString(),
      data,
      ansi: hasAnsiCodes(data),
    };
    this.emitPtyEvent(event);
  }

  /**
   * Emits an exit event when process terminates
   */
  emitExit(exitCode: number, finalOutput?: string): void {
    const event: ExitEvent = {
      type: "exit",
      timestamp: new Date().toISOString(),
      exitCode,
      data: finalOutput,
    };
    this.emitPtyEvent(event);
  }

  /**
   * Emits an error event for spawn/permission errors
   */
  emitError(message: string): void {
    const event: ErrorEvent = {
      type: "error",
      timestamp: new Date().toISOString(),
      data: message,
    };
    this.emitPtyEvent(event);
  }
}

/**
 * Creates a new PTY event emitter
 */
export function createEventEmitter(): PTYEventEmitter {
  return new PTYEventEmitter();
}

/**
 * Event batcher for UI updates
 * Batches events to reduce re-renders: 50 lines OR 100ms, whichever first
 */
export class EventBatcher {
  private buffer: PTYEvent[] = [];
  private flushTimeout: ReturnType<typeof setTimeout> | null = null;
  private lineCount = 0;

  constructor(
    private readonly onFlush: (events: PTYEvent[]) => void,
    private readonly maxLines: number = 50,
    private readonly maxDelayMs: number = 100
  ) {}

  push(event: PTYEvent): void {
    this.buffer.push(event);

    // Count lines in data events
    if (event.type === "data" && event.data) {
      this.lineCount += (event.data.match(/\n/g) || []).length;
    }

    // Flush immediately for exit/error events
    if (event.type === "exit" || event.type === "error") {
      this.flush();
      return;
    }

    // Flush if we hit max lines
    if (this.lineCount >= this.maxLines) {
      this.flush();
      return;
    }

    // Schedule flush if not already scheduled
    if (!this.flushTimeout) {
      this.flushTimeout = setTimeout(() => {
        this.flush();
      }, this.maxDelayMs);
    }
  }

  flush(): void {
    if (this.flushTimeout) {
      clearTimeout(this.flushTimeout);
      this.flushTimeout = null;
    }

    if (this.buffer.length === 0) return;

    const events = this.buffer;
    this.buffer = [];
    this.lineCount = 0;

    this.onFlush(events);
  }

  clear(): void {
    if (this.flushTimeout) {
      clearTimeout(this.flushTimeout);
      this.flushTimeout = null;
    }
    this.buffer = [];
    this.lineCount = 0;
  }
}
