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
import { existsSync, chmodSync, statSync } from "fs";
import { join } from "path";

// AIDEV-NOTE: This wrapper abstracts node-pty's API to provide a cleaner interface
// for the runner. It handles terminal size detection, signal forwarding, and
// provides callback-based event handling instead of EventEmitter.

// AIDEV-NOTE: Bun has compatibility issues with node-pty's use of tty.ReadStream.
// The issue is that Bun's tty.ReadStream implementation doesn't accept file descriptors
// the same way Node.js does. We detect this and suggest using --no-pty flag.
const IS_BUN = typeof (globalThis as any).Bun !== "undefined";

/**
 * Check if PTY mode is supported on this runtime
 * @returns true if PTY mode is supported, false otherwise
 */
export function isPTYSupported(): boolean {
  // Bun currently doesn't support node-pty properly
  return !IS_BUN;
}

/**
 * Get a message explaining why PTY mode isn't supported
 * @returns explanation string, or null if supported
 */
export function getPTYUnsupportedReason(): string | null {
  if (IS_BUN) {
    return "node-pty is not compatible with Bun runtime. Use --no-pty flag or run with Node.js.";
  }
  return null;
}

const DEFAULT_COLS = 80;
const DEFAULT_ROWS = 30;
const DEFAULT_TERM_NAME = "xterm-color";

/**
 * Ensures spawn-helper has executable permissions.
 * This is a workaround for node-pty prebuilt binaries missing +x on some systems.
 */
function ensureSpawnHelperExecutable(): void {
  // Find node_modules directory by walking up from current file
  const nodePtyPaths = [
    // From ralph-ui src directory
    join(__dirname, "..", "..", "..", "node_modules", "node-pty", "prebuilds"),
    // From ralph-ui root
    join(process.cwd(), "node_modules", "node-pty", "prebuilds"),
    join(process.cwd(), "ralph-ui", "node_modules", "node-pty", "prebuilds"),
  ];

  for (const prebuildsDir of nodePtyPaths) {
    if (!existsSync(prebuildsDir)) continue;

    // Try common platform directories
    const platforms = ["darwin-arm64", "darwin-x64", "linux-x64", "linux-arm64"];
    for (const platform of platforms) {
      const helperPath = join(prebuildsDir, platform, "spawn-helper");
      if (existsSync(helperPath)) {
        try {
          const stats = statSync(helperPath);
          // Check if file is not executable (mode & 0o111 === 0 means no execute bits)
          if ((stats.mode & 0o111) === 0) {
            chmodSync(helperPath, stats.mode | 0o111);
          }
        } catch {
          // Ignore permission errors - will fail later with a clearer message
        }
      }
    }
  }
}

// Run once on module load
try {
  ensureSpawnHelperExecutable();
} catch {
  // Ignore errors - will surface during spawn
}

export class PTYWrapper implements PTYProcess {
  private pty: nodePty.IPty;
  private dataHandlers: Array<(chunk: string) => void> = [];
  private exitHandlers: Array<(code: number) => void> = [];
  private errorHandlers: Array<(err: Error) => void> = [];
  private _exited = false;
  private _spawnError: Error | null = null;

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
      const error = err instanceof Error ? err : new Error(String(err));

      // AIDEV-NOTE: Enhance error message for common issues
      if (error.message.includes("posix_spawnp failed")) {
        this._spawnError = new Error(
          `PTY spawn failed: ${error.message}. ` +
          `This may be due to missing execute permissions on spawn-helper. ` +
          `Try running: chmod +x node_modules/node-pty/prebuilds/*/spawn-helper`
        );
      } else if (IS_BUN && (error.message.includes("file path string") || error.message.includes("file descriptor"))) {
        this._spawnError = new Error(
          `PTY spawn failed: node-pty is not compatible with Bun runtime. ` +
          `Use --no-pty flag or run with Node.js instead of Bun.`
        );
      } else {
        this._spawnError = error;
      }

      // Emit error asynchronously so handlers can be registered first
      // Use setImmediate to ensure all handlers are registered before error fires
      setImmediate(() => {
        if (this._spawnError) {
          // Also log to stderr for visibility
          console.error(`[PTYWrapper] Spawn error: ${this._spawnError.message}`);
          this.errorHandlers.forEach((h) => h(this._spawnError!));
          // Emit exit with error code so callers don't hang
          this._exited = true;
          this.exitHandlers.forEach((h) => h(1));
        }
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
