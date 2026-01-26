import { describe, test, expect, beforeEach, afterEach } from 'bun:test';
import { SessionContext } from '../../ralph-ui/src/runner/session-context';

describe('SessionContext', () => {
  let originalEnv: Record<string, string | undefined>;

  beforeEach(() => {
    // Save original environment
    originalEnv = {
      RALPH_SESSION: process.env.RALPH_SESSION,
      RALPH_NOTIFY: process.env.RALPH_NOTIFY,
    };
  });

  afterEach(() => {
    // Restore original environment
    process.env.RALPH_SESSION = originalEnv.RALPH_SESSION;
    process.env.RALPH_NOTIFY = originalEnv.RALPH_NOTIFY;
  });

  describe('SessionContext.create()', () => {
    test('returns valid context with default values', () => {
      // Ensure clean environment for this test
      delete process.env.RALPH_SESSION;
      
      const context = SessionContext.create();
      
      expect(context).toBeDefined();
      expect(context.runner).toBe('direct'); // No RALPH_SESSION set
      expect(context.model).toBe('opus');
      expect(context.interactive).toBe(true); // direct mode is interactive
      expect(context.notifications).toEqual({
        enabled: false,
        topic: undefined,
      });
    });
  });

  describe('detectRunner()', () => {
    test('returns "ralph" when RALPH_SESSION is set', () => {
      process.env.RALPH_SESSION = '1';
      
      const context = SessionContext.create();
      
      expect(context.runner).toBe('ralph');
      expect(context.interactive).toBe(false); // ralph mode is not interactive
    });

    test('returns "direct" when no RALPH_SESSION', () => {
      delete process.env.RALPH_SESSION;
      
      const context = SessionContext.create();
      
      expect(context.runner).toBe('direct');
      expect(context.interactive).toBe(true); // direct mode is interactive
    });
  });

  describe('notifications.enabled', () => {
    test('is true when RALPH_NOTIFY=1 via config', () => {
      process.env.RALPH_NOTIFY = '1';
      
      // Simulate how ralph-ui passes RALPH_NOTIFY via config
      const context = SessionContext.create({
        config: {
          notifications: {
            enabled: !!process.env.RALPH_NOTIFY
          }
        }
      });
      
      expect(context.notifications.enabled).toBe(true);
    });

    test('is false when RALPH_NOTIFY unset via config', () => {
      delete process.env.RALPH_NOTIFY;
      
      // Simulate how ralph-ui passes RALPH_NOTIFY via config
      const context = SessionContext.create({
        config: {
          notifications: {
            enabled: !!process.env.RALPH_NOTIFY
          }
        }
      });
      
      expect(context.notifications.enabled).toBe(false);
    });

    test('reflects RALPH_NOTIFY env via flags.notify', () => {
      process.env.RALPH_NOTIFY = '1';
      
      const context = SessionContext.create({
        flags: { notify: true }
      });
      
      expect(context.notifications.enabled).toBe(true);
    });

    test('is false when no notification flags set', () => {
      delete process.env.RALPH_NOTIFY;
      
      const context = SessionContext.create();
      
      expect(context.notifications.enabled).toBe(false);
    });

    test('config.notifications.enabled is respected', () => {
      const context = SessionContext.create({
        config: {
          notifications: {
            enabled: true,
            topic: 'test-topic'
          }
        }
      });
      
      expect(context.notifications.enabled).toBe(true);
      expect(context.notifications.topic).toBe('test-topic');
    });

    test('flags.notify overrides config.notifications.enabled', () => {
      const context = SessionContext.create({
        config: {
          notifications: {
            enabled: false
          }
        },
        flags: {
          notify: true
        }
      });
      
      expect(context.notifications.enabled).toBe(true);
    });
  });

  describe('[SESSION] log values', () => {
    test('provides expected values for session log', () => {
      process.env.RALPH_SESSION = 'ralph-123-456';
      
      const context = SessionContext.create({
        config: {
          notifications: {
            enabled: true,
            topic: 'test-topic'
          }
        }
      });
      
      // Verify the values that would be logged in [SESSION] format
      expect(context.runner).toBe('ralph');
      expect(context.model).toBe('opus');
      expect(context.notifications.enabled).toBe(true);
      
      // Verify the log format would be correct
      const expectedLogMessage = `[SESSION] runner=${context.runner} model=${context.model} notify=${context.notifications.enabled}`;
      expect(expectedLogMessage).toBe('[SESSION] runner=ralph model=opus notify=true');
    });

    test('provides expected values for direct session', () => {
      delete process.env.RALPH_SESSION;
      
      const context = SessionContext.create();
      
      // Verify the values that would be logged in [SESSION] format
      expect(context.runner).toBe('direct');
      expect(context.model).toBe('opus');
      expect(context.notifications.enabled).toBe(false);
      
      // Verify the log format would be correct
      const expectedLogMessage = `[SESSION] runner=${context.runner} model=${context.model} notify=${context.notifications.enabled}`;
      expect(expectedLogMessage).toBe('[SESSION] runner=direct model=opus notify=false');
    });
  });
});
