import React from 'react';
import { Box, Text } from 'ink';
import { ProgressBar } from './ProgressBar.js';
import type { StoryData } from '../types.js';

interface StoryBoxProps {
  story: StoryData | null;
}

export function StoryBox({ story }: StoryBoxProps) {
  if (!story) {
    return (
      <Box borderStyle="single" borderColor="gray" paddingX={1}>
        <Text dimColor>No current story</Text>
      </Box>
    );
  }

  const checkedCount = story.acceptanceCriteria.filter(c => c.checked).length;
  const totalCount = story.acceptanceCriteria.length;

  // Determine border color based on status
  let borderColor = 'yellow';
  if (story.passes) {
    borderColor = 'green';
  } else if (story.blockedBy) {
    borderColor = 'red';
  }

  return (
    <Box flexDirection="column" borderStyle="round" borderColor={borderColor} paddingX={1}>
      <Box>
        <Text bold color="magenta">{story.id}</Text>
        <Text> - </Text>
        <Text>{story.title}</Text>
      </Box>

      {story.model && (
        <Box>
          <Text dimColor>Model: </Text>
          <Text color="yellow">{story.model}</Text>
        </Box>
      )}

      <Box marginTop={1} flexDirection="column">
        <Text bold>Acceptance Criteria:</Text>
        <ProgressBar
          current={checkedCount}
          total={totalCount}
          color={story.passes ? 'green' : 'yellow'}
          width={20}
        />
      </Box>

      <Box marginTop={1} flexDirection="column">
        {story.acceptanceCriteria.map((criterion, i) => (
          <Box key={i}>
            <Text color={criterion.checked ? 'green' : 'gray'}>
              {criterion.checked ? '✓' : '○'}
            </Text>
            <Text> {criterion.text}</Text>
          </Box>
        ))}
      </Box>
    </Box>
  );
}
