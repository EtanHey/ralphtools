import { useState, useEffect } from 'react';
import { readFileSync, existsSync, watch, readdirSync, statSync } from 'fs';
import { join } from 'path';
import type { RalphStatus } from '../types.js';

interface UseStatusFileOptions {
  enabled?: boolean;
  pollIntervalMs?: number;
}

/**
 * Hook to watch ralph status file at /tmp/ralph-status-*.json
 * The file is written by ralph.zsh during execution.
 *
 * Returns null if no status file exists (Ralph not running).
 */
export function useStatusFile({
  enabled = true,
  pollIntervalMs = 1000,
}: UseStatusFileOptions = {}): RalphStatus | null {
  const [status, setStatus] = useState<RalphStatus | null>(null);

  useEffect(() => {
    if (!enabled) {
      setStatus(null);
      return;
    }

    // Find the most recent ralph status file
    const findStatusFile = (): string | null => {
      try {
        const files = readdirSync('/tmp')
          .filter(f => f.startsWith('ralph-status-') && f.endsWith('.json'));

        if (files.length === 0) return null;

        // Get the most recent file by modification time
        let latestFile = files[0];
        let latestMtime = 0;

        for (const file of files) {
          const path = join('/tmp', file);
          try {
            const stats = statSync(path);
            if (stats.mtimeMs > latestMtime) {
              latestMtime = stats.mtimeMs;
              latestFile = file;
            }
          } catch {
            // Ignore errors, try next file
          }
        }

        return join('/tmp', latestFile);
      } catch {
        return null;
      }
    };

    const loadStatus = () => {
      const statusFile = findStatusFile();
      if (!statusFile || !existsSync(statusFile)) {
        setStatus(null);
        return;
      }

      try {
        const content = readFileSync(statusFile, 'utf-8');
        const parsed = JSON.parse(content) as RalphStatus;
        // Only update if changed
        setStatus(prev => {
          if (!prev) return parsed;
          if (JSON.stringify(prev) === JSON.stringify(parsed)) return prev;
          return parsed;
        });
      } catch {
        // Invalid JSON or read error - status might be mid-write
        // Keep previous status
      }
    };

    // Initial load
    loadStatus();

    // Poll for changes (more reliable than fs.watch for /tmp)
    const interval = setInterval(loadStatus, pollIntervalMs);

    // Also try fs.watch for faster updates
    let watcher: ReturnType<typeof watch> | null = null;
    const statusFile = findStatusFile();
    if (statusFile && existsSync(statusFile)) {
      try {
        watcher = watch(statusFile, () => {
          loadStatus();
        });
      } catch {
        // Watch might fail on some systems, fallback to polling
      }
    }

    return () => {
      clearInterval(interval);
      if (watcher) {
        watcher.close();
      }
    };
  }, [enabled, pollIntervalMs]);

  return status;
}
