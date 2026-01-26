import React, { useState, useEffect, useMemo } from 'react';
import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';

interface AliveIndicatorProps {
  lastActivity: number; // Unix timestamp in seconds
  isRunning: boolean;
}

/**
 * Shows a spinner and "last activity Xs ago" indicator.
 * Helps users know Ralph is still processing.
 * MP-131: Optimized to only re-render when display value changes.
 */
export const AliveIndicator = React.memo(({ lastActivity, isRunning }: AliveIndicatorProps) => {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  const [lastDisplayText, setLastDisplayText] = useState('');

  // Format the time ago string - memoized to prevent recalculation
  const formatTimeAgo = useMemo(() => {
    return (seconds: number): string => {
      if (seconds < 5) return 'just now';
      if (seconds < 60) return `${seconds}s ago`;
      if (seconds < 3600) {
        const mins = Math.floor(seconds / 60);
        return `${mins}m ago`;
      }
      const hours = Math.floor(seconds / 3600);
      return `${hours}h ago`;
    };
  }, []);

  // Color based on how long since last activity - memoized
  const getColor = useMemo(() => {
    return (seconds: number): string => {
      if (seconds < 10) return 'green';
      if (seconds < 30) return 'yellow';
      if (seconds < 60) return 'yellowBright';
      return 'red';
    };
  }, []);

  // Calculate current display values
  const secondsAgo = now - lastActivity;
  const displayText = useMemo(() => formatTimeAgo(secondsAgo), [formatTimeAgo, secondsAgo]);
  const displayColor = useMemo(() => getColor(secondsAgo), [getColor, secondsAgo]);

  // Only update "now" when the display text would actually change
  useEffect(() => {
    const interval = setInterval(() => {
      const currentNow = Math.floor(Date.now() / 1000);
      const currentSecondsAgo = currentNow - lastActivity;
      const currentDisplayText = formatTimeAgo(currentSecondsAgo);
      
      // Only update state if display text would change
      if (currentDisplayText !== lastDisplayText) {
        setNow(currentNow);
        setLastDisplayText(currentDisplayText);
      }
    }, 1000);
    
    return () => clearInterval(interval);
  }, [lastActivity, formatTimeAgo, lastDisplayText]);

  // Initialize lastDisplayText on first render
  useEffect(() => {
    if (!lastDisplayText) {
      setLastDisplayText(displayText);
    }
  }, [displayText, lastDisplayText]);

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
      <Text color={displayColor}>
        Last activity: {displayText}
      </Text>
    </Box>
  );
});
