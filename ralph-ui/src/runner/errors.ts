/**
 * Error Detection and Retry Logic
 * Part of MP-006: Move iteration loop from zsh to TypeScript
 */

import type { ErrorType } from "./types";
import {
  MAX_RETRIES,
  NO_MSG_MAX_RETRIES,
  GENERAL_COOLDOWN_MS,
  NO_MSG_COOLDOWN_MS,
} from "./types";

// AIDEV-NOTE: These patterns must match the error detection in tests/claude.test.ts
// and the existing zsh behavior for backwards compatibility

export const ERROR_PATTERNS: Record<ErrorType, RegExp> = {
  no_messages: /No messages returned/i,
  connection_reset: /ECONNRESET|EAGAIN|fetch failed/i,
  timeout: /ETIMEDOUT|socket hang up/i,
  rate_limit: /rate limit|overloaded/i,
  server_error: /Error: 5[0-9][0-9]|HTTP.*5[0-9][0-9]/i,
  unknown: /Error/i,
};

export function detectError(output: string): ErrorType | null {
  // Check specific patterns first (in order of specificity)
  for (const type of [
    "no_messages",
    "connection_reset",
    "timeout",
    "rate_limit",
    "server_error",
  ] as ErrorType[]) {
    if (ERROR_PATTERNS[type].test(output)) {
      return type;
    }
  }

  // Generic error detection
  if (/Error/i.test(output)) {
    return "unknown";
  }

  return null;
}

export function shouldRetry(errorType: ErrorType, retryCount: number): boolean {
  if (errorType === "no_messages") {
    return retryCount < NO_MSG_MAX_RETRIES;
  }
  return retryCount < MAX_RETRIES;
}

export function getCooldownMs(errorType: ErrorType): number {
  if (errorType === "no_messages") {
    return NO_MSG_COOLDOWN_MS;
  }
  return GENERAL_COOLDOWN_MS;
}

export function getMaxRetries(errorType: ErrorType): number {
  if (errorType === "no_messages") {
    return NO_MSG_MAX_RETRIES;
  }
  return MAX_RETRIES;
}

// Completion signal detection
// AIDEV-NOTE: Patterns must be specific to avoid false positives
// e.g., "I'll complete this" or "iteration complete" should NOT trigger PRD completion
const COMPLETION_PATTERNS = [
  /\bPRD_COMPLETE\b/i,                    // PRD_COMPLETE keyword (preferred)
  /<PRD_COMPLETE>/i,                      // <PRD_COMPLETE> tag format
  /all\s+stories\s+(are\s+)?complete/i,   // "all stories complete"
  /prd\s+(is\s+)?complete/i,              // "PRD is complete"
  /"passes"\s*:\s*true/i,                 // JSON "passes": true (final story)
];

export function hasCompletionSignal(output: string): boolean {
  return COMPLETION_PATTERNS.some((pattern) => pattern.test(output));
}

// Blocked signal detection
// AIDEV-NOTE: Patterns must be specific to avoid false positives
const BLOCKED_PATTERNS = [
  /^\s*BLOCKED\s*$/m,                     // BLOCKED on its own line
  /<BLOCKED>/i,                           // <BLOCKED> tag format
  /\bALL_BLOCKED\b/i,                     // ALL_BLOCKED keyword
  /all\s+stories\s+(are\s+)?blocked/i,    // "all stories blocked"
  /story\s+is\s+blocked\s+by/i,           // "story is blocked by"
  /manual\s+intervention\s+required/i,    // "manual intervention required"
];

export function hasBlockedSignal(output: string): boolean {
  return BLOCKED_PATTERNS.some((pattern) => pattern.test(output));
}

// Promise tag detection (output from Claude)
export function hasCompletePromise(output: string): boolean {
  return /<promise>PRD_COMPLETE<\/promise>/i.test(output);
}

export function hasAllBlockedPromise(output: string): boolean {
  return /<promise>ALL_BLOCKED<\/promise>/i.test(output);
}

// Human-readable error descriptions
export function getErrorDescription(errorType: ErrorType): string {
  switch (errorType) {
    case "no_messages":
      return "No messages returned from API";
    case "connection_reset":
      return "Connection was reset";
    case "timeout":
      return "Request timed out";
    case "rate_limit":
      return "Rate limit exceeded";
    case "server_error":
      return "Server error (5xx)";
    case "unknown":
      return "Unknown error";
  }
}
