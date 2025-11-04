/**
 * 🤝 REFERRAL SYSTEM - Viral Growth
 * Based on research: Traditional "free month" referrals fail (+3% Duolingo)
 * Credit-based referrals work better (ongoing value vs one-time)
 */

const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { awardCredits, CREDIT_CONFIG } = require('./credit-system');
const { checkReferralMilestones } = require('./achievement-system');

const db = getFirestore();

// ============================================================================
// REFERRAL CONFIGURATION
// ============================================================================

const REFERRAL_CONFIG = {
  // Credit rewards (NOT "free month" - that fails per Duolingo research)
  referrerSignupReward: 10,    // When referred friend signs up
  referrerPurchaseReward: 50,  // When referred friend buys premium (bonus!)
  refereeSignupBonus: 5,       // New user gets bonus credits for using referral code

  // Referral code generation
  codeLength: 6,
  codePrefix: 'CG',  // CrystalGrimoire

  // Limits (prevent abuse)
  maxReferralsPerDay: 20,
  maxReferralsPerMonth: 100,

  // Tracking period
  attributionWindowDays: 30  // Credit referrer if friend signs up within 30 days of click
};

// ============================================================================
// REFERRAL CODE OPERATIONS
// ============================================================================

/**
 * Generate unique referral code
 */
function generateReferralCode() {
  const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars
  let code = REFERRAL_CONFIG.codePrefix;

  for (let i = 0; i < REFERRAL_CONFIG.codeLength; i++) {
    code += characters.charAt(Math.floor(Math.random() * characters.length));
  }

  return code;
}

/**
 * Get or create user's referral code
 */
async function getReferralCode(userId) {
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (userDoc.exists && userDoc.data().referralCode) {
    return userDoc.data().referralCode;
  }

  // Generate new unique code
  let code;
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    code = generateReferralCode();

    // Check if code already exists
    const existingSnapshot = await db.collection('users')
      .where('referralCode', '==', code)
      .limit(1)
      .get();

    if (existingSnapshot.empty) {
      isUnique = true;
    }

    attempts++;
  }

  if (!isUnique) {
    throw new HttpsError('internal', 'Failed to generate unique referral code');
  }

  // Save code to user document
  await userRef.update({
    referralCode: code,
    referralCodeCreatedAt: FieldValue.serverTimestamp()
  });

  console.log(`🔗 Generated referral code ${code} for ${userId}`);

  return code;
}

/**
 * Track referral click (for attribution)
 */
async function trackReferralClick(referralCode, metadata = {}) {
  // Find referrer by code
  const referrerSnapshot = await db.collection('users')
    .where('referralCode', '==', referralCode)
    .limit(1)
    .get();

  if (referrerSnapshot.empty) {
    throw new HttpsError('not-found', 'Invalid referral code');
  }

  const referrerId = referrerSnapshot.docs[0].id;

  // Log the click
  const clickRef = db.collection('referral_clicks').doc();
  await clickRef.set({
    referralCode,
    referrerId,
    clickedAt: FieldValue.serverTimestamp(),
    metadata: {
      userAgent: metadata.userAgent || null,
      source: metadata.source || 'unknown',
      ipAddress: metadata.ipAddress || null
    },
    converted: false
  });

  console.log(`👆 Referral click tracked for code ${referralCode}`);

  return {
    referralCode,
    clickId: clickRef.id
  };
}

/**
 * Process referral signup (when new user signs up with code)
 */
async function processReferralSignup(newUserId, referralCode) {
  if (!referralCode) {
    return null;
  }

  // Find referrer by code
  const referrerSnapshot = await db.collection('users')
    .where('referralCode', '==', referralCode)
    .limit(1)
    .get();

  if (referrerSnapshot.empty) {
    console.warn(`Invalid referral code: ${referralCode}`);
    return null;
  }

  const referrerId = referrerSnapshot.docs[0].id;

  // Can't refer yourself
  if (referrerId === newUserId) {
    console.warn(`User ${newUserId} tried to use their own referral code`);
    return null;
  }

  // Check if already used a referral code
  const existingReferralSnapshot = await db.collection('referrals')
    .where('refereeId', '==', newUserId)
    .limit(1)
    .get();

  if (!existingReferralSnapshot.empty) {
    console.warn(`User ${newUserId} already used a referral code`);
    return null;
  }

  // Create referral record
  const referralRef = db.collection('referrals').doc();
  await referralRef.set({
    referrerId,
    refereeId: newUserId,
    referralCode,
    status: 'completed',
    signupAt: FieldValue.serverTimestamp(),
    referrerRewardGiven: false,
    refereeRewardGiven: false
  });

  // Award credits to referrer
  await awardCredits(
    referrerId,
    REFERRAL_CONFIG.referrerSignupReward,
    'referral_signup',
    { refereeId: newUserId, referralCode }
  );

  // Award bonus credits to new user
  await awardCredits(
    newUserId,
    REFERRAL_CONFIG.refereeSignupBonus,
    'referred_signup_bonus',
    { referrerId, referralCode }
  );

  // Mark rewards as given
  await referralRef.update({
    referrerRewardGiven: true,
    refereeRewardGiven: true,
    rewardsGivenAt: FieldValue.serverTimestamp()
  });

  // Check for referral milestones
  const referralCount = await getReferralCount(referrerId);
  await checkReferralMilestones(referrerId, referralCount);

  console.log(`🎉 Referral processed: ${referrerId} → ${newUserId} (+${REFERRAL_CONFIG.referrerSignupReward} credits)`);

  return {
    referrerId,
    referrerReward: REFERRAL_CONFIG.referrerSignupReward,
    refereeBonus: REFERRAL_CONFIG.refereeSignupBonus
  };
}

