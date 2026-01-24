#!/usr/bin/env bun
import React from 'react';
import { render } from 'ink';
import { Dashboard } from './components/Dashboard.js';

// Parse command line arguments
function parseArgs(): {
  mode: 'startup' | 'iteration' | 'live';
  prdPath: string;
  iteration: number;
  model: string;
  startTime: number;
  ntfyTopic?: string;
} {
  const args = process.argv.slice(2);
  let mode: 'startup' | 'iteration' | 'live' = 'startup';
  let prdPath = process.cwd() + '/prd-json';
  let iteration = 1;
  let model = 'sonnet';
  let startTime = Date.now();
  let ntfyTopic: string | undefined = process.env.RALPH_NTFY_TOPIC;

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
    } else if (arg === '--iteration' || arg === '-i') {
      iteration = parseInt(args[++i], 10) || 1;
    } else if (arg.startsWith('--iteration=')) {
      iteration = parseInt(arg.split('=')[1], 10) || 1;
    } else if (arg === '--model') {
      model = args[++i];
    } else if (arg.startsWith('--model=')) {
      model = arg.split('=')[1];
    } else if (arg === '--start-time') {
      startTime = parseInt(args[++i], 10) || Date.now();
    } else if (arg.startsWith('--start-time=')) {
      startTime = parseInt(arg.split('=')[1], 10) || Date.now();
    } else if (arg === '--ntfy-topic') {
      ntfyTopic = args[++i];
    } else if (arg.startsWith('--ntfy-topic=')) {
      ntfyTopic = arg.split('=')[1];
    } else if (arg === '--help' || arg === '-h') {
      console.log(`
Ralph UI - React Ink Terminal Dashboard

Usage:
  bun ralph-ui/src/index.tsx [options]

Options:
  --mode, -m <mode>       Mode: startup, iteration, or live (default: startup)
  --prd-path, -p <path>   Path to prd-json directory (default: ./prd-json)
  --iteration, -i <num>   Current iteration number (default: 1)
  --model <model>         Current model name (default: sonnet)
  --start-time <ms>       Start timestamp in milliseconds (default: now)
  --ntfy-topic <topic>    Ntfy notification topic (default: from env)
  --help, -h              Show this help message

Modes:
  startup    Show initial PRD status
  iteration  Show iteration status with progress
  live       Watch for file changes and update in real-time
`);
      process.exit(0);
    }
  }

  return { mode, prdPath, iteration, model, startTime, ntfyTopic };
}

const config = parseArgs();

// Render the dashboard
const { waitUntilExit } = render(
  <Dashboard
    mode={config.mode}
    prdPath={config.prdPath}
    iteration={config.iteration}
    model={config.model}
    startTime={config.startTime}
    ntfyTopic={config.ntfyTopic}
  />
);

// Wait for the app to exit, then exit the process
waitUntilExit().then(() => {
  process.exit(0);
});
