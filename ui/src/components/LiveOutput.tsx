import React, { useState, useEffect, useRef } from 'react';
import { Box, Text, useStdout } from 'ink';
import Spinner from 'ink-spinner';

interface LiveOutputProps {
  /** Stream of output lines */
  lines?: string[];
  /** Maximum lines to display (scrolling) */
  maxLines?: number;
  /** Show spinner while processing */
  isProcessing?: boolean;
  /** Title for the output box */
  title?: string;
  /** Show line numbers */
  showLineNumbers?: boolean;
}

/**
 * Live streaming output component for Claude output
 * Shows scrolling output with optional line numbers
 */
export function LiveOutput({
  lines = [],
  maxLines = 20,
  isProcessing = false,
  title = 'Claude Output',
  showLineNumbers = false,
}: LiveOutputProps) {
  const { stdout } = useStdout();
  const terminalWidth = stdout?.columns || 80;

  // Get the last N lines for display
  const displayLines = lines.slice(-maxLines);

  return (
    <Box flexDirection="column" borderStyle="round" borderColor="gray" paddingX={1}>
      {/* Header */}
      <Box>
        {isProcessing && (
          <Text color="cyan">
            <Spinner type="dots" />{' '}
          </Text>
        )}
        <Text bold>{title}</Text>
        {lines.length > maxLines && (
          <Text dimColor> ({lines.length} lines total)</Text>
        )}
      </Box>

      {/* Output lines */}
      <Box flexDirection="column" marginTop={1}>
        {displayLines.length === 0 ? (
          <Text dimColor>Waiting for output...</Text>
        ) : (
          displayLines.map((line, i) => {
            const lineNum = lines.length - displayLines.length + i + 1;
            const maxLineWidth = terminalWidth - 10;
            const truncatedLine = line.length > maxLineWidth
              ? line.substring(0, maxLineWidth - 3) + '...'
              : line;

            return (
              <Box key={i}>
                {showLineNumbers && (
                  <Text dimColor>{String(lineNum).padStart(4, ' ')} │ </Text>
                )}
                <Text wrap="truncate">{truncatedLine}</Text>
              </Box>
            );
          })
        )}
      </Box>
    </Box>
  );
}

/**
 * Hook to accumulate streaming output
 */
export function useStreamOutput() {
  const [lines, setLines] = useState<string[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);

  const addLine = (line: string) => {
    setLines((prev) => [...prev, line]);
  };

  const addLines = (newLines: string[]) => {
    setLines((prev) => [...prev, ...newLines]);
  };

  const clear = () => {
    setLines([]);
  };

  const startProcessing = () => setIsProcessing(true);
  const stopProcessing = () => setIsProcessing(false);

  return {
    lines,
    isProcessing,
    addLine,
    addLines,
    clear,
    startProcessing,
    stopProcessing,
  };
}

/**
 * Streaming output with auto-scroll to bottom
 */
export function StreamingOutput({
  stream,
  maxLines = 30,
}: {
  stream?: AsyncIterable<string>;
  maxLines?: number;
}) {
  const [lines, setLines] = useState<string[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);

  useEffect(() => {
    if (!stream) return;

    let mounted = true;
    setIsStreaming(true);

    const consume = async () => {
      for await (const chunk of stream) {
        if (!mounted) break;
        // Split chunk into lines and add each
        const newLines = chunk.split('\n');
        setLines((prev) => [...prev, ...newLines.filter(Boolean)]);
      }
      if (mounted) setIsStreaming(false);
    };

    consume().catch(() => {
      if (mounted) setIsStreaming(false);
    });

    return () => {
      mounted = false;
    };
  }, [stream]);

  return (
    <LiveOutput
      lines={lines}
      maxLines={maxLines}
      isProcessing={isStreaming}
      title="Claude Output"
    />
  );
}
