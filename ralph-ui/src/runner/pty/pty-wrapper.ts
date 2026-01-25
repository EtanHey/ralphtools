/**
 * PTY Wrapper - Wraps node-pty with a clean TypeScript interface
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * This module provides:
 * - PTYProcess interface for spawning processes in pseudo-terminals
 * - Signal propagation (Ctrl+C -> graceful PTY termination)
 * - Event-based output handling
 */

import * as nodePty from "node-pty";
import type { PTYProcess, PTYSpawnOptions } from "./types";

// AIDEV-NOTE: This wrapper abstracts node-pty's API to provide a cleaner interface
// for the runner. It handles terminal size detection, signal forwarding, and
// provides callback-based event handling instead of EventEmitter.

const DEFAULT_COLS = 80;
const DEFAULT_ROWS = 30;
const DEFAULT_TERM_NAME = "xterm-color";

export class PTYWrapper implements PTYProcess {
  private pty: nodePty.IPty;
  private dataHandlers: Array<(chunk: string) => void> = [];
  private exitHandlers: Array<(code: number) => void> = [];
  private errorHandlers: Array<(err: Error) => void> = [];
  private _exited = false;

  constructor(cmd: string, args: string[], options: PTYSpawnOptions = {}) {
    const cols = options.cols ?? process.stdout.columns ?? DEFAULT_COLS;
    const rows = options.rows ?? process.stdout.rows ?? DEFAULT_ROWS;

    try {
      this.pty = nodePty.spawn(cmd, args, {
        name: options.name ?? DEFAULT_TERM_NAME,
        cols,
        rows,
        cwd: options.cwd,
        env: options.env ?? (process.env as Record<string, string>),
      });

      // Wire up event handlers
      this.pty.onData((data: string) => {
        this.dataHandlers.forEach((h) => h(data));
      });

      this.pty.onExit(({ exitCode }) => {
        this._exited = true;
        this.exitHandlers.forEach((h) => h(exitCode));
      });
    } catch (err) {
      // Emit error asynchronously so handlers can be registered first
      process.nextTick(() => {
        const error = err instanceof Error ? err : new Error(String(err));
        this.errorHandlers.forEach((h) => h(error));
      });

      // Create a no-op PTY for error cases
      this.pty = {
        pid: -1,
        cols,
        rows,
        process: "",
        onData: () => ({ dispose: () => {} }),
        onExit: () => ({ dispose: () => {} }),
        write: () => {},
        resize: () => {},
        kill: () => {},
        pause: () => {},
        resume: () => {},
        clear: () => {},
      } as unknown as nodePty.IPty;
    }
  }

  onData(handler: (chunk: string) => void): void {
    this.dataHandlers.push(handler);
  }

  onExit(handler: (code: number) => void): void {
    this.exitHandlers.push(handler);
  }

  onError(handler: (err: Error) => void): void {
    this.errorHandlers.push(handler);
  }

  write(data: string): void {
    if (!this._exited) {
      this.pty.write(data);
    }
  }

  resize(cols: number, rows: number): void {
    if (!this._exited) {
      this.pty.resize(cols, rows);
    }
  }

  kill(signal?: string): void {
    if (!this._exited) {
      // node-pty.kill() accepts a signal parameter on unix
      this.pty.kill(signal);
    }
  }

  getPid(): number {
    return this.pty.pid;
  }

  get exited(): boolean {
    return this._exited;
  }
}

/**
 * Spawns a command in a pseudo-terminal
 * @param cmd - The command to spawn
 * @param args - Arguments for the command
 * @param options - PTY spawn options
 * @returns PTYProcess interface
 */
export function spawnPTY(
  cmd: string,
  args: string[] = [],
  options: PTYSpawnOptions = {}
): PTYProcess {
  return new PTYWrapper(cmd, args, options);
}
