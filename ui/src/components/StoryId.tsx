import React from 'react';
import { Text } from 'ink';
import { getStoryColor } from './Box.js';

interface StoryIdProps {
  id: string;
  bold?: boolean;
}

/**
 * Colored story ID based on story type prefix
 * Matches ralph.zsh _ralph_color_story_id function:
 * - US    → blue
 * - BUG   → red
 * - V     → purple (magenta in terminal)
 * - TEST  → yellow
 * - AUDIT → magenta
 * - MP    → cyan
 */
export function StoryId({ id, bold = true }: StoryIdProps) {
  const color = getStoryColor(id);

  return (
    <Text color={color} bold={bold}>
      {id}
    </Text>
  );
}

/**
 * Story ID with emoji prefix
 */
export function StoryIdWithIcon({ id, bold = true }: StoryIdProps) {
  const color = getStoryColor(id);

  return (
    <Text>
      <Text>📖 </Text>
      <Text color={color} bold={bold}>{id}</Text>
    </Text>
  );
}
