import React, { useState, useEffect } from 'react';
import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';

interface AliveIndicatorProps {
  lastActivity: number; // Unix timestamp in seconds
  isRunning: boolean;
}

/**
 * Shows a spinner and "last activity Xs ago" indicator.
 * Helps users know Ralph is still processing.
 */
export function AliveIndicator({ lastActivity, isRunning }: AliveIndicatorProps) {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));

  // Update "now" every second for relative time display
  useEffect(() => {
    const interval = setInterval(() => {
      setNow(Math.floor(Date.now() / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const secondsAgo = now - lastActivity;

  // Format the time ago string
  const formatTimeAgo = (seconds: number): string => {
    if (seconds < 5) return 'just now';
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) {
      const mins = Math.floor(seconds / 60);
      return `${mins}m ago`;
    }
    const hours = Math.floor(seconds / 3600);
    return `${hours}h ago`;
  };

  // Color based on how long since last activity
  const getColor = (seconds: number): string => {
    if (seconds < 10) return 'green';
    if (seconds < 30) return 'yellow';
    if (seconds < 60) return 'yellowBright';
    return 'red';
  };

  if (!isRunning) {
    return (
      <Box>
        <Text color="gray">○ Idle</Text>
      </Box>
    );
  }

  return (
    <Box gap={1}>
      <Text color="green">
        <Spinner type="dots" />
      </Text>
      <Text color={getColor(secondsAgo)}>
        Last activity: {formatTimeAgo(secondsAgo)}
      </Text>
    </Box>
  );
}
