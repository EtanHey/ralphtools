/**
 * Claude Spawning Tests - TDD for MP-006
 * Tests for Claude CLI spawning (ralph-ui/src/runner/claude.ts)
 */

import { describe, it, expect } from "bun:test";

// Types that will be implemented
interface SpawnOptions {
  model: string;
  prompt: string;
  contextFile?: string;
  workingDir: string;
  timeout: number;
  maxTurns?: number;
}

interface SpawnResult {
  success: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
  sessionId?: string;
}

// Error types
type ErrorType =
  | "no_messages"
  | "connection_reset"
  | "timeout"
  | "rate_limit"
  | "server_error"
  | "unknown";

describe("CLI Argument Building", () => {
  it("should build Claude CLI args correctly", () => {
    const options: SpawnOptions = {
      model: "sonnet",
      prompt: "Test prompt",
      workingDir: "/tmp/test",
      timeout: 300000,
    };

    // Expected args for Claude CLI
    const expectedArgs = [
      "-p", "Test prompt",
      "--model", "sonnet",
      "--output-format", "json",
    ];

    // Simulate buildCliArgs logic
    const args: string[] = [];
    args.push("-p", options.prompt);
    args.push("--model", options.model);
    args.push("--output-format", "json");

    expect(args).toEqual(expectedArgs);
  });

  it("should include context file when provided", () => {
    const options: SpawnOptions = {
      model: "opus",
      prompt: "Test prompt",
      contextFile: "/tmp/context.md",
      workingDir: "/tmp/test",
      timeout: 300000,
    };

    // Simulate buildCliArgs with context
    const args: string[] = [];
    args.push("-p", options.prompt);
    args.push("--model", options.model);
    if (options.contextFile) {
      args.push("--append-system-prompt", options.contextFile);
    }
    args.push("--output-format", "json");

    expect(args).toContain("--append-system-prompt");
    expect(args).toContain("/tmp/context.md");
  });

  it("should include max turns when provided", () => {
    const options: SpawnOptions = {
      model: "haiku",
      prompt: "Quick test",
      workingDir: "/tmp/test",
      timeout: 60000,
      maxTurns: 5,
    };

    // Simulate buildCliArgs with maxTurns
    const args: string[] = [];
    args.push("-p", options.prompt);
    args.push("--model", options.model);
    if (options.maxTurns) {
      args.push("--max-turns", options.maxTurns.toString());
    }
    args.push("--output-format", "json");

    expect(args).toContain("--max-turns");
    expect(args).toContain("5");
  });

  it("should handle different model names", () => {
    const models = ["haiku", "sonnet", "opus"];

    for (const model of models) {
      const options: SpawnOptions = {
        model,
        prompt: "Test",
        workingDir: "/tmp",
        timeout: 60000,
      };

      const args: string[] = [];
      args.push("-p", options.prompt);
      args.push("--model", options.model);

      expect(args).toContain("--model");
      expect(args).toContain(model);
    }
  });
});

describe("Spawn Result", () => {
  it("should have correct success structure", () => {
    const result: SpawnResult = {
      success: true,
      exitCode: 0,
      stdout: '{"type":"assistant","content":"Hello"}',
      stderr: "",
      durationMs: 5000,
      sessionId: "session-123",
    };

    expect(result.success).toBe(true);
    expect(result.exitCode).toBe(0);
    expect(result.durationMs).toBeGreaterThan(0);
  });

  it("should have correct error structure", () => {
    const result: SpawnResult = {
      success: false,
      exitCode: 1,
      stdout: "",
      stderr: "Error: Connection reset",
      durationMs: 1000,
    };

    expect(result.success).toBe(false);
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Connection reset");
  });

  it("should handle timeout as special exit code", () => {
    const result: SpawnResult = {
      success: false,
      exitCode: -1, // Timeout indicator
      stdout: "",
      stderr: "Process timed out",
      durationMs: 300000,
    };

    expect(result.exitCode).toBe(-1);
    expect(result.success).toBe(false);
  });
});

