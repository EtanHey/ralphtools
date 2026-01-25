/**
 * PTY Types - Type definitions for the PTY subsystem
 * Part of MP-007: Implement node-pty runner for ralph-ui
 */

export interface PTYProcess {
  onData: (handler: (chunk: string) => void) => void;
  onExit: (handler: (code: number) => void) => void;
  onError: (handler: (err: Error) => void) => void;
  write: (data: string) => void;
  resize: (cols: number, rows: number) => void;
  kill: (signal?: string) => void;
  getPid: () => number;
}

export interface PTYSpawnOptions {
  name?: string; // Terminal name (default: 'xterm-color')
  cols?: number; // Columns (default: 80)
  rows?: number; // Rows (default: 30)
  cwd?: string; // Working directory
  env?: Record<string, string>; // Environment variables
}

export type PTYEventType = "data" | "exit" | "error";

export interface PTYEvent {
  type: PTYEventType;
  timestamp: string; // ISO-8601
  data?: string; // Output or error message
  ansi?: boolean; // Whether data contains ANSI codes
  exitCode?: number; // For exit events
}

export interface DataEvent extends PTYEvent {
  type: "data";
  data: string;
  ansi: boolean;
}

export interface ExitEvent extends PTYEvent {
  type: "exit";
  exitCode: number;
  data?: string; // Final output if any
}

export interface ErrorEvent extends PTYEvent {
  type: "error";
  data: string; // Error message
}

export type SignalType = "SIGINT" | "SIGTERM" | "SIGKILL" | "SIGHUP";

export interface ShutdownResult {
  success: boolean;
  exitCode: number | null;
  graceful: boolean; // Whether it exited before force kill
  streamsClosed: boolean;
}

export interface DualOutputStream {
  displayData: (handler: (data: string) => void) => void;
  fileData: (handler: (data: string) => void) => void;
  push: (data: string) => void;
  close: () => void;
  isClosed: () => boolean;
}
