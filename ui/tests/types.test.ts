import { describe, test, expect } from 'bun:test';
import type { StoryType, ModelName, DisplayMode, StoryData, PRDStats } from '../src/types';

describe('Type definitions', () => {
  test('StoryType includes all story prefixes', () => {
    const storyTypes: StoryType[] = ['US', 'BUG', 'V', 'TEST', 'AUDIT', 'MP'];
    expect(storyTypes).toHaveLength(6);
  });

  test('ModelName includes all model options', () => {
    const models: ModelName[] = ['opus', 'sonnet', 'haiku'];
    expect(models).toHaveLength(3);
  });

  test('DisplayMode includes compact and full', () => {
    const modes: DisplayMode[] = ['compact', 'full'];
    expect(modes).toHaveLength(2);
  });

  test('StoryData has required fields', () => {
    const story: StoryData = {
      id: 'US-001',
      title: 'Test story',
      status: 'pending',
      acceptanceCriteria: [
        { text: 'Criterion 1', checked: false },
        { text: 'Criterion 2', checked: true },
      ],
      passes: false,
    };

    expect(story.id).toBe('US-001');
    expect(story.title).toBe('Test story');
    expect(story.acceptanceCriteria).toHaveLength(2);
    expect(story.passes).toBe(false);
  });

  test('PRDStats has required fields', () => {
    const stats: PRDStats = {
      totalStories: 50,
      completedStories: 25,
      pendingStories: 20,
      blockedStories: 5,
      totalCriteria: 200,
      checkedCriteria: 100,
      currentStory: null,
      nextStoryId: 'US-001',
    };

    expect(stats.totalStories).toBe(50);
    expect(stats.completedStories).toBe(25);
    expect(stats.pendingStories).toBe(20);
    expect(stats.blockedStories).toBe(5);
    expect(stats.totalCriteria).toBe(200);
    expect(stats.checkedCriteria).toBe(100);
  });
});
