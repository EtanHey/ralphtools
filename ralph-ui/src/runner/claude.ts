/**
 * Claude Spawning - Spawn Claude CLI via child_process
 * Part of MP-006: Move iteration loop from zsh to TypeScript
 */

import { spawn as bunSpawn } from "bun";
import type { SpawnOptions, SpawnResult, Model } from "./types";
import { DEFAULT_TIMEOUT_MS } from "./types";
import { detectError, hasCompletionSignal, hasBlockedSignal } from "./errors";

// AIDEV-NOTE: This module spawns the Claude CLI as a subprocess
// It must handle TTY inheritance properly for interactive features
// The tests in tests/claude.test.ts verify the argument building and result parsing

export function buildCliArgs(options: SpawnOptions): string[] {
  const args: string[] = [];
  const cli = getCliForModel(options.model);

  if (cli === "claude") {
    // Claude CLI arguments
    args.push("--print", "--dangerously-skip-permissions");
    args.push("--model", options.model);

    if (options.contextFile) {
      args.push("--append-system-prompt", options.contextFile);
    }

    if (options.maxTurns) {
      args.push("--max-turns", options.maxTurns.toString());
    }

    args.push("-p", options.prompt);
  } else if (cli === "gemini") {
    // Gemini CLI arguments: gemini [query..] [options]
    args.push("--yolo");  // Auto-approve all tools
    args.push("-o", "json");  // JSON output format

    // Model selection for gemini
    if (options.model === "gemini-pro") {
      args.push("-m", "gemini-2.0-pro-exp");
    } else {
      args.push("-m", "gemini-2.0-flash-exp");
    }

    // Prompt as positional argument (at end)
    args.push(options.prompt);
  } else if (cli === "kiro-cli") {
    // Kiro CLI arguments: kiro-cli chat [OPTIONS] [INPUT]
    args.push("chat");
    args.push("--trust-all-tools");  // Like --dangerously-skip-permissions
    args.push("--no-interactive");   // Non-interactive mode
    args.push(options.prompt);       // Prompt as positional argument
  } else if (cli === "aider") {
    // Aider CLI arguments for Ollama local models
    // aider --yes --no-git --model ollama/qwen3-coder --message "prompt"
    args.push("--yes");  // Auto-approve all edits
    args.push("--no-git");  // Ralph handles git, not aider
    args.push("--model", "ollama/qwen3-coder");  // Use local Ollama model

    // Inject context file if provided (same context as Claude gets)
    if (options.contextFile) {
      args.push("--read", options.contextFile);
    }

    args.push("--message", options.prompt);
  }

  return args;
}

export async function spawnClaude(options: SpawnOptions): Promise<SpawnResult> {
  const startTime = Date.now();
  const args = buildCliArgs(options);

  // Get the right CLI for this model (claude, gemini, or kiro-cli)
  const cliName = getCliForModel(options.model);
  let cli = cliName;

  // Find the CLI path - use which to locate it
  try {
    const whichProc = bunSpawn(["which", cliName], {
      stdout: "pipe",
      stderr: "pipe",
    });
    const whichOutput = await new Response(whichProc.stdout).text();
    if (whichOutput.trim()) {
      cli = whichOutput.trim();
    }
  } catch {
    // Use default CLI name if which fails
  }

  try {
    const proc = bunSpawn([cli, ...args], {
      cwd: options.workingDir,
      stdin: "inherit", // Pass through stdin for TTY
      stdout: "pipe", // Capture for parsing
      stderr: "pipe", // Capture for error detection
      env: {
        ...process.env,
        ANTHROPIC_NO_TERMINAL: "1", // Hint for non-terminal mode
      },
    });

    // Set up timeout
    const timeout = options.timeout || DEFAULT_TIMEOUT_MS;
    let timedOut = false;

    const timeoutId = setTimeout(() => {
      timedOut = true;
      proc.kill();
    }, timeout);

    // Wait for process to complete
    const exitCode = await proc.exited;
    clearTimeout(timeoutId);

    // Collect output
    const stdout = await new Response(proc.stdout).text();
    const stderr = await new Response(proc.stderr).text();

    const durationMs = Date.now() - startTime;

    if (timedOut) {
      return {
        success: false,
        exitCode: -1,
        stdout,
        stderr: "Process timed out",
        durationMs,
      };
    }

    // Extract session ID if present
    let sessionId: string | undefined;
    const sessionMatch = stdout.match(/"session_id":\s*"([^"]+)"/);
    if (sessionMatch) {
      sessionId = sessionMatch[1];
    }

    return {
      success: exitCode === 0,
      exitCode,
      stdout,
      stderr,
      durationMs,
      sessionId,
    };
  } catch (error) {
    const durationMs = Date.now() - startTime;
    return {
      success: false,
      exitCode: -1,
      stdout: "",
      stderr: error instanceof Error ? error.message : String(error),
      durationMs,
    };
  }
}

