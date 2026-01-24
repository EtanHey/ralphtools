import React from 'react';
import { Box, Text } from 'ink';

interface NotificationStatusProps {
  topic?: string;
  enabled?: boolean;
}

export function NotificationStatus({ topic, enabled = true }: NotificationStatusProps) {
  if (!enabled || !topic) {
    return (
      <Box borderStyle="single" borderColor="gray" paddingX={1}>
        <Text dimColor>🔔 Notifications: disabled</Text>
      </Box>
    );
  }

  return (
    <Box
      flexDirection="column"
      borderStyle="single"
      borderColor="green"
      paddingX={1}
      flexWrap="wrap"
    >
      <Box>
        <Text color="green">🔔 Notifications: enabled</Text>
      </Box>
      <Box flexWrap="wrap">
        <Text dimColor>Topic: </Text>
        <Text wrap="wrap">{topic}</Text>
      </Box>
    </Box>
  );
}
