import React, { useState, useEffect, useCallback } from 'react';
import { Box, Text, useStdout, useStdin, useInput, useApp } from 'ink';
import { IterationHeader } from './IterationHeader.js';
import { PRDStatus } from './PRDStatus.js';
import { StoryBox } from './StoryBox.js';
import { NotificationStatus } from './NotificationStatus.js';
import { AliveIndicator } from './AliveIndicator.js';
import { CodeRabbitStatus } from './CodeRabbitStatus.js';
import { ErrorBanner } from './ErrorBanner.js';
import { RetryCountdown } from './RetryCountdown.js';
import { HangingWarning } from './HangingWarning.js';
import { ConfigMenu } from './ConfigMenu.js';
import { useFileWatch } from '../hooks/useFileWatch.js';
import { useStatusFile } from '../hooks/useStatusFile.js';
import type { DashboardProps, PRDStats } from '../types.js';

// Live clock hook - only used in live mode
// MP-131: Synchronized with other 1000ms timers to reduce render conflicts
function useLiveClock(enabled: boolean): string {
  const [time, setTime] = useState(() => new Date().toLocaleTimeString());

  useEffect(() => {
    if (!enabled) return;

    // Synchronize with other 1000ms timers by starting at next second boundary
    const now = Date.now();
    const msUntilNextSecond = 1000 - (now % 1000);
    let intervalId: ReturnType<typeof setInterval> | null = null;

    const initialTimeout = setTimeout(() => {
      setTime(new Date().toLocaleTimeString());

      // Then update every second
      intervalId = setInterval(() => {
        setTime(new Date().toLocaleTimeString());
      }, 1000);
    }, msUntilNextSecond);

    return () => {
      clearTimeout(initialTimeout);
      if (intervalId) clearInterval(intervalId);
    };
  }, [enabled]);

  return time;
}

// AIDEV-NOTE: Ink's useInput hook throws an error when called in non-TTY contexts
// (even with isActive: false). We must conditionally render the component that uses it.
// This is split into two components: one that uses useInput (for TTY), one that doesn't.

// Component that uses Ink's useInput - only rendered when raw mode IS supported
function RawModeKeyboardHandler({ onExit, onConfig, configActive }: { onExit: () => void; onConfig: () => void; configActive: boolean }) {
  // AIDEV-NOTE: Ctrl+C is handled by SIGINT handler in index.tsx, not here.
  // Disabled when config menu is active (ConfigMenu handles its own input)
  useInput((input, key) => {
    if (input === 'q' || key.escape) {
      onExit();
    } else if (input === 'c') {
      onConfig();
    }
  }, { isActive: !configActive });

  return null;
}

// Component that uses manual stdin handling - only rendered when raw mode is NOT supported
// AIDEV-NOTE: Ctrl+C is handled by SIGINT handler in index.tsx, not here.
function FallbackKeyboardHandler({ onExit, onConfig, configActive }: { onExit: () => void; onConfig: () => void; configActive: boolean }) {
  useEffect(() => {
    if (configActive) return; // Config menu handles its own input

    const stdinHandler = (data: Buffer) => {
      const char = data.toString();
      if (char === 'q' || char === '\x1b') { // q, Escape
        onExit();
      } else if (char === 'c') {
        onConfig();
      }
    };

    if (process.stdin.isTTY) {
      process.stdin.setRawMode?.(true);
      process.stdin.resume();
      process.stdin.on('data', stdinHandler);

      return () => {
        process.stdin.off('data', stdinHandler);
        process.stdin.setRawMode?.(false);
      };
    }
  }, [onExit, onConfig, configActive]);

  return null;
}

// Wrapper component that conditionally renders the appropriate keyboard handler
// AIDEV-NOTE: This component handles keyboard input for the dashboard.
// It calls onExit() which signals the parent to exit gracefully.
// The actual process.exit() is handled by the global signal handlers in index.tsx.
// Also handles 'c' key to open config menu.
function KeyboardHandler({ onExit, onConfig, configActive }: { onExit: () => void; onConfig: () => void; configActive: boolean }) {
  const { isRawModeSupported } = useStdin();

  // Conditionally render based on raw mode support to avoid Ink errors
  if (isRawModeSupported) {
    return <RawModeKeyboardHandler onExit={onExit} onConfig={onConfig} configActive={configActive} />;
  }

  return <FallbackKeyboardHandler onExit={onExit} onConfig={onConfig} configActive={configActive} />;
}

