/**
 * 🛡️ AGGRESSIVE COST PROTECTION SYSTEM
 * Prevents $500 overnight surges with multi-layer protection
 */

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

const db = getFirestore();

// ============================================================================
// LAYER 1: HARD SPENDING LIMITS (Circuit Breaker)
// ============================================================================

const SPENDING_LIMITS = {
  perUser: {
    free: {
      perHour: 0.10,    // $0.10/hour max
      perDay: 0.50,     // $0.50/day max
      perMonth: 5.00    // $5/month max
    },
    premium: {
      perHour: 0.50,
      perDay: 5.00,
      perMonth: 50.00
    },
    pro: {
      perHour: 2.00,
      perDay: 20.00,
      perMonth: 200.00
    },
    founders: {
      perHour: 5.00,
      perDay: 50.00,
      perMonth: 500.00
    }
  },
  global: {
    perHour: 10.00,    // $10/hour total across all users
    perDay: 100.00,    // $100/day total
    emergency: 500.00  // EMERGENCY STOP at $500
  }
};

// Estimated costs per operation
const OPERATION_COSTS = {
  // Image operations
  thumbnailAnalysis: 0.001,      // Grid-based, low-res
  fullImageAnalysis: 0.015,       // Full resolution with Pro model
  progressiveAnalysis: 0.008,     // Medium resolution with Flash

  // Text operations
  guidanceFlash: 0.001,
  guidancePro: 0.003,
  dreamAnalysis: 0.002,

  // Database operations (negligible but tracked)
  firestoreRead: 0.0000001,
  firestoreWrite: 0.0000002
};

/**
 * Check if user or system has exceeded spending limits
 * THROWS HttpsError if limit exceeded - STOPS execution immediately
 */
async function checkSpendingLimits(userId, operationType, userTier = 'free') {
  const now = new Date();
  const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

  try {
    // Get user's spending from tracking collection
    const userSpendingRef = db.collection('user_spending').doc(userId);
    const userSpendingDoc = await userSpendingRef.get();
    const userSpending = userSpendingDoc.exists ? userSpendingDoc.data() : {
      hourly: 0,
      daily: 0,
      monthly: 0,
      lastHourReset: Timestamp.now(),
      lastDayReset: Timestamp.now(),
      lastMonthReset: Timestamp.now()
    };

    // Reset counters if time windows have passed
    const hourlyNeedsReset = userSpending.lastHourReset.toDate() < hourAgo;
    const dailyNeedsReset = userSpending.lastDayReset.toDate() < dayAgo;
    const monthlyNeedsReset = userSpending.lastMonthReset.toDate() < monthStart;

    if (hourlyNeedsReset) userSpending.hourly = 0;
    if (dailyNeedsReset) userSpending.daily = 0;
    if (monthlyNeedsReset) userSpending.monthly = 0;

    // Check user limits
    const userLimits = SPENDING_LIMITS.perUser[userTier] || SPENDING_LIMITS.perUser.free;
    const estimatedCost = OPERATION_COSTS[operationType] || 0.01;

    if (userSpending.hourly + estimatedCost > userLimits.perHour) {
      throw new HttpsError(
        'resource-exhausted',
        `Hourly spending limit reached ($${userLimits.perHour}). Resets in ${60 - now.getMinutes()} minutes.`
      );
    }

    if (userSpending.daily + estimatedCost > userLimits.perDay) {
      throw new HttpsError(
        'resource-exhausted',
        `Daily spending limit reached ($${userLimits.perDay}). Resets at midnight.`
      );
    }

    if (userSpending.monthly + estimatedCost > userLimits.perMonth) {
      throw new HttpsError(
        'resource-exhausted',
        `Monthly spending limit reached ($${userLimits.perMonth}). Please upgrade your plan.`
      );
    }

    // Check global limits (prevent system-wide abuse)
    const globalSpendingRef = db.collection('_system').doc('global_spending');
    const globalDoc = await globalSpendingRef.get();
    const globalSpending = globalDoc.exists ? globalDoc.data() : {
      hourly: 0,
      daily: 0,
      total: 0,
      lastHourReset: Timestamp.now(),
      lastDayReset: Timestamp.now()
    };

    // EMERGENCY CIRCUIT BREAKER
    if (globalSpending.total >= SPENDING_LIMITS.global.emergency) {
      console.error('🚨 EMERGENCY: Global spending limit reached!');
      throw new HttpsError(
        'resource-exhausted',
        'Service temporarily unavailable. Please try again later.'
      );
    }

    if (globalSpending.hourly >= SPENDING_LIMITS.global.perHour) {
      throw new HttpsError(
        'resource-exhausted',
        'System is experiencing high demand. Please try again in a few minutes.'
      );
    }

    // All checks passed - update spending tracking
    await userSpendingRef.set({
      hourly: userSpending.hourly + estimatedCost,
      daily: userSpending.daily + estimatedCost,
      monthly: userSpending.monthly + estimatedCost,
      lastHourReset: hourlyNeedsReset ? Timestamp.now() : userSpending.lastHourReset,
      lastDayReset: dailyNeedsReset ? Timestamp.now() : userSpending.lastDayReset,
      lastMonthReset: monthlyNeedsReset ? Timestamp.now() : userSpending.lastMonthReset,
      lastOperation: Timestamp.now()
    }, { merge: true });

    await globalSpendingRef.set({
      hourly: globalSpending.hourly + estimatedCost,
      daily: globalSpending.daily + estimatedCost,
      total: globalSpending.total + estimatedCost,
      lastHourReset: globalSpending.lastHourReset?.toDate() < hourAgo ? Timestamp.now() : globalSpending.lastHourReset,
      lastDayReset: globalSpending.lastDayReset?.toDate() < dayAgo ? Timestamp.now() : globalSpending.lastDayReset,
      lastOperation: Timestamp.now()
    }, { merge: true });

    console.log(`💰 Cost tracking: User ${userId} spent $${estimatedCost.toFixed(4)} (${operationType})`);
    console.log(`   Hourly: $${userSpending.hourly.toFixed(4)}/$${userLimits.perHour}`);

  } catch (error) {
    if (error instanceof HttpsError) {
      throw error; // Re-throw limit errors
    }
    console.error('⚠️ Spending check failed (allowing request):', error);
    // Don't block on tracking errors, but log them
  }
}

