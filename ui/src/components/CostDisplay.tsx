import React from 'react';
import { Text } from 'ink';
import { getCostColor } from './Box.js';

interface CostDisplayProps {
  cost: number;
  showIcon?: boolean;
  prefix?: string;
}

/**
 * Colored cost display based on amount thresholds
 * Matches ralph.zsh _ralph_color_cost function:
 * - green  < $0.50
 * - yellow < $2.00
 * - red    >= $2.00
 */
export function CostDisplay({ cost, showIcon = false, prefix = '$' }: CostDisplayProps) {
  const color = getCostColor(cost);
  const formatted = cost.toFixed(2);

  return (
    <Text>
      {showIcon && <Text>💰 </Text>}
      <Text color={color}>{prefix}{formatted}</Text>
    </Text>
  );
}

/**
 * Cost display with label
 */
export function CostDisplayWithLabel({ cost }: { cost: number }) {
  const color = getCostColor(cost);
  const formatted = cost.toFixed(2);

  return (
    <Text>
      <Text dimColor>Cost: </Text>
      <Text color={color}>${formatted}</Text>
    </Text>
  );
}

/**
 * Cumulative cost display with emoji
 */
export function TotalCost({ cost }: { cost: number }) {
  const color = getCostColor(cost);
  const formatted = cost.toFixed(2);

  return (
    <Text>
      <Text>💰 </Text>
      <Text color={color}>${formatted}</Text>
    </Text>
  );
}
