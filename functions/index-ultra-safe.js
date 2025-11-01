/**
 * 🛡️ ULTRA-SAFE Crystal Grimoire Cloud Functions
 * Multi-layer cost protection prevents $500 overnight surges
 *
 * SAFETY FEATURES:
 * - Hard spending limits per user and globally
 * - Rate limiting with multiple time windows
 * - Image preprocessing with grid-based analysis
 * - Progressive enhancement only for paid tiers
 * - Request deduplication
 * - Database query tracking
 * - Circuit breakers
 * - Spending alerts
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { config } = require('firebase-functions/v1');

const db = getFirestore();

// Import protection modules
const {
  checkSpendingLimits,
  checkRateLimit,
  checkDuplicateRequest,
  QueryTracker,
  checkAndSendAlerts,
  OPERATION_COSTS
} = require('./cost-protection');

const {
  preprocessImage,
  validateImageData,
  getAnalysisStrategy,
  shouldTriggerProgressiveAnalysis,
  createThumbnail
} = require('./image-preprocessing');

// ============================================================================
// ULTRA-SAFE CRYSTAL IDENTIFICATION
// Progressive analysis with multi-layer protection
// ============================================================================

exports.identifyCrystalSafe = onCall(
  {
    cors: true,
    memory: '512MiB',
    timeoutSeconds: 30,        // Reduced timeout to prevent long-running costs
    maxInstances: 10          // Limit concurrent executions
  },
  async (request) => {
    // PROTECTION LAYER 1: Authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;
    const queryTracker = new QueryTracker(10); // Max 10 DB queries per request

    try {
      const { imageData, imagePath, forceFullAnalysis } = request.data;

      console.log(`🔍 [SAFE] Crystal ID request from user ${userId}`);

      // PROTECTION LAYER 2: Get user tier (with query tracking)
      queryTracker.track('read', 'users');
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      const userTier = userData.subscriptionTier || 'free';

      console.log(`   User tier: ${userTier}`);

      // PROTECTION LAYER 3: Validate image data
      const cleanImageData = validateImageData(imageData, userTier);

      // PROTECTION LAYER 4: Request deduplication (prevent spam)
      const crypto = require('crypto');
      const requestHash = crypto.createHash('sha256')
        .update(cleanImageData.substring(0, 500))
        .digest('hex')
        .substring(0, 16);

      await checkDuplicateRequest(userId, requestHash, 10); // 10 second window

      // PROTECTION LAYER 5: Rate limiting
      await checkRateLimit(userId, 'identify', userTier);

      // PROTECTION LAYER 6: Determine analysis strategy
      const strategy = getAnalysisStrategy(userTier, null);
      console.log(`   Analysis strategy:`, strategy);

      // If user is forcing full analysis but not authorized, deny
      if (forceFullAnalysis && userTier !== 'pro' && userTier !== 'founders') {
        throw new HttpsError(
          'permission-denied',
          'Full resolution analysis requires Pro subscription'
        );
      }

      const analysisType = forceFullAnalysis ? 'full' : strategy.type;

      // PROTECTION LAYER 7: Spending limits check
      const operationType = analysisType === 'initial' ? 'thumbnailAnalysis' : 'fullImageAnalysis';
      await checkSpendingLimits(userId, operationType, userTier);

      // PROTECTION LAYER 8: Image preprocessing (grid-based for free tier)
      console.log(`   Preprocessing image (${analysisType})...`);
      const preprocessed = await preprocessImage(cleanImageData, userTier, analysisType);

      console.log(`   Preprocessed: ${preprocessed.metadata.processedWidth}x${preprocessed.metadata.processedHeight}`);
      console.log(`   Compression: ${preprocessed.metadata.compressionRatio}%`);
      console.log(`   Cost tier: ${preprocessed.costTier}`);

      // PROTECTION LAYER 9: Check cache (save money!)
      queryTracker.track('read', 'ai_cache');
      const cacheKey = `crystal_${preprocessed.hash}`;
      const cacheDoc = await db.collection('ai_cache').doc(cacheKey).get();

      if (cacheDoc.exists) {
        const cached = cacheDoc.data();
        const ageHours = (Date.now() - cached.timestamp.toMillis()) / (1000 * 60 * 60);

        if (ageHours < 24) {
          console.log(`   💰 CACHE HIT! Saved $${OPERATION_COSTS[operationType]}`);

          // Update cache hit counter
          queryTracker.track('write', 'ai_cache');
          await cacheDoc.ref.update({
            hits: FieldValue.increment(1),
            lastHit: Timestamp.now()
          });

          // Still save to user's collection
          queryTracker.track('write', 'identifications');
          await saveIdentification(userId, cached.response, preprocessed, strategy, queryTracker);

          return cached.response;
        }
      }

      // PROTECTION LAYER 10: Call Gemini with safety limits
      const { GoogleGenerativeAI } = require('@google/generative-ai');
      const genAI = new GoogleGenerativeAI(config().gemini.api_key);

      const model = genAI.getGenerativeModel({
        model: strategy.model,
        generationConfig: {
          maxOutputTokens: strategy.maxTokens,
          temperature: 0.4,
          topP: 1,
          topK: 32,
          candidateCount: 1  // Only one response to save costs
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' }
        ]
      });

      // Compressed prompt for cost savings
      const prompt = `Analyze crystal. JSON only:\n{"identification":{"name":"string","variety":"string","confidence":0-100},"description":"string (max 150 chars)","metaphysical_properties":{"healing_properties":["string"],"primary_chakras":["string"],"energy_type":"grounding|energizing|calming","element":"earth|air|fire|water"},"care_instructions":{"cleansing":["method"],"charging":["method"]}}`;

      console.log(`   🤖 Calling Gemini (${strategy.model})...`);
      const startTime = Date.now();

      const result = await model.generateContent([
        prompt,
        {
          inlineData: {
            mimeType: 'image/jpeg',
            data: preprocessed.processedImage
          }
        }
      ]);

      const aiLatency = Date.now() - startTime;
      console.log(`   ✅ Gemini response in ${aiLatency}ms`);

      const responseText = result.response.text();
      const cleanJson = responseText.replace(/```json\n?|\n?```/g, '').trim();
      let crystalData;

      try {
        crystalData = JSON.parse(cleanJson);
      } catch (parseError) {
        console.error('JSON parse error:', parseError);
        throw new HttpsError('internal', 'AI response parsing failed');
      }

      // Normalize confidence
      const confidenceRaw = crystalData?.identification?.confidence;
      let confidence = 0;
      if (typeof confidenceRaw === 'number') {
        confidence = confidenceRaw > 1 ? confidenceRaw / 100 : confidenceRaw;
      }

      console.log(`   Identified: ${crystalData.identification?.name} (${(confidence * 100).toFixed(0)}% confidence)`);

      // PROGRESSIVE ENHANCEMENT: Check if we need higher quality analysis
      let progressiveData = null;
      if (shouldTriggerProgressiveAnalysis(confidence, userTier) && !forceFullAnalysis) {
        console.log(`   ⚠️  Low confidence (${(confidence * 100).toFixed(0)}%) - checking progressive analysis...`);

        const progressiveStrategy = getAnalysisStrategy(userTier, confidence);

        if (progressiveStrategy) {
          console.log(`   🔍 Triggering progressive analysis...`);

          // Check spending limits for progressive analysis
          await checkSpendingLimits(userId, 'progressiveAnalysis', userTier);

          // Preprocess with larger grid
          const progressivePreprocessed = await preprocessImage(
            cleanImageData,
            userTier,
            'progressive'
          );

          // Call Gemini again with better image
          const progressiveModel = genAI.getGenerativeModel({
            model: progressiveStrategy.model,
            generationConfig: {
              maxOutputTokens: progressiveStrategy.maxTokens,
              temperature: 0.4
            }
          });

          const progressiveResult = await progressiveModel.generateContent([
            prompt,
            {
              inlineData: {
                mimeType: 'image/jpeg',
                data: progressivePreprocessed.processedImage
              }
            }
          ]);

          const progressiveText = progressiveResult.response.text();
          const progressiveJson = progressiveText.replace(/```json\n?|\n?```/g, '').trim();
          progressiveData = JSON.parse(progressiveJson);

          const newConfidence = typeof progressiveData?.identification?.confidence === 'number'
            ? (progressiveData.identification.confidence > 1
                ? progressiveData.identification.confidence / 100
                : progressiveData.identification.confidence)
            : confidence;

          console.log(`   ✅ Progressive analysis: ${progressiveData.identification?.name} (${(newConfidence * 100).toFixed(0)}%)`);

          // Use progressive result if better
          if (newConfidence > confidence) {
            crystalData = progressiveData;
            confidence = newConfidence;
          }
        } else {
          console.log(`   ℹ️  Progressive analysis not available for ${userTier} tier`);
        }
      }

      // Create thumbnail for storage
      const thumbnail = await createThumbnail(cleanImageData, 128);

      // Save identification with query tracking
      const savedId = await saveIdentification(
        userId,
        crystalData,
        preprocessed,
        strategy,
        queryTracker,
        {
          confidence,
          thumbnail,
          imagePath,
          aiLatency,
          progressiveAnalysis: !!progressiveData
        }
      );

      // Cache the result
      queryTracker.track('write', 'ai_cache');
      await db.collection('ai_cache').doc(cacheKey).set({
        response: crystalData,
        timestamp: Timestamp.now(),
        hits: 0,
        userTier,
        strategy: strategy.type
      });

      // Send usage alerts if needed
      await checkAndSendAlerts(userId, userTier);

      console.log(`   💾 Saved as ${savedId}`);
      console.log(`   📊 Query stats:`, queryTracker.getStats());
      console.log(`   ✅ Request complete`);

      return {
        ...crystalData,
        _metadata: {
          confidence: confidence,
          analysisType: strategy.type,
          gridSize: preprocessed.metadata.gridSize,
          progressiveAnalysisTriggered: !!progressiveData,
          estimatedCost: strategy.estimatedCost,
          userTier,
          identificationId: savedId
        }
      };

    } catch (error) {
      console.error('❌ Crystal identification error:', error);

      if (error instanceof HttpsError) {
        throw error;
      }

      // Don't expose internal errors
      throw new HttpsError('internal', 'Identification failed. Please try again.');
    }
  }
);

// ============================================================================
// ULTRA-SAFE CRYSTAL GUIDANCE (Text-only, much cheaper)
// ============================================================================

exports.getCrystalGuidanceSafe = onCall(
  {
    cors: true,
    memory: '128MiB',
    timeoutSeconds: 20,
    maxInstances: 20
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;
    const queryTracker = new QueryTracker(5);

    try {
      const { question, intentions, experience } = request.data;

      if (!question || question.trim().length < 5) {
        throw new HttpsError('invalid-argument', 'Question must be at least 5 characters');
      }

      if (question.length > 500) {
        throw new HttpsError('invalid-argument', 'Question too long (max 500 characters)');
      }

      console.log(`💭 [SAFE] Guidance request from ${userId}`);

      // Get user tier
      queryTracker.track('read', 'users');
      const userDoc = await db.collection('users').doc(userId).get();
      const userTier = userDoc.exists ? userDoc.data().subscriptionTier : 'free';

      // Rate limiting
      await checkRateLimit(userId, 'guidance', userTier);

      // Spending limits
      const operationType = userTier === 'pro' || userTier === 'founders'
        ? 'guidancePro'
        : 'guidanceFlash';
      await checkSpendingLimits(userId, operationType, userTier);

      // Check cache
      const crypto = require('crypto');
      const cacheKey = `guidance_${crypto.createHash('sha256').update(question.toLowerCase().trim()).digest('hex').substring(0, 16)}`;

      queryTracker.track('read', 'ai_cache');
      const cacheDoc = await db.collection('ai_cache').doc(cacheKey).get();

      if (cacheDoc.exists) {
        const cached = cacheDoc.data();
        const ageHours = (Date.now() - cached.timestamp.toMillis()) / (1000 * 60 * 60);

        if (ageHours < 12) {
          console.log(`   💰 CACHE HIT!`);

          queryTracker.track('write', 'ai_cache');
          await cacheDoc.ref.update({ hits: FieldValue.increment(1) });

          return cached.response;
        }
      }

      // Call Gemini
      const { GoogleGenerativeAI } = require('@google/generative-ai');
      const genAI = new GoogleGenerativeAI(config().gemini.api_key);

      const model = genAI.getGenerativeModel({
        model: 'gemini-1.5-flash',  // Always use Flash for text-only
        generationConfig: {
          maxOutputTokens: 800,
          temperature: 0.7
        }
      });

      const prompt = `Crystal advisor. Q: "${question}"\nExp: ${experience || 'beginner'}\nIntent: ${intentions?.join(', ') || 'wellness'}\n\nJSON:\n{"recommended_crystals":[{"name":"string","reason":"string (max 100 chars)","how_to_use":"string (max 80 chars)"}],"guidance":"string (max 250 chars)","affirmation":"string (max 80 chars)","meditation_tip":"string (max 120 chars)"}`;

      const result = await model.generateContent([prompt]);
      const responseText = result.response.text();
      const cleanJson = responseText.replace(/```json\n?|\n?```/g, '').trim();
      const guidanceData = JSON.parse(cleanJson);

      // Save session
      queryTracker.track('write', 'guidance_sessions');
      await db.collection('guidance_sessions').add({
        question,
        intentions,
        experience,
        guidance: guidanceData,
        userId,
        timestamp: Timestamp.now(),
        modelUsed: 'gemini-1.5-flash'
      });

      // Cache result
      queryTracker.track('write', 'ai_cache');
      await db.collection('ai_cache').doc(cacheKey).set({
        response: guidanceData,
        timestamp: Timestamp.now(),
        hits: 0
      });

      console.log(`   ✅ Guidance provided`);
      console.log(`   📊 Queries:`, queryTracker.getStats());

      return guidanceData;

    } catch (error) {
      console.error('❌ Guidance error:', error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Guidance failed');
    }
  }
);

// ============================================================================
// HELPER: Save identification with query tracking
// ============================================================================

async function saveIdentification(userId, crystalData, preprocessed, strategy, queryTracker, additionalData = {}) {
  const candidateEntry = {
    name: crystalData?.identification?.name || 'Unknown',
    confidence: additionalData.confidence || 0,
    rationale: typeof crystalData?.description === 'string'
      ? crystalData.description.substring(0, 200)
      : '',
    variety: crystalData?.identification?.variety || null
  };

  const identificationDocument = {
    imagePath: additionalData.imagePath || null,
    thumbnail: additionalData.thumbnail || null,
    candidates: [candidateEntry],
    selected: candidateEntry,
    modelUsed: strategy.model,
    analysisType: strategy.type,
    gridSize: preprocessed.metadata.gridSize,
    imageMetadata: {
      originalSize: preprocessed.metadata.originalSize,
      processedSize: preprocessed.metadata.processedSize,
      compressionRatio: preprocessed.metadata.compressionRatio
    },
    estimatedCost: strategy.estimatedCost,
    aiLatency: additionalData.aiLatency || null,
    progressiveAnalysis: additionalData.progressiveAnalysis || false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  };

  queryTracker.track('write', 'identifications');
  const docRef = await db
    .collection('users')
    .doc(userId)
    .collection('identifications')
    .add(identificationDocument);

  return docRef.id;
}

// ============================================================================
// USAGE STATISTICS (Free endpoint, no AI costs)
// ============================================================================

exports.getUsageStatsSafe = onCall(
  { cors: true, memory: '128MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = request.auth.uid;
    const queryTracker = new QueryTracker(5);

    try {
      const now = new Date();
      const hourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      // Get user tier
      queryTracker.track('read', 'users');
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      const userTier = userData.subscriptionTier || 'free';

      // Get spending data
      queryTracker.track('read', 'user_spending');
      const spendingDoc = await db.collection('user_spending').doc(userId).get();
      const spending = spendingDoc.exists ? spendingDoc.data() : {
        hourly: 0,
        daily: 0,
        monthly: 0
      };

      // Get rate limit data
      queryTracker.track('read', 'rate_limits');
      const rateLimitDoc = await db.collection('rate_limits').doc(userId).get();
      const rateLimit = rateLimitDoc.exists ? rateLimitDoc.data() : {
        identifyHourly: 0,
        identifyDaily: 0,
        guidanceHourly: 0,
        guidanceDaily: 0
      };

      const { SPENDING_LIMITS, RATE_LIMITS } = require('./cost-protection');
      const spendingLimits = SPENDING_LIMITS.perUser[userTier] || SPENDING_LIMITS.perUser.free;
      const rateLimits = RATE_LIMITS[userTier] || RATE_LIMITS.free;

      return {
        tier: userTier,
        spending: {
          hourly: spending.hourly || 0,
          daily: spending.daily || 0,
          monthly: spending.monthly || 0,
          limits: spendingLimits
        },
        usage: {
          identify: {
            hourly: rateLimit.identifyHourly || 0,
            daily: rateLimit.identifyDaily || 0,
            limits: {
              hourly: rateLimits.identifyPerHour,
              daily: rateLimits.identifyPerDay
            }
          },
          guidance: {
            hourly: rateLimit.guidanceHourly || 0,
            daily: rateLimit.guidanceDaily || 0,
            limits: {
              hourly: rateLimits.guidancePerHour,
              daily: rateLimits.guidancePerDay
            }
          }
        },
        remaining: {
          identifyHourly: Math.max(0, rateLimits.identifyPerHour - (rateLimit.identifyHourly || 0)),
          identifyDaily: Math.max(0, rateLimits.identifyPerDay - (rateLimit.identifyDaily || 0)),
          guidanceHourly: Math.max(0, rateLimits.guidancePerHour - (rateLimit.guidanceHourly || 0)),
          guidanceDaily: Math.max(0, rateLimits.guidancePerDay - (rateLimit.guidanceDaily || 0))
        }
      };

    } catch (error) {
      console.error('Usage stats error:', error);
      throw new HttpsError('internal', 'Failed to get usage stats');
    }
  }
);

console.log('🛡️ ULTRA-SAFE Crystal Grimoire Functions initialized');
console.log('✅ Multi-layer cost protection active');
console.log('✅ Grid-based image analysis enabled');
console.log('✅ Progressive enhancement for paid tiers');
console.log('✅ Hard spending limits enforced');
console.log('💰 Expected free tier cost: $0.001-0.002 per identification');
