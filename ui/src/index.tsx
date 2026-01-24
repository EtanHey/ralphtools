#!/usr/bin/env bun
import React from 'react';
import { render } from 'ink';
import { Dashboard } from './components/Dashboard.js';
import type { DisplayMode, ModelName } from './types.js';

// Valid model names
const VALID_MODELS: ModelName[] = ['opus', 'sonnet', 'haiku'];

function isValidModel(value: string): value is ModelName {
  return VALID_MODELS.includes(value as ModelName);
}

// Parse command line arguments
function parseArgs(): {
  mode: 'startup' | 'iteration' | 'live';
  prdPath: string;
  version: string;
  iteration: number;
  maxIterations: number;
  model: ModelName;
  startTime: number;
  cost: number;
  displayMode: DisplayMode;
  debounceMs: number;
} {
  const args = process.argv.slice(2);
  let mode: 'startup' | 'iteration' | 'live' = 'startup';
  let prdPath = process.cwd() + '/prd-json';
  let version = '1.0.0';
  let iteration = 1;
  let maxIterations = 100;
  let model: ModelName = 'sonnet';
  let startTime = Date.now();
  let cost = 0;
  let displayMode: DisplayMode = 'full';
  let debounceMs = 500;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--mode' || arg === '-m') {
      const value = args[++i];
      if (value === 'startup' || value === 'iteration' || value === 'live') {
        mode = value;
      }
    } else if (arg.startsWith('--mode=')) {
      const value = arg.split('=')[1];
      if (value === 'startup' || value === 'iteration' || value === 'live') {
        mode = value;
      }
    } else if (arg === '--prd-path' || arg === '-p') {
      prdPath = args[++i];
    } else if (arg.startsWith('--prd-path=')) {
      prdPath = arg.split('=')[1];
    } else if (arg === '--version' || arg === '-v') {
      version = args[++i];
    } else if (arg.startsWith('--version=')) {
      version = arg.split('=')[1];
    } else if (arg === '--iteration' || arg === '-i') {
      iteration = parseInt(args[++i], 10) || 1;
    } else if (arg.startsWith('--iteration=')) {
      iteration = parseInt(arg.split('=')[1], 10) || 1;
    } else if (arg === '--max-iterations') {
      maxIterations = parseInt(args[++i], 10) || 100;
    } else if (arg.startsWith('--max-iterations=')) {
      maxIterations = parseInt(arg.split('=')[1], 10) || 100;
    } else if (arg === '--model') {
      const value = args[++i];
      if (isValidModel(value)) {
        model = value;
      } else {
        console.error(`Invalid model: ${value}. Valid models: ${VALID_MODELS.join(', ')}`);
        process.exit(1);
      }
    } else if (arg.startsWith('--model=')) {
      const value = arg.split('=')[1];
      if (isValidModel(value)) {
        model = value;
      } else {
        console.error(`Invalid model: ${value}. Valid models: ${VALID_MODELS.join(', ')}`);
        process.exit(1);
      }
    } else if (arg === '--start-time') {
      startTime = parseInt(args[++i], 10) || Date.now();
    } else if (arg.startsWith('--start-time=')) {
      startTime = parseInt(arg.split('=')[1], 10) || Date.now();
    } else if (arg === '--cost') {
      cost = parseFloat(args[++i]) || 0;
    } else if (arg.startsWith('--cost=')) {
      cost = parseFloat(arg.split('=')[1]) || 0;
    } else if (arg === '--compact') {
      displayMode = 'compact';
    } else if (arg === '--debounce') {
      debounceMs = parseInt(args[++i], 10) || 500;
    } else if (arg.startsWith('--debounce=')) {
      debounceMs = parseInt(arg.split('=')[1], 10) || 500;
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
Ralph UI - React Ink Terminal Dashboard

Usage:
  bun ui/src/index.tsx [options]

Options:
  --mode, -m <mode>         Mode: startup, iteration, or live (default: startup)
  --prd-path, -p <path>     Path to prd-json directory (default: ./prd-json)
  --version, -v <version>   Ralph version string (default: 1.0.0)
  --iteration, -i <num>     Current iteration number (default: 1)
  --max-iterations <num>    Maximum iterations (default: 100)
  --model <model>           Current model: opus, sonnet, haiku (default: sonnet)
  --start-time <ms>         Start timestamp in milliseconds (default: now)
  --cost <amount>           Current cost in dollars (default: 0)
  --compact                 Use compact display mode (single line)
  --debounce <ms>           Debounce delay for file watching (default: 500)
  --help, -h                Show this help message

Modes:
  startup    Show initial PRD status and model routing
  iteration  Show iteration status with progress
  live       Watch for file changes and update in real-time

Display Modes:
  full       Box-based display with full details (default)
  compact    Single-line display for minimal output

Examples:
  bun ui/src/index.tsx --mode=live --prd-path=./prd-json
  bun ui/src/index.tsx --mode=iteration --iteration=5 --model=opus --compact
`);
      process.exit(0);
    }
  }

  return { mode, prdPath, version, iteration, maxIterations, model, startTime, cost, displayMode, debounceMs };
}

// Only run the dashboard when executed directly (not imported as library)
if (import.meta.main) {
  const config = parseArgs();

  render(
    <Dashboard
      mode={config.mode}
      prdPath={config.prdPath}
      version={config.version}
      iteration={config.iteration}
      maxIterations={config.maxIterations}
      model={config.model}
      startTime={config.startTime}
      cost={config.cost}
      displayMode={config.displayMode}
      debounceMs={config.debounceMs}
    />
  );
}

// Export components for library use
export * from './components/index.js';
export * from './hooks/index.js';
export * from './types.js';
