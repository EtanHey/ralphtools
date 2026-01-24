import React from 'react';
import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';

interface CodeRabbitStatusProps {
  isReviewing: boolean;
}

/**
 * Shows CodeRabbit review status when Ralph is running cr review.
 */
export function CodeRabbitStatus({ isReviewing }: CodeRabbitStatusProps) {
  if (!isReviewing) {
    return null;
  }

  return (
    <Box
      borderStyle="round"
      borderColor="magenta"
      paddingX={1}
      flexDirection="row"
      gap={1}
    >
      <Text color="magenta">
        <Spinner type="dots" />
      </Text>
      <Text color="magenta" bold>
        🐰 CodeRabbit
      </Text>
      <Text color="magentaBright">
        Running code review...
      </Text>
    </Box>
  );
}