// ============================================================================
// LAYER 2: RATE LIMITING (Prevent Abuse)
// ============================================================================

const RATE_LIMITS = {
  free: {
    identifyPerHour: 3,
    identifyPerDay: 10,
    guidancePerHour: 2,
    guidancePerDay: 5
  },
  premium: {
    identifyPerHour: 10,
    identifyPerDay: 30,
    guidancePerHour: 8,
    guidancePerDay: 20
  },
  pro: {
    identifyPerHour: 30,
    identifyPerDay: 100,
    guidancePerHour: 20,
    guidancePerDay: 60
  },
  founders: {
    identifyPerHour: 100,
    identifyPerDay: 500,
    guidancePerHour: 50,
    guidancePerDay: 200
  }
};

/**
 * Check rate limits
 * THROWS HttpsError if exceeded
 */
async function checkRateLimit(userId, actionType, userTier = 'free') {
  const now = new Date();
  const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const rateLimitRef = db.collection('rate_limits').doc(userId);
  const rateLimitDoc = await rateLimitRef.get();
  const rateLimit = rateLimitDoc.exists ? rateLimitDoc.data() : {
    identifyHourly: 0,
    identifyDaily: 0,
    guidanceHourly: 0,
    guidanceDaily: 0,
    lastHourReset: Timestamp.now(),
    lastDayReset: Timestamp.now()
  };

  // Reset if needed
  if (rateLimit.lastHourReset.toDate() < hourAgo) {
    rateLimit.identifyHourly = 0;
    rateLimit.guidanceHourly = 0;
  }
  if (rateLimit.lastDayReset.toDate() < dayAgo) {
    rateLimit.identifyDaily = 0;
    rateLimit.guidanceDaily = 0;
  }

  const limits = RATE_LIMITS[userTier] || RATE_LIMITS.free;

  // Check limits based on action type
  if (actionType === 'identify') {
    if (rateLimit.identifyHourly >= limits.identifyPerHour) {
      throw new HttpsError(
        'resource-exhausted',
        `Rate limit: ${limits.identifyPerHour} identifications per hour. Resets in ${60 - now.getMinutes()} min.`
      );
    }
    if (rateLimit.identifyDaily >= limits.identifyPerDay) {
      throw new HttpsError(
        'resource-exhausted',
        `Daily limit: ${limits.identifyPerDay} identifications. Upgrade for more!`
      );
    }
  } else if (actionType === 'guidance') {
    if (rateLimit.guidanceHourly >= limits.guidancePerHour) {
      throw new HttpsError(
        'resource-exhausted',
        `Rate limit: ${limits.guidancePerHour} guidance requests per hour.`
      );
    }
    if (rateLimit.guidanceDaily >= limits.guidancePerDay) {
      throw new HttpsError(
        'resource-exhausted',
        `Daily limit: ${limits.guidancePerDay} guidance requests.`
      );
    }
  }

  // Update counters
  await rateLimitRef.set({
    identifyHourly: actionType === 'identify' ? rateLimit.identifyHourly + 1 : rateLimit.identifyHourly,
    identifyDaily: actionType === 'identify' ? rateLimit.identifyDaily + 1 : rateLimit.identifyDaily,
    guidanceHourly: actionType === 'guidance' ? rateLimit.guidanceHourly + 1 : rateLimit.guidanceHourly,
    guidanceDaily: actionType === 'guidance' ? rateLimit.guidanceDaily + 1 : rateLimit.guidanceDaily,
    lastHourReset: rateLimit.lastHourReset?.toDate() < hourAgo ? Timestamp.now() : rateLimit.lastHourReset,
    lastDayReset: rateLimit.lastDayReset?.toDate() < dayAgo ? Timestamp.now() : rateLimit.lastDayReset,
    lastAction: Timestamp.now()
  }, { merge: true });

  console.log(`✅ Rate limit OK: ${actionType} for ${userId} (${userTier})`);
}

