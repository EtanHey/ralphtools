import React from 'react';
import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';

interface IterationHeaderProps {
  iteration: number;
  model: string;
  startTime: number;
  isRunning?: boolean;
}

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

export function IterationHeader({
  iteration,
  model,
  startTime,
  isRunning = true,
}: IterationHeaderProps) {
  return (
    <Box flexDirection="column" borderStyle="round" borderColor="cyan" paddingX={1}>
      <Box justifyContent="space-between">
        <Box>
          {isRunning && (
            <Text color="green">
              <Spinner type="dots" />
              {' '}
            </Text>
          )}
          <Text bold color="cyan">Iteration {iteration}</Text>
        </Box>
        <Text color="yellow">Model: {model}</Text>
      </Box>
      <Box justifyContent="flex-end">
        <Text dimColor>Elapsed: {formatElapsed(startTime)}</Text>
      </Box>
    </Box>
  );
}
