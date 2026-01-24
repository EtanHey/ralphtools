import React, { useState, useEffect } from 'react';
import { Box, Text } from 'ink';

interface HangingWarningProps {
  lastActivity: number; // Unix timestamp in seconds
  thresholdSeconds?: number; // When to show warning (default: 60)
  isRunning: boolean;
}

/**
 * Yellow warning shown when no activity for >60 seconds.
 * Helps users know if Ralph might be stuck or waiting.
 */
export function HangingWarning({
  lastActivity,
  thresholdSeconds = 60,
  isRunning,
}: HangingWarningProps) {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

  // Update time every second
  useEffect(() => {
    if (!isRunning) return;

    const interval = setInterval(() => {
      setNow(Math.floor(Date.now() / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, [isRunning]);

  if (!isRunning) {
    return null;
  }

  const secondsAgo = now - lastActivity;

  if (secondsAgo < thresholdSeconds) {
    return null;
  }

  // Format duration for display
  const formatDuration = (seconds: number): string => {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    if (mins < 60) return `${mins}m ${secs}s`;
    const hours = Math.floor(mins / 60);
    const remainingMins = mins % 60;
    return `${hours}h ${remainingMins}m`;
  };

  return (
    <Box
      borderStyle="round"
      borderColor="yellow"
      paddingX={1}
      flexDirection="column"
    >
      <Text color="yellow" bold>
        ⚠️ Possible Hang Detected
      </Text>
      <Text color="yellowBright">
        No activity for {formatDuration(secondsAgo)}
      </Text>
      <Text color="gray" dimColor>
        Claude may be processing a large response, or stuck.
      </Text>
    </Box>
  );
}
