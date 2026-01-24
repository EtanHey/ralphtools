export interface StoryData {
  id: string;
  title: string;
  description?: string;
  type?: string;
  priority?: string;
  storyPoints?: number;
  status: string;
  model?: string;
  acceptanceCriteria: AcceptanceCriterion[];
  dependencies?: string[];
  passes: boolean;
  blockedBy?: string;
}

export interface AcceptanceCriterion {
  text: string;
  checked: boolean;
}

export interface PRDIndex {
  generatedAt: string;
  // stats field is optional - compute from arrays if missing
  stats?: {
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

export interface DashboardProps {
  mode: 'startup' | 'iteration' | 'live';
  prdPath: string;
  iteration?: number;
  model?: string;
  startTime?: number;
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
