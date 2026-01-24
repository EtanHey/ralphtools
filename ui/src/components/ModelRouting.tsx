import React from 'react';
import { Box, Text } from 'ink';
import { StoryId } from './StoryId.js';
import { ModelBadge } from './ModelBadge.js';
import type { ModelRouting as ModelRoutingType, StoryType, ModelName } from '../types.js';

interface ModelRoutingProps {
  routing: ModelRoutingType[];
  strategy?: 'smart' | 'single';
  defaultModel?: ModelName;
}

/**
 * Shows all story type → model mappings
 * Displays the smart routing configuration from config.json
 */
export function ModelRoutingDisplay({
  routing,
  strategy = 'smart',
  defaultModel = 'sonnet',
}: ModelRoutingProps) {
  if (strategy === 'single') {
    return (
      <Box flexDirection="column" borderStyle="single" borderColor="gray" paddingX={1}>
        <Text bold>🧠 Model Routing: Single</Text>
        <Box marginTop={1}>
          <Text dimColor>All stories: </Text>
          <ModelBadge model={defaultModel} />
        </Box>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" borderStyle="single" borderColor="cyan" paddingX={1}>
      <Text bold color="cyan">🧠 Model Routing: Smart</Text>
      <Box marginTop={1} flexDirection="column">
        {routing.map(({ type, model }) => (
          <Box key={type}>
            <Box width={8}>
              <StoryId id={`${type}-*`} bold={false} />
            </Box>
            <Text dimColor>→ </Text>
            <ModelBadge model={model} />
          </Box>
        ))}
      </Box>
    </Box>
  );
}

/**
 * Inline model routing indicator
 */
export function ModelRoutingInline({
  type,
  model,
}: {
  type: StoryType;
  model: ModelName;
}) {
  return (
    <Box>
      <StoryId id={`${type}-*`} bold={false} />
      <Text dimColor> → </Text>
      <ModelBadge model={model} />
    </Box>
  );
}

/**
 * Default routing configuration matching ralph.zsh defaults
 */
export const DEFAULT_ROUTING: ModelRoutingType[] = [
  { type: 'US', model: 'opus' },
  { type: 'BUG', model: 'opus' },
  { type: 'V', model: 'sonnet' },
  { type: 'TEST', model: 'sonnet' },
  { type: 'AUDIT', model: 'sonnet' },
  { type: 'MP', model: 'opus' },
];
