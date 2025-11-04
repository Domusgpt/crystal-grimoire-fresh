/**
 * 🏆 ACHIEVEMENT SYSTEM - Gamification & Engagement
 * Based on Duolingo research: +116% referrals via achievements vs +3% via traditional referrals
 */

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { awardCredits, CREDIT_CONFIG } = require('./credit-system');
const { awardBadge } = require('./streak-system');

const db = getFirestore();

// ============================================================================
// ACHIEVEMENT DEFINITIONS
// ============================================================================

const ACHIEVEMENTS = {
  // First-time achievements
  first_identification: {
    id: 'first_identification',
    name: 'First Discovery',
    description: 'Identify your first crystal',
    credits: 2,
    badge: 'novice_seeker',
    icon: '🔍',
    category: 'beginner'
  },

  first_guidance: {
    id: 'first_guidance',
    name: 'Seeking Wisdom',
    description: 'Ask your first guidance question',
    credits: 2,
    badge: 'wisdom_seeker',
    icon: '💭',
    category: 'beginner'
  },

  first_dream: {
    id: 'first_dream',
    name: 'Dream Walker',
    description: 'Record your first dream',
    credits: 3,
    badge: 'dream_walker',
    icon: '🌙',
    category: 'beginner'
  },

  first_share: {
    id: 'first_share',
    name: 'Crystal Sharer',
    description: 'Share a crystal on social media',
    credits: 2,
    badge: 'social_crystal',
    icon: '📱',
    category: 'social'
  },

  // Profile completion
  complete_profile: {
    id: 'complete_profile',
    name: 'Profile Complete',
    description: 'Fill out your complete profile',
    credits: 5,
    badge: 'profile_master',
    icon: '👤',
    category: 'profile'
  },

  setup_birth_chart: {
    id: 'setup_birth_chart',
    name: 'Cosmic Navigator',
    description: 'Set up your birth chart',
    credits: 10,
    badge: 'astro_mystic',
    icon: '✨',
    category: 'profile'
  },

  // Collection milestones
  collect_10: {
    id: 'collect_10',
    name: 'Crystal Collector',
    description: 'Add 10 crystals to your collection',
    credits: 5,
    badge: 'collector_bronze',
    icon: '💎',
    category: 'collection',
    requirement: 10
  },

  collect_25: {
    id: 'collect_25',
    name: 'Crystal Enthusiast',
    description: 'Add 25 crystals to your collection',
    credits: 10,
    badge: 'collector_silver',
    icon: '💎',
    category: 'collection',
    requirement: 25
  },

  collect_50: {
    id: 'collect_50',
    name: 'Crystal Master',
    description: 'Add 50 crystals to your collection',
    credits: 20,
    badge: 'collector_gold',
    icon: '💎',
    category: 'collection',
    requirement: 50
  },

  collect_100: {
    id: 'collect_100',
    name: 'Crystal Sage',
    description: 'Add 100 crystals to your collection',
    credits: 50,
    badge: 'collector_platinum',
    icon: '💎',
    category: 'collection',
    requirement: 100
  },

  // Identification milestones
  identify_10: {
    id: 'identify_10',
    name: 'Novice Identifier',
    description: 'Identify 10 different crystals',
    credits: 5,
    badge: 'identifier_novice',
    icon: '🔮',
    category: 'identification',
    requirement: 10
  },

  identify_50: {
    id: 'identify_50',
    name: 'Expert Identifier',
    description: 'Identify 50 different crystals',
    credits: 20,
    badge: 'identifier_expert',
    icon: '🔮',
    category: 'identification',
    requirement: 50
  },

  // Social achievements
  refer_1: {
    id: 'refer_1',
    name: 'Friend Finder',
    description: 'Refer your first friend',
    credits: 10,
    badge: 'friend_finder',
    icon: '🤝',
    category: 'social'
  },

  refer_5: {
    id: 'refer_5',
    name: 'Crystal Ambassador',
    description: 'Refer 5 friends',
    credits: 50,
    badge: 'ambassador',
    icon: '🌟',
    category: 'social',
    requirement: 5
  },

  refer_20: {
    id: 'refer_20',
    name: 'Community Builder',
    description: 'Refer 20 friends',
    credits: 200,
    badge: 'community_builder',
    icon: '👑',
    category: 'social',
    requirement: 20
  },

  // Engagement achievements
  login_7_days: {
    id: 'login_7_days',
    name: 'Week Warrior',
    description: '7-day login streak',
    credits: 5,
    badge: 'week_warrior',
    icon: '🔥',
    category: 'engagement',
    requirement: 7
  },

  login_30_days: {
    id: 'login_30_days',
    name: 'Monthly Mystic',
    description: '30-day login streak',
    credits: 20,
    badge: 'monthly_mystic',
    icon: '🔥',
    category: 'engagement',
    requirement: 30
  },

  login_365_days: {
    id: 'login_365_days',
    name: 'Yearly Yogi',
    description: '365-day login streak (Legendary!)',
    credits: 200,
    badge: 'yearly_yogi',
    icon: '👑',
    category: 'engagement',
    requirement: 365
  }
};

// ============================================================================
// ACHIEVEMENT OPERATIONS
// ============================================================================

/**
 * Check and award achievement
 */
