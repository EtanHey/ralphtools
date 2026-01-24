import { describe, test, expect } from 'bun:test';
import { DEFAULT_ROUTING } from '../src/components/ModelRouting';

describe('DEFAULT_ROUTING', () => {
  test('has 6 routing entries', () => {
    expect(DEFAULT_ROUTING).toHaveLength(6);
  });

  test('maps US stories to opus', () => {
    const usRouting = DEFAULT_ROUTING.find(r => r.type === 'US');
    expect(usRouting?.model).toBe('opus');
  });

  test('maps BUG stories to opus', () => {
    const bugRouting = DEFAULT_ROUTING.find(r => r.type === 'BUG');
    expect(bugRouting?.model).toBe('opus');
  });

  test('maps V stories to sonnet', () => {
    const vRouting = DEFAULT_ROUTING.find(r => r.type === 'V');
    expect(vRouting?.model).toBe('sonnet');
  });

  test('maps TEST stories to sonnet', () => {
    const testRouting = DEFAULT_ROUTING.find(r => r.type === 'TEST');
    expect(testRouting?.model).toBe('sonnet');
  });

  test('maps AUDIT stories to sonnet', () => {
    const auditRouting = DEFAULT_ROUTING.find(r => r.type === 'AUDIT');
    expect(auditRouting?.model).toBe('sonnet');
  });

  test('maps MP stories to opus', () => {
    const mpRouting = DEFAULT_ROUTING.find(r => r.type === 'MP');
    expect(mpRouting?.model).toBe('opus');
  });
});
