import React from 'react';
import { Box, Text } from 'ink';
import { ProgressBar } from './ProgressBar.js';
import type { PRDStats } from '../types.js';

interface PRDStatusProps {
  stats: PRDStats;
}

export function PRDStatus({ stats }: PRDStatusProps) {
  const {
    totalStories,
    completedStories,
    pendingStories,
    blockedStories,
    totalCriteria,
    checkedCriteria,
  } = stats;

  return (
    <Box flexDirection="column" borderStyle="single" borderColor="blue" paddingX={1}>
      <Text bold color="blue">📊 PRD Status</Text>

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

      <Box marginTop={1} flexDirection="column">
        <Text>Story Progress:</Text>
        <ProgressBar
          current={completedStories}
          total={totalStories}
          color="green"
          width={25}
        />
      </Box>

      <Box marginTop={1} flexDirection="column">
        <Text>Criteria Progress:</Text>
        <ProgressBar
          current={checkedCriteria}
          total={totalCriteria}
          color="cyan"
          width={25}
        />
      </Box>
    </Box>
  );
}