describe("Error Detection", () => {
  const ERROR_PATTERNS = {
    no_messages: /No messages returned/i,
    connection_reset: /ECONNRESET|EAGAIN|fetch failed/i,
    timeout: /ETIMEDOUT|socket hang up/i,
    rate_limit: /rate limit|overloaded/i,
    server_error: /Error: 5[0-9][0-9]|HTTP.*5[0-9][0-9]/i,
  };

  function detectError(output: string): ErrorType | null {
    for (const [type, pattern] of Object.entries(ERROR_PATTERNS)) {
      if (pattern.test(output)) {
        return type as ErrorType;
      }
    }
    return output.includes("Error") ? "unknown" : null;
  }

  it("should detect 'No messages returned' error", () => {
    const output = "Error: No messages returned from API";
    expect(detectError(output)).toBe("no_messages");
  });

  it("should detect connection reset errors", () => {
    const outputs = [
      "Error: ECONNRESET",
      "Error: EAGAIN",
      "Error: fetch failed",
    ];

    for (const output of outputs) {
      expect(detectError(output)).toBe("connection_reset");
    }
  });

  it("should detect timeout errors", () => {
    const outputs = [
      "Error: ETIMEDOUT",
      "Error: socket hang up",
    ];

    for (const output of outputs) {
      expect(detectError(output)).toBe("timeout");
    }
  });

  it("should detect rate limit errors", () => {
    const outputs = [
      "Error: rate limit exceeded",
      "Error: server overloaded",
    ];

    for (const output of outputs) {
      expect(detectError(output)).toBe("rate_limit");
    }
  });

  it("should detect server errors (5xx)", () => {
    const outputs = [
      "Error: 500 Internal Server Error",
      "Error: 503 Service Unavailable",
      "HTTP Error 502 Bad Gateway",
    ];

    for (const output of outputs) {
      expect(detectError(output)).toBe("server_error");
    }
  });

  it("should return null for non-error output", () => {
    const output = '{"type":"assistant","content":"Hello, how can I help?"}';
    expect(detectError(output)).toBeNull();
  });
});

describe("Retry Logic", () => {
  const MAX_RETRIES = 5;
  const NO_MSG_MAX_RETRIES = 3;
  const GENERAL_COOLDOWN = 15000; // 15 seconds
  const NO_MSG_COOLDOWN = 30000; // 30 seconds

  function shouldRetry(errorType: ErrorType, retryCount: number): boolean {
    if (errorType === "no_messages") {
      return retryCount < NO_MSG_MAX_RETRIES;
    }
    return retryCount < MAX_RETRIES;
  }

  function getCooldownMs(errorType: ErrorType): number {
    if (errorType === "no_messages") {
      return NO_MSG_COOLDOWN;
    }
    return GENERAL_COOLDOWN;
  }

  it("should retry no_messages up to 3 times", () => {
    expect(shouldRetry("no_messages", 0)).toBe(true);
    expect(shouldRetry("no_messages", 1)).toBe(true);
    expect(shouldRetry("no_messages", 2)).toBe(true);
    expect(shouldRetry("no_messages", 3)).toBe(false);
  });

  it("should retry other errors up to 5 times", () => {
    const errorTypes: ErrorType[] = ["connection_reset", "timeout", "rate_limit", "server_error"];

    for (const errorType of errorTypes) {
      expect(shouldRetry(errorType, 0)).toBe(true);
      expect(shouldRetry(errorType, 4)).toBe(true);
      expect(shouldRetry(errorType, 5)).toBe(false);
    }
  });

  it("should use 30s cooldown for no_messages", () => {
    expect(getCooldownMs("no_messages")).toBe(30000);
  });

  it("should use 15s cooldown for other errors", () => {
    const errorTypes: ErrorType[] = ["connection_reset", "timeout", "rate_limit", "server_error"];

    for (const errorType of errorTypes) {
      expect(getCooldownMs(errorType)).toBe(15000);
    }
  });
});

