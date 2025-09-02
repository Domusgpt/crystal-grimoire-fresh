import test from 'node:test';
import assert from 'node:assert';
import { calculateMoonPhase } from '../utils/moon.js';

test('calculateMoonPhase returns expected structure', () => {
  const result = calculateMoonPhase();
  assert.ok(result.phase, 'phase is present');
  assert.ok(result.emoji, 'emoji is present');
  assert.strictEqual(typeof result.illumination, 'number');
  assert.ok(result.nextFullMoon, 'nextFullMoon is present');
  assert.ok(result.nextNewMoon, 'nextNewMoon is present');
});
