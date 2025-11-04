/**
 * 💳 CREDIT SYSTEM - Gamified Freemium Model
 * Based on PictureThis market leader + Duolingo engagement patterns
 */

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

const db = getFirestore();

// ============================================================================
// CREDIT CONFIGURATION (Based on Research)
// ============================================================================

const CREDIT_CONFIG = {
  // Starting credits (PictureThis model: enough to see value)
  signup: 15,

  // Daily engagement (Duolingo model)
  dailyCheckIn: 1,

  // Streak bonuses (Duolingo: biggest growth driver)
  streaks: {
    7: 5,   // 7-day streak: +5 credits
    30: 20, // 30-day streak: +20 credits
    90: 50, // 90-day streak: +50 credits
    365: 200 // 1-year streak: +200 credits (legendary)
  },

  // Social sharing (PictureThis model: optional, not forced)
  socialShare: 2,
  socialShareMaxPerWeek: 3,

  // Referral (NOT "free month" - Duolingo research shows that fails)
  referralSignup: 10, // When referred friend signs up
  referralPurchase: 50, // When referred friend buys premium (extra reward)

  // Achievements (Duolingo: +116% referrals via badges)
  achievements: {
    firstIdentification: 2,
    completeProfile: 5,
    setupBirthChart: 10,
    reach10Collection: 5,
    reach50Collection: 20,
    firstDreamEntry: 3,
    firstGuidance: 2,
    shareFirst: 2,
    refer5Friends: 50,
    refer20Friends: 200
  },

  // Cost per operation
  costs: {
    identification: 1,
    guidance: 1,
    dreamAnalysis: 2,
    progressiveAnalysis: 1 // Additional cost for low confidence re-analysis
  }
};

const TIER_LIMITS = {
  free: {
    collectionMax: 10,  // Figma/Notion model: clear limit creates upgrade pressure
    needsCredits: true
  },
  premium: {
    collectionMax: 250,
    needsCredits: false  // Premium = no credit tracking
  },
  pro: {
    collectionMax: 1000,
    needsCredits: false
  },
  founders: {
    collectionMax: Infinity,
    needsCredits: false
  }
};

// ============================================================================
// CREDIT OPERATIONS
// ============================================================================

/**
 * Get user's credit balance
 */
async function getCreditBalance(userId) {
  const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');
  const creditsDoc = await creditsRef.get();

  if (!creditsDoc.exists) {
    // Initialize with signup credits
    await creditsRef.set({
      balance: CREDIT_CONFIG.signup,
      totalEarned: CREDIT_CONFIG.signup,
      totalSpent: 0,
      lastUpdated: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp()
    });

    return CREDIT_CONFIG.signup;
  }

  return creditsDoc.data().balance || 0;
}

/**
 * Check if user has enough credits
 */
async function checkCredits(userId, cost, userTier = 'free') {
  // Paid tiers don't use credits
  if (userTier !== 'free') {
    return { hasCredits: true, balance: Infinity };
  }

  const balance = await getCreditBalance(userId);

  if (balance < cost) {
    throw new HttpsError(
      'resource-exhausted',
      `Not enough credits. Need ${cost}, have ${balance}. Earn more or upgrade to Premium!`
    );
  }

  return { hasCredits: true, balance };
}

/**
 * Deduct credits for an operation
 */
async function deductCredits(userId, cost, operation, metadata = {}) {
  const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(creditsRef);
    const currentBalance = doc.exists ? doc.data().balance : 0;

    if (currentBalance < cost) {
      throw new HttpsError(
        'resource-exhausted',
        `Insufficient credits: need ${cost}, have ${currentBalance}`
      );
    }

    const newBalance = currentBalance - cost;

    transaction.update(creditsRef, {
      balance: newBalance,
      totalSpent: FieldValue.increment(cost),
      lastUpdated: FieldValue.serverTimestamp()
    });

    // Log transaction
    const transactionRef = db.collection('users')
      .doc(userId)
      .collection('credits')
      .doc('transactions')
      .collection('history')
      .doc();

    transaction.set(transactionRef, {
      type: 'deduction',
      amount: -cost,
      operation,
      metadata,
      balanceAfter: newBalance,
      timestamp: FieldValue.serverTimestamp()
    });
  });

  console.log(`💳 Deducted ${cost} credits from ${userId} for ${operation}`);
}

/**
 * Award credits to user
 */