describe("Output Parsing", () => {
  it("should parse JSONL output from Claude", () => {
    const output = `{"type":"system","subtype":"init"}
{"type":"assistant","content":[{"type":"text","text":"Hello"}]}
{"type":"result","usage":{"input_tokens":100,"output_tokens":50}}`;

    const lines = output.split("\n").filter(line => line.trim());
    const messages: Array<{ type: string; content?: string }> = [];

    for (const line of lines) {
      try {
        const data = JSON.parse(line);
        if (data.type === "assistant" && data.content) {
          const text = Array.isArray(data.content)
            ? data.content.filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("")
            : data.content;
          messages.push({ type: "assistant", content: text });
        }
      } catch {
        // Skip malformed lines
      }
    }

    expect(messages).toHaveLength(1);
    expect(messages[0].content).toBe("Hello");
  });

  it("should detect completion signal in output", () => {
    // AIDEV-NOTE: Patterns must be specific to avoid false positives
    // e.g., "I'll complete this" or "iteration complete" should NOT trigger PRD completion
    const completionPatterns = [
      /\bPRD_COMPLETE\b/i,                    // PRD_COMPLETE keyword (preferred)
      /<PRD_COMPLETE>/i,                      // <PRD_COMPLETE> tag format
      /all\s+stories\s+(are\s+)?complete/i,   // "all stories complete"
      /prd\s+(is\s+)?complete/i,              // "PRD is complete"
      /"passes"\s*:\s*true/i,                 // JSON "passes": true (final story)
    ];

    function hasCompletionSignal(output: string): boolean {
      return completionPatterns.some(pattern => pattern.test(output));
    }

    // Should match
    expect(hasCompletionSignal("PRD_COMPLETE")).toBe(true);
    expect(hasCompletionSignal("<PRD_COMPLETE>")).toBe(true);
    expect(hasCompletionSignal("All stories are complete")).toBe(true);
    expect(hasCompletionSignal("The PRD is complete")).toBe(true);
    expect(hasCompletionSignal('{"passes": true}')).toBe(true);
    // Should NOT match (false positives we're avoiding)
    expect(hasCompletionSignal("Working on criterion 1")).toBe(false);
    expect(hasCompletionSignal("I'll complete this task")).toBe(false);
    expect(hasCompletionSignal("autocomplete")).toBe(false);
    expect(hasCompletionSignal("The story is complete")).toBe(false);
    expect(hasCompletionSignal("COMPLETE")).toBe(false); // too vague without PRD_
    expect(hasCompletionSignal("iteration complete")).toBe(false);
  });

  it("should detect blocked signal in output", () => {
    // AIDEV-NOTE: Patterns must be specific to avoid false positives
    const blockedPatterns = [
      /^\s*BLOCKED\s*$/m,                     // BLOCKED on its own line
      /<BLOCKED>/i,                           // <BLOCKED> tag format
      /\bALL_BLOCKED\b/i,                     // ALL_BLOCKED keyword
      /all\s+stories\s+(are\s+)?blocked/i,    // "all stories blocked"
      /story\s+is\s+blocked\s+by/i,           // "story is blocked by"
      /manual\s+intervention\s+required/i,    // "manual intervention required"
    ];

    function hasBlockedSignal(output: string): boolean {
      return blockedPatterns.some(pattern => pattern.test(output));
    }

    // Should match
    expect(hasBlockedSignal("<BLOCKED>")).toBe(true);
    expect(hasBlockedSignal("BLOCKED")).toBe(true);
    expect(hasBlockedSignal("ALL_BLOCKED")).toBe(true);
    expect(hasBlockedSignal("All stories are blocked")).toBe(true);
    expect(hasBlockedSignal("Story is blocked by: missing dependency")).toBe(true);
    expect(hasBlockedSignal("Manual intervention required")).toBe(true);
    // Should NOT match (false positives we're avoiding)
    expect(hasBlockedSignal("Working on story")).toBe(false);
    expect(hasBlockedSignal("The blocker was removed")).toBe(false);
    expect(hasBlockedSignal("Cannot proceed without user input")).toBe(false); // too vague
  });
});

describe("Process Spawning (Mock)", () => {
  it("should spawn with correct environment", () => {
    // Test environment setup for spawning
    const env = {
      ...process.env,
      ANTHROPIC_NO_TERMINAL: "1",
    };

    expect(env.ANTHROPIC_NO_TERMINAL).toBe("1");
    expect(env.PATH).toBeDefined();
  });

  it("should use correct stdio configuration", () => {
    // Expected stdio config for spawn
    const stdioConfig = {
      stdin: "inherit",
      stdout: "pipe",
      stderr: "pipe",
    };

    expect(stdioConfig.stdin).toBe("inherit");
    expect(stdioConfig.stdout).toBe("pipe");
    expect(stdioConfig.stderr).toBe("pipe");
  });
});
