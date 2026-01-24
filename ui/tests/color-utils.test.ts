import { describe, test, expect } from 'bun:test';
import { getStoryColor, getModelColor, getCostColor, getProgressColor } from '../src/components/Box';

describe('getStoryColor', () => {
  test('returns blue for US stories', () => {
    expect(getStoryColor('US-001')).toBe('blue');
    expect(getStoryColor('US-123')).toBe('blue');
  });

  test('returns red for BUG stories', () => {
    expect(getStoryColor('BUG-001')).toBe('red');
    expect(getStoryColor('BUG-999')).toBe('red');
  });

  test('returns magenta for V (verification) stories', () => {
    expect(getStoryColor('V-001')).toBe('magenta');
    expect(getStoryColor('V-012')).toBe('magenta');
  });

  test('returns yellow for TEST stories', () => {
    expect(getStoryColor('TEST-001')).toBe('yellow');
  });

  test('returns magenta for AUDIT stories', () => {
    expect(getStoryColor('AUDIT-001')).toBe('magenta');
  });

  test('returns cyan for MP (master plan) stories', () => {
    expect(getStoryColor('MP-001')).toBe('cyan');
    expect(getStoryColor('MP-002')).toBe('cyan');
  });

  test('returns white for unknown story types', () => {
    expect(getStoryColor('UNKNOWN-001')).toBe('white');
    expect(getStoryColor('XYZ-123')).toBe('white');
  });
});

describe('getModelColor', () => {
  test('returns yellow for opus', () => {
    expect(getModelColor('opus')).toBe('yellow');
  });

  test('returns cyan for sonnet', () => {
    expect(getModelColor('sonnet')).toBe('cyan');
  });

  test('returns green for haiku', () => {
    expect(getModelColor('haiku')).toBe('green');
  });

  test('returns white for unknown model', () => {
    expect(getModelColor('unknown' as any)).toBe('white');
  });
});

describe('getCostColor', () => {
  test('returns green for cost < $0.50', () => {
    expect(getCostColor(0)).toBe('green');
    expect(getCostColor(0.25)).toBe('green');
    expect(getCostColor(0.49)).toBe('green');
  });

  test('returns yellow for cost >= $0.50 and < $2.00', () => {
    expect(getCostColor(0.5)).toBe('yellow');
    expect(getCostColor(1.0)).toBe('yellow');
    expect(getCostColor(1.99)).toBe('yellow');
  });

  test('returns red for cost >= $2.00', () => {
    expect(getCostColor(2.0)).toBe('red');
    expect(getCostColor(5.0)).toBe('red');
    expect(getCostColor(100.0)).toBe('red');
  });
});

describe('getProgressColor', () => {
  test('returns green for percent >= 75', () => {
    expect(getProgressColor(75)).toBe('green');
    expect(getProgressColor(80)).toBe('green');
    expect(getProgressColor(100)).toBe('green');
  });

  test('returns yellow for percent >= 50 and < 75', () => {
    expect(getProgressColor(50)).toBe('yellow');
    expect(getProgressColor(60)).toBe('yellow');
    expect(getProgressColor(74)).toBe('yellow');
  });

  test('returns red for percent < 50', () => {
    expect(getProgressColor(0)).toBe('red');
    expect(getProgressColor(25)).toBe('red');
    expect(getProgressColor(49)).toBe('red');
  });
});