// Parse JSONL output from Claude CLI
export interface ClaudeMessage {
  type: string;
  subtype?: string;
  content?: string | Array<{ type: string; text?: string }>;
}

export function parseJsonlOutput(output: string): ClaudeMessage[] {
  const messages: ClaudeMessage[] = [];
  const lines = output.split("\n").filter((line) => line.trim());

  for (const line of lines) {
    try {
      const data = JSON.parse(line);
      // Skip null/undefined values (can happen with "null" lines)
      if (data != null) {
        messages.push(data);
      }
    } catch {
      // Skip malformed lines
    }
  }

  return messages;
}

export function extractAssistantText(output: string): string {
  const messages = parseJsonlOutput(output);
  const textParts: string[] = [];

  for (const message of messages) {
    if (message.type === "assistant" && message.content) {
      if (Array.isArray(message.content)) {
        for (const part of message.content) {
          if (part.type === "text" && part.text) {
            textParts.push(part.text);
          }
        }
      } else if (typeof message.content === "string") {
        textParts.push(message.content);
      }
    }
  }

  return textParts.join("\n");
}

// Analyze spawn result for iteration outcome
export interface IterationOutcome {
  success: boolean;
  hasComplete: boolean;
  hasAllBlocked: boolean;
  errorType: ReturnType<typeof detectError>;
  assistantText: string;
}

export function analyzeResult(result: SpawnResult): IterationOutcome {
  const combinedOutput = result.stdout + result.stderr;
  const assistantText = extractAssistantText(result.stdout);

  const errorType = result.success ? null : detectError(combinedOutput);
  const hasComplete = hasCompletionSignal(combinedOutput);
  const hasAllBlocked = hasBlockedSignal(combinedOutput);

  return {
    success: result.success,
    hasComplete,
    hasAllBlocked,
    errorType,
    assistantText,
  };
}

// Model name mapping for Claude CLI
const MODEL_NAMES: Record<Model, string> = {
  haiku: "haiku",
  sonnet: "sonnet",
  opus: "opus",
  // Gemini models with quota (updated 2026-01-26)
  "gemini-flash": "gemini-2.5-flash",           // 99.6% quota left
  "gemini-flash-lite": "gemini-2.5-flash-lite", // 99.4% quota - fast for V-* stories
  "gemini-3-flash": "gemini-3-flash-preview",   // 99.6% quota - newest
  "gemini-pro": "gemini-2.5-pro",               // 0% quota - exhausted
  kiro: "kiro",
  ollama: "ollama/qwen3-coder",
};

export function getModelName(model: Model): string {
  return MODEL_NAMES[model] || "sonnet";
}

// Check if model is a Gemini model
export function isGeminiModel(model: Model): boolean {
  return model === "gemini-flash" || model === "gemini-flash-lite" || model === "gemini-3-flash" || model === "gemini-pro";
}

// Check if model is Kiro
export function isKiroModel(model: Model): boolean {
  return model === "kiro";
}

// Check if model is Ollama (local)
export function isOllamaModel(model: Model): boolean {
  return model === "ollama";
}

// Get the CLI command for a specific model
export function getCliForModel(model: Model): string {
  if (isGeminiModel(model)) {
    return "gemini";
  }
  if (isKiroModel(model)) {
    return "kiro-cli";
  }
  if (isOllamaModel(model)) {
    return "aider";
  }
  return "claude";
}
