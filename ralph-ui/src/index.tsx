#!/usr/bin/env bun
import React from 'react';
import { render } from 'ink';
import { existsSync, unlinkSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';
import { Dashboard } from './components/Dashboard.js';
import { runIterations, createConfig } from './runner/index.js';
import { cleanupStatus } from './runner/status.js';
import type { Model } from './runner/types.js';
import { isPTYSupported, getPTYUnsupportedReason } from './runner/pty/index.js';
import { loadConfig as loadRalphConfig } from './utils/config.js';

// AIDEV-NOTE: This is the main entry point for ralph-ui
// Phase 2 of MP-006 adds --run flag for iteration execution mode
// Without --run, it runs in display-only mode (current behavior)

// Immediate process-level exit handlers (before Ink takes over)
let exitRequested = false;
let inkInstance: ReturnType<typeof render> | undefined;

// Cleanup files on exit - use os.homedir() for cross-platform compatibility
const stopFile = join(homedir(), '.ralph-stop');

function cleanupAndExit(code: number = 0): void {
  exitRequested = true;

  // Cleanup status file
  try { cleanupStatus(); } catch {}

  // Cleanup stop file if it exists
  try {
    if (existsSync(stopFile)) {
      unlinkSync(stopFile);
    }
  } catch {}

  // Unmount Ink UI gracefully before exit
  if (inkInstance) {
    try { inkInstance.unmount(); } catch {}
    inkInstance = undefined;
  }

  // Reset terminal raw mode before exit so command line works
  try {
    if (process.stdin.isTTY && process.stdin.setRawMode) {
      process.stdin.setRawMode(false);
    }
  } catch {}

  process.exit(code);
}

// Force exit on any signal
const forceExit = () => cleanupAndExit(0);
process.on('SIGINT', forceExit);
process.on('SIGTERM', forceExit);
process.on('SIGHUP', forceExit);

// Watchdog: check for ~/.ralph-stop file every 500ms
// Touch this file to force exit: touch ~/.ralph-stop
const watchdogInterval = setInterval(() => {
  try {
    if (existsSync(stopFile)) {
      unlinkSync(stopFile);
      forceExit();
    }
  } catch {}
}, 500);

// AIDEV-NOTE: Removed process-level stdin handler - it interfered with Ink's useInput.
// Ctrl+C is already handled by process.on('SIGINT', forceExit) above.
// All other keyboard input is handled by Ink's useInput in Dashboard and ConfigMenu.

// CLI configuration interface
interface CLIConfig {
  // Mode flags
  run: boolean;  // --run enables iteration runner
  mode: 'startup' | 'iteration' | 'live';

  // Runner options (used when --run is set)
  iterations: number;
  gap: number;
  model: Model;
  quiet: boolean;
  verbose: boolean;
  notify: boolean;
  usePty: boolean;  // Use PTY for live output (MP-007)

  // Path options
  prdPath: string;
  workingDir: string;

  // Display options
  iteration: number;  // Current iteration for display
  startTime: number;
  ntfyTopic?: string;
}

// Parse command line arguments
function parseArgs(): CLIConfig {
  const args = process.argv.slice(2);

  // Check if PTY is supported (not supported on Bun)
  const ptySupported = isPTYSupported();

  // Load config file for notifications
  const ralphConfig = loadRalphConfig();
  const notifyFromConfig = ralphConfig.notifications?.enabled ?? false;
  const ntfyTopicFromConfig = ralphConfig.notifications?.ntfyTopic;

  // Defaults (config file -> env var -> hardcoded)
  const config: CLIConfig = {
    run: false,
    mode: 'live',
    iterations: parseInt(process.env.RALPH_ITERATIONS || '100', 10),
    gap: parseInt(process.env.RALPH_SLEEP_SECONDS || '5', 10),
    model: (process.env.RALPH_MODEL as Model) || ralphConfig.defaultModel || 'sonnet',
    quiet: false,
    verbose: false,
    notify: !!process.env.RALPH_NOTIFY || notifyFromConfig,
    usePty: ptySupported, // Default to PTY mode only if supported
    prdPath: process.cwd() + '/prd-json',
    workingDir: process.cwd(),
    iteration: 1,
    startTime: Date.now(),
    ntfyTopic: process.env.RALPH_NTFY_TOPIC || ntfyTopicFromConfig,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    // --run flag (enables runner mode)
    if (arg === '--run' || arg === '-r') {
      config.run = true;
      config.mode = 'iteration';  // Switch to iteration display mode when running
    }
    // --iterations
    else if (arg === '--iterations' || arg === '-n') {
      config.iterations = parseInt(args[++i], 10) || 100;
    } else if (arg.startsWith('--iterations=')) {
      config.iterations = parseInt(arg.split('=')[1], 10) || 100;
    }
    // --gap
    else if (arg === '--gap' || arg === '-g') {
      config.gap = parseInt(args[++i], 10) || 5;
    } else if (arg.startsWith('--gap=')) {
      config.gap = parseInt(arg.split('=')[1], 10) || 5;
    }
    // --model (accepts: haiku, sonnet, opus, gemini-flash, gemini-flash-lite, gemini-3-flash, gemini-pro, kiro, ollama)
    else if (arg === '--model') {
      const modelVal = args[++i];
      if (['haiku', 'sonnet', 'opus', 'gemini-flash', 'gemini-flash-lite', 'gemini-3-flash', 'gemini-pro', 'kiro', 'ollama'].includes(modelVal)) {
        config.model = modelVal as Model;
      }
    } else if (arg.startsWith('--model=')) {
      const modelVal = arg.split('=')[1];
      if (['haiku', 'sonnet', 'opus', 'gemini-flash', 'gemini-flash-lite', 'gemini-3-flash', 'gemini-pro', 'kiro', 'ollama'].includes(modelVal)) {
        config.model = modelVal as Model;
      }
    }
    // --quiet
    else if (arg === '--quiet' || arg === '-q') {
      config.quiet = true;
    }
    // --verbose
    else if (arg === '--verbose' || arg === '-v') {
      config.verbose = true;
    }
    // --notify
    else if (arg === '--notify') {
      config.notify = true;
    }
    // --pty / --no-pty (PTY mode toggle)
    else if (arg === '--pty') {
      if (!ptySupported) {
        const reason = getPTYUnsupportedReason();
        console.warn(`Warning: --pty requested but PTY is not supported: ${reason}`);
        console.warn('Falling back to non-PTY mode.');
      }
      config.usePty = ptySupported; // Only enable if supported
    }
    else if (arg === '--no-pty') {
      config.usePty = false;
    }
    // --mode (display mode)
    else if (arg === '--mode' || arg === '-m') {
      const value = args[++i];
      if (value === 'startup' || value === 'iteration' || value === 'live') {
        config.mode = value;
      }
    } else if (arg.startsWith('--mode=')) {
      const value = arg.split('=')[1];
      if (value === 'startup' || value === 'iteration' || value === 'live') {
        config.mode = value;
      }
    }
    // --prd-path
    else if (arg === '--prd-path' || arg === '-p') {
      config.prdPath = args[++i];
    } else if (arg.startsWith('--prd-path=')) {
      config.prdPath = arg.split('=')[1];
    }
    // --working-dir
    else if (arg === '--working-dir' || arg === '-w') {
      config.workingDir = args[++i];
    } else if (arg.startsWith('--working-dir=')) {
      config.workingDir = arg.split('=')[1];
    }
    // --iteration (display only)
    else if (arg === '--iteration' || arg === '-i') {
      config.iteration = parseInt(args[++i], 10) || 1;
    } else if (arg.startsWith('--iteration=')) {
      config.iteration = parseInt(arg.split('=')[1], 10) || 1;
    }
    // --start-time
    else if (arg === '--start-time') {
      config.startTime = parseInt(args[++i], 10) || Date.now();
    } else if (arg.startsWith('--start-time=')) {
      config.startTime = parseInt(arg.split('=')[1], 10) || Date.now();
    }
    // --ntfy-topic
    else if (arg === '--ntfy-topic') {
      config.ntfyTopic = args[++i];
    } else if (arg.startsWith('--ntfy-topic=')) {
      config.ntfyTopic = arg.split('=')[1];
    }
    // --help
    else if (arg === '--help' || arg === '-h') {
      console.log(`
Ralph UI - React Ink Terminal Dashboard & Iteration Runner

Usage:
  bun ralph-ui/src/index.tsx [options]

Runner Mode (--run):
  --run, -r               Enable iteration runner (executes Claude in a loop)
  --iterations, -n <num>  Number of iterations to run (default: 100, env: RALPH_ITERATIONS)
  --gap, -g <seconds>     Seconds between iterations (default: 5, env: RALPH_SLEEP_SECONDS)
  --model <model>         Model to use: haiku, sonnet, opus, gemini-flash, gemini-flash-lite, gemini-3-flash, kiro, ollama (env: RALPH_MODEL)
  --quiet, -q             Suppress UI output (runner only)
  --verbose, -v           Enable verbose logging
  --notify                Send ntfy notifications (env: RALPH_NOTIFY)
  --pty                   Use PTY for live output (default, enables streaming)
  --no-pty                Use child_process spawning (legacy mode)

Display Mode (without --run):
  --mode, -m <mode>       Mode: startup, iteration, or live (default: live)

Common Options:
  --prd-path, -p <path>   Path to prd-json directory (default: ./prd-json)
  --working-dir, -w <path> Working directory for Claude (default: cwd)
  --iteration, -i <num>   Current iteration number for display (default: 1)
  --start-time <ms>       Start timestamp in milliseconds (default: now)
  --ntfy-topic <topic>    Ntfy notification topic (env: RALPH_NTFY_TOPIC)
  --help, -h              Show this help message

Examples:
  # Run iterations with display
  bun ralph-ui/src/index.tsx --run --iterations 100 --model opus

  # Run quietly (no UI)
  bun ralph-ui/src/index.tsx --run --quiet

  # Display only (watch mode)
  bun ralph-ui/src/index.tsx --mode live

  # Display PRD status once
  bun ralph-ui/src/index.tsx --mode startup

Modes:
  startup    Show initial PRD status and exit
  iteration  Show iteration status with progress
  live       Watch for file changes and update in real-time
`);
      process.exit(0);
    }
  }

  return config;
}

// Main execution
async function main() {
  const config = parseArgs();

  if (config.run) {
    // Runner mode: execute iterations
    await runInRunnerMode(config);
  } else {
    // Display-only mode: show dashboard
    await runInDisplayMode(config);
  }
}

// Format elapsed time from milliseconds to human-readable
function formatElapsed(ms: number): string {
  const seconds = Math.floor(ms / 1000);
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${mins}m ${secs}s`;
  } else if (mins > 0) {
    return `${mins}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

// Wait for any keypress (or timeout)
async function waitForKeypress(timeoutMs: number = 30000): Promise<void> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      cleanup();
      resolve();
    }, timeoutMs);

    const cleanup = () => {
      clearTimeout(timeout);
      if (process.stdin.isTTY) {
        process.stdin.setRawMode?.(false);
        process.stdin.pause();
        process.stdin.removeListener('data', handler);
      }
    };

    const handler = () => {
      cleanup();
      resolve();
    };

    if (process.stdin.isTTY) {
      process.stdin.setRawMode?.(true);
      process.stdin.resume();
      process.stdin.once('data', handler);
      console.log('\nPress any key to exit (or wait 30s)...');
    } else {
      // Non-TTY: just wait a short time for messages to be read
      setTimeout(resolve, 2000);
    }
  });
}

