import React from 'react';
import { Box, Text } from 'ink';
import { getProgressColor } from './Box.js';
import { StoryIdWithIcon } from './StoryId.js';
import { ModelBadge } from './ModelBadge.js';
import { CostDisplay } from './CostDisplay.js';
import type { IterationInfo, DisplayMode, PRDStats } from '../types.js';

// Helper to safely repeat spaces (never negative)
function pad(length: number): string {
  return ' '.repeat(Math.max(0, length));
}

interface IterationBoxProps {
  iteration: IterationInfo;
  stats: PRDStats;
  elapsed: string;
  mode?: DisplayMode;
  hasGum?: boolean;
}

/**
 * Full iteration status box matching ralph.zsh _ralph_show_iteration_status
 * Box is 65 chars wide, inner content area is 61 chars
 *
 * Full mode (4-5 lines):
 * ┌───────────────────────────────────────────────────────────────┐
 * │  [████░░░░░░] 20/30 (67%)                                     │
 * │  📖 US-001 │ 🧠 opus │ 🔄 3/10                                │
 * │  ⏱ 5m 30s │ 💰 $1.50                                          │
 * │  [v]erbose ✓ [p]ause   [s]kip [q]uit                          │
 * └───────────────────────────────────────────────────────────────┘
 *
 * Compact mode (2 lines):
 * ── [████░░░░░░] 20/30 (67%) │ ⏱ 5m 30s │ 💰 $1.50 ──
 */
export function IterationBox({
  iteration,
  stats,
  elapsed,
  mode = 'full',
  hasGum = false,
}: IterationBoxProps) {
  const { completedStories, totalStories } = stats;
  const { current, max, story, model, cost, pauseEnabled, verboseEnabled } = iteration;

  // Sanity check: cap completed at total
  const safeCompleted = Math.min(completedStories, totalStories);
  const percent = totalStories > 0 ? Math.round((safeCompleted / totalStories) * 100) : 0;

  // Build progress bar (10 chars)
  const barWidth = 10;
  const barFilled = Math.round((percent / 100) * barWidth);
  const barEmpty = barWidth - barFilled;
  const progressBar = '█'.repeat(barFilled) + '░'.repeat(barEmpty);
  const progressColor = getProgressColor(percent);

  if (mode === 'compact') {
    // Compact: single line
    return (
      <Box>
        <Text>── </Text>
        <Text color={progressColor}>{progressBar}</Text>
        <Text> {safeCompleted}/{totalStories} ({percent}%)</Text>
        <Text> │ ⏱ {elapsed}</Text>
        <Text> │ </Text>
        <CostDisplay cost={cost} showIcon />
        <Text> ──</Text>
      </Box>
    );
  }

  // Full mode: box with multiple lines
  return (
    <Box flexDirection="column">
      <Text>┌───────────────────────────────────────────────────────────────┐</Text>

      {/* Progress bar line */}
      <Box>
        <Text>│  </Text>
        <Text color={progressColor}>{progressBar}</Text>
        <Text> {safeCompleted}/{totalStories} ({percent}%)</Text>
        <Text>{pad(41 - String(safeCompleted).length - String(totalStories).length - String(percent).length)}│</Text>
      </Box>

      {/* Story, model, iteration line */}
      <Box>
        <Text>│  </Text>
        <StoryIdWithIcon id={story} />
        <Text> │ </Text>
        <ModelBadge model={model} showIcon />
        <Text> │ 🔄 {current}/{max}</Text>
        <Text>{pad(32 - story.length - model.length - String(current).length - String(max).length)}│</Text>
      </Box>

      {/* Elapsed time and cost line */}
      <Box>
        <Text>│  ⏱ {elapsed}</Text>
        <Text> │ </Text>
        <CostDisplay cost={cost} showIcon />
        <Text>{pad(42 - elapsed.length - String(cost.toFixed(2)).length)}│</Text>
      </Box>

      {/* Keybind hints (if gum available) */}
      {hasGum && (
        <Box>
          <Text>│  </Text>
          <Text dimColor>
            [v]erbose {verboseEnabled ? '✓' : ' '} [p]ause {pauseEnabled ? '✓' : ' '} [s]kip [q]uit
          </Text>
          <Text>             │</Text>
        </Box>
      )}

      <Text>└───────────────────────────────────────────────────────────────┘</Text>
    </Box>
  );
}

/**
 * Warning box for max iterations reached
 * Yellow border matching ralph.zsh warning box
 */
export function MaxIterationsBox({
  maxIterations,
  remaining,
  cost,
  storyProgress,
}: {
  maxIterations: number;
  remaining: number;
  cost: number;
  storyProgress?: { completed: number; total: number };
}) {
  return (
    <Box flexDirection="column">
      <Text color="yellow">╔═══════════════════════════════════════════════════════════════╗</Text>
      <Box>
        <Text color="yellow">║</Text>
        <Text>  ⚠️  </Text>
        <Text color="yellow" bold>REACHED MAX ITERATIONS</Text>
        <Text> ({maxIterations})</Text>
        <Text>{pad(28 - String(maxIterations).length)}</Text>
        <Text color="yellow">║</Text>
      </Box>
      <Box>
        <Text color="yellow">║</Text>
        <Text>  📋 Remaining: {remaining}</Text>
        <Text>{pad(44 - String(remaining).length)}</Text>
        <Text color="yellow">║</Text>
      </Box>
      {storyProgress && (
        <Box>
          <Text color="yellow">║</Text>
          <Text>  Stories: {storyProgress.completed}/{storyProgress.total}</Text>
          <Text>{pad(47 - String(storyProgress.completed).length - String(storyProgress.total).length)}</Text>
          <Text color="yellow">║</Text>
        </Box>
      )}
      <Box>
        <Text color="yellow">║</Text>
        <Text>  💰 Total cost: </Text>
        <CostDisplay cost={cost} />
        <Text>{pad(39 - String(cost.toFixed(2)).length)}</Text>
        <Text color="yellow">║</Text>
      </Box>
      <Text color="yellow">╚═══════════════════════════════════════════════════════════════╝</Text>
    </Box>
  );
}

/**
 * Quit confirmation box (yellow border)
 */
export function QuitBox({
  iterations,
  cost,
}: {
  iterations: number;
  cost: number;
}) {
  return (
    <Box flexDirection="column">
      <Text color="yellow">╔═══════════════════════════════════════════════════════════════╗</Text>
      <Box>
        <Text color="yellow">║</Text>
        <Text>  🛑 </Text>
        <Text bold>QUIT REQUESTED</Text>
        <Text> after {iterations} iterations</Text>
        <Text>{pad(26 - String(iterations).length)}</Text>
        <Text color="yellow">║</Text>
      </Box>
      <Box>
        <Text color="yellow">║</Text>
        <Text>  💰 Total cost: </Text>
        <CostDisplay cost={cost} />
        <Text>{pad(39 - String(cost.toFixed(2)).length)}</Text>
        <Text color="yellow">║</Text>
      </Box>
      <Text color="yellow">╚═══════════════════════════════════════════════════════════════╝</Text>
    </Box>
  );
}