export const Dashboard = React.memo(({
  mode,
  prdPath,
  iteration = 1,
  model = 'sonnet',
  startTime = Date.now(),
  ntfyTopic,
  onExitRequest,
}: DashboardProps) => {
  const { stdout } = useStdout();
  const { isRawModeSupported } = useStdin();
  const { exit } = useApp();
  const [terminalWidth, setTerminalWidth] = useState(stdout?.columns || 80);
  const [showConfig, setShowConfig] = useState(false);
  const isLiveMode = mode === 'live';
  const isIterationMode = mode === 'iteration';
  const currentTime = useLiveClock(isLiveMode || isIterationMode);

  // Stable exit callback - calls onExitRequest first (for runner mode), then exits UI
  const handleExit = useCallback(() => {
    if (onExitRequest) {
      onExitRequest();
    }
    exit();
  }, [exit, onExitRequest]);

  // Toggle config menu
  const handleOpenConfig = useCallback(() => {
    setShowConfig(true);
  }, []);

  const handleCloseConfig = useCallback(() => {
    setShowConfig(false);
  }, []);

  // Auto-exit for startup mode only: render once, then exit immediately
  // Iteration mode should stay open for live updates
  useEffect(() => {
    if (mode === 'startup') {
      // Use setImmediate/setTimeout 0 to allow render to complete, then exit
      const timer = setTimeout(() => {
        handleExit();
      }, 100); // 100ms to ensure render completes
      return () => clearTimeout(timer);
    }
  }, [mode, handleExit]);

  // Poll for file changes in live and iteration modes (fs.watch unreliable on macOS)
  const liveStats = useFileWatch({
    prdPath,
    enabled: isLiveMode || mode === 'iteration', // Poll in both live and iteration modes
    intervalMs: 1000,
  });

  // Watch ralph status file for live state updates
  const ralphStatus = useStatusFile({
    enabled: isLiveMode || mode === 'iteration',
    pollIntervalMs: 1000,
  });

  // Use live stats if available, otherwise use defaults
  const stats: PRDStats = liveStats || {
    totalStories: 0,
    completedStories: 0,
    pendingStories: 0,
    blockedStories: 0,
    totalCriteria: 0,
    checkedCriteria: 0,
    currentStory: null,
    nextStoryId: '',
  };

  // Handle terminal resize
  useEffect(() => {
    const handleResize = () => {
      if (stdout) {
        setTerminalWidth(stdout.columns);
      }
    };

    stdout?.on('resize', handleResize);
    return () => {
      stdout?.off('resize', handleResize);
    };
  }, [stdout]);

  return (
    <Box key={`dashboard-${ralphStatus?.iteration ?? iteration}-${ralphStatus?.state ?? 'unknown'}`} flexDirection="column" width={terminalWidth}>
      {/* Keyboard handler - in live or iteration mode (SIGINT works even without raw mode) */}
      {(isLiveMode || isIterationMode) && (
        <KeyboardHandler onExit={handleExit} onConfig={handleOpenConfig} configActive={showConfig} />
      )}

      {/* Config Menu overlay */}
      {showConfig && (
        <ConfigMenu onClose={handleCloseConfig} />
      )}

      {/* Header */}
      <Box marginBottom={1}>
        <Text bold color="blue">
          ╭{'─'.repeat(Math.min(terminalWidth - 2, 78))}╮
        </Text>
      </Box>
      <Box marginBottom={1} justifyContent="space-between" paddingX={2}>
        <Text bold color="blue">🐺 RALPH - React Ink Terminal UI</Text>
        <Text color="cyan">🕐 {currentTime}</Text>
      </Box>

      {/* Iteration Header (shown in iteration/live modes) - reads from status file for dynamic values */}
      {(mode === 'iteration' || mode === 'live') && (
        <Box marginBottom={1}>
          <IterationHeader
            iteration={ralphStatus?.iteration ?? iteration}
            model={ralphStatus?.model ?? model}
            startTime={ralphStatus?.startTime ?? startTime}
            isRunning={mode === 'iteration'}
          />
        </Box>
      )}

      {/* Ralph Status Indicators (shown in iteration/live modes) */}
      {(mode === 'iteration' || mode === 'live') && ralphStatus && (
        <Box flexDirection="column" marginBottom={1} gap={1}>
          {/* Alive Indicator - always show when running */}
          <AliveIndicator
            lastActivity={ralphStatus.lastActivity}
            isRunning={ralphStatus.state === 'running' || ralphStatus.state === 'cr_review'}
          />

          {/* CodeRabbit Status - show during CR review */}
          <CodeRabbitStatus isReviewing={ralphStatus.state === 'cr_review'} />

          {/* Error Banner - show on error */}
          <ErrorBanner error={ralphStatus.error} />

          {/* Retry Countdown - show during retry */}
          <RetryCountdown
            retryIn={ralphStatus.retryIn}
            isRetrying={ralphStatus.state === 'retry'}
          />

          {/* Hanging Warning - show if no activity for >60s */}
          <HangingWarning
            lastActivity={ralphStatus.lastActivity}
            isRunning={ralphStatus.state === 'running' || ralphStatus.state === 'cr_review'}
            thresholdSeconds={60}
          />
        </Box>
      )}

      {/* PRD Status */}
      <Box marginBottom={1}>
        <PRDStatus stats={stats} />
      </Box>

      {/* Current Story */}
      {stats.currentStory && (
        <Box marginBottom={1}>
          <StoryBox story={stats.currentStory} />
        </Box>
      )}

      {/* Notification Status */}
      <Box marginBottom={1}>
        <NotificationStatus topic={ntfyTopic} enabled={!!ntfyTopic} />
      </Box>

      {/* Footer - show quit hint in live and iteration modes */}
      <Box marginTop={1}>
        <Text dimColor>
          {(isLiveMode || isIterationMode)
            ? (isRawModeSupported ? "'q' quit • 'c' config" : 'Ctrl+C to quit (no raw mode)')
            : `Mode: ${mode}`} • Terminal width: {terminalWidth}
        </Text>
      </Box>
    </Box>
  );
});