// Runner mode: executes iterations with optional UI
async function runInRunnerMode(config: CLIConfig) {
  const runnerConfig = createConfig({
    prdJsonDir: config.prdPath,
    workingDir: config.workingDir,
    iterations: config.iterations,
    gapSeconds: config.gap,
    model: config.model,
    notify: config.notify,
    ntfyTopic: config.ntfyTopic,
    quiet: config.quiet,
    verbose: config.verbose,
    usePty: config.usePty,
  });

  const runStartTime = Date.now();

  // Start UI if not quiet - use the global inkInstance
  if (!config.quiet) {
    // Create a wrapper component that handles exit callback
    const RunnerDashboard = () => {
      const handleExitRequest = React.useCallback(() => {
        exitRequested = true;
      }, []);

      return (
        <Dashboard
          mode="iteration"
          prdPath={config.prdPath}
          iteration={config.iteration}
          model={config.model}
          startTime={config.startTime}
          ntfyTopic={config.ntfyTopic}
          onExitRequest={handleExitRequest}
        />
      );
    };

    // AIDEV-NOTE: CRITICAL - Ink keyboard input setup (DO NOT REMOVE)
    // Without this, useInput() in Dashboard/ConfigMenu won't receive any keystrokes.
    // Both setRawMode(true) AND resume() are required BEFORE render().
    // See: docs.local/learnings/ralph-ui-keyboard-fix.md
    // See: ~/.claude/learnings/ink-stdin-keyboard-handling.md
    if (process.stdin.isTTY && process.stdin.setRawMode) {
      process.stdin.setRawMode(true);
      process.stdin.resume();
    }

    // AIDEV-NOTE: Pass stdin/stdout explicitly - Ink may not read stdin otherwise.
    // exitOnCtrlC: false because we handle Ctrl+C via SIGINT (line ~55).
    // DO NOT add process.stdin.on('data', ...) handlers - they conflict with Ink's useInput.
    // MP-131: Add performance optimizations for stable rendering
    inkInstance = render(<RunnerDashboard />, {
      exitOnCtrlC: false,
      stdin: process.stdin,
      stdout: process.stdout,
      maxFps: 10,              // Reduce from default 30 FPS
      incrementalRendering: true, // Only update changed lines
      debug: false,
    });

    // Also listen for Ink's exit event to set exitRequested
    inkInstance.waitUntilExit().then(() => {
      exitRequested = true;
    });
  }

  // Track stats for summary
  let storiesCompleted = 0;
  let iterationsRun = 0;
  let hasErrors = false;
  let exitReason: 'complete' | 'blocked' | 'interrupted' | 'iterations' = 'iterations';

  try {
    // Run iterations
    for await (const result of runIterations(runnerConfig)) {
      iterationsRun = result.iteration;

      // Track successful story completions
      if (result.success && result.storyId) {
        storiesCompleted++;
      }

      // Track errors
      if (result.error) {
        hasErrors = true;
      }

      // Check for exit request
      if (exitRequested) {
        exitReason = 'interrupted';
        break;
      }

      // Handle completion
      if (result.hasComplete) {
        exitReason = 'complete';
        break;
      }

      // Handle all blocked
      if (result.hasBlocked && !result.storyId) {
        exitReason = 'blocked';
        break;
      }
    }
  } finally {
    // Clear watchdog interval before cleanup
    clearInterval(watchdogInterval);

    // Cleanup status file
    cleanupStatus();

    // Unmount UI before showing summary
    if (inkInstance) {
      inkInstance.unmount();
      inkInstance = undefined;
    }
  }

  // Show completion summary (unless quiet)
  if (!config.quiet) {
    const elapsedMs = Date.now() - runStartTime;
    const elapsed = formatElapsed(elapsedMs);

    console.log('\n' + '═'.repeat(60));
    console.log('📋 RALPH SESSION SUMMARY');
    console.log('═'.repeat(60));

    // Status emoji and message based on exit reason
    switch (exitReason) {
      case 'complete':
        console.log('✅ Status: All stories complete!');
        break;
      case 'blocked':
        console.log('⚠️  Status: All remaining stories are blocked');
        break;
      case 'interrupted':
        console.log('🛑 Status: Interrupted by user');
        break;
      case 'iterations':
        console.log(`📊 Status: Completed ${config.iterations} iterations`);
        break;
    }

    console.log(`📈 Iterations run: ${iterationsRun}`);
    console.log(`📚 Stories completed: ${storiesCompleted}`);
    console.log(`⏱  Elapsed time: ${elapsed}`);
    if (hasErrors) {
      console.log('⚠️  Some iterations had errors (check progress.txt)');
    }
    console.log('═'.repeat(60));

    // Wait for keypress before exiting
    await waitForKeypress();
  }

  cleanupAndExit(0);
}

