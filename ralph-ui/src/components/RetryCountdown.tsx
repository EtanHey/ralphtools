import React, { useState, useEffect } from 'react';
import { Box, Text } from 'ink';

interface RetryCountdownProps {
  retryIn: number; // Initial seconds until retry
  isRetrying: boolean;
}

/**
 * Shows countdown timer when Ralph is waiting to retry after an error.
 */
export function RetryCountdown({ retryIn, isRetrying }: RetryCountdownProps) {
  const [secondsLeft, setSecondsLeft] = useState(retryIn);

  // Reset countdown when retryIn changes
  useEffect(() => {
    setSecondsLeft(retryIn);
  }, [retryIn]);

  // Count down every second
  useEffect(() => {
    if (!isRetrying || secondsLeft <= 0) return;

    const interval = setInterval(() => {
      setSecondsLeft(prev => Math.max(0, prev - 1));
    }, 1000);

    return () => clearInterval(interval);
  }, [isRetrying, secondsLeft]);

  if (!isRetrying || secondsLeft <= 0) {
    return null;
  }

  // Progress bar showing time remaining
  const maxWidth = 20;
  const progress = Math.ceil((secondsLeft / Math.max(retryIn, 1)) * maxWidth);
  const bar = '▓'.repeat(progress) + '░'.repeat(maxWidth - progress);

  return (
    <Box
      borderStyle="round"
      borderColor="yellow"
      paddingX={1}
      flexDirection="column"
    >
      <Box gap={1}>
        <Text color="yellow" bold>
          ⏳ Retrying
        </Text>
        <Text color="yellowBright">
          in {secondsLeft}s
        </Text>
      </Box>
      <Text color="yellow">
        [{bar}]
      </Text>
    </Box>
  );
}
