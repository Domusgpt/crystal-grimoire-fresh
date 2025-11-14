/**
 * 🎮 GAMIFIED CRYSTAL GRIMOIRE CLOUD FUNCTIONS
 * Complete integration of credit system, streaks, achievements, and referrals
 * Based on research: PictureThis + Duolingo + Co-Star models
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { config } = require('firebase-functions/v1');
const {
  analyzeCrystalImage,
  normalizeAnalysisResponse,
  DEFAULT_PROMPT,
} = require('./services/geminiCrystalAnalyzer');

const db = getFirestore();

// Import all gamification systems
const {
  getCreditBalance,
  checkCredits,
  deductCredits,
  awardCredits,
  getCreditHistory,
  checkCollectionLimit,
  getCollectionStats,
  getCreditAnalytics,
  CREDIT_CONFIG
} = require('./credit-system');

const {
  getStreak,
  dailyCheckIn,
  awardCheckInCredits,
  getStreakStats,
  resetMonthlyFreezes
} = require('./streak-system');

const {
  checkAchievement,
  checkCollectionMilestones,
  checkIdentificationMilestones,
  getUserAchievements,
  getAchievementProgress
} = require('./achievement-system');

const {
  getReferralCode,
  processReferralSignup,
  processReferralPurchase,
  getReferralStats,
  validateReferralCode
} = require('./referral-system');

const {
  preprocessImage,
  validateImageData,
  getAnalysisStrategy
} = require('./image-preprocessing');

const {
  checkSpendingLimits,
  QueryTracker
} = require('./cost-protection');

// ============================================================================
// DAILY CHECK-IN (Core Engagement Loop)
// ============================================================================

exports.dailyCheckIn = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;

    try {
      console.log(`🌅 Daily check-in for ${userId}`);

      // Get user tier
      const userDoc = await db.collection('users').doc(userId).get();
      const userTier = userDoc.exists ? userDoc.data().subscriptionTier : 'free';

      // Process check-in
      const checkInResult = await dailyCheckIn(userId, userTier);

      // Award credits
      const totalCredits = await awardCheckInCredits(userId, checkInResult);

      // Get updated balance and streak
      const [balance, streak] = await Promise.all([
        getCreditBalance(userId),
        getStreak(userId)
      ]);

      console.log(`✅ Check-in complete: +${totalCredits} credits (streak: ${checkInResult.current})`);

      return {
        success: true,
        streak: checkInResult.current,
        longest: checkInResult.longest,
        creditsEarned: totalCredits,
        newBalance: balance,
        isMilestone: checkInResult.isMilestone,
        badge: checkInResult.badge || null,
        nextMilestone: checkInResult.nextMilestone,
        message: checkInResult.isMilestone
          ? `🎉 ${checkInResult.current}-day streak! You earned ${totalCredits} credits!`
          : `🔥 ${checkInResult.current}-day streak! +${totalCredits} credits`
      };

    } catch (error) {
      console.error('❌ Check-in error:', error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Check-in failed');
    }
  }
);

// ============================================================================
// CRYSTAL IDENTIFICATION (Credit-Based)
// ============================================================================

exports.identifyCrystalGamified = onCall(
  {
    cors: true,
    memory: '512MiB',
    timeoutSeconds: 30,
    maxInstances: 10
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;
    const queryTracker = new QueryTracker(10);

    try {
      const { imageData, imagePath, saveToCollection = true } = request.data;

      console.log(`🔍 [GAMIFIED] Crystal ID request from ${userId}`);

      // Get user data
      queryTracker.track('read', 'users');
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      const userTier = userData.subscriptionTier || 'free';

      // CHECK CREDITS (free tier only)
      if (userTier === 'free') {
        await checkCredits(userId, CREDIT_CONFIG.costs.identification, userTier);
      }

      // Validate image
      const cleanImageData = validateImageData(imageData, userTier);

      // Determine analysis strategy
      const strategy = getAnalysisStrategy(userTier, null);

      // Check spending limits (cost protection)
      const operationType = strategy.type === 'initial' ? 'thumbnailAnalysis' : 'fullImageAnalysis';
      await checkSpendingLimits(userId, operationType, userTier);

      // Preprocess image
      const preprocessed = await preprocessImage(cleanImageData, userTier, strategy.type);

      console.log(`   Processed: ${preprocessed.metadata.processedWidth}x${preprocessed.metadata.processedHeight}`);

      const geminiApiKey = config().gemini?.api_key;
      if (!geminiApiKey) {
        throw new HttpsError('failed-precondition', 'Gemini API key not configured');
      }

      const prompt = `${DEFAULT_PROMPT}\n\nGamified mode: ${strategy.type} analysis for user rewards.`;

      const rawAnalysis = await analyzeCrystalImage({
        apiKey: geminiApiKey,
        imageData: preprocessed.processedImage,
        mimeType: 'image/jpeg',
        model: strategy.model,
        prompt,
      });

      const crystalData = normalizeAnalysisResponse(rawAnalysis);

      // Normalize confidence (0-1 for credit system)
      const confidence = typeof crystalData?.identification?.confidence === 'number'
        ? crystalData.identification.confidence / 100
        : 0;

      console.log(`   Identified: ${crystalData.identification?.name} (${(confidence * 100).toFixed(0)}%)`);

      // DEDUCT CREDITS (free tier only)
      if (userTier === 'free') {
        await deductCredits(userId, CREDIT_CONFIG.costs.identification, 'crystal_identification', {
          crystalName: crystalData.identification?.name,
          confidence
        });
      }

      // CHECK FIRST IDENTIFICATION ACHIEVEMENT
      const identificationsSnapshot = await db.collection('users')
        .doc(userId)
        .collection('identifications')
        .get();

      const isFirstIdentification = identificationsSnapshot.empty;

      // Save identification
      let identificationId = null;
      if (saveToCollection) {
        const identificationRef = await db.collection('users')
          .doc(userId)
          .collection('identifications')
          .add({
            imagePath,
            crystalName: crystalData.identification?.name,
            variety: crystalData.identification?.variety,
            confidence,
            description: crystalData.description,
            metaphysicalProperties: crystalData.metaphysical_properties,
            modelUsed: strategy.model,
            analysisType: strategy.type,
            analysis: crystalData,
            structuredData: crystalData.structured_data,
            reportMarkdown: crystalData.report_markdown,
            colors: crystalData.colors,
            analysisDate: crystalData.analysis_date,
            createdAt: FieldValue.serverTimestamp()
          });

        identificationId = identificationRef.id;
      }

      // AWARD FIRST IDENTIFICATION ACHIEVEMENT
      const achievements = [];
      if (isFirstIdentification) {
        const achievement = await checkAchievement(userId, 'first_identification', {
          crystalName: crystalData.identification?.name
        });
        if (achievement) {
          achievements.push(achievement);
        }
      }

      // CHECK IDENTIFICATION MILESTONES
      const totalIdentifications = identificationsSnapshot.size + 1;
      const milestoneAchievements = await checkIdentificationMilestones(userId, totalIdentifications);
      achievements.push(...milestoneAchievements);

      // Get updated balance
      const newBalance = await getCreditBalance(userId);

      console.log(`   ✅ Complete (balance: ${newBalance} credits, achievements: ${achievements.length})`);

      return {
        ...crystalData,
        _gamification: {
          creditsSpent: userTier === 'free' ? CREDIT_CONFIG.costs.identification : 0,
          newBalance,
          achievements,
          identificationId,
          totalIdentifications
        }
      };

    } catch (error) {
      console.error('❌ Identification error:', error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Identification failed');
    }
  }
);

// ============================================================================
// SAVE TO COLLECTION (Check Limits & Achievements)
// ============================================================================

exports.addToCollection = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;

    try {
      const { crystalData } = request.data;

      console.log(`💎 Adding to collection: ${userId}`);

      // Get user tier
      const userDoc = await db.collection('users').doc(userId).get();
      const userTier = userDoc.exists ? userDoc.data().subscriptionTier : 'free';

      // CHECK COLLECTION LIMIT
      const limitCheck = await checkCollectionLimit(userId, userTier);

      // Add to collection
      const collectionRef = await db.collection('users')
        .doc(userId)
        .collection('crystals')
        .add({
          ...crystalData,
          addedAt: FieldValue.serverTimestamp()
        });

      // CHECK COLLECTION MILESTONES
      const newCount = limitCheck.current + 1;
      const achievements = await checkCollectionMilestones(userId, newCount);

      // Get updated stats
      const collectionStats = await getCollectionStats(userId, userTier);

      console.log(`   ✅ Added (${collectionStats.current}/${collectionStats.maxDisplay})`);

      return {
        success: true,
        crystalId: collectionRef.id,
        collectionStats,
        achievements
      };

    } catch (error) {
      console.error('❌ Add to collection error:', error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Failed to add to collection');
    }
  }
);

// ============================================================================
// GET USER DASHBOARD (All Gamification Data)
// ============================================================================

exports.getUserDashboard = onCall(
  { cors: true, memory: '256MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;

    try {
      console.log(`📊 Dashboard for ${userId}`);

      // Get all gamification data in parallel
      const [
        userDoc,
        creditBalance,
        creditAnalytics,
        streak,
        achievements,
        collectionStats,
        referralStats
      ] = await Promise.all([
        db.collection('users').doc(userId).get(),
        getCreditBalance(userId),
        getCreditAnalytics(userId),
        getStreak(userId),
        getUserAchievements(userId),
        getCollectionStats(userId, 'free'), // Will update with actual tier
        getReferralStats(userId)
      ]);

      const userData = userDoc.exists ? userDoc.data() : {};
      const userTier = userData.subscriptionTier || 'free';

      // Update collection stats with actual tier
      const actualCollectionStats = await getCollectionStats(userId, userTier);

      return {
        user: {
          tier: userTier,
          displayName: userData.displayName || 'Crystal Seeker',
          email: userData.email
        },
        credits: {
          balance: creditBalance,
          analytics: creditAnalytics
        },
        streak: {
          current: streak.current,
          longest: streak.longest,
          canCheckIn: streak.canCheckIn,
          nextMilestone: streak.nextMilestone
        },
        achievements: {
          earned: achievements.earned.length,
          total: achievements.totalAvailable,
          percentage: achievements.completionPercentage,
          recent: achievements.earned.slice(0, 5)
        },
        collection: actualCollectionStats,
        referrals: {
          code: referralStats.referralCode,
          total: referralStats.totalReferrals,
          earned: referralStats.totalEarned
        }
      };

    } catch (error) {
      console.error('❌ Dashboard error:', error);
      throw new HttpsError('internal', 'Failed to load dashboard');
    }
  }
);

// ============================================================================
// REFERRAL OPERATIONS
// ============================================================================

exports.getMyReferralCode = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    try {
      const userId = request.auth.uid;
      const code = await getReferralCode(userId);
      const stats = await getReferralStats(userId);

      return {
        code,
        shareUrl: stats.shareUrl,
        stats: {
          totalReferrals: stats.totalReferrals,
          earned: stats.totalEarned,
          rewards: stats.rewards
        }
      };

    } catch (error) {
      console.error('❌ Get referral code error:', error);
      throw new HttpsError('internal', 'Failed to get referral code');
    }
  }
);

exports.applyReferralCode = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;
    const { referralCode } = request.data;

    try {
      if (!referralCode) {
        throw new HttpsError('invalid-argument', 'Referral code required');
      }

      // Validate code
      const isValid = await validateReferralCode(referralCode);
      if (!isValid) {
        throw new HttpsError('invalid-argument', 'Invalid referral code');
      }

      // Process signup
      const result = await processReferralSignup(userId, referralCode);

      if (!result) {
        throw new HttpsError('already-exists', 'Referral code already used or invalid');
      }

      // Get new balance
      const newBalance = await getCreditBalance(userId);

      return {
        success: true,
        creditsEarned: result.refereeBonus,
        newBalance,
        message: `Welcome! You've earned ${result.refereeBonus} bonus credits!`
      };

    } catch (error) {
      console.error('❌ Apply referral code error:', error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Failed to apply referral code');
    }
  }
);

// ============================================================================
// ACHIEVEMENTS & PROGRESS
// ============================================================================

exports.getMyAchievements = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    try {
      const userId = request.auth.uid;
      const [achievements, progress] = await Promise.all([
        getUserAchievements(userId),
        getAchievementProgress(userId)
      ]);

      return {
        achievements,
        progress
      };

    } catch (error) {
      console.error('❌ Get achievements error:', error);
      throw new HttpsError('internal', 'Failed to get achievements');
    }
  }
);

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

// Reset streak freezes monthly (1st of each month at midnight UTC)
exports.resetStreakFreezes = onSchedule(
  { schedule: '0 0 1 * *', timeZone: 'UTC' },
  async (event) => {
    console.log('🔄 Monthly streak freeze reset starting...');
    const count = await resetMonthlyFreezes();
    console.log(`✅ Reset freezes for ${count} users`);
  }
);

console.log('🎮 GAMIFIED Crystal Grimoire Functions initialized');
console.log('✅ Credit system active');
console.log('✅ Streak system active');
console.log('✅ Achievement system active');
console.log('✅ Referral system active');
