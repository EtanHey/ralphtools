/**
 * Main Iteration Runner - Core iteration loop for Ralph
 * Part of MP-006: Move iteration loop from zsh to TypeScript
 */

import type {
  RunnerConfig,
  IterationResult,
  RunnerState,
  Model,
  SpawnOptions,
} from "./types";
import { DEFAULT_TIMEOUT_MS } from "./types";
import {
  readIndex,
  getNextStory,
  applyUpdateQueue,
  isComplete,
  isAllBlocked,
  getCriteriaProgress,
  autoBlockStoryIfNeeded,
} from "./prd";
import { spawnClaude, analyzeResult } from "./claude";
import { spawnClaudePTY } from "./pty-claude";
import {
  writeStatus,
  cleanupStatus,
  setRunning,
  setComplete,
  setError,
  setRetry,
  setInterrupted,
  setTerminated,
} from "./status";
import {
  detectError,
  shouldRetry,
  getCooldownMs,
  getErrorDescription,
  hasCompletePromise,
  hasAllBlockedPromise,
} from "./errors";
import { buildIterationContext } from "./context";
import {
  notifyIterationComplete,
  notifyPRDComplete,
  notifyError,
  notifyRetry,
} from "./ntfy";
import { SessionContext } from "./session-context";

// AIDEV-NOTE: This is the main iteration loop that replaces the 943-line loop in ralph.zsh
// The state machine follows the design in docs.local/mp-006-design.md

// Default configuration values
export const DEFAULT_CONFIG: Partial<RunnerConfig> = {
  iterations: 100,
  gapSeconds: 5,
  model: "sonnet" as Model,
  notify: false,
  quiet: false,
  verbose: false,
};

// Create a full config from partial options
export function createConfig(options: Partial<RunnerConfig>): RunnerConfig {
  if (!options.prdJsonDir) {
    throw new Error("prdJsonDir is required");
  }
  if (!options.workingDir) {
    throw new Error("workingDir is required");
  }

  return {
    prdJsonDir: options.prdJsonDir,
    workingDir: options.workingDir,
    iterations: options.iterations ?? DEFAULT_CONFIG.iterations!,
    gapSeconds: options.gapSeconds ?? DEFAULT_CONFIG.gapSeconds!,
    model: options.model ?? DEFAULT_CONFIG.model!,
    notify: options.notify ?? DEFAULT_CONFIG.notify!,
    ntfyTopic: options.ntfyTopic,
    quiet: options.quiet ?? DEFAULT_CONFIG.quiet!,
    verbose: options.verbose ?? DEFAULT_CONFIG.verbose!,
    usePty: options.usePty,
    onOutput: options.onOutput,
    onStrippedOutput: options.onStrippedOutput,
  };
}

// Sleep utility
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Log utility (respects quiet mode)
function log(config: RunnerConfig, message: string): void {
  if (!config.quiet) {
    console.log(message);
  }
}

// Verbose log utility
function verbose(config: RunnerConfig, message: string): void {
  if (config.verbose && !config.quiet) {
    console.log(`[verbose] ${message}`);
  }
}

// Single iteration execution
export async function runSingleIteration(
  config: RunnerConfig,
  iteration: number,
  runStartTime?: number
): Promise<IterationResult> {
  const startTime = Date.now();

  // Check for update queue
  const updateResult = applyUpdateQueue(config.prdJsonDir);
  if (updateResult.applied) {
    verbose(config, `Applied update queue: ${updateResult.changes.join(", ")}`);
  }

  // Get next story
  let story = getNextStory(config.prdJsonDir);

  if (!story) {
    // Check if complete or all blocked
    if (isComplete(config.prdJsonDir)) {
      return {
        iteration,
        storyId: "",
        success: true,
        hasComplete: true,
        hasBlocked: false,
        durationMs: Date.now() - startTime,
      };
    }

    if (isAllBlocked(config.prdJsonDir)) {
      return {
        iteration,
        storyId: "",
        success: false,
        hasComplete: false,
        hasBlocked: true,
        durationMs: Date.now() - startTime,
      };
    }

    // No story available but not complete
    return {
      iteration,
      storyId: "",
      success: false,
      hasComplete: false,
      hasBlocked: false,
      durationMs: Date.now() - startTime,
      error: "No story available",
    };
  }

  // Update status with model and start time
  setRunning(iteration, story.id, {
    model: config.model,
    startTime: runStartTime ?? startTime,
  });

  // Check if story is blocked (auto-unblock if blocker is completed)
  if (story.blockedBy) {
    const wasAutoBlocked = autoBlockStoryIfNeeded(config.prdJsonDir, story.id);

    if (wasAutoBlocked) {
      // Story was moved to blocked array - return blocked status
      verbose(config, `Story ${story.id} auto-blocked: ${story.blockedBy}`);
      return {
        iteration,
        storyId: story.id,
        success: false,
        hasComplete: false,
        hasBlocked: true,
        durationMs: Date.now() - startTime,
        error: `Blocked: ${story.blockedBy}`,
      };
    }
    // wasAutoBlocked=false means blocker completed, story was unblocked - continue execution
    // Re-read story to get updated state without blockedBy
    story = getNextStory(config.prdJsonDir)!;
  }

  // Build context and prompt for Claude
  const progress = getCriteriaProgress(story);
  const { systemContext, storyPrompt } = buildIterationContext(
    story.id,
    config.model,
    config.prdJsonDir,
    config.workingDir
  );

  // Spawn Claude with full context
  const spawnOptions: SpawnOptions = {
    model: config.model,
    prompt: storyPrompt,
    contextFile: systemContext, // Pass system context directly (not a file path)
    workingDir: config.workingDir,
    timeout: DEFAULT_TIMEOUT_MS,
  };

  verbose(config, `Spawning Claude with model ${config.model}${config.usePty ? " (PTY)" : ""}`);

  // Use PTY or regular spawning based on config
  const spawnResult = config.usePty
    ? await spawnClaudePTY(spawnOptions, {
        onData: config.onOutput,
        onStrippedData: config.onStrippedOutput,
      })
    : await spawnClaude(spawnOptions);
  const outcome = analyzeResult(spawnResult);

  const durationMs = Date.now() - startTime;

  // Check for completion signals in output
  if (hasCompletePromise(spawnResult.stdout)) {
    return {
      iteration,
      storyId: story.id,
      success: true,
      hasComplete: true,
      hasBlocked: false,
      durationMs,
    };
  }

  if (hasAllBlockedPromise(spawnResult.stdout)) {
    return {
      iteration,
      storyId: story.id,
      success: false,
      hasComplete: false,
      hasBlocked: true,
      durationMs,
    };
  }

  // Handle errors
  if (!spawnResult.success && outcome.errorType) {
    const errorDesc = getErrorDescription(outcome.errorType);
    return {
      iteration,
      storyId: story.id,
      success: false,
      hasComplete: false,
      hasBlocked: false,
      durationMs,
      error: errorDesc,
    };
  }

  return {
    iteration,
    storyId: story.id,
    success: spawnResult.success,
    hasComplete: outcome.hasComplete,
    hasBlocked: outcome.hasAllBlocked,
    durationMs,
    error: spawnResult.success ? undefined : spawnResult.stderr,
  };
}