// ============================================================================
// LAYER 3: REQUEST DEDUPLICATION (Prevent Accidental Spam)
// ============================================================================

/**
 * Prevent duplicate requests within short time window
 * Uses request fingerprinting
 */
async function checkDuplicateRequest(userId, requestHash, windowSeconds = 10) {
  const dedupeRef = db.collection('request_dedupe').doc(`${userId}_${requestHash}`);
  const dedupeDoc = await dedupeRef.get();

  if (dedupeDoc.exists) {
    const data = dedupeDoc.data();
    const ageSeconds = (Date.now() - data.timestamp.toMillis()) / 1000;

    if (ageSeconds < windowSeconds) {
      throw new HttpsError(
        'already-exists',
        `Duplicate request detected. Please wait ${Math.ceil(windowSeconds - ageSeconds)} seconds.`
      );
    }
  }

  // Set dedupe marker (expires after windowSeconds)
  await dedupeRef.set({
    timestamp: Timestamp.now(),
    userId
  });

  // Clean up old markers (TTL would be better but this works)
  setTimeout(async () => {
    try {
      await dedupeRef.delete();
    } catch (e) {
      // Ignore cleanup errors
    }
  }, windowSeconds * 1000);
}

// ============================================================================
// LAYER 4: DATABASE QUERY PROTECTION (Prevent LLM Query Loops)
// ============================================================================

/**
 * Track and limit database queries per request
 * Prevents the "$500 overnight" scenario from query loops
 */
class QueryTracker {
  constructor(maxQueries = 10) {
    this.queryCount = 0;
    this.maxQueries = maxQueries;
    this.queries = [];
  }

  track(operation, collection) {
    this.queryCount++;
    this.queries.push({ operation, collection, timestamp: Date.now() });

    if (this.queryCount > this.maxQueries) {
      console.error('🚨 QUERY LIMIT EXCEEDED:', this.queries);
      throw new HttpsError(
        'resource-exhausted',
        'Internal error: Too many database operations. Please contact support.'
      );
    }
  }

  getStats() {
    return {
      total: this.queryCount,
      max: this.maxQueries,
      queries: this.queries
    };
  }
}

// ============================================================================
// LAYER 5: SPENDING ALERTS (Notify on High Usage)
// ============================================================================

async function checkAndSendAlerts(userId, userTier) {
  try {
    const spendingDoc = await db.collection('user_spending').doc(userId).get();
    if (!spendingDoc.exists) return;

    const spending = spendingDoc.data();
    const limits = SPENDING_LIMITS.perUser[userTier] || SPENDING_LIMITS.perUser.free;

    // Check if user has crossed 80% threshold
    const dailyPercent = (spending.daily / limits.perDay) * 100;
    const monthlyPercent = (spending.monthly / limits.perMonth) * 100;

    if (dailyPercent >= 80 && !spending.dailyAlertSent) {
      console.warn(`⚠️ User ${userId} at ${dailyPercent.toFixed(0)}% of daily limit`);
      // TODO: Send email/notification to user
      await db.collection('user_spending').doc(userId).update({
        dailyAlertSent: true
      });
    }

    if (monthlyPercent >= 80 && !spending.monthlyAlertSent) {
      console.warn(`⚠️ User ${userId} at ${monthlyPercent.toFixed(0)}% of monthly limit`);
      // TODO: Send email/notification to user
      await db.collection('user_spending').doc(userId).update({
        monthlyAlertSent: true
      });
    }

    // Global spending alerts
    const globalDoc = await db.collection('_system').doc('global_spending').get();
    if (globalDoc.exists) {
      const global = globalDoc.data();
      if (global.daily >= SPENDING_LIMITS.global.perDay * 0.8) {
        console.error('🚨 CRITICAL: Global daily spending at 80%!');
        // TODO: Send alert to admin
      }
    }

  } catch (error) {
    console.error('Alert check failed:', error);
    // Don't block on alert errors
  }
}

module.exports = {
  checkSpendingLimits,
  checkRateLimit,
  checkDuplicateRequest,
  QueryTracker,
  checkAndSendAlerts,
  OPERATION_COSTS,
  SPENDING_LIMITS,
  RATE_LIMITS
};