async function checkAchievement(userId, achievementId, metadata = {}) {
  const achievement = ACHIEVEMENTS[achievementId];

  if (!achievement) {
    console.warn(`Unknown achievement: ${achievementId}`);
    return null;
  }

  // Check if already earned
  const achievementRef = db.collection('users')
    .doc(userId)
    .collection('achievements')
    .doc(achievementId);

  const doc = await achievementRef.get();

  if (doc.exists) {
    // Already earned
    return null;
  }

  // Award achievement
  await achievementRef.set({
    achievementId,
    earnedAt: FieldValue.serverTimestamp(),
    metadata
  });

  // Award credits
  if (achievement.credits > 0) {
    await awardCredits(
      userId,
      achievement.credits,
      `achievement_${achievementId}`,
      { achievement: achievement.name }
    );
  }

  // Award badge
  if (achievement.badge) {
    await awardBadge(userId, achievement.badge, {
      achievement: achievement.name,
      credits: achievement.credits
    });
  }

  console.log(`🏆 Achievement unlocked: ${achievement.name} for ${userId} (+${achievement.credits} credits)`);

  return {
    ...achievement,
    earnedAt: new Date().toISOString()
  };
}

/**
 * Check collection milestone achievements
 */
async function checkCollectionMilestones(userId, collectionCount) {
  const milestones = [
    { count: 10, id: 'collect_10' },
    { count: 25, id: 'collect_25' },
    { count: 50, id: 'collect_50' },
    { count: 100, id: 'collect_100' }
  ];

  const earned = [];

  for (const milestone of milestones) {
    if (collectionCount >= milestone.count) {
      const result = await checkAchievement(userId, milestone.id, {
        collectionCount
      });
      if (result) {
        earned.push(result);
      }
    }
  }

  return earned;
}

/**
 * Check identification milestone achievements
 */
async function checkIdentificationMilestones(userId, identificationCount) {
  const milestones = [
    { count: 10, id: 'identify_10' },
    { count: 50, id: 'identify_50' }
  ];

  const earned = [];

  for (const milestone of milestones) {
    if (identificationCount >= milestone.count) {
      const result = await checkAchievement(userId, milestone.id, {
        identificationCount
      });
      if (result) {
        earned.push(result);
      }
    }
  }

  return earned;
}

/**
 * Check referral milestone achievements
 */
async function checkReferralMilestones(userId, referralCount) {
  const milestones = [
    { count: 1, id: 'refer_1' },
    { count: 5, id: 'refer_5' },
    { count: 20, id: 'refer_20' }
  ];

  const earned = [];

  for (const milestone of milestones) {
    if (referralCount >= milestone.count) {
      const result = await checkAchievement(userId, milestone.id, {
        referralCount
      });
      if (result) {
        earned.push(result);
      }
    }
  }

  return earned;
}

/**
 * Get all user achievements
 */
async function getUserAchievements(userId) {
  const achievementsSnapshot = await db.collection('users')
    .doc(userId)
    .collection('achievements')
    .get();

  const earned = achievementsSnapshot.docs.map(doc => {
    const achievement = ACHIEVEMENTS[doc.id];
    return {
      id: doc.id,
      ...achievement,
      earnedAt: doc.data().earnedAt?.toDate()?.toISOString(),
      metadata: doc.data().metadata
    };
  });

  // Get all available achievements
  const all = Object.values(ACHIEVEMENTS).map(ach => ({
    ...ach,
    earned: earned.some(e => e.id === ach.id)
  }));

  return {
    earned,
    available: all.filter(a => !a.earned),
    totalEarned: earned.length,
    totalAvailable: all.length,
    completionPercentage: (earned.length / all.length) * 100
  };
}

/**
 * Get achievement progress
 */
async function getAchievementProgress(userId) {
  // Get current stats
  const [
    collectionSnapshot,
    identificationsSnapshot,
    referralsSnapshot,
    streakDoc
  ] = await Promise.all([
    db.collection('users').doc(userId).collection('crystals').get(),
    db.collection('users').doc(userId).collection('identifications').get(),
    db.collection('referrals').where('referrerId', '==', userId).where('status', '==', 'completed').get(),
    db.collection('users').doc(userId).collection('engagement').doc('streak').get()
  ]);

  const collectionCount = collectionSnapshot.size;
  const identificationCount = identificationsSnapshot.size;
  const referralCount = referralsSnapshot.size;
  const currentStreak = streakDoc.exists ? (streakDoc.data().current || 0) : 0;

  return {
    collection: {
      current: collectionCount,
      milestones: [
        { count: 10, achieved: collectionCount >= 10 },
        { count: 25, achieved: collectionCount >= 25 },
        { count: 50, achieved: collectionCount >= 50 },
        { count: 100, achieved: collectionCount >= 100 }
      ]
    },
    identifications: {
      current: identificationCount,
      milestones: [
        { count: 10, achieved: identificationCount >= 10 },
        { count: 50, achieved: identificationCount >= 50 }
      ]
    },
    referrals: {
      current: referralCount,
      milestones: [
        { count: 1, achieved: referralCount >= 1 },
        { count: 5, achieved: referralCount >= 5 },
        { count: 20, achieved: referralCount >= 20 }
      ]
    },
    streak: {
      current: currentStreak,
      milestones: [
        { count: 7, achieved: currentStreak >= 7 },
        { count: 30, achieved: currentStreak >= 30 },
        { count: 365, achieved: currentStreak >= 365 }
      ]
    }
  };
}

module.exports = {
  ACHIEVEMENTS,
  checkAchievement,
  checkCollectionMilestones,
  checkIdentificationMilestones,
  checkReferralMilestones,
  getUserAchievements,
  getAchievementProgress
};
