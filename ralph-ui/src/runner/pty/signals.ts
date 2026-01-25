/**
 * Signal Handler - Graceful shutdown for PTY processes
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * Handles signal propagation:
 * - SIGINT (Ctrl+C) -> graceful termination
 * - SIGTERM -> graceful termination
 * - SIGKILL -> force termination
 */

import type { PTYProcess, SignalType, ShutdownResult } from "./types";
import type { DualOutput } from "./dual-output";

// AIDEV-NOTE: Proper signal handling is critical for graceful shutdown.
// The pattern is:
// 1. Send signal to PTY
// 2. Wait for graceful exit (500ms timeout)
// 3. Force kill if not exited
// 4. Close all streams

const DEFAULT_GRACEFUL_TIMEOUT_MS = 500;
const FORCE_KILL_WAIT_MS = 100;

/**
 * Handles signal propagation and graceful shutdown
 */
export class SignalHandler {
  private exitCode: number | null = null;
  private exited = false;
  private exitPromiseResolve: ((code: number) => void) | null = null;

  constructor(
    private readonly pty: PTYProcess,
    private readonly dualOutput?: DualOutput,
    private readonly gracefulTimeoutMs: number = DEFAULT_GRACEFUL_TIMEOUT_MS
  ) {
    // Listen for PTY exit
    this.pty.onExit((code) => {
      this.exitCode = code;
      this.exited = true;
      if (this.exitPromiseResolve) {
        this.exitPromiseResolve(code);
      }
    });
  }

  /**
   * Sends a signal and handles graceful/forced shutdown
   */
  async sendSignal(signal: SignalType): Promise<ShutdownResult> {
    // Send signal to PTY
    this.pty.kill(signal);

    // SIGKILL doesn't need graceful wait
    if (signal === "SIGKILL") {
      await this.waitForExit(FORCE_KILL_WAIT_MS);
      const streamsClosed = this.closeStreams();
      return {
        success: this.exited,
        exitCode: this.exitCode,
        graceful: false,
        streamsClosed,
      };
    }

    // Wait for graceful exit
    const gracefulExit = await this.waitForExit(this.gracefulTimeoutMs);

    if (!gracefulExit) {
      // Force kill if graceful shutdown failed
      this.pty.kill("SIGKILL");
      await this.waitForExit(FORCE_KILL_WAIT_MS);
    }

    // Close streams
    const streamsClosed = this.closeStreams();

    return {
      success: this.exited,
      exitCode: this.exitCode,
      graceful: gracefulExit,
      streamsClosed,
    };
  }

  /**
   * Waits for process exit with timeout
   */
  private waitForExit(timeoutMs: number): Promise<boolean> {
    return new Promise((resolve) => {
      if (this.exited) {
        resolve(true);
        return;
      }

      const timeout = setTimeout(() => {
        this.exitPromiseResolve = null;
        resolve(false);
      }, timeoutMs);

      this.exitPromiseResolve = () => {
        clearTimeout(timeout);
        this.exitPromiseResolve = null;
        resolve(true);
      };
    });
  }

  /**
   * Closes dual output streams
   */
  private closeStreams(): boolean {
    if (this.dualOutput) {
      this.dualOutput.close();
    }
    return true;
  }

  /**
   * Returns true if process has exited
   */
  hasExited(): boolean {
    return this.exited;
  }

  /**
   * Returns the exit code (null if not exited)
   */
  getExitCode(): number | null {
    return this.exitCode;
  }
}

/**
 * Creates a signal handler for a PTY process
 */
export function createSignalHandler(
  pty: PTYProcess,
  dualOutput?: DualOutput,
  gracefulTimeoutMs?: number
): SignalHandler {
  return new SignalHandler(pty, dualOutput, gracefulTimeoutMs);
}

/**
 * Sets up process-level signal handlers for graceful shutdown
 * Returns a cleanup function
 */
export function setupProcessSignals(
  onSignal: (signal: SignalType) => void
): () => void {
  const handlers: Record<string, () => void> = {
    SIGINT: () => onSignal("SIGINT"),
    SIGTERM: () => onSignal("SIGTERM"),
  };

  for (const [signal, handler] of Object.entries(handlers)) {
    process.on(signal as NodeJS.Signals, handler);
  }

  // Return cleanup function
  return () => {
    for (const [signal, handler] of Object.entries(handlers)) {
      process.off(signal as NodeJS.Signals, handler);
    }
  };
}
