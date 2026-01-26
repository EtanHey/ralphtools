/**
 * PRD Operations - Read/write PRD JSON files
 * Part of MP-006: Move iteration loop from zsh to TypeScript
 */

import { existsSync, readFileSync, writeFileSync, unlinkSync } from "fs";
import { join } from "path";
import type { PRDIndex, Story, UpdateQueue, AcceptanceCriterion } from "./types";

// AIDEV-NOTE: PRD file operations must match the existing zsh behavior exactly
// The tests in tests/prd.test.ts verify this behavior

export function readIndex(prdJsonDir: string): PRDIndex | null {
  const indexPath = join(prdJsonDir, "index.json");

  if (!existsSync(indexPath)) {
    return null;
  }

  try {
    const content = readFileSync(indexPath, "utf-8");
    return JSON.parse(content) as PRDIndex;
  } catch {
    return null;
  }
}

export function writeIndex(prdJsonDir: string, index: PRDIndex): void {
  const indexPath = join(prdJsonDir, "index.json");
  writeFileSync(indexPath, JSON.stringify(index, null, 2) + "\n");
}

export function readStory(prdJsonDir: string, storyId: string): Story | null {
  const storyPath = join(prdJsonDir, "stories", `${storyId}.json`);

  if (!existsSync(storyPath)) {
    return null;
  }

  try {
    const content = readFileSync(storyPath, "utf-8");
    return JSON.parse(content) as Story;
  } catch {
    return null;
  }
}

export function writeStory(prdJsonDir: string, story: Story): void {
  const storyPath = join(prdJsonDir, "stories", `${story.id}.json`);
  writeFileSync(storyPath, JSON.stringify(story, null, 2) + "\n");
}

export function getNextStory(prdJsonDir: string): Story | null {
  const index = readIndex(prdJsonDir);

  if (!index || !index.nextStory) {
    return null;
  }

  return readStory(prdJsonDir, index.nextStory);
}

export function checkCriterion(
  prdJsonDir: string,
  storyId: string,
  criterionIndex: number
): void {
  const story = readStory(prdJsonDir, storyId);

  if (!story) {
    throw new Error(`Story not found: ${storyId}`);
  }

  if (criterionIndex < 0 || criterionIndex >= story.acceptanceCriteria.length) {
    throw new Error(`Invalid criterion index: ${criterionIndex}`);
  }

  story.acceptanceCriteria[criterionIndex].checked = true;

  // Check if all criteria are now checked
  const allChecked = story.acceptanceCriteria.every((c) => c.checked);
  if (allChecked) {
    story.passes = true;
  }

  writeStory(prdJsonDir, story);
}

export function completeStory(
  prdJsonDir: string,
  storyId: string,
  completedBy: string = "opus"
): void {
  // Update story
  const story = readStory(prdJsonDir, storyId);

  if (!story) {
    throw new Error(`Story not found: ${storyId}`);
  }

  story.passes = true;
  story.completedAt = new Date().toISOString();
  story.completedBy = completedBy;

  writeStory(prdJsonDir, story);

  // Update index
  const index = readIndex(prdJsonDir);

  if (!index) {
    throw new Error("PRD index not found");
  }

  // Remove from pending
  index.pending = index.pending.filter((id) => id !== storyId);

  // Add to completed
  if (!index.completed) {
    index.completed = [];
  }
  if (!index.completed.includes(storyId)) {
    index.completed.push(storyId);
  }

  // Auto-unblock any stories that were blocked by this completed story
  const storiesToUnblock: string[] = [];
  for (const blockedId of index.blocked) {
    const blockedStory = readStory(prdJsonDir, blockedId);
    if (blockedStory?.blockedBy === storyId) {
      storiesToUnblock.push(blockedId);
    }
  }

  for (const unblockedId of storiesToUnblock) {
    index.blocked = index.blocked.filter((id) => id !== unblockedId);
    if (!index.pending.includes(unblockedId)) {
      index.pending.push(unblockedId);
    }
    const unblockedStory = readStory(prdJsonDir, unblockedId);
    if (unblockedStory) {
      delete unblockedStory.blockedBy;
      writeStory(prdJsonDir, unblockedStory);
      console.log(`[PRD] Auto-unblocked ${unblockedId}: blocker ${storyId} completed`);
    }
  }

  // Update nextStory
  index.nextStory = index.pending.length > 0 ? index.pending[0] : undefined;

  writeIndex(prdJsonDir, index);
}

