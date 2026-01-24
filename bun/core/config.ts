/**
 * Configuration module for Ralph
 * Reads and manages config.json settings
 */

import { existsSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// Model types
export type Model = "haiku" | "sonnet" | "opus" | "gemini-flash" | "gemini-pro" | "kiro" | string;
export type TaskType = "US" | "V" | "TEST" | "BUG" | "AUDIT" | "MP" | string;
export type ModelStrategy = "single" | "smart";
export type Runtime = "bash" | "bun";
export type NotificationEvent = "iteration_complete" | "story_complete" | "all_complete" | "blocked" | "all_blocked" | "error";

// Pricing per million tokens
export interface ModelPricing {
  input: number;
  output: number;
}

// Config interfaces matching config.schema.json
export interface RalphConfig {
  $schema?: string;
  schemaVersion?: string;
  lastRalphVersion?: string;
  runtime?: Runtime;
  modelStrategy: ModelStrategy;
  defaultModel?: Model;
  unknownTaskType?: Model;
  models?: Partial<Record<TaskType, Model>>;
  parallelVerification?: boolean;
  parallelAgents?: number;
  notifications?: {
    enabled: boolean;
    ntfyTopic?: string;
    events?: NotificationEvent[];
  };
  defaults?: {
    maxIterations?: number;
    sleepSeconds?: number;
  };
  secrets?: {
    provider: "file" | "1password";
    vault?: string;
  };
  pricing?: Record<Model, ModelPricing>;
  costEstimation?: {
    enabled?: boolean;
    avgTokensPerStory?: {
      input?: number;
      output?: number;
    };
    warnThreshold?: number;
  };
  errorHandling?: {
    maxRetries?: number;
    noMessagesMaxRetries?: number;
    generalCooldownSeconds?: number;
    noMessagesCooldownSeconds?: number;
  };
  colorScheme?: string;
  contexts?: {
    directory?: string;
    additional?: string[];
  };
}

// Default config values
export const DEFAULT_CONFIG: Partial<RalphConfig> = {
  runtime: "bun",
  modelStrategy: "smart",
  defaultModel: "opus",
  unknownTaskType: "sonnet",
  models: {
    US: "sonnet",
    V: "haiku",
    TEST: "haiku",
    BUG: "sonnet",
    AUDIT: "opus",
    MP: "opus",
  },
  parallelVerification: false,
  parallelAgents: 2,
  notifications: {
    enabled: false,
    events: ["all_complete", "error", "blocked"],
  },
  defaults: {
    maxIterations: 50,
    sleepSeconds: 2,
  },
  secrets: {
    provider: "file",
  },
  pricing: {
    haiku: { input: 1, output: 5 },
    sonnet: { input: 3, output: 15 },
    opus: { input: 15, output: 75 },
    "gemini-flash": { input: 0.075, output: 0.30 },
    "gemini-pro": { input: 1.25, output: 5 },
    kiro: { input: 0, output: 0 }, // Credit-based
  },
  costEstimation: {
    enabled: false,
    avgTokensPerStory: {
      input: 50000,
      output: 10000,
    },
    warnThreshold: 10,
  },
  errorHandling: {
    maxRetries: 5,
    noMessagesMaxRetries: 3,
    generalCooldownSeconds: 15,
    noMessagesCooldownSeconds: 30,
  },
  colorScheme: "default",
};

// Default config directory
export const RALPH_CONFIG_DIR = join(homedir(), ".config", "ralphtools");
export const RALPH_CONFIG_FILE = join(RALPH_CONFIG_DIR, "config.json");

/**
 * Load config from config.json with defaults
 * @param configPath - Optional custom config path (defaults to ~/.config/ralphtools/config.json)
 */
export function loadConfig(configPath?: string): RalphConfig {
  const filePath = configPath ?? RALPH_CONFIG_FILE;

  if (!existsSync(filePath)) {
    return { ...DEFAULT_CONFIG } as RalphConfig;
  }

  try {
    const content = readFileSync(filePath, "utf-8");
    const userConfig: Partial<RalphConfig> = JSON.parse(content);

    // Deep merge with defaults
    return mergeConfig(DEFAULT_CONFIG, userConfig) as RalphConfig;
  } catch (error) {
    console.error(`Failed to load config from ${filePath}:`, error);
    return { ...DEFAULT_CONFIG } as RalphConfig;
  }
}

/**
 * Deep merge two config objects
 */
function mergeConfig(
  defaults: Partial<RalphConfig>,
  userConfig: Partial<RalphConfig>
): Partial<RalphConfig> {
  const result: Partial<RalphConfig> = { ...defaults };

  for (const key of Object.keys(userConfig) as (keyof RalphConfig)[]) {
    const userValue = userConfig[key];
    const defaultValue = defaults[key];

    if (userValue === undefined) continue;

    if (
      typeof userValue === "object" &&
      userValue !== null &&
      !Array.isArray(userValue) &&
      typeof defaultValue === "object" &&
      defaultValue !== null &&
      !Array.isArray(defaultValue)
    ) {
      // Deep merge objects
      (result as Record<string, unknown>)[key] = { ...defaultValue, ...userValue };
    } else {
      // Direct assignment for primitives and arrays
      (result as Record<string, unknown>)[key] = userValue;
    }
  }

  return result;
}

/**
 * Get a specific config value with type-safe defaults
 */
export function getConfigValue<K extends keyof RalphConfig>(
  config: RalphConfig,
  key: K
): NonNullable<RalphConfig[K]> {
  const value = config[key];
  if (value !== undefined) {
    return value as NonNullable<RalphConfig[K]>;
  }
  return DEFAULT_CONFIG[key] as NonNullable<RalphConfig[K]>;
}

/**
 * Check if config file exists
 */
export function configExists(configPath?: string): boolean {
  return existsSync(configPath ?? RALPH_CONFIG_FILE);
}
