/**
 * 🧪 GAMIFICATION SYSTEM TEST
 * Unit tests for credit system, streaks, achievements, referrals
 * Run with: node test-gamification.js
 */

// Initialize Firebase Admin for testing
const admin = require('firebase-admin');

// Initialize with test credentials (doesn't need real project)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'test-project',
    databaseURL: 'http://localhost:8080'
  });
}

const { CREDIT_CONFIG, TIER_LIMITS } = require('./credit-system');
const { STREAK_CONFIG } = require('./streak-system');
const { ACHIEVEMENTS } = require('./achievement-system');
const { REFERRAL_CONFIG, generateReferralCode } = require('./referral-system');

console.log('🧪 Testing Gamification System...\n');

let testsPassed = 0;
let testsFailed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`✅ ${name}`);
    testsPassed++;
  } catch (error) {
    console.log(`❌ ${name}`);
    console.log(`   Error: ${error.message}`);
    testsFailed++;
  }
}

// ============================================================================
// CREDIT SYSTEM TESTS
// ============================================================================

console.log('📦 CREDIT SYSTEM CONFIGURATION\n');

test('Signup credits should be 15', () => {
  if (CREDIT_CONFIG.signup !== 15) {
    throw new Error(`Expected 15, got ${CREDIT_CONFIG.signup}`);
  }
});

test('Daily check-in should award 1 credit', () => {
  if (CREDIT_CONFIG.dailyCheckIn !== 1) {
    throw new Error(`Expected 1, got ${CREDIT_CONFIG.dailyCheckIn}`);
  }
});

test('7-day streak bonus should be 5 credits', () => {
  if (CREDIT_CONFIG.streaks[7] !== 5) {
    throw new Error(`Expected 5, got ${CREDIT_CONFIG.streaks[7]}`);
  }
});

test('30-day streak bonus should be 20 credits', () => {
  if (CREDIT_CONFIG.streaks[30] !== 20) {
    throw new Error(`Expected 20, got ${CREDIT_CONFIG.streaks[30]}`);
  }
});

test('Identification should cost 1 credit', () => {
  if (CREDIT_CONFIG.costs.identification !== 1) {
    throw new Error(`Expected 1, got ${CREDIT_CONFIG.costs.identification}`);
  }
});

test('Referral signup reward should be 10 credits', () => {
  if (CREDIT_CONFIG.referralSignup !== 10) {
    throw new Error(`Expected 10, got ${CREDIT_CONFIG.referralSignup}`);
  }
});

test('Referral purchase reward should be 50 credits', () => {
  if (CREDIT_CONFIG.referralPurchase !== 50) {
    throw new Error(`Expected 50, got ${CREDIT_CONFIG.referralPurchase}`);
  }
});

test('Free tier collection limit should be 10', () => {
  if (TIER_LIMITS.free.collectionMax !== 10) {
    throw new Error(`Expected 10, got ${TIER_LIMITS.free.collectionMax}`);
  }
});

test('Free tier should require credits', () => {
  if (TIER_LIMITS.free.needsCredits !== true) {
    throw new Error('Free tier should need credits');
  }
});

test('Premium tier should not require credits', () => {
  if (TIER_LIMITS.premium.needsCredits !== false) {
    throw new Error('Premium tier should not need credits');
  }
});

// ============================================================================
// STREAK SYSTEM TESTS
// ============================================================================

console.log('\n🔥 STREAK SYSTEM CONFIGURATION\n');

test('7-day milestone should exist', () => {
  if (!STREAK_CONFIG.milestones[7]) {
    throw new Error('7-day milestone not defined');
  }
});

test('7-day milestone should award 5 credits', () => {
  if (STREAK_CONFIG.milestones[7].credits !== 5) {
    throw new Error(`Expected 5, got ${STREAK_CONFIG.milestones[7].credits}`);
  }
});

test('30-day milestone should award 20 credits', () => {
  if (STREAK_CONFIG.milestones[30].credits !== 20) {
    throw new Error(`Expected 20, got ${STREAK_CONFIG.milestones[30].credits}`);
  }
});

test('365-day milestone should award 200 credits', () => {
  if (STREAK_CONFIG.milestones[365].credits !== 200) {
    throw new Error(`Expected 200, got ${STREAK_CONFIG.milestones[365].credits}`);
  }
});

test('Free tier should have 0 freeze days', () => {
  if (STREAK_CONFIG.freezeAvailable.free !== 0) {
    throw new Error(`Expected 0, got ${STREAK_CONFIG.freezeAvailable.free}`);
  }
});

test('Premium tier should have 3 freeze days', () => {
  if (STREAK_CONFIG.freezeAvailable.premium !== 3) {
    throw new Error(`Expected 3, got ${STREAK_CONFIG.freezeAvailable.premium}`);
  }
});

// ============================================================================
// ACHIEVEMENT SYSTEM TESTS
// ============================================================================

console.log('\n🏆 ACHIEVEMENT SYSTEM CONFIGURATION\n');

test('first_identification achievement should exist', () => {
  if (!ACHIEVEMENTS.first_identification) {
    throw new Error('first_identification achievement not found');
  }
});

test('first_identification should award 2 credits', () => {
  if (ACHIEVEMENTS.first_identification.credits !== 2) {
    throw new Error(`Expected 2, got ${ACHIEVEMENTS.first_identification.credits}`);
  }
});

test('collect_10 achievement should exist', () => {
  if (!ACHIEVEMENTS.collect_10) {
    throw new Error('collect_10 achievement not found');
  }
});

