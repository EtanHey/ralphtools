/**
 * PTY Module - Re-exports for the PTY subsystem
 * Part of MP-007: Implement node-pty runner for ralph-ui
 */

// Types
export type {
  PTYProcess,
  PTYSpawnOptions,
  PTYEvent,
  PTYEventType,
  DataEvent,
  ExitEvent,
  ErrorEvent,
  SignalType,
  ShutdownResult,
  DualOutputStream,
} from "./types";

// PTY Wrapper
export { PTYWrapper, spawnPTY, isPTYSupported, getPTYUnsupportedReason } from "./pty-wrapper";

// ANSI Utilities
export { stripAnsi, hasAnsiCodes } from "./ansi";

// Dual Output
export {
  DualOutput,
  createDualOutput,
  createDualOutputStreams,
  forkOutput,
  LogFileWriter,
  createLogDir,
  type DualOutputStreams,
} from "./dual-output";

// Event System
export {
  PTYEventEmitter,
  createEventEmitter,
  EventBatcher,
} from "./events";

// Signal Handling
export {
  SignalHandler,
  createSignalHandler,
  setupProcessSignals,
} from "./signals";
