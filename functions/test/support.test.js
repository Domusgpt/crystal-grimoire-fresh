const assert = require('node:assert/strict');
const test = require('node:test');

const {
  normalizePriority,
  assertValidSupportStatus,
  isSupportAgent,
  canTransitionStatus,
  computeNextStatusOnComment,
} = require('../src/support');

test('normalizePriority coerces values to the supported range', () => {
  assert.equal(normalizePriority('HIGH'), 'high');
  assert.equal(normalizePriority('low'), 'low');
  assert.equal(normalizePriority('unknown'), 'medium');
  assert.equal(normalizePriority(undefined), 'medium');
});

test('assertValidSupportStatus normalizes and validates', () => {
  assert.equal(assertValidSupportStatus(' Resolved '), 'resolved');
  assert.throws(() => assertValidSupportStatus('invalid'), /Unsupported status/);
});

test('isSupportAgent recognises admin and support roles', () => {
  assert.equal(isSupportAgent({ role: 'admin' }), true);
  assert.equal(isSupportAgent({ roles: ['support'] }), true);
  assert.equal(isSupportAgent({ groups: ['operations'] }), true);
  assert.equal(isSupportAgent({}), false);
});

test('canTransitionStatus enforces transition map', () => {
  assert.equal(canTransitionStatus('open', 'pending_support', true), true);
  assert.equal(canTransitionStatus('open', 'closed', true), true);
  assert.equal(canTransitionStatus('open', 'resolved', false), false);
  assert.equal(canTransitionStatus('pending_user', 'pending_support', false), true);
  assert.equal(canTransitionStatus('closed', 'resolved', true), false);
});

test('computeNextStatusOnComment escalates correctly', () => {
  assert.equal(computeNextStatusOnComment('open', 'customer'), 'pending_support');
  assert.equal(computeNextStatusOnComment('pending_user', 'customer'), 'pending_support');
  assert.equal(computeNextStatusOnComment('pending_support', 'support'), 'pending_user');
  assert.equal(computeNextStatusOnComment('resolved', 'support'), 'resolved');
});
