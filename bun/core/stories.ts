/**
 * Story management module for Ralph
 * Read/write operations for prd-json/ directory structure
 */

import { existsSync, readFileSync, writeFileSync, readdirSync, unlinkSync } from "fs";
import { join } from "path";

// Story types
export type StoryStatus = "pending" | "in_progress" | "completed" | "blocked";
export type StoryType = "feature" | "bug" | "test" | "audit" | "verification" | "meta";
export type Priority = "critical" | "high" | "medium" | "low";

// Acceptance criterion
export interface AcceptanceCriterion {
  text: string;
  checked: boolean;
}

// Story JSON structure
export interface Story {
  id: string;
  title: string;
  description?: string;
  type?: StoryType;
  priority?: Priority;
  storyPoints?: number;
  status?: StoryStatus;
  acceptanceCriteria: AcceptanceCriterion[];
  dependencies?: string[];
  blockedBy?: string;
  passes?: boolean;
  failedAttempts?: number;
  notes?: string;
  completedAt?: string;
  commitHash?: string;
  model?: string; // Story-level model override
}

// PRD Index structure
export interface PRDIndex {
  $schema?: string;
  generatedAt?: string;
  stats: {
    total: number;
    completed: number;
    pending: number;
    blocked: number;
  };
  nextStory?: string;
  storyOrder: string[];
  pending: string[];
  blocked: string[];
  newStories?: string[];
}

/**
 * Read the PRD index.json file
 */
export function readIndex(prdJsonDir: string): PRDIndex | null {
  const indexPath = join(prdJsonDir, "index.json");

  if (!existsSync(indexPath)) {
    return null;
  }

  try {
    const content = readFileSync(indexPath, "utf-8");
    return JSON.parse(content) as PRDIndex;
  } catch (error) {
    console.error(`Failed to read index.json:`, error);
    return null;
  }
}

/**
 * Write the PRD index.json file
 */
export function writeIndex(prdJsonDir: string, index: PRDIndex): void {
  const indexPath = join(prdJsonDir, "index.json");
  const content = JSON.stringify(index, null, 2);
  writeFileSync(indexPath, content + "\n");
}

/**
 * Read a story file
 */
export function readStory(prdJsonDir: string, storyId: string): Story | null {
  const storyPath = join(prdJsonDir, "stories", `${storyId}.json`);

  if (!existsSync(storyPath)) {
    return null;
  }

  try {
    const content = readFileSync(storyPath, "utf-8");
    return JSON.parse(content) as Story;
  } catch (error) {
    console.error(`Failed to read story ${storyId}:`, error);
    return null;
  }
}

/**
 * Write a story file
 */
export function writeStory(prdJsonDir: string, story: Story): void {
  const storyPath = join(prdJsonDir, "stories", `${story.id}.json`);
  const content = JSON.stringify(story, null, 2);
  writeFileSync(storyPath, content + "\n");
}

/**
 * List all story IDs in the stories directory
 */
export function listStoryIds(prdJsonDir: string): string[] {
  const storiesDir = join(prdJsonDir, "stories");

  if (!existsSync(storiesDir)) {
    return [];
  }

  const files = readdirSync(storiesDir).filter(f => f.endsWith(".json"));
  return files.map(f => f.replace(".json", ""));
}

/**
 * Get the next story to work on
 */
export function getNextStory(prdJsonDir: string): Story | null {
  const index = readIndex(prdJsonDir);
  if (!index || !index.nextStory) {
    return null;
  }

  return readStory(prdJsonDir, index.nextStory);
}

/**
 * Mark a criterion as checked in a story
 */
export function checkCriterion(
  prdJsonDir: string,
  storyId: string,
  criterionIndex: number
): boolean {
  const story = readStory(prdJsonDir, storyId);
  if (!story) return false;

  if (criterionIndex < 0 || criterionIndex >= story.acceptanceCriteria.length) {
    return false;
  }

  story.acceptanceCriteria[criterionIndex].checked = true;
  writeStory(prdJsonDir, story);
  return true;
}

/**
 * Mark a story as complete (all criteria checked)
 */