// AIDEV-NOTE: Prompt building moved to context.ts - buildIterationContext()

// Main iteration loop as async generator
export async function* runIterations(
  config: RunnerConfig
): AsyncGenerator<IterationResult> {
  // Create unified session context
  const sessionContext = SessionContext.create({
    config: {
      notifications: {
        enabled: config.notify,
        topic: config.ntfyTopic,
      },
    },
  });

  let iteration = 1;
  let retryCount = 0;
  const runStartTime = Date.now(); // Track start time for the entire run

  // Set up signal handlers
  let interrupted = false;
  const handleSignal = () => {
    interrupted = true;
  };

  process.on("SIGINT", handleSignal);
  process.on("SIGTERM", handleSignal);

  try {
    while (iteration <= config.iterations && !interrupted) {
      log(config, `\n=== Iteration ${iteration} ===`);

      const result = await runSingleIteration(config, iteration, runStartTime);

      // Yield result to caller
      yield result;

      // Handle completion
      if (result.hasComplete) {
        log(config, "All stories complete!");
        setComplete();
        if (sessionContext.notifications.enabled && sessionContext.notifications.topic) {
          await notifyPRDComplete(sessionContext.notifications.topic);
        }
        break;
      }

      // Handle all blocked
      if (result.hasBlocked && !result.storyId) {
        log(config, "All remaining stories are blocked");
        setError("All stories blocked");
        if (sessionContext.notifications.enabled && sessionContext.notifications.topic) {
          await notifyError(sessionContext.notifications.topic, "All stories blocked");
        }
        break;
      }

      // Handle errors with retry
      if (!result.success && result.error) {
        const errorType = detectError(result.error);

        if (errorType && shouldRetry(errorType, retryCount)) {
          retryCount++;
          const cooldown = getCooldownMs(errorType);
          const cooldownSecs = Math.ceil(cooldown / 1000);

          log(config, `Retry ${retryCount}: ${result.error}`);
          setRetry(cooldownSecs);
          if (sessionContext.notifications.enabled && sessionContext.notifications.topic) {
            await notifyRetry(sessionContext.notifications.topic, retryCount, cooldownSecs);
          }

          await sleep(cooldown);
          continue; // Don't increment iteration for retry
        }

        // Max retries exceeded or non-retryable error
        log(config, `Error: ${result.error}`);
      }

      // Reset retry count on success
      if (result.success) {
        retryCount = 0;
        if (sessionContext.notifications.enabled && sessionContext.notifications.topic) {
          await notifyIterationComplete(sessionContext.notifications.topic, iteration, result.storyId);
        }
      }

      // Gap between iterations
      if (iteration < config.iterations && config.gapSeconds > 0) {
        verbose(config, `Waiting ${config.gapSeconds}s before next iteration`);
        await sleep(config.gapSeconds * 1000);
      }

      iteration++;
    }
  } finally {
    // Clean up signal handlers
    process.off("SIGINT", handleSignal);
    process.off("SIGTERM", handleSignal);

    if (interrupted) {
      setInterrupted();
    }
  }
}

// Convenience function to run all iterations and collect results
export async function runAllIterations(
  config: RunnerConfig
): Promise<IterationResult[]> {
  const results: IterationResult[] = [];

  for await (const result of runIterations(config)) {
    results.push(result);
  }

  return results;
}

// Export types
export type { RunnerConfig, IterationResult, RunnerState, Model };
