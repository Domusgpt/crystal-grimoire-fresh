const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  normalizePlanId,
  resolvePlanDetails,
  PLAN_CATALOG_METADATA,
  buildPlanStatusResponse,
  coerceUsageSnapshot,
} = require('../src/plan_catalog');

describe('plan catalog helpers', () => {
  test('normalizePlanId handles aliases and casing', () => {
    assert.equal(normalizePlanId('Premium'), 'premium');
    assert.equal(normalizePlanId('Emissary'), 'premium');
    assert.equal(normalizePlanId('ASCENDED'), 'pro');
    assert.equal(normalizePlanId('esper'), 'founders');
    assert.equal(normalizePlanId(undefined), 'free');
  });

  test('resolvePlanDetails returns defensive copies', () => {
    const premium = resolvePlanDetails('premium');
    assert.equal(premium.plan, 'premium');
    assert.equal(premium.tier, 'premium');
    assert.equal(premium.lifetime, false);
    premium.effectiveLimits.identifyPerDay = 999;
    const fresh = resolvePlanDetails('premium');
    assert.equal(fresh.effectiveLimits.identifyPerDay, 15);
  });

  test('catalog metadata exposes sorted plans with feature bullets', () => {
    const order = Object.values(PLAN_CATALOG_METADATA).map((entry) => entry.sortOrder);
    assert.deepEqual(order, [...order].sort((a, b) => a - b));

    const premium = PLAN_CATALOG_METADATA.premium;
    assert.ok(Array.isArray(premium.features));
    assert.ok(premium.features.length >= 3);
    assert.equal(typeof premium.displayName, 'string');
  });

  test('coerceUsageSnapshot normalizes malformed payloads', () => {
    const empty = coerceUsageSnapshot(null);
    assert.deepEqual(empty, {
      dailyCounts: {},
      lifetimeCounts: {},
      lastResetDate: null,
      updatedAt: null,
    });

    const normalized = coerceUsageSnapshot({
      dailyCounts: { crystalIdentification: 3 },
      lifetimeCounts: { crystalIdentification: 25 },
      lastResetDate: '2024-10-01',
      updatedAt: '2024-10-01T10:00:00.000Z',
    });

    assert.equal(normalized.dailyCounts.crystalIdentification, 3);
    assert.equal(normalized.lifetimeCounts.crystalIdentification, 25);
    assert.equal(normalized.lastResetDate, '2024-10-01');
    assert.equal(normalized.updatedAt, '2024-10-01T10:00:00.000Z');
  });

  test('buildPlanStatusResponse merges plan limits with usage counts', () => {
    const plan = resolvePlanDetails('premium');
    const response = buildPlanStatusResponse(plan, {
      dailyCounts: { crystalIdentification: 2 },
      lifetimeCounts: { crystalIdentification: 50 },
      lastResetDate: '2024-09-24',
      updatedAt: '2024-09-24T10:00:00.000Z',
    });

    assert.equal(response.plan, 'premium');
    assert.equal(response.tier, 'premium');
    assert.equal(response.limits.identifyPerDay, 15);
    assert.equal(response.usage.daily.crystalIdentification, 2);
    assert.equal(response.usage.lifetime.crystalIdentification, 50);
    assert.equal(response.usage.lastResetDate, '2024-09-24');
    assert.equal(response.usage.updatedAt, '2024-09-24T10:00:00.000Z');
  });
});
