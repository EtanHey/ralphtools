/**
 * Runner Types - Core types for the iteration runner
 * Part of MP-006: Move iteration loop from zsh to TypeScript
 */

// AIDEV-NOTE: These types are designed to match the test specifications in tests/runner.test.ts

export interface RunnerConfig {
  prdJsonDir: string;
  workingDir: string;
  iterations: number;
  gapSeconds: number;
  model: Model;
  notify: boolean;
  ntfyTopic?: string;
  quiet: boolean;
  verbose: boolean;
  usePty?: boolean; // Use PTY-based spawning (MP-007)
  onOutput?: (data: string) => void; // Callback for live output (PTY mode)
  onStrippedOutput?: (data: string) => void; // Callback for stripped output (PTY mode)
}

export type Model = "haiku" | "sonnet" | "opus";

export interface IterationResult {
  iteration: number;
  storyId: string;
  success: boolean;
  hasComplete: boolean;
  hasBlocked: boolean;
  durationMs: number;
  error?: string;
}

export type RunnerState =
  | "init"
  | "load_story"
  | "executing"
  | "success"
  | "error"
  | "retry"
  | "complete"
  | "blocked";

// Status file for UI communication
export interface RalphStatus {
  state: "running" | "cr_review" | "error" | "retry" | "complete" | "interrupted" | "terminated";
  iteration: number;
  storyId: string;
  model?: string; // Model being used (haiku, sonnet, opus)
  startTime?: number; // Start time in milliseconds (for elapsed time calculation)
  lastActivity: number; // Unix timestamp in seconds
  error: string | null;
  retryIn: number; // Seconds until retry (0 if not retrying)
  pid: number;
}

// Error types for detection and retry logic
export type ErrorType =
  | "no_messages"
  | "connection_reset"
  | "timeout"
  | "rate_limit"
  | "server_error"
  | "unknown";

// Claude spawning options
export interface SpawnOptions {
  model: Model;
  prompt: string;
  contextFile?: string;
  workingDir: string;
  timeout: number;
  maxTurns?: number;
}

export interface SpawnResult {
  success: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
  sessionId?: string;
}

// PRD types (extending existing types.ts)
export interface AcceptanceCriterion {
  text: string;
  checked: boolean;
}

export interface Story {
  id: string;
  title: string;
  description?: string;
  acceptanceCriteria: AcceptanceCriterion[];
  dependencies?: string[];
  blockedBy?: string;
  passes?: boolean;
  completedAt?: string;
  completedBy?: string;
}

export interface PRDIndex {
  $schema?: string;
  generatedAt?: string;
  nextStory?: string;
  storyOrder: string[];
  pending: string[];
  blocked: string[];
  completed?: string[];
  newStories?: string[];
}

export interface UpdateQueue {
  newStories?: Story[];
  updateStories?: Partial<Story>[];
  moveToPending?: string[];
  moveToBlocked?: [string, string][];
  removeStories?: string[];
}

// Constants
export const MAX_RETRIES = 5;
export const NO_MSG_MAX_RETRIES = 3;
export const GENERAL_COOLDOWN_MS = 15000; // 15 seconds
export const NO_MSG_COOLDOWN_MS = 30000; // 30 seconds
export const DEFAULT_TIMEOUT_MS = 600000; // 10 minutes
