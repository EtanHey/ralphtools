import React, { useState, useEffect, useMemo } from 'react';
import { Box, Text } from 'ink';

interface RetryCountdownProps {
  retryIn: number; // Initial seconds until retry
  isRetrying: boolean;
}

/**
 * Shows countdown timer when Ralph is waiting to retry after an error.
 * MP-131: Optimized with memoization to reduce re-render overhead.
 */
export const RetryCountdown = React.memo(({ retryIn, isRetrying }: RetryCountdownProps) => {
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

  // Memoize progress bar calculation to prevent recalculation on every render
  const progressBar = useMemo(() => {
    const maxWidth = 20;
    const rawProgress = Math.ceil((secondsLeft / Math.max(retryIn, 1)) * maxWidth);
    // Guard against negative, NaN, or Infinity values
    const progress = Math.min(maxWidth, Math.max(0, Number.isFinite(rawProgress) ? rawProgress : 0));
    const remaining = maxWidth - progress;
    return '▓'.repeat(progress) + '░'.repeat(remaining);
  }, [secondsLeft, retryIn]);

  if (!isRetrying || secondsLeft <= 0) {
    return null;
  }

  // Use stable key to prevent duplicate box renders during countdown
  const stableKey = `retry-${retryIn}-${isRetrying}`;

  return (
    <Box
      key={stableKey}
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
        [{progressBar}]
      </Text>
    </Box>
  );
});
