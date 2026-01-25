/**
 * Dual Output Pipeline - Splits PTY output to display and file streams
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * The dual output system:
 * 1. Display stream: preserves ANSI codes for UI rendering
 * 2. File stream: strips ANSI codes for clean logs
 */

import { PassThrough, Transform } from "stream";
import type { Writable } from "stream";
import { stripAnsi } from "./ansi";
import type { DualOutputStream } from "./types";

// AIDEV-NOTE: This module implements the dual-stream architecture from the research.
// It forks output to two destinations simultaneously:
// - Display path: raw data with ANSI preserved for Ink UI
// - File path: stripped data for searchable log files

export interface DualOutputStreams {
  display: PassThrough;
  file: Transform;
}

/**
 * Creates paired streams for dual output
 * Display stream preserves ANSI, file stream strips it
 */
export function createDualOutputStreams(): DualOutputStreams {
  const display = new PassThrough();

  const file = new Transform({
    transform(chunk, _encoding, callback) {
      const stripped = stripAnsi(chunk.toString());
      callback(null, stripped);
    },
  });

  return { display, file };
}

/**
 * Forks data to both streams simultaneously
 */
export function forkOutput(data: string, streams: DualOutputStreams): void {
  streams.display.write(data);
  streams.file.write(data);
}

/**
 * Dual output handler with callback-based API
 * Simpler than streams for direct event handling
 */
export class DualOutput implements DualOutputStream {
  private displayHandlers: Array<(data: string) => void> = [];
  private fileHandlers: Array<(data: string) => void> = [];
  private _closed = false;

  displayData(handler: (data: string) => void): void {
    this.displayHandlers.push(handler);
  }

  fileData(handler: (data: string) => void): void {
    this.fileHandlers.push(handler);
  }

  push(data: string): void {
    if (this._closed) return;

    // Display gets raw data with ANSI preserved
    this.displayHandlers.forEach((h) => h(data));

    // File gets stripped data
    const stripped = stripAnsi(data);
    this.fileHandlers.forEach((h) => h(stripped));
  }

  close(): void {
    this._closed = true;
  }

  isClosed(): boolean {
    return this._closed;
  }
}

/**
 * Creates a dual output handler
 */
export function createDualOutput(): DualOutput {
  return new DualOutput();
}

/**
 * Log file writer that buffers and writes to file
 */
export class LogFileWriter {
  private buffer: string[] = [];
  private fileHandle: ReturnType<Bun.BunFile["writer"]> | null = null;
  private flushTimeout: ReturnType<typeof setTimeout> | null = null;
  private readonly flushIntervalMs: number;
  private readonly maxBufferSize: number;

  constructor(
    private readonly logPath: string,
    options: { flushIntervalMs?: number; maxBufferSize?: number } = {}
  ) {
    this.flushIntervalMs = options.flushIntervalMs ?? 1000;
    this.maxBufferSize = options.maxBufferSize ?? 100;
  }

  async open(): Promise<void> {
    const file = Bun.file(this.logPath);
    this.fileHandle = file.writer();
  }

  write(data: string): void {
    this.buffer.push(data);

    // Flush if buffer is full
    if (this.buffer.length >= this.maxBufferSize) {
      void this.flush();
      return;
    }

    // Schedule flush if not already scheduled
    if (!this.flushTimeout) {
      this.flushTimeout = setTimeout(() => {
        void this.flush();
      }, this.flushIntervalMs);
    }
  }

  async flush(): Promise<void> {
    if (this.flushTimeout) {
      clearTimeout(this.flushTimeout);
      this.flushTimeout = null;
    }

    if (this.buffer.length === 0 || !this.fileHandle) return;

    const data = this.buffer.join("");
    this.buffer = [];

    this.fileHandle.write(data);
  }

  async close(): Promise<void> {
    await this.flush();
    if (this.fileHandle) {
      await this.fileHandle.end();
      this.fileHandle = null;
    }
  }
}

/**
 * Creates log directory and returns log file path
 */
export async function createLogDir(): Promise<string> {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const configDir =
    process.env.XDG_CONFIG_HOME || `${process.env.HOME}/.config`;
  const runsDir = `${configDir}/ralphtools/runs/${timestamp}`;

  await Bun.write(`${runsDir}/.keep`, "");
  return `${runsDir}/output.log`;
}
