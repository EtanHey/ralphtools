/**
 * PTY Claude Spawning - Spawn Claude CLI via node-pty
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * This module replaces the child_process-based spawning with PTY,
 * enabling live output streaming with TTY semantics preserved.
 */

import type { SpawnOptions, SpawnResult, Model } from "./types";
import { DEFAULT_TIMEOUT_MS } from "./types";
import { detectError, hasCompletionSignal, hasBlockedSignal } from "./errors";
import { spawnPTY, createDualOutput, createEventEmitter, EventBatcher } from "./pty/index";
import type { PTYProcess, PTYEvent, DualOutputStream } from "./pty/index";
import { buildCliArgs } from "./claude";

// AIDEV-NOTE: This module provides PTY-based Claude spawning.
// It enables live output streaming while maintaining the same interface as claude.ts

export interface PTYSpawnCallbacks {
  onData?: (data: string) => void;
  onStrippedData?: (data: string) => void;
  onEvent?: (event: PTYEvent) => void;
  onBatchedEvents?: (events: PTYEvent[]) => void;
}

/**
 * Spawns Claude CLI via PTY with live output callbacks
 */
export async function spawnClaudePTY(
  options: SpawnOptions,
  callbacks: PTYSpawnCallbacks = {}
): Promise<SpawnResult> {
  const startTime = Date.now();
  const args = buildCliArgs(options);

  // Find the Claude CLI
  let cli = "claude";
  try {
    const whichProc = Bun.spawn(["which", "claude"], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const whichOutput = await new Response(whichProc.stdout).text();
    if (whichOutput.trim()) {
      cli = whichOutput.trim();
    }
  } catch {
    // Use default "claude" if which fails
  }

  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    let timedOut = false;

    // Create dual output for display and file paths
    const dualOutput = createDualOutput();

    // Create event emitter for structured events
    const eventEmitter = createEventEmitter();

    // Create event batcher if batched callbacks provided
    let eventBatcher: EventBatcher | undefined;
    if (callbacks.onBatchedEvents) {
      eventBatcher = new EventBatcher(callbacks.onBatchedEvents);
    }

    // Wire up callbacks
    if (callbacks.onData) {
      dualOutput.displayData(callbacks.onData);
    }
    if (callbacks.onStrippedData) {
      dualOutput.fileData(callbacks.onStrippedData);
    }
    if (callbacks.onEvent) {
      eventEmitter.onPtyEvent(callbacks.onEvent);
    }

    // Spawn Claude via PTY
    const pty = spawnPTY(cli, args, {
      cwd: options.workingDir,
      cols: process.stdout.columns || 120,
      rows: process.stdout.rows || 40,
      env: process.env as Record<string, string>,
    });

    // Set up timeout
    const timeout = options.timeout || DEFAULT_TIMEOUT_MS;
    const timeoutId = setTimeout(() => {
      timedOut = true;
      pty.kill("SIGTERM");
    }, timeout);

    // Collect output
    pty.onData((data) => {
      stdout += data;
      dualOutput.push(data);

      // Emit event
      eventEmitter.emitData(data);

      // Batch event if batcher exists
      if (eventBatcher) {
        const event: PTYEvent = {
          type: "data",
          timestamp: new Date().toISOString(),
          data,
          ansi: /\x1b\[[0-9;]*[a-zA-Z]/.test(data),
        };
        eventBatcher.push(event);
      }
    });

    pty.onError((err) => {
      stderr += err.message;
      eventEmitter.emitError(err.message);
    });

    pty.onExit((exitCode) => {
      clearTimeout(timeoutId);

      // Flush any pending batched events
      eventBatcher?.flush();

      // Close dual output
      dualOutput.close();

      // Emit exit event
      eventEmitter.emitExit(exitCode);

      const durationMs = Date.now() - startTime;

      if (timedOut) {
        resolve({
          success: false,
          exitCode: -1,
          stdout,
          stderr: "Process timed out",
          durationMs,
        });
        return;
      }

      // Extract session ID if present
      let sessionId: string | undefined;
      const sessionMatch = stdout.match(/"session_id":\s*"([^"]+)"/);
      if (sessionMatch) {
        sessionId = sessionMatch[1];
      }

      resolve({
        success: exitCode === 0,
        exitCode,
        stdout,
        stderr,
        durationMs,
        sessionId,
      });
    });
  });
}

/**
 * Creates a PTY runner with all callbacks configured
 */
export function createPTYRunner(callbacks: PTYSpawnCallbacks = {}): {
  spawn: (options: SpawnOptions) => Promise<SpawnResult>;
  kill: () => void;
} {
  let currentPty: PTYProcess | undefined;

  return {
    async spawn(options: SpawnOptions): Promise<SpawnResult> {
      return spawnClaudePTY(options, callbacks);
    },
    kill() {
      currentPty?.kill("SIGTERM");
    },
  };
}
