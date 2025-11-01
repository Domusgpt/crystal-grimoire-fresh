/**
 * 🔥 STREAK SYSTEM - Daily Engagement & Retention
 * Based on Duolingo research: "biggest driver of growth to multi-billion business"
 * +20% next-day retention with streak mechanics
 */

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { awardCredits, CREDIT_CONFIG } = require('./credit-system');

const db = getFirestore();

// ============================================================================
// STREAK CONFIGURATION
// ============================================================================

const STREAK_CONFIG = {
  // Timezone handling (default to UTC, but can be user-specific)
  defaultTimezone: 'UTC',

  // Grace period (miss 1 day = keep streak if check in within grace)
  gracePeriodHours: 24,

  // Milestones for bonus rewards (Duolingo model)
  milestones: {
    7: { credits: 5, badge: 'week_warrior' },
    30: { credits: 20, badge: 'monthly_mystic' },
    90: { credits: 50, badge: 'season_sage' },
    365: { credits: 200, badge: 'yearly_yogi' }
  },

  // Streak freeze (can save 1 missed day)
  freezeAvailable: {
    free: 0,      // No freeze for free
    premium: 3,   // 3 freeze days per month
    pro: 7,       // 7 freeze days per month
    founders: 14  // 14 freeze days per month
  }
};

// ============================================================================
// STREAK OPERATIONS
// ============================================================================

/**
 * Get user's current streak
 */
async function getStreak(userId) {
  const streakRef = db.collection('users').doc(userId).collection('engagement').doc('streak');
  const streakDoc = await streakRef.get();

  if (!streakDoc.exists) {
    return {
      current: 0,
      longest: 0,
      lastCheckIn: null,
      canCheckIn: true,
      nextMilestone: 7,
      freezesRemaining: 0
    };
  }

  const data = streakDoc.data();
  const now = new Date();
  const lastCheckIn = data.lastCheckIn?.toDate();

  // Check if can check in today
  const canCheckIn = !lastCheckIn || !isSameDay(lastCheckIn, now);

  // Find next milestone
  const milestones = Object.keys(STREAK_CONFIG.milestones).map(Number).sort((a, b) => a - b);
  const nextMilestone = milestones.find(m => m > data.current) || null;

  return {
    current: data.current || 0,
    longest: data.longest || 0,
    lastCheckIn: lastCheckIn?.toISOString(),
    canCheckIn,
    nextMilestone,
    milestoneProgress: nextMilestone ? (data.current / nextMilestone) * 100 : 100,
    freezesRemaining: data.freezesRemaining || 0,
    totalCheckIns: data.totalCheckIns || 0
  };
}

/**
 * Daily check-in (core engagement loop)
 */
async function dailyCheckIn(userId, userTier = 'free') {
  const streakRef = db.collection('users').doc(userId).collection('engagement').doc('streak');

  return await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(streakRef);
    const now = new Date();

    let current = 0;
    let longest = 0;
    let lastCheckIn = null;
    let freezesRemaining = STREAK_CONFIG.freezeAvailable[userTier] || 0;
    let totalCheckIns = 0;

    if (doc.exists) {
      const data = doc.data();
      lastCheckIn = data.lastCheckIn?.toDate();
      current = data.current || 0;
      longest = data.longest || 0;
      freezesRemaining = data.freezesRemaining || 0;
      totalCheckIns = data.totalCheckIns || 0;

      // Check if already checked in today
      if (lastCheckIn && isSameDay(lastCheckIn, now)) {
        throw new HttpsError(
          'already-exists',
          'Already checked in today! Come back tomorrow for your streak.'
        );
      }

      // Check if streak is broken
      if (lastCheckIn) {
        const daysSinceLastCheckIn = getDaysDifference(lastCheckIn, now);

        if (daysSinceLastCheckIn === 1) {
          // Consecutive day - increment streak
          current += 1;
        } else if (daysSinceLastCheckIn === 2 && freezesRemaining > 0) {
          // Missed 1 day but have freeze available
          current += 1;
          freezesRemaining -= 1;
          console.log(`🧊 Streak freeze used for ${userId}. Remaining: ${freezesRemaining}`);
        } else {
          // Streak broken - reset
          console.log(`💔 Streak broken for ${userId}. Was ${current}, resetting to 1`);
          current = 1;
        }
      } else {
        // First check-in
        current = 1;
      }
    } else {
      // First ever check-in
      current = 1;
      freezesRemaining = STREAK_CONFIG.freezeAvailable[userTier] || 0;
    }

    // Update longest streak
    longest = Math.max(longest, current);

    // Save streak data
    transaction.set(streakRef, {
      current,
      longest,
      lastCheckIn: Timestamp.fromDate(now),
      freezesRemaining,
      totalCheckIns: totalCheckIns + 1,
      tier: userTier,
      lastUpdated: FieldValue.serverTimestamp()
    }, { merge: true });

    // Award daily credits
    const dailyCredits = CREDIT_CONFIG.dailyCheckIn;

    // Check for milestone bonus
    const milestoneReward = STREAK_CONFIG.milestones[current];
    let bonusCredits = 0;
    let badge = null;

    if (milestoneReward) {
      bonusCredits = milestoneReward.credits;
      badge = milestoneReward.badge;
      console.log(`🎉 Milestone reached: ${current} days! Badge: ${badge}`);
    }

    const totalCredits = dailyCredits + bonusCredits;

    return {
      current,
      longest,
      dailyCredits,
      bonusCredits,
      totalCredits,
      badge,
      isMilestone: !!milestoneReward,
      freezesRemaining,
      nextMilestone: getNextMilestone(current)
    };
  });
}