async function awardCredits(userId, amount, reason, metadata = {}) {
  const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(creditsRef);

    if (!doc.exists) {
      // Initialize if doesn't exist
      transaction.set(creditsRef, {
        balance: amount,
        totalEarned: amount,
        totalSpent: 0,
        lastUpdated: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp()
      });
    } else {
      transaction.update(creditsRef, {
        balance: FieldValue.increment(amount),
        totalEarned: FieldValue.increment(amount),
        lastUpdated: FieldValue.serverTimestamp()
      });
    }

    // Log transaction
    const transactionRef = db.collection('users')
      .doc(userId)
      .collection('credits')
      .doc('transactions')
      .collection('history')
      .doc();

    const newBalance = (doc.exists ? doc.data().balance : 0) + amount;

    transaction.set(transactionRef, {
      type: 'award',
      amount: +amount,
      reason,
      metadata,
      balanceAfter: newBalance,
      timestamp: FieldValue.serverTimestamp()
    });
  });

  console.log(`💰 Awarded ${amount} credits to ${userId} for ${reason}`);
  return amount;
}

/**
 * Get credit transaction history
 */
async function getCreditHistory(userId, limit = 50) {
  const historySnapshot = await db.collection('users')
    .doc(userId)
    .collection('credits')
    .doc('transactions')
    .collection('history')
    .orderBy('timestamp', 'desc')
    .limit(limit)
    .get();

  return historySnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    timestamp: doc.data().timestamp?.toDate()?.toISOString()
  }));
}

// ============================================================================
// COLLECTION LIMITS
// ============================================================================

/**
 * Check if user can add to collection
 */
async function checkCollectionLimit(userId, userTier = 'free') {
  const limits = TIER_LIMITS[userTier] || TIER_LIMITS.free;

  // Get current collection count
  const collectionSnapshot = await db.collection('users')
    .doc(userId)
    .collection('crystals')
    .get();

  const currentCount = collectionSnapshot.size;

  if (currentCount >= limits.collectionMax) {
    const upgradeMessage = userTier === 'free'
      ? 'Collection limit reached (10 crystals). Upgrade to Premium for unlimited storage!'
      : 'Collection limit reached. Contact support to increase limit.';

    throw new HttpsError('resource-exhausted', upgradeMessage);
  }

  return {
    canAdd: true,
    current: currentCount,
    max: limits.collectionMax,
    remaining: limits.collectionMax - currentCount
  };
}

/**
 * Get collection stats
 */
async function getCollectionStats(userId, userTier = 'free') {
  const limits = TIER_LIMITS[userTier] || TIER_LIMITS.free;

  const collectionSnapshot = await db.collection('users')
    .doc(userId)
    .collection('crystals')
    .get();

  const currentCount = collectionSnapshot.size;
  const percentage = limits.collectionMax === Infinity
    ? 0
    : (currentCount / limits.collectionMax) * 100;

  return {
    current: currentCount,
    max: limits.collectionMax,
    maxDisplay: limits.collectionMax === Infinity ? 'Unlimited' : limits.collectionMax,
    remaining: limits.collectionMax === Infinity ? Infinity : limits.collectionMax - currentCount,
    percentage: Math.min(100, percentage),
    isUnlimited: limits.collectionMax === Infinity,
    needsUpgrade: currentCount >= limits.collectionMax * 0.8 && userTier === 'free'
  };
}

// ============================================================================
// CREDIT ANALYTICS
// ============================================================================

/**
 * Get user's credit analytics
 */
async function getCreditAnalytics(userId) {
  const balanceDoc = await db.collection('users')
    .doc(userId)
    .collection('credits')
    .doc('balance')
    .get();

  const balance = balanceDoc.exists ? balanceDoc.data() : {
    balance: 0,
    totalEarned: 0,
    totalSpent: 0
  };

  // Get earning breakdown
  const historySnapshot = await db.collection('users')
    .doc(userId)
    .collection('credits')
    .doc('transactions')
    .collection('history')
    .where('type', '==', 'award')
    .get();

  const earningBreakdown = {};
  historySnapshot.docs.forEach(doc => {
    const reason = doc.data().reason;
    earningBreakdown[reason] = (earningBreakdown[reason] || 0) + doc.data().amount;
  });

  return {
    balance: balance.balance || 0,
    totalEarned: balance.totalEarned || 0,
    totalSpent: balance.totalSpent || 0,
    earningBreakdown,
    createdAt: balance.createdAt?.toDate()?.toISOString(),
    lastUpdated: balance.lastUpdated?.toDate()?.toISOString()
  };
}

module.exports = {
  CREDIT_CONFIG,
  TIER_LIMITS,
  getCreditBalance,
  checkCredits,
  deductCredits,
  awardCredits,
  getCreditHistory,
  checkCollectionLimit,
  getCollectionStats,
  getCreditAnalytics
};
