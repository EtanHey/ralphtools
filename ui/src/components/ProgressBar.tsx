import React from 'react';
import { Box, Text } from 'ink';
import { getProgressColor } from './Box.js';

interface ProgressBarProps {
  current: number;
  total: number;
  width?: number;
  showCount?: boolean;
  showPercentage?: boolean;
  label?: string;
  /** Override automatic color based on percentage */
  color?: string;
}

/**
 * Progress bar with colored blocks based on percentage
 * Matches ralph.zsh _ralph_progress_bar function:
 * - green >= 75%
 * - yellow >= 50%
 * - red < 50%
 *
 * Uses Unicode blocks: █ (filled) and ░ (empty)
 */
export function ProgressBar({
  current,
  total,
  width = 10,
  showCount = true,
  showPercentage = true,
  label,
  color: overrideColor,
}: ProgressBarProps) {
  // Handle edge cases (matches ralph.zsh logic)
  const safeTotal = Math.max(1, total);
  const safeCurrent = Math.max(0, Math.min(current, safeTotal));

  // Calculate percentage and filled blocks (cap at 100%)
  const percent = Math.min(100, Math.round((safeCurrent / safeTotal) * 100));
  const filled = Math.round((safeCurrent / safeTotal) * width);
  const empty = width - filled;

  // Get color based on percentage (or use override)
  const color = overrideColor ?? getProgressColor(percent);

  // Build the bar using Unicode blocks
  const filledBar = '█'.repeat(filled);
  const emptyBar = '░'.repeat(empty);

  return (
    <Box>
      {label && <Text>{label} </Text>}
      <Text color={color}>[{filledBar}</Text>
      <Text dimColor>{emptyBar}</Text>
      <Text color={color}>]</Text>
      {showCount && <Text> {safeCurrent}/{safeTotal}</Text>}
      {showPercentage && <Text dimColor> ({percent}%)</Text>}
    </Box>
  );
}

/**
 * Iteration progress bar: X/MAX iterations
 * Usage: <IterationProgress current={3} max={10} />
 */
export function IterationProgress({
  current,
  max,
}: {
  current: number;
  max: number;
}) {
  return <ProgressBar current={current} total={max} width={10} label="🔄" showPercentage={false} />;
}

/**
 * Story progress bar: completed/total stories
 * Usage: <StoryProgress completed={20} total={30} />
 */
export function StoryProgress({
  completed,
  total,
}: {
  completed: number;
  total: number;
}) {
  return <ProgressBar current={completed} total={total} width={10} />;
}

/**
 * Criteria progress bar: checked/total criteria for current story
 * Usage: <CriteriaProgress checked={4} total={6} />
 */
export function CriteriaProgress({
  checked,
  total,
}: {
  checked: number;
  total: number;
}) {
  return <ProgressBar current={checked} total={total} width={10} />;
}
