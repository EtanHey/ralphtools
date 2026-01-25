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
import { useFileWatch } from '../hooks/useFileWatch.js';
import { useStatusFile } from '../hooks/useStatusFile.js';
import type { DashboardProps, PRDStats } from '../types.js';

// Live clock hook - only used in live mode
function useLiveClock(enabled: boolean): string {
  const [time, setTime] = useState(() => new Date().toLocaleTimeString());

  useEffect(() => {
    if (!enabled) return;

    const interval = setInterval(() => {
      setTime(new Date().toLocaleTimeString());
    }, 1000);
    return () => clearInterval(interval);
  }, [enabled]);

  return time;
}

// Wrapper component that conditionally uses input (only for live mode)
function KeyboardHandler({ onExit }: { onExit: () => void }) {
  const { isRawModeSupported } = useStdin();

  // Use Ink's useInput when raw mode is available
  useInput((input, key) => {
    if (input === 'q' || (key.ctrl && input === 'c') || key.escape) {
      onExit();
    }
  }, { isActive: isRawModeSupported });

  // Handle SIGINT (Ctrl+C) at process level - works even without raw mode
  useEffect(() => {
    const sigintHandler = () => {
      onExit();
      process.exit(0);
    };
    process.on('SIGINT', sigintHandler);

    // Also handle SIGTERM for graceful shutdown
    process.on('SIGTERM', sigintHandler);

    return () => {
      process.off('SIGINT', sigintHandler);
      process.off('SIGTERM', sigintHandler);
    };
  }, [onExit]);

  // Fallback: direct stdin handler when raw mode not available
  useEffect(() => {
    if (isRawModeSupported) return; // useInput handles it

    const stdinHandler = (data: Buffer) => {
      const char = data.toString();
      if (char === 'q' || char === '\x03' || char === '\x1b') { // q, Ctrl+C, Escape
        onExit();
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
  }, [isRawModeSupported, onExit]);

  return null;
}

export function Dashboard({
  mode,
  prdPath,
  iteration = 1,
  model = 'sonnet',
  startTime = Date.now(),
  ntfyTopic,
}: DashboardProps & { ntfyTopic?: string }) {
  const { stdout } = useStdout();
  const { isRawModeSupported } = useStdin();
  const { exit } = useApp();
  const [terminalWidth, setTerminalWidth] = useState(stdout?.columns || 80);
  const isLiveMode = mode === 'live';
  const currentTime = useLiveClock(isLiveMode);

  // Stable exit callback
  const handleExit = useCallback(() => {
    exit();
  }, [exit]);

  // Auto-exit for non-live modes: render once, then exit immediately
  useEffect(() => {
    if (!isLiveMode) {
      // Use setImmediate/setTimeout 0 to allow render to complete, then exit
      const timer = setTimeout(() => {
        handleExit();
      }, 100); // 100ms to ensure render completes
      return () => clearTimeout(timer);
    }
  }, [isLiveMode, handleExit]);

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
    <Box flexDirection="column" width={terminalWidth}>
      {/* Keyboard handler - in live mode (SIGINT works even without raw mode) */}
      {isLiveMode && <KeyboardHandler onExit={handleExit} />}

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

      {/* Iteration Header (shown in iteration/live modes) */}
      {(mode === 'iteration' || mode === 'live') && (
        <Box marginBottom={1}>
          <IterationHeader
            iteration={iteration}
            model={model}
            startTime={startTime}
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

      {/* Footer - only show quit hint in live mode */}
      <Box marginTop={1}>
        <Text dimColor>
          {isLiveMode
            ? (isRawModeSupported ? "Press 'q' to quit" : 'Ctrl+C to quit')
            : `Mode: ${mode}`} • Terminal width: {terminalWidth}
        </Text>
      </Box>
    </Box>
  );
}