export function completeStory(prdJsonDir: string, storyId: string): boolean {
  const story = readStory(prdJsonDir, storyId);
  if (!story) return false;

  // Mark all criteria as checked
  for (const criterion of story.acceptanceCriteria) {
    criterion.checked = true;
  }
  story.passes = true;
  story.completedAt = new Date().toISOString();
  writeStory(prdJsonDir, story);

  // Update index
  const index = readIndex(prdJsonDir);
  if (index) {
    // Check if story was in pending or blocked
    const wasInPending = index.pending.includes(storyId);
    const wasInBlocked = index.blocked.includes(storyId);

    // Remove from pending
    index.pending = index.pending.filter(id => id !== storyId);
    // Also remove from blocked if it was there
    index.blocked = index.blocked.filter(id => id !== storyId);

    // Update stats only if story was actually in one of the lists
    if (wasInPending) {
      index.stats.completed++;
      index.stats.pending = Math.max(0, index.stats.pending - 1);
    } else if (wasInBlocked) {
      index.stats.completed++;
      index.stats.blocked = Math.max(0, index.stats.blocked - 1);
    }

    // Set next story
    if (index.pending.length > 0) {
      index.nextStory = index.pending[0];
    } else {
      index.nextStory = undefined;
    }

    writeIndex(prdJsonDir, index);
  }

  return true;
}

/**
 * Mark a story as blocked
 */
export function blockStory(
  prdJsonDir: string,
  storyId: string,
  reason: string
): boolean {
  const story = readStory(prdJsonDir, storyId);
  if (!story) return false;

  story.blockedBy = reason;
  writeStory(prdJsonDir, story);

  // Update index
  const index = readIndex(prdJsonDir);
  if (index) {
    // Check if story was in pending (before removing)
    const wasInPending = index.pending.includes(storyId);
    const wasAlreadyBlocked = index.blocked.includes(storyId);

    // Remove from pending
    index.pending = index.pending.filter(id => id !== storyId);

    // Add to blocked only if not already there
    if (!wasAlreadyBlocked) {
      index.blocked.push(storyId);
    }

    // Update stats only if story was actually moved
    if (wasInPending) {
      index.stats.pending = Math.max(0, index.stats.pending - 1);
      if (!wasAlreadyBlocked) {
        index.stats.blocked++;
      }
    }

    // Set next story
    if (index.pending.length > 0) {
      index.nextStory = index.pending[0];
    } else {
      index.nextStory = undefined;
    }

    writeIndex(prdJsonDir, index);
  }

  return true;
}

/**
 * Get criteria progress for a story
 */
export function getCriteriaProgress(story: Story): {
  checked: number;
  total: number;
  percentage: number;
} {
  const total = story.acceptanceCriteria.length;
  const checked = story.acceptanceCriteria.filter(c => c.checked).length;
  const percentage = total > 0 ? Math.round((checked / total) * 100) : 0;

  return { checked, total, percentage };
}

/**
 * Check if a story has partial progress (some criteria checked but not complete)
 */
export function hasPartialProgress(story: Story): boolean {
  const { checked, total } = getCriteriaProgress(story);
  return checked > 0 && checked < total && !story.passes;
}

/**
 * Get unchecked criteria for a story
 */
export function getUncheckedCriteria(story: Story): AcceptanceCriterion[] {
  return story.acceptanceCriteria.filter(c => !c.checked);
}

/**
 * Get checked criteria for a story
 */
export function getCheckedCriteria(story: Story): AcceptanceCriterion[] {
  return story.acceptanceCriteria.filter(c => c.checked);
}

/**
 * Check if story dependencies are satisfied
 */
export function areDependenciesSatisfied(
  prdJsonDir: string,
  story: Story
): boolean {
  if (!story.dependencies || story.dependencies.length === 0) {
    return true;
  }

  for (const depId of story.dependencies) {
    const depStory = readStory(prdJsonDir, depId);
    if (!depStory || !depStory.passes) {
      return false;
    }
  }

  return true;
}

/**
 * Get unsatisfied dependencies for a story
 */
export function getUnsatisfiedDependencies(
  prdJsonDir: string,
  story: Story
): string[] {
  if (!story.dependencies || story.dependencies.length === 0) {
    return [];
  }

  const unsatisfied: string[] = [];
  for (const depId of story.dependencies) {
    const depStory = readStory(prdJsonDir, depId);
    if (!depStory || !depStory.passes) {
      unsatisfied.push(depId);
    }
  }

  return unsatisfied;
}

// Update queue structure (update.json)
export interface UpdateQueue {
  newStories?: (Story | string)[];
  updateStories?: Partial<Story>[];
  moveToPending?: string[];
  moveToBlocked?: [string, string][]; // [storyId, reason][]
  removeStories?: string[];
}

// Result of processing update queue
export interface UpdateQueueResult {
  newStoriesCount: number;
  updateStoriesCount: number;
  moveToPendingCount: number;
  moveToBlockedCount: number;
  removeStoriesCount: number;
  totalChanges: number;
}

/**
 * Process update.json queue file
 * Supports: newStories, updateStories, moveToPending, moveToBlocked, removeStories
 */