export function blockStory(
  prdJsonDir: string,
  storyId: string,
  reason: string
): void {
  // Update story
  const story = readStory(prdJsonDir, storyId);

  if (!story) {
    throw new Error(`Story not found: ${storyId}`);
  }

  story.blockedBy = reason;

  writeStory(prdJsonDir, story);

  // Update index
  const index = readIndex(prdJsonDir);

  if (!index) {
    throw new Error("PRD index not found");
  }

  // Remove from pending
  index.pending = index.pending.filter((id) => id !== storyId);

  // Add to blocked
  if (!index.blocked.includes(storyId)) {
    index.blocked.push(storyId);
  }

  // Update nextStory
  index.nextStory = index.pending.length > 0 ? index.pending[0] : undefined;

  writeIndex(prdJsonDir, index);
}

export function unblockStory(prdJsonDir: string, storyId: string): void {
  // Update story
  const story = readStory(prdJsonDir, storyId);

  if (!story) {
    throw new Error(`Story not found: ${storyId}`);
  }

  delete story.blockedBy;

  writeStory(prdJsonDir, story);

  // Update index
  const index = readIndex(prdJsonDir);

  if (!index) {
    throw new Error("PRD index not found");
  }

  // Remove from blocked
  index.blocked = index.blocked.filter((id) => id !== storyId);

  // Add to pending
  if (!index.pending.includes(storyId)) {
    index.pending.push(storyId);
  }

  writeIndex(prdJsonDir, index);
}

export function applyUpdateQueue(prdJsonDir: string): { applied: boolean; changes: string[] } {
  const updatePath = join(prdJsonDir, "update.json");

  if (!existsSync(updatePath)) {
    return { applied: false, changes: [] };
  }

  const changes: string[] = [];

  try {
    const queue = JSON.parse(readFileSync(updatePath, "utf-8")) as UpdateQueue;
    const index = readIndex(prdJsonDir);

    if (!index) {
      throw new Error("PRD index not found");
    }

    // Process newStories
    if (queue.newStories) {
      for (const story of queue.newStories) {
        writeStory(prdJsonDir, story);

        if (!index.pending.includes(story.id)) {
          index.pending.push(story.id);
        }
        if (!index.storyOrder.includes(story.id)) {
          index.storyOrder.push(story.id);
        }

        changes.push(`Added story: ${story.id}`);
      }
    }

    // Process updateStories
    if (queue.updateStories) {
      for (const update of queue.updateStories) {
        if (!update.id) continue;

        const story = readStory(prdJsonDir, update.id);
        if (story) {
          Object.assign(story, update);
          writeStory(prdJsonDir, story);
          changes.push(`Updated story: ${update.id}`);
        }
      }
    }

    // Process moveToPending
    if (queue.moveToPending) {
      for (const storyId of queue.moveToPending) {
        index.blocked = index.blocked.filter((id) => id !== storyId);
        if (!index.pending.includes(storyId)) {
          index.pending.push(storyId);
        }

        const story = readStory(prdJsonDir, storyId);
        if (story) {
          delete story.blockedBy;
          writeStory(prdJsonDir, story);
        }

        changes.push(`Unblocked story: ${storyId}`);
      }
    }

    // Process moveToBlocked
    if (queue.moveToBlocked) {
      for (const [storyId, reason] of queue.moveToBlocked) {
        index.pending = index.pending.filter((id) => id !== storyId);
        if (!index.blocked.includes(storyId)) {
          index.blocked.push(storyId);
        }

        const story = readStory(prdJsonDir, storyId);
        if (story) {
          story.blockedBy = reason;
          writeStory(prdJsonDir, story);
        }

        changes.push(`Blocked story: ${storyId} (${reason})`);
      }
    }

    // Process removeStories
    if (queue.removeStories) {
      for (const storyId of queue.removeStories) {
        index.pending = index.pending.filter((id) => id !== storyId);
        index.blocked = index.blocked.filter((id) => id !== storyId);
        index.storyOrder = index.storyOrder.filter((id) => id !== storyId);
        if (index.completed) {
          index.completed = index.completed.filter((id) => id !== storyId);
        }

        changes.push(`Removed story: ${storyId}`);
      }
    }

    // BUG-029 fix: Process direct override format (storyOrder and pending arrays)
    // This supports the format used by the /prd skill when adding stories to an existing PRD
    if (queue.storyOrder && Array.isArray(queue.storyOrder)) {
      // Merge new story IDs into storyOrder (preserve existing, add new ones not already present)
      for (const storyId of queue.storyOrder) {
        if (!index.storyOrder.includes(storyId)) {
          index.storyOrder.push(storyId);
          changes.push(`Added to storyOrder: ${storyId}`);
        }
      }
    }

    if (queue.pending && Array.isArray(queue.pending)) {
      // Merge new story IDs into pending (preserve existing, add new ones not already present)
      for (const storyId of queue.pending) {
        if (!index.pending.includes(storyId)) {
          index.pending.push(storyId);
          changes.push(`Added to pending: ${storyId}`);
        }
      }
    }

    // Update nextStory
    index.nextStory = index.pending.length > 0 ? index.pending[0] : undefined;

    writeIndex(prdJsonDir, index);

    // Delete update.json after processing
    unlinkSync(updatePath);

    return { applied: true, changes };
  } catch (error) {
    return { applied: false, changes: [`Error: ${error}`] };
  }
}