// Display-only mode: show dashboard without running iterations
async function runInDisplayMode(config: CLIConfig) {
  // AIDEV-NOTE: CRITICAL - Ink keyboard input setup (DO NOT REMOVE)
  // Without this, useInput() in Dashboard/ConfigMenu won't receive any keystrokes.
  // Both setRawMode(true) AND resume() are required BEFORE render().
  // See: docs.local/learnings/ralph-ui-keyboard-fix.md
  if (process.stdin.isTTY && process.stdin.setRawMode) {
    process.stdin.setRawMode(true);
    process.stdin.resume();
  }

  // AIDEV-NOTE: Pass stdin/stdout explicitly - Ink may not read stdin otherwise.
  // exitOnCtrlC: false because we handle Ctrl+C via SIGINT (line ~55).
  // MP-131: Add performance optimizations for stable rendering
  inkInstance = render(
    <Dashboard
      mode={config.mode}
      prdPath={config.prdPath}
      iteration={config.iteration}
      model={config.model}
      startTime={config.startTime}
      ntfyTopic={config.ntfyTopic}
    />,
    {
      exitOnCtrlC: false,
      stdin: process.stdin,
      stdout: process.stdout,
      maxFps: 10,              // Reduce from default 30 FPS
      incrementalRendering: true, // Only update changed lines
      debug: false,
    }
  );

  // Wait for the app to exit, then cleanup
  await inkInstance.waitUntilExit();
  cleanupAndExit(0);
}

// Run main
main().catch((error) => {
  console.error('Error:', error);
  cleanupAndExit(1);
});
