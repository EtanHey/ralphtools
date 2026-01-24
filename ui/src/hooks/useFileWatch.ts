import { useState, useEffect, useCallback, useRef } from 'react';
import { watch, existsSync, readFileSync, FSWatcher } from 'fs';
import { join } from 'path';
import type { PRDStats, PRDIndex, StoryData } from '../types.js';

interface UseFileWatchOptions {
  prdPath: string;
  enabled?: boolean;
  /** Debounce delay in ms (default: 500ms to prevent flicker) */
  debounceMs?: number;
}

/**
 * Load stats from PRD JSON files
 */
function loadStats(prdPath: string): PRDStats | null {
  try {
    const indexPath = join(prdPath, 'index.json');
    if (!existsSync(indexPath)) {
      return null;
    }

    const indexContent = readFileSync(indexPath, 'utf-8');
    const index: PRDIndex = JSON.parse(indexContent);

    let totalCriteria = 0;
    let checkedCriteria = 0;
    let currentStory: StoryData | null = null;

    // Load current story
    if (index.nextStory) {
      const storyPath = join(prdPath, 'stories', `${index.nextStory}.json`);
      if (existsSync(storyPath)) {
        const storyContent = readFileSync(storyPath, 'utf-8');
        currentStory = JSON.parse(storyContent);
      }
    }

    // Calculate criteria counts from all stories in storyOrder
    const storiesDir = join(prdPath, 'stories');
    for (const storyId of index.storyOrder) {
      const storyPath = join(storiesDir, `${storyId}.json`);
      if (existsSync(storyPath)) {
        try {
          const storyContent = readFileSync(storyPath, 'utf-8');
          const story: StoryData = JSON.parse(storyContent);
          if (story.acceptanceCriteria) {
            totalCriteria += story.acceptanceCriteria.length;
            checkedCriteria += story.acceptanceCriteria.filter(c => c.checked).length;
          }
        } catch {
          // Skip invalid story files
        }
      }
    }

    return {
      totalStories: index.stats.total,
      completedStories: index.stats.completed,
      pendingStories: index.stats.pending,
      blockedStories: index.stats.blocked,
      totalCriteria,
      checkedCriteria,
      currentStory,
      nextStoryId: index.nextStory,
    };
  } catch {
    return null;
  }
}

/**
 * Hook for watching PRD JSON files and live-updating stats
 * Uses fs.watch with 500ms debounce to prevent flicker
 */
export function useFileWatch({
  prdPath,
  enabled = true,
  debounceMs = 500,
}: UseFileWatchOptions): PRDStats | null {
  const [stats, setStats] = useState<PRDStats | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const watchersRef = useRef<FSWatcher[]>([]);

  const reload = useCallback(() => {
    const newStats = loadStats(prdPath);
    if (newStats) {
      setStats(newStats);
    }
  }, [prdPath]);

  useEffect(() => {
    // Initial load
    reload();

    if (!enabled) {
      return;
    }

    const handleChange = () => {
      // Debounce rapid changes (500ms default)
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      timeoutRef.current = setTimeout(() => {
        reload();
        timeoutRef.current = null;
      }, debounceMs);
    };

    // Watch index.json
    const indexPath = join(prdPath, 'index.json');
    if (existsSync(indexPath)) {
      try {
        const watcher = watch(indexPath, handleChange);
        watchersRef.current.push(watcher);
      } catch {
        // Ignore watch errors
      }
    }

    // Watch stories directory with recursive flag
    const storiesPath = join(prdPath, 'stories');
    if (existsSync(storiesPath)) {
      try {
        const watcher = watch(storiesPath, { recursive: true }, handleChange);
        watchersRef.current.push(watcher);
      } catch {
        // Ignore watch errors
      }
    }

    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      for (const watcher of watchersRef.current) {
        watcher.close();
      }
      watchersRef.current = [];
    };
  }, [prdPath, enabled, debounceMs, reload]);

  return stats;
}

/**
 * Hook for polling-based updates (fallback when fs.watch isn't available)
 */
export function usePollingWatch({
  prdPath,
  enabled = true,
  intervalMs = 1000,
}: UseFileWatchOptions & { intervalMs?: number }): PRDStats | null {
  const [stats, setStats] = useState<PRDStats | null>(null);

  useEffect(() => {
    const reload = () => {
      const newStats = loadStats(prdPath);
      if (newStats) {
        setStats(newStats);
      }
    };

    // Initial load
    reload();

    if (!enabled) {
      return;
    }

    const interval = setInterval(reload, intervalMs);
    return () => clearInterval(interval);
  }, [prdPath, enabled, intervalMs]);

  return stats;
}
