/**
 * Ntfy Notification Sending
 * Sends rich notifications to ntfy.sh for iteration events
 * Format matches the zsh version (_ralph_ntfy in ralph-models.zsh)
 */

import { basename } from "path";

export interface NtfyOptions {
  topic: string;
  title: string;
  message: string;
  priority?: "min" | "low" | "default" | "high" | "urgent";
  tags?: string[];
}

export interface RichNtfyOptions {
  topic: string;
  event: "complete" | "blocked" | "error" | "iteration" | "max_iterations" | "retry";
  storyId?: string;
  model?: string;
  iteration?: number;
  pendingStories?: number;
  pendingCriteria?: number;
  cost?: number;
  projectName?: string;
  message?: string; // For error/retry messages
}

/**
 * Send a notification to ntfy.sh
 */
export async function sendNtfy(options: NtfyOptions): Promise<boolean> {
  if (!options.topic) {
    return false;
  }

  try {
    const headers: Record<string, string> = {
      Title: options.title,
      Priority: options.priority || "default",
      Markdown: "true",
    };

    if (options.tags && options.tags.length > 0) {
      headers.Tags = options.tags.join(",");
    }

    const response = await fetch(`https://ntfy.sh/${options.topic}`, {
      method: "POST",
      headers,
      body: options.message,
    });

    return response.ok;
  } catch {
    // Silently fail - notifications are non-critical
    return false;
  }
}

/**
 * Build rich 3-line notification body
 * Line 1: project name
 * Line 2: iteration + story_id + model
 * Line 3: remaining stats + cost
 */
function buildRichBody(options: RichNtfyOptions): string {
  const lines: string[] = [];

  // Line 1: project name
  const projectName = options.projectName || basename(process.cwd());
  lines.push(projectName);

  // Line 2: iteration + story + model
  const line2Parts: string[] = [];
  if (options.iteration !== undefined) line2Parts.push(String(options.iteration));
  if (options.storyId) line2Parts.push(options.storyId);
  if (options.model) line2Parts.push(options.model);
  if (line2Parts.length > 0) lines.push(line2Parts.join(" "));

  // Line 3: remaining stats + cost (or error message)
  if (options.message) {
    lines.push(options.message);
  } else {
    const line3Parts: string[] = [];
    if (options.pendingStories !== undefined) line3Parts.push(`${options.pendingStories} stories`);
    if (options.pendingCriteria !== undefined) line3Parts.push(`${options.pendingCriteria} criteria`);
    if (options.cost !== undefined) line3Parts.push(`$${options.cost.toFixed(2)}`);
    if (line3Parts.length > 0) lines.push(line3Parts.join(" "));
  }

  return lines.join("\n");
}

/**
 * Get title and tags for event type
 */
function getEventConfig(event: RichNtfyOptions["event"]): {
  title: string;
  tags: string[];
  priority: NtfyOptions["priority"];
} {
  switch (event) {
    case "complete":
      return { title: "[Ralph] Complete", tags: ["white_check_mark", "robot"], priority: "high" };
    case "blocked":
      return { title: "[Ralph] Blocked", tags: ["stop_button", "warning"], priority: "urgent" };
    case "error":
      return { title: "[Ralph] Error", tags: ["x", "fire"], priority: "urgent" };
    case "iteration":
      return { title: "[Ralph] Progress", tags: ["arrows_counterclockwise"], priority: "low" };
    case "max_iterations":
      return { title: "[Ralph] Limit Hit", tags: ["warning", "hourglass"], priority: "high" };
    case "retry":
      return { title: "[Ralph] Retry", tags: ["hourglass"], priority: "low" };
    default:
      return { title: "[Ralph]", tags: ["robot"], priority: "default" };
  }
}

/**
 * Send rich notification with full context
 */
export async function sendRichNtfy(options: RichNtfyOptions): Promise<boolean> {
  const { title, tags, priority } = getEventConfig(options.event);
  const body = buildRichBody(options);

  return sendNtfy({
    topic: options.topic,
    title,
    message: body,
    priority,
    tags,
  });
}

/**
 * Send iteration complete notification
 */
export async function notifyIterationComplete(
  topic: string,
  iteration: number,
  storyId: string,
  model?: string,
  pendingStories?: number,
  pendingCriteria?: number
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "iteration",
    iteration,
    storyId,
    model,
    pendingStories,
    pendingCriteria,
  });
}

/**
 * Send story complete notification
 */
export async function notifyStoryComplete(
  topic: string,
  storyId: string,
  model?: string,
  pendingStories?: number,
  pendingCriteria?: number
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "complete",
    storyId,
    model,
    pendingStories,
    pendingCriteria,
  });
}

/**
 * Send PRD complete notification
 */
export async function notifyPRDComplete(topic: string): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "complete",
    message: "All stories completed!",
  });
}

/**
 * Send error notification
 */
export async function notifyError(
  topic: string,
  error: string,
  storyId?: string,
  model?: string
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "error",
    storyId,
    model,
    message: error,
  });
}

/**
 * Send retry notification
 */
export async function notifyRetry(
  topic: string,
  retryCount: number,
  cooldownSecs: number,
  storyId?: string
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "retry",
    storyId,
    message: `Retry ${retryCount} - waiting ${cooldownSecs}s`,
  });
}

/**
 * Send blocked notification
 */
export async function notifyBlocked(
  topic: string,
  storyId?: string,
  reason?: string
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "blocked",
    storyId,
    message: reason || "Story blocked",
  });
}

/**
 * Send max iterations notification
 */
export async function notifyMaxIterations(
  topic: string,
  iterations: number,
  storyId?: string
): Promise<void> {
  await sendRichNtfy({
    topic,
    event: "max_iterations",
    storyId,
    message: `Reached ${iterations} iterations limit`,
  });
}
