import React from 'react';
import { Box, Text } from 'ink';

interface ErrorBannerProps {
  error: string | null;
}

/**
 * Red banner shown when Ralph encounters an error.
 */
export function ErrorBanner({ error }: ErrorBannerProps) {
  if (!error) {
    return null;
  }

  return (
    <Box
      borderStyle="double"
      borderColor="red"
      paddingX={2}
      paddingY={0}
      flexDirection="column"
    >
      <Text color="red" bold>
        ❌ ERROR
      </Text>
      <Text color="redBright" wrap="wrap">
        {error}
      </Text>
    </Box>
  );
}
