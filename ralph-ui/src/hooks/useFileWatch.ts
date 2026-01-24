import { useState, useEffect, useCallback } from 'react';
import { watch, existsSync } from 'fs';
import { join } from 'path';
import type { PRDStats } from '../types.js';
import { createStatsLoader } from './usePRDStats.js';

interface UseFileWatchOptions {
  prdPath: string;
  enabled?: boolean;
  debounceMs?: number;
}

export function useFileWatch({
  prdPath,
  enabled = true,
  debounceMs = 100,
}: UseFileWatchOptions): PRDStats | null {
  const [stats, setStats] = useState<PRDStats | null>(null);
  const loadStats = createStatsLoader(prdPath);

  const reload = useCallback(() => {
    const newStats = loadStats();
    if (newStats) {
      setStats(newStats);
    }
  }, [loadStats]);

  useEffect(() => {
    // Initial load
    reload();

    if (!enabled) {
      return;
    }

    let timeoutId: ReturnType<typeof setTimeout> | null = null;

    const handleChange = () => {
      // Debounce rapid changes
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      timeoutId = setTimeout(() => {
        reload();
        timeoutId = null;
      }, debounceMs);
    };

    const watchers: ReturnType<typeof watch>[] = [];

    // Watch index.json
    const indexPath = join(prdPath, 'index.json');
    if (existsSync(indexPath)) {
      try {
        const watcher = watch(indexPath, handleChange);
        watchers.push(watcher);
      } catch {
        // Ignore watch errors
      }
    }

    // Watch stories directory
    const storiesPath = join(prdPath, 'stories');
    if (existsSync(storiesPath)) {
      try {
        const watcher = watch(storiesPath, { recursive: true }, handleChange);
        watchers.push(watcher);
      } catch {
        // Ignore watch errors
      }
    }

    return () => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
      for (const watcher of watchers) {
        watcher.close();
      }
    };
  }, [prdPath, enabled, debounceMs, reload]);

  return stats;
}