export function processUpdateQueue(prdJsonDir: string): UpdateQueueResult | null {
  const updatePath = join(prdJsonDir, "update.json");
  const indexPath = join(prdJsonDir, "index.json");
  const storiesDir = join(prdJsonDir, "stories");

  // Early return if no update.json
  if (!existsSync(updatePath)) {
    return null;
  }

  const index = readIndex(prdJsonDir);
  if (!index) {
    return null;
  }

  let update: UpdateQueue;
  try {
    update = JSON.parse(readFileSync(updatePath, "utf-8"));
  } catch {
    console.error("Failed to parse update.json");
    return null;
  }

  const result: UpdateQueueResult = {
    newStoriesCount: 0,
    updateStoriesCount: 0,
    moveToPendingCount: 0,
    moveToBlockedCount: 0,
    removeStoriesCount: 0,
    totalChanges: 0,
  };

  // 1. Process newStories
  if (update.newStories && update.newStories.length > 0) {
    for (const entry of update.newStories) {
      let storyId: string;

      if (typeof entry === "string") {
        // String format: just the story ID (file must exist)
        storyId = entry;
        const storyPath = join(storiesDir, `${storyId}.json`);
        if (!existsSync(storyPath)) {
          console.warn(`Skipping ${storyId}: story file not found`);
          continue;
        }
      } else {
        // Object format: full story definition
        storyId = entry.id;
        writeStory(prdJsonDir, entry as Story);
      }

      // Add to pending and storyOrder if not already present
      if (!index.pending.includes(storyId)) {
        index.pending.push(storyId);
      }
      if (!index.storyOrder.includes(storyId)) {
        index.storyOrder.push(storyId);
      }
      result.newStoriesCount++;
    }
  }

  // 2. Process updateStories
  if (update.updateStories && update.updateStories.length > 0) {
    for (const updateEntry of update.updateStories) {
      if (!updateEntry.id) continue;

      const existingStory = readStory(prdJsonDir, updateEntry.id);
      if (!existingStory) continue;

      // Merge the update into the existing story
      const mergedStory: Story = { ...existingStory, ...updateEntry } as Story;
      writeStory(prdJsonDir, mergedStory);
      result.updateStoriesCount++;
    }
  }

  // 3. Process moveToPending - move from blocked to pending, clear blockedBy
  if (update.moveToPending && update.moveToPending.length > 0) {
    for (const storyId of update.moveToPending) {
      // Remove from blocked
      index.blocked = index.blocked.filter(id => id !== storyId);

      // Add to pending if not already there
      if (!index.pending.includes(storyId)) {
        index.pending.push(storyId);
      }

      // Clear blockedBy in story file
      const story = readStory(prdJsonDir, storyId);
      if (story) {
        delete story.blockedBy;
        writeStory(prdJsonDir, story);
      }
      result.moveToPendingCount++;
    }
  }

  // 4. Process moveToBlocked - move from pending to blocked, set blockedBy
  if (update.moveToBlocked && update.moveToBlocked.length > 0) {
    for (const [storyId, reason] of update.moveToBlocked) {
      // Remove from pending
      index.pending = index.pending.filter(id => id !== storyId);

      // Add to blocked if not already there
      if (!index.blocked.includes(storyId)) {
        index.blocked.push(storyId);
      }

      // Set blockedBy in story file
      const story = readStory(prdJsonDir, storyId);
      if (story) {
        story.blockedBy = reason;
        writeStory(prdJsonDir, story);
      }
      result.moveToBlockedCount++;
    }
  }

  // 5. Process removeStories - remove from all arrays and delete file
  if (update.removeStories && update.removeStories.length > 0) {
    for (const storyId of update.removeStories) {
      // Remove from all arrays
      index.pending = index.pending.filter(id => id !== storyId);
      index.blocked = index.blocked.filter(id => id !== storyId);
      index.storyOrder = index.storyOrder.filter(id => id !== storyId);

      // Delete story file
      const storyPath = join(storiesDir, `${storyId}.json`);
      if (existsSync(storyPath)) {
        unlinkSync(storyPath);
      }
      result.removeStoriesCount++;
    }
  }

  // Calculate total changes
  result.totalChanges =
    result.newStoriesCount +
    result.updateStoriesCount +
    result.moveToPendingCount +
    result.moveToBlockedCount +
    result.removeStoriesCount;

  // 6. Update nextStory and write index
  if (result.totalChanges > 0) {
    index.nextStory = index.pending.length > 0 ? index.pending[0] : undefined;
    index.newStories = [];
    writeIndex(prdJsonDir, index);
  }

  // 7. Delete update.json
  unlinkSync(updatePath);

  return result;
}