/**
 * Award credits for check-in (called after transaction)
 */
async function awardCheckInCredits(userId, checkInResult) {
  // Award daily credits
  await awardCredits(
    userId,
    checkInResult.dailyCredits,
    'daily_check_in',
    { streak: checkInResult.current }
  );

  // Award milestone bonus if applicable
  if (checkInResult.bonusCredits > 0) {
    await awardCredits(
      userId,
      checkInResult.bonusCredits,
      'streak_milestone',
      {
        streak: checkInResult.current,
        badge: checkInResult.badge
      }
    );

    // Award badge
    if (checkInResult.badge) {
      await awardBadge(userId, checkInResult.badge, {
        streak: checkInResult.current,
        credits: checkInResult.bonusCredits
      });
    }
  }

  return checkInResult.totalCredits;
}

/**
 * Award badge to user
 */
async function awardBadge(userId, badgeId, metadata = {}) {
  const badgeRef = db.collection('users')
    .doc(userId)
    .collection('badges')
    .doc(badgeId);

  await badgeRef.set({
    badgeId,
    earnedAt: FieldValue.serverTimestamp(),
    metadata
  });

  console.log(`🏆 Badge awarded: ${badgeId} to ${userId}`);
}

/**
 * Get streak statistics
 */
async function getStreakStats(userId) {
  const streakDoc = await db.collection('users')
    .doc(userId)
    .collection('engagement')
    .doc('streak')
    .get();

  if (!streakDoc.exists) {
    return {
      current: 0,
      longest: 0,
      totalCheckIns: 0,
      badges: [],
      nextMilestone: 7
    };
  }

  const data = streakDoc.data();

  // Get badges
  const badgesSnapshot = await db.collection('users')
    .doc(userId)
    .collection('badges')
    .get();

  const badges = badgesSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
    earnedAt: doc.data().earnedAt?.toDate()?.toISOString()
  }));

  return {
    current: data.current || 0,
    longest: data.longest || 0,
    totalCheckIns: data.totalCheckIns || 0,
    lastCheckIn: data.lastCheckIn?.toDate()?.toISOString(),
    freezesRemaining: data.freezesRemaining || 0,
    badges,
    nextMilestone: getNextMilestone(data.current || 0)
  };
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Check if two dates are the same day
 */
function isSameDay(date1, date2) {
  return (
    date1.getFullYear() === date2.getFullYear() &&
    date1.getMonth() === date2.getMonth() &&
    date1.getDate() === date2.getDate()
  );
}

/**
 * Get days difference between two dates
 */
function getDaysDifference(date1, date2) {
  const oneDay = 24 * 60 * 60 * 1000;
  const diffDays = Math.round(Math.abs((date2 - date1) / oneDay));
  return diffDays;
}

/**
 * Get next milestone
 */
function getNextMilestone(current) {
  const milestones = Object.keys(STREAK_CONFIG.milestones).map(Number).sort((a, b) => a - b);
  return milestones.find(m => m > current) || null;
}

/**
 * Reset monthly freezes (called by scheduled function)
 */
async function resetMonthlyFreezes() {
  const usersSnapshot = await db.collection('users').get();

  const batch = db.batch();
  let count = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const tier = userData.subscriptionTier || 'free';
    const maxFreezes = STREAK_CONFIG.freezeAvailable[tier] || 0;

    const streakRef = userDoc.ref.collection('engagement').doc('streak');

    batch.update(streakRef, {
      freezesRemaining: maxFreezes,
      freezeResetAt: FieldValue.serverTimestamp()
    });

    count++;

    // Firestore batch limit is 500
    if (count % 500 === 0) {
      await batch.commit();
    }
  }

  if (count % 500 !== 0) {
    await batch.commit();
  }

  console.log(`🔄 Reset freezes for ${count} users`);
  return count;
}

module.exports = {
  STREAK_CONFIG,
  getStreak,
  dailyCheckIn,
  awardCheckInCredits,
  getStreakStats,
  awardBadge,
  resetMonthlyFreezes
};
