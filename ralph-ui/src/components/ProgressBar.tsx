import React from 'react';
import { Box, Text } from 'ink';

interface ProgressBarProps {
  current: number;
  total: number;
  width?: number;
  showPercentage?: boolean;
  color?: string;
  label?: string;
}

export function ProgressBar({
  current,
  total,
  width = 20,
  showPercentage = true,
  color = 'green',
  label,
}: ProgressBarProps) {
  const percentage = total > 0 ? Math.round((current / total) * 100) : 0;
  const filled = total > 0 ? Math.round((current / total) * width) : 0;
  const empty = width - filled;

  const filledBar = '█'.repeat(filled);
  const emptyBar = '░'.repeat(empty);

  return (
    <Box>
      {label && <Text>{label} </Text>}
      <Text color={color}>{filledBar}</Text>
      <Text dimColor>{emptyBar}</Text>
      {showPercentage && (
        <Text> {current}/{total} ({percentage}%)</Text>
      )}
    </Box>
  );
}