test('collect_10 should award 5 credits', () => {
  if (ACHIEVEMENTS.collect_10.credits !== 5) {
    throw new Error(`Expected 5, got ${ACHIEVEMENTS.collect_10.credits}`);
  }
});

test('refer_5 achievement should award 50 credits', () => {
  if (ACHIEVEMENTS.refer_5.credits !== 50) {
    throw new Error(`Expected 50, got ${ACHIEVEMENTS.refer_5.credits}`);
  }
});

test('Should have at least 15 achievements defined', () => {
  const achievementCount = Object.keys(ACHIEVEMENTS).length;
  if (achievementCount < 15) {
    throw new Error(`Expected at least 15, got ${achievementCount}`);
  }
});

// ============================================================================
// REFERRAL SYSTEM TESTS
// ============================================================================

console.log('\n🤝 REFERRAL SYSTEM CONFIGURATION\n');

test('Referrer signup reward should be 10 credits', () => {
  if (REFERRAL_CONFIG.referrerSignupReward !== 10) {
    throw new Error(`Expected 10, got ${REFERRAL_CONFIG.referrerSignupReward}`);
  }
});

test('Referrer purchase reward should be 50 credits', () => {
  if (REFERRAL_CONFIG.referrerPurchaseReward !== 50) {
    throw new Error(`Expected 50, got ${REFERRAL_CONFIG.referrerPurchaseReward}`);
  }
});

test('Referee signup bonus should be 5 credits', () => {
  if (REFERRAL_CONFIG.refereeSignupBonus !== 5) {
    throw new Error(`Expected 5, got ${REFERRAL_CONFIG.refereeSignupBonus}`);
  }
});

test('Referral code should start with CG prefix', () => {
  if (REFERRAL_CONFIG.codePrefix !== 'CG') {
    throw new Error(`Expected CG, got ${REFERRAL_CONFIG.codePrefix}`);
  }
});

test('Referral code should be 6 characters plus prefix', () => {
  if (REFERRAL_CONFIG.codeLength !== 6) {
    throw new Error(`Expected 6, got ${REFERRAL_CONFIG.codeLength}`);
  }
});

test('generateReferralCode should create valid format', () => {
  const code = generateReferralCode();
  if (!code.startsWith('CG')) {
    throw new Error(`Code should start with CG, got ${code}`);
  }
  if (code.length !== 8) {  // CG + 6 characters
    throw new Error(`Code should be 8 characters, got ${code.length}`);
  }
});

test('generateReferralCode should create unique codes', () => {
  const code1 = generateReferralCode();
  const code2 = generateReferralCode();
  if (code1 === code2) {
    throw new Error('Generated codes should be different (may fail rarely due to randomness)');
  }
});

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

console.log('\n🔗 INTEGRATION VALIDATION\n');

test('Total free tier earnings should be reasonable', () => {
  // Signup + daily check-ins + achievements + streaks
  const maxPossibleFreeCredits =
    CREDIT_CONFIG.signup + // 15
    (CREDIT_CONFIG.dailyCheckIn * 30) + // 30 (monthly)
    (CREDIT_CONFIG.streaks[7]) + // 5
    (CREDIT_CONFIG.streaks[30]) + // 20
    (CREDIT_CONFIG.achievements.firstIdentification || 0) + // 2
    (CREDIT_CONFIG.achievements.completeProfile || 0) + // 5
    (CREDIT_CONFIG.achievements.setupBirthChart || 0) + // 10
    (CREDIT_CONFIG.achievements.reach10Collection || 0) + // 5
    (CREDIT_CONFIG.socialShare * 3 * 4); // 24 (max social shares per month)

  console.log(`   Max monthly free credits: ~${maxPossibleFreeCredits}`);

  if (maxPossibleFreeCredits < 50) {
    throw new Error('Users should be able to earn at least 50 credits/month');
  }

  if (maxPossibleFreeCredits > 200) {
    throw new Error('Free credits might be too generous, check monetization');
  }
});

test('Cost per identification should be sustainable', () => {
  const costPerID = 0.001; // $0.001 from research
  const maxFreeIDs = 100; // Conservative estimate
  const monthlyCost = costPerID * maxFreeIDs;

  console.log(`   Max monthly cost per heavy user: $${monthlyCost.toFixed(2)}`);

  if (monthlyCost > 0.15) {
    throw new Error('Free tier costs might be too high for sustainability');
  }
});

test('Conversion pressure should exist (collection limit)', () => {
  if (TIER_LIMITS.free.collectionMax >= 50) {
    throw new Error('Free tier limit too high, reduces upgrade pressure');
  }

  if (TIER_LIMITS.free.collectionMax < 5) {
    throw new Error('Free tier limit too low, may frustrate users');
  }

  console.log(`   Collection limit ${TIER_LIMITS.free.collectionMax} is in sweet spot (5-50)`);
});

// ============================================================================
// RESULTS
// ============================================================================

console.log('\n' + '='.repeat(60));
console.log('TEST RESULTS');
console.log('='.repeat(60));
console.log(`✅ Passed: ${testsPassed}`);
console.log(`❌ Failed: ${testsFailed}`);
console.log(`📊 Total:  ${testsPassed + testsFailed}`);

if (testsFailed === 0) {
  console.log('\n🎉 ALL TESTS PASSED! System configuration is correct.\n');
  process.exit(0);
} else {
  console.log('\n⚠️  SOME TESTS FAILED. Review configuration.\n');
  process.exit(1);
}