export function verifyPendingCount(prdJsonDir: string): boolean {
  const index = readIndex(prdJsonDir);

  if (!index) {
    return false;
  }

  // Verify each pending story exists
  for (const storyId of index.pending) {
    const story = readStory(prdJsonDir, storyId);
    if (!story) {
      return false;
    }
  }

  return true;
}

export function isComplete(prdJsonDir: string): boolean {
  const index = readIndex(prdJsonDir);

  if (!index) {
    return false;
  }

  return index.pending.length === 0 && index.blocked.length === 0;
}

export function isAllBlocked(prdJsonDir: string): boolean {
  const index = readIndex(prdJsonDir);

  if (!index) {
    return false;
  }

  return index.pending.length === 0 && index.blocked.length > 0;
}

export function getCriteriaProgress(story: Story): {
  total: number;
  checked: number;
  percentage: number;
} {
  const total = story.acceptanceCriteria.length;
  const checked = story.acceptanceCriteria.filter((c) => c.checked).length;
  const percentage = total > 0 ? Math.round((checked / total) * 100) : 0;

  return { total, checked, percentage };
}

/**
 * Auto-block a story that has blockedBy field but is still in pending array
 * This fixes the bug where Ralph loops forever on such stories
 *
 * IMPORTANT: If the blocker is already completed, clear blockedBy instead of blocking
 */
export function autoBlockStoryIfNeeded(prdJsonDir: string, storyId: string): boolean {
  const story = readStory(prdJsonDir, storyId);
  const index = readIndex(prdJsonDir);

  if (!story || !index) {
    return false;
  }

  // Check if story has blockedBy but is in pending array
  if (story.blockedBy && index.pending.includes(storyId)) {
    // Check if the blocker is already completed
    const blockerIsCompleted = (index.completed ?? []).includes(story.blockedBy);

    if (blockerIsCompleted) {
      // Blocker is done - clear blockedBy and keep in pending
      console.log(`[PRD] Auto-unblocked ${storyId}: blocker ${story.blockedBy} is completed`);
      delete story.blockedBy;
      writeStory(prdJsonDir, story);
      return false; // Not blocked, can proceed
    }

    // Blocker is NOT completed - auto-block the story
    console.log(`[PRD] Auto-blocked ${storyId}: ${story.blockedBy}`);

    // Move from pending to blocked
    index.pending = index.pending.filter((id) => id !== storyId);
    if (!index.blocked.includes(storyId)) {
      index.blocked.push(storyId);
    }

    // Update nextStory to next pending story
    index.nextStory = index.pending.length > 0 ? index.pending[0] : undefined;

    writeIndex(prdJsonDir, index);
    return true;
  }

  return false;
}
