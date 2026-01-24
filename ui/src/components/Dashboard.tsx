import React, { useState, useEffect } from 'react';
import { Box, Text, useStdout, useStdin, useInput, useApp } from 'ink';
import Spinner from 'ink-spinner';
import { StartupBanner, StartupInfo } from './StartupBanner.js';
import { IterationBox } from './IterationBox.js';
import { StoryId } from './StoryId.js';
import { ProgressBar } from './ProgressBar.js';
import { useFileWatch } from '../hooks/useFileWatch.js';
import { useInPlaceRender } from '../hooks/useCursor.js';
import type { PRDStats, IterationInfo, DisplayMode, ModelName } from '../types.js';

interface DashboardProps {
  mode: 'startup' | 'iteration' | 'live';
  prdPath: string;
  version?: string;
  iteration?: number;
  maxIterations?: number;
  model?: ModelName;
  startTime?: number;
  cost?: number;
  displayMode?: DisplayMode;
  /** Debounce for file watching (default 500ms) */
  debounceMs?: number;
}

// Wrapper component that conditionally uses input
function KeyboardHandler({ onExit }: { onExit: () => void }) {
  useInput((input, key) => {
    if (input === 'q' || (key.ctrl && input === 'c')) {
      onExit();
    }
  });
  return null;
}

/**
 * Format elapsed time from start timestamp
 */
function formatElapsed(startTime: number): string {
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const hours = Math.floor(elapsed / 3600);
  const minutes = Math.floor((elapsed % 3600) / 60);
  const seconds = elapsed % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ${seconds}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }
  return `${seconds}s`;
}

/**
 * Main Dashboard component
 * Supports startup, iteration, and live modes
 * Supports compact (single line) and full (box) display modes
 */
export function Dashboard({
  mode,
  prdPath,
  version = '1.0.0',
  iteration = 1,
  maxIterations = 100,
  model = 'sonnet',
  startTime = Date.now(),
  cost = 0,
  displayMode = 'full',
  debounceMs = 500,
}: DashboardProps) {
  const { stdout } = useStdout();
  const { isRawModeSupported } = useStdin();
  const { exit } = useApp();
  const [terminalWidth, setTerminalWidth] = useState(stdout?.columns || 80);
  const [elapsedTime, setElapsedTime] = useState('0s');

  // Watch for file changes in live mode
  const liveStats = useFileWatch({
    prdPath,
    enabled: mode === 'live' || mode === 'iteration',
    debounceMs,
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

  // Update elapsed time periodically
  useEffect(() => {
    if (mode !== 'iteration') return;

    const interval = setInterval(() => {
      setElapsedTime(formatElapsed(startTime));
    }, 1000);

    return () => clearInterval(interval);
  }, [startTime, mode]);

  // Calculate line count for in-place rendering
  const lineCount = displayMode === 'compact' ? 2 : 15;
  useInPlaceRender(lineCount);

  // Build iteration info
  const iterationInfo: IterationInfo = {
    current: iteration,
    max: maxIterations,
    story: stats.nextStoryId || 'unknown',
    model,
    startTime,
    cost,
  };

  // Compact mode
  if (displayMode === 'compact') {
    return (
      <Box flexDirection="column" width={terminalWidth}>
        {isRawModeSupported && <KeyboardHandler onExit={exit} />}

        {mode === 'startup' && (
          <StartupInfo
            version={version}
            pendingStories={stats.pendingStories}
            totalCriteria={stats.totalCriteria}
          />
        )}

        {(mode === 'iteration' || mode === 'live') && (
          <IterationBox
            iteration={iterationInfo}
            stats={stats}
            elapsed={elapsedTime}
            mode="compact"
          />
        )}
      </Box>
    );
  }

  // Full mode
  return (
    <Box flexDirection="column" width={terminalWidth}>
      {/* Keyboard handler - only when raw mode is supported */}
      {isRawModeSupported && <KeyboardHandler onExit={exit} />}

      {/* Startup mode: show full banner */}
      {mode === 'startup' && (
        <StartupBanner
          version={version}
          prdPath={prdPath}
          stats={stats}
        />
      )}

      {/* Iteration mode: show iteration box */}
      {mode === 'iteration' && (
        <Box flexDirection="column">
          <Box marginBottom={1}>
            <Text color="cyan">
              <Spinner type="dots" />{' '}
            </Text>
            <Text bold color="cyan">Iteration {iteration}/{maxIterations}</Text>
          </Box>

          <IterationBox
            iteration={iterationInfo}
            stats={stats}
            elapsed={elapsedTime}
            mode="full"
          />

          {/* Current story details */}
          {stats.currentStory && (
            <Box flexDirection="column" marginTop={1} borderStyle="round" borderColor="blue" paddingX={1}>
              <Box>
                <StoryId id={stats.currentStory.id} />
                <Text> - {stats.currentStory.title}</Text>
              </Box>

              <Box marginTop={1}>
                <Text>Criteria: </Text>
                <ProgressBar
                  current={stats.currentStory.acceptanceCriteria.filter(c => c.checked).length}
                  total={stats.currentStory.acceptanceCriteria.length}
                  width={15}
                />
              </Box>
            </Box>
          )}
        </Box>
      )}

      {/* Live mode: show live-updating stats */}
      {mode === 'live' && (
        <Box flexDirection="column">
          <Box marginBottom={1}>
            <Text color="green">
              <Spinner type="dots" />{' '}
            </Text>
            <Text bold color="green">Live Mode</Text>
            <Text dimColor> (watching {prdPath})</Text>
          </Box>

          <StartupBanner
            version={version}
            prdPath={prdPath}
            stats={stats}
          />
        </Box>
      )}

      {/* Footer */}
      <Box marginTop={1}>
        <Text dimColor>
          {isRawModeSupported ? "Press 'q' to quit" : 'Ctrl+C to quit'}
          {' • '}
          Width: {terminalWidth}
        </Text>
      </Box>
    </Box>
  );
}
