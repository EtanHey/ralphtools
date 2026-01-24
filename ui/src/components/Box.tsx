import React from 'react';
import { Box as InkBox, Text } from 'ink';
import type { ModelName } from '../types.js';

// Unicode box drawing characters
// Single line: ┌ ─ ┐ │ └ ┘
// Double line: ╔ ═ ╗ ║ ╚ ╝
// Round:       ╭ ─ ╮ │ ╰ ╯
export type BoxStyle = 'single' | 'double' | 'round';

interface UnicodeBoxProps {
  children: React.ReactNode;
  width?: number;
  style?: BoxStyle;
  color?: string;
  title?: string;
}

const BOX_CHARS = {
  single: { tl: '┌', tr: '┐', bl: '└', br: '┘', h: '─', v: '│' },
  double: { tl: '╔', tr: '╗', bl: '╚', br: '╝', h: '═', v: '║' },
  round:  { tl: '╭', tr: '╮', bl: '╰', br: '╯', h: '─', v: '│' },
};

/**
 * Unicode box with customizable border style
 * Matches ralph.zsh box drawing (╔═╗║╚═╝ for double, ┌─┐│└─┘ for single)
 */
export function UnicodeBox({
  children,
  width = 65,
  style = 'single',
  color,
  title,
}: UnicodeBoxProps) {
  const chars = BOX_CHARS[style];
  const innerWidth = width - 2; // Account for left and right borders
  const horizontalLine = chars.h.repeat(innerWidth);

  // Top border with optional title
  let topBorder = `${chars.tl}${horizontalLine}${chars.tr}`;
  if (title) {
    const titleWithPadding = ` ${title} `;
    topBorder = `${chars.tl}${chars.h}${titleWithPadding}${chars.h.repeat(innerWidth - titleWithPadding.length - 1)}${chars.tr}`;
  }

  return (
    <InkBox flexDirection="column">
      <Text color={color}>{topBorder}</Text>
      <InkBox flexDirection="column">
        {React.Children.map(children, (child) => (
          <InkBox>
            <Text color={color}>{chars.v}</Text>
            <InkBox width={innerWidth}>{child}</InkBox>
            <Text color={color}>{chars.v}</Text>
          </InkBox>
        ))}
      </InkBox>
      <Text color={color}>{chars.tl === '╔' ? '╚' : chars.bl}{horizontalLine}{chars.tl === '╔' ? '╝' : chars.br}</Text>
    </InkBox>
  );
}

// Get color for model badge
export function getModelColor(model: ModelName): string {
  switch (model) {
    case 'opus': return 'yellow';
    case 'sonnet': return 'cyan';
    case 'haiku': return 'green';
    default: return 'white';
  }
}

// Get color for story ID based on prefix
export function getStoryColor(storyId: string): string {
  const prefix = storyId.split('-')[0];
  switch (prefix) {
    case 'US': return 'blue';
    case 'BUG': return 'red';
    case 'V': return 'magenta'; // purple in terminal is often magenta
    case 'TEST': return 'yellow';
    case 'AUDIT': return 'magenta';
    case 'MP': return 'cyan';
    default: return 'white';
  }
}

// Get color for cost based on thresholds
export function getCostColor(cost: number): string {
  if (cost < 0.50) return 'green';
  if (cost < 2.00) return 'yellow';
  return 'red';
}

// Get color for progress percentage
export function getProgressColor(percent: number): string {
  if (percent >= 75) return 'green';
  if (percent >= 50) return 'yellow';
  return 'red';
}
