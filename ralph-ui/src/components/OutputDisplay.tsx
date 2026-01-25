/**
 * OutputDisplay - Live output display using Ink's Static component
 * Part of MP-007: Implement node-pty runner for ralph-ui
 *
 * Displays scrolling output from PTY with:
 * - ANSI color support via Ink
 * - Batched updates for performance
 * - Status bar with elapsed time
 */

import React, { memo, useMemo } from "react";
import { Box, Text, Static } from "ink";

// AIDEV-NOTE: This component uses Ink's <Static> for scrolling output.
// Static renders items once and doesn't re-render them, perfect for logs.
// New lines are appended at the bottom.

export interface OutputLine {
  id: string;
  text: string;
  timestamp?: number;
}

export interface OutputDisplayProps {
  lines: string[];
  maxDisplayLines?: number; // Lines to show (default: 20)
  showLineNumbers?: boolean;
  title?: string;
}

// Memoized line component to prevent re-renders
const OutputLineItem = memo(function OutputLineItem({
  line,
  index,
  showLineNumbers,
}: {
  line: string;
  index: number;
  showLineNumbers: boolean;
}) {
  return (
    <Box>
      {showLineNumbers && (
        <Text dimColor>{String(index + 1).padStart(4, " ")} │ </Text>
      )}
      <Text>{line}</Text>
    </Box>
  );
});

export const OutputDisplay = memo(function OutputDisplay({
  lines,
  maxDisplayLines = 20,
  showLineNumbers = false,
  title,
}: OutputDisplayProps) {
  // Get the last N lines for display
  const displayLines = useMemo(() => {
    if (lines.length <= maxDisplayLines) {
      return lines;
    }
    return lines.slice(-maxDisplayLines);
  }, [lines, maxDisplayLines]);

  // Calculate line number offset for correct numbering
  const lineOffset = Math.max(0, lines.length - maxDisplayLines);

  if (displayLines.length === 0) {
    return (
      <Box flexDirection="column" borderStyle="single" borderColor="gray">
        {title && (
          <Box marginBottom={1}>
            <Text bold>{title}</Text>
          </Box>
        )}
        <Text dimColor>No output yet...</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" borderStyle="single" borderColor="gray">
      {title && (
        <Box marginBottom={1} justifyContent="space-between">
          <Text bold>{title}</Text>
          <Text dimColor>
            {lines.length} line{lines.length !== 1 ? "s" : ""}
          </Text>
        </Box>
      )}
      <Static items={displayLines.map((line, i) => ({ key: `${lineOffset + i}`, line }))}>
        {({ key, line }) => (
          <OutputLineItem
            key={key}
            line={line}
            index={lineOffset + displayLines.indexOf(line)}
            showLineNumbers={showLineNumbers}
          />
        )}
      </Static>
      {lines.length > maxDisplayLines && (
        <Box marginTop={1}>
          <Text dimColor>
            ... {lines.length - maxDisplayLines} more line
            {lines.length - maxDisplayLines !== 1 ? "s" : ""} above
          </Text>
        </Box>
      )}
    </Box>
  );
});

/**
 * Compact output display without borders
 */
export const CompactOutputDisplay = memo(function CompactOutputDisplay({
  lines,
  maxDisplayLines = 10,
}: {
  lines: string[];
  maxDisplayLines?: number;
}) {
  const displayLines = useMemo(() => {
    if (lines.length <= maxDisplayLines) {
      return lines;
    }
    return lines.slice(-maxDisplayLines);
  }, [lines, maxDisplayLines]);

  if (displayLines.length === 0) {
    return <Text dimColor>Waiting for output...</Text>;
  }

  return (
    <Box flexDirection="column">
      {displayLines.map((line, i) => (
        <Text key={i}>{line}</Text>
      ))}
    </Box>
  );
});
