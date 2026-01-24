// Story types
export type StoryType = 'US' | 'BUG' | 'V' | 'TEST' | 'AUDIT' | 'MP';
export type ModelName = 'opus' | 'sonnet' | 'haiku';
export type DisplayMode = 'compact' | 'full';

export interface AcceptanceCriterion {
  text: string;
  checked: boolean;
}

export interface StoryData {
  id: string;
  title: string;
  description?: string;
  type?: string;
  priority?: string;
  storyPoints?: number;
  status: string;
  model?: ModelName;
  acceptanceCriteria: AcceptanceCriterion[];
  dependencies?: string[];
  passes: boolean;
  blockedBy?: string;
}

export interface PRDIndex {
  generatedAt: string;
  stats: {
    total: number;
    completed: number;
    pending: number;
    blocked: number;
  };
  nextStory: string;
  storyOrder: string[];
  pending: string[];
  blocked: string[];
  newStories: string[];
}

export interface PRDStats {
  totalStories: number;
  completedStories: number;
  pendingStories: number;
  blockedStories: number;
  totalCriteria: number;
  checkedCriteria: number;
  currentStory: StoryData | null;
  nextStoryId: string;
}

export interface ModelRouting {
  type: StoryType;
  model: ModelName;
}

export interface IterationInfo {
  current: number;
  max: number;
  story: string;
  model: ModelName;
  startTime: number;
  cost: number;
  pauseEnabled?: boolean;
  verboseEnabled?: boolean;
}
