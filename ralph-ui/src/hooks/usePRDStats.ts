import { useState, useEffect, useCallback } from 'react';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import type { PRDIndex, StoryData, PRDStats } from '../types.js';

export function usePRDStats(prdPath: string): PRDStats {
  const [stats, setStats] = useState<PRDStats>({
    totalStories: 0,
    completedStories: 0,
    pendingStories: 0,
    blockedStories: 0,
    totalCriteria: 0,
    checkedCriteria: 0,
    currentStory: null,
    nextStoryId: '',
  });

  const loadStats = useCallback(() => {
    try {
      const indexPath = join(prdPath, 'index.json');
      if (!existsSync(indexPath)) {
        return;
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

      setStats({
        totalStories: index.stats.total,
        completedStories: index.stats.completed,
        pendingStories: index.stats.pending,
        blockedStories: index.stats.blocked,
        totalCriteria,
        checkedCriteria,
        currentStory,
        nextStoryId: index.nextStory,
      });
    } catch (error) {
      // Keep existing stats on error
    }
  }, [prdPath]);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  return stats;
}

// Export reload function for external use
export function createStatsLoader(prdPath: string) {
  return () => {
    const indexPath = join(prdPath, 'index.json');
    if (!existsSync(indexPath)) {
      return null;
    }

    const indexContent = readFileSync(indexPath, 'utf-8');
    const index: PRDIndex = JSON.parse(indexContent);

    let totalCriteria = 0;
    let checkedCriteria = 0;
    let currentStory: StoryData | null = null;

    if (index.nextStory) {
      const storyPath = join(prdPath, 'stories', `${index.nextStory}.json`);
      if (existsSync(storyPath)) {
        const storyContent = readFileSync(storyPath, 'utf-8');
        currentStory = JSON.parse(storyContent);
      }
    }

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
  };
}
