import React from 'react';
import { Text } from 'ink';
import { getModelColor } from './Box.js';
import type { ModelName } from '../types.js';

interface ModelBadgeProps {
  model: ModelName | string;
  showIcon?: boolean;
}

/**
 * Colored model badge based on model name
 * Matches ralph.zsh _ralph_color_model function:
 * - opus   → gold (yellow in terminal)
 * - sonnet → cyan
 * - haiku  → green
 */
export function ModelBadge({ model, showIcon = false }: ModelBadgeProps) {
  const color = getModelColor(model as ModelName);

  return (
    <Text>
      {showIcon && <Text>🧠 </Text>}
      <Text color={color}>{model}</Text>
    </Text>
  );
}

/**
 * Model badge with label
 */
export function ModelBadgeWithLabel({ model }: { model: ModelName | string }) {
  const color = getModelColor(model as ModelName);

  return (
    <Text>
      <Text dimColor>Model: </Text>
      <Text color={color}>{model}</Text>
    </Text>
  );
}
