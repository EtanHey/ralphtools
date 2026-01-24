import React from 'react';
import { Box, Text } from 'ink';
import { ProgressBar } from './ProgressBar.js';
import { ModelRoutingDisplay, DEFAULT_ROUTING } from './ModelRouting.js';
import type { PRDStats, ModelRouting, ModelName } from '../types.js';

interface StartupBannerProps {
  version: string;
  prdPath: string;
  stats: PRDStats;
  routing?: ModelRouting[];
  strategy?: 'smart' | 'single';
  defaultModel?: ModelName;
}

/**
 * Ralph startup banner showing version, path, stats, and criteria count
 * Matches the ralph.zsh startup display
 */
export function StartupBanner({
  version,
  prdPath,
  stats,
  routing = DEFAULT_ROUTING,
  strategy = 'smart',
  defaultModel = 'sonnet',
}: StartupBannerProps) {
  const {
    totalStories,
    completedStories,
    pendingStories,
    blockedStories,
    totalCriteria,
    checkedCriteria,
  } = stats;

  return (
    <Box flexDirection="column">
      {/* Header */}
      <Box marginBottom={1}>
        <Text bold color="blue">
          ╭{'─'.repeat(63)}╮
        </Text>
      </Box>
      <Box justifyContent="center" marginBottom={1}>
        <Text bold color="blue">🐺 RALPH v{version}</Text>
      </Box>

      {/* Path */}
      <Box marginBottom={1}>
        <Text dimColor>📁 </Text>
        <Text>{prdPath}</Text>
      </Box>

      {/* Stats box */}
      <Box flexDirection="column" borderStyle="single" borderColor="blue" paddingX={1} marginBottom={1}>
        <Text bold color="blue">📊 PRD Status</Text>

        {/* Story counts */}
        <Box marginTop={1}>
          <Text>Stories: </Text>
          <Text color="green">{completedStories} done</Text>
          <Text> / </Text>
          <Text color="yellow">{pendingStories} pending</Text>
          {blockedStories > 0 && (
            <>
              <Text> / </Text>
              <Text color="red">{blockedStories} blocked</Text>
            </>
          )}
          <Text dimColor> ({totalStories} total)</Text>
        </Box>

        {/* Story progress bar */}
        <Box marginTop={1} flexDirection="column">
          <Text>Story Progress:</Text>
          <ProgressBar
            current={completedStories}
            total={totalStories}
            width={25}
          />
        </Box>

        {/* Criteria progress bar */}
        <Box marginTop={1} flexDirection="column">
          <Text>Criteria Progress:</Text>
          <ProgressBar
            current={checkedCriteria}
            total={totalCriteria}
            width={25}
          />
        </Box>
      </Box>

      {/* Model routing */}
      <ModelRoutingDisplay
        routing={routing}
        strategy={strategy}
        defaultModel={defaultModel}
      />

      {/* Footer */}
      <Box marginTop={1}>
        <Text dimColor>
          ╰{'─'.repeat(63)}╯
        </Text>
      </Box>
    </Box>
  );
}

/**
 * Compact startup info (single line)
 */
export function StartupInfo({
  version,
  pendingStories,
  totalCriteria,
}: {
  version: string;
  pendingStories: number;
  totalCriteria: number;
}) {
  return (
    <Box>
      <Text>🐺 RALPH v{version}</Text>
      <Text dimColor> │ </Text>
      <Text>{pendingStories} pending stories</Text>
      <Text dimColor> │ </Text>
      <Text>{totalCriteria} criteria</Text>
    </Box>
  );
}