/**
 * Process referral purchase (when referred friend buys premium)
 */
async function processReferralPurchase(purchaserId) {
  // Find referral record
  const referralSnapshot = await db.collection('referrals')
    .where('refereeId', '==', purchaserId)
    .where('status', '==', 'completed')
    .limit(1)
    .get();

  if (referralSnapshot.empty) {
    // No referral for this user
    return null;
  }

  const referralDoc = referralSnapshot.docs[0];
  const referralData = referralDoc.data();

  // Check if already rewarded for purchase
  if (referralData.purchaseRewardGiven) {
    return null;
  }

  const referrerId = referralData.referrerId;

  // Award bonus credits to referrer
  await awardCredits(
    referrerId,
    REFERRAL_CONFIG.referrerPurchaseReward,
    'referral_purchase',
    { refereeId: purchaserId }
  );

  // Update referral record
  await referralDoc.ref.update({
    purchaseRewardGiven: true,
    purchaseRewardGivenAt: FieldValue.serverTimestamp(),
    refereePurchasedAt: FieldValue.serverTimestamp()
  });

  console.log(`💰 Referral purchase bonus: ${referrerId} gets +${REFERRAL_CONFIG.referrerPurchaseReward} credits`);

  return {
    referrerId,
    bonus: REFERRAL_CONFIG.referrerPurchaseReward
  };
}

/**
 * Get user's referral stats
 */
async function getReferralStats(userId) {
  // Get referral code
  const userDoc = await db.collection('users').doc(userId).get();
  const referralCode = userDoc.exists ? userDoc.data().referralCode : null;

  if (!referralCode) {
    return {
      referralCode: null,
      totalReferrals: 0,
      completedReferrals: 0,
      purchasedReferrals: 0,
      totalEarned: 0,
      referrals: []
    };
  }

  // Get all referrals
  const referralsSnapshot = await db.collection('referrals')
    .where('referrerId', '==', userId)
    .orderBy('signupAt', 'desc')
    .get();

  const referrals = referralsSnapshot.docs.map(doc => {
    const data = doc.data();
    return {
      id: doc.id,
      refereeId: data.refereeId,
      status: data.status,
      signupAt: data.signupAt?.toDate()?.toISOString(),
      purchased: data.purchaseRewardGiven || false,
      rewardEarned: REFERRAL_CONFIG.referrerSignupReward + (data.purchaseRewardGiven ? REFERRAL_CONFIG.referrerPurchaseReward : 0)
    };
  });

  const completedReferrals = referrals.filter(r => r.status === 'completed').length;
  const purchasedReferrals = referrals.filter(r => r.purchased).length;
  const totalEarned = completedReferrals * REFERRAL_CONFIG.referrerSignupReward +
                     purchasedReferrals * REFERRAL_CONFIG.referrerPurchaseReward;

  return {
    referralCode,
    totalReferrals: referrals.length,
    completedReferrals,
    purchasedReferrals,
    totalEarned,
    referrals,
    shareUrl: `https://crystalgrimoire.app?ref=${referralCode}`,
    rewards: {
      perSignup: REFERRAL_CONFIG.referrerSignupReward,
      perPurchase: REFERRAL_CONFIG.referrerPurchaseReward
    }
  };
}

/**
 * Get referral count (for achievements)
 */
async function getReferralCount(userId) {
  const snapshot = await db.collection('referrals')
    .where('referrerId', '==', userId)
    .where('status', '==', 'completed')
    .get();

  return snapshot.size;
}

/**
 * Validate referral code
 */
async function validateReferralCode(referralCode) {
  const snapshot = await db.collection('users')
    .where('referralCode', '==', referralCode)
    .limit(1)
    .get();

  return !snapshot.empty;
}

module.exports = {
  REFERRAL_CONFIG,
  generateReferralCode,
  getReferralCode,
  trackReferralClick,
  processReferralSignup,
  processReferralPurchase,
  getReferralStats,
  getReferralCount,
  validateReferralCode
};
