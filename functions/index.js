/**
 * 🔮 Crystal Grimoire Cloud Functions - Complete Backend System
 * Authentication, user management, and crystal identification with Gemini AI
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { config } = require('firebase-functions/v1');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const auth = getAuth();

// Stripe configuration (optional)
const stripeConfig = config().stripe || {};
let stripeClient = null;
try {
  if (stripeConfig.secret_key) {
    stripeClient = require('stripe')(stripeConfig.secret_key);
  }
} catch (error) {
  console.error('⚠️ Unable to initialise Stripe client:', error.message);
}

const stripePriceMapping = new Map();
if (stripeConfig.premium_price_id) {
  stripePriceMapping.set(stripeConfig.premium_price_id, { tier: 'premium', mode: 'subscription' });
}
if (stripeConfig.pro_price_id) {
  stripePriceMapping.set(stripeConfig.pro_price_id, { tier: 'pro', mode: 'subscription' });
}
if (stripeConfig.founders_price_id) {
  stripePriceMapping.set(stripeConfig.founders_price_id, { tier: 'founders', mode: 'payment' });
}

const PLAN_DETAILS = {
  free: {
    plan: 'free',
    effectiveLimits: {
      identifyPerDay: 3,
      guidancePerDay: 1,
      journalMax: 50,
      collectionMax: 50,
    },
    flags: ['free'],
    lifetime: false,
  },
  premium: {
    plan: 'premium',
    effectiveLimits: {
      identifyPerDay: 15,
      guidancePerDay: 5,
      journalMax: 200,
      collectionMax: 250,
    },
    flags: ['stripe', 'priority_support'],
    lifetime: false,
  },
  pro: {
    plan: 'pro',
    effectiveLimits: {
      identifyPerDay: 40,
      guidancePerDay: 15,
      journalMax: 500,
      collectionMax: 1000,
    },
    flags: ['stripe', 'priority_support', 'advanced_ai'],
    lifetime: false,
  },
  founders: {
    plan: 'founders',
    effectiveLimits: {
      identifyPerDay: 999,
      guidancePerDay: 200,
      journalMax: 2000,
      collectionMax: 2000,
    },
    flags: ['stripe', 'lifetime', 'founder'],
    lifetime: true,
  },
};

const PLAN_ALIASES = {
  explorer: 'free',
  emissary: 'premium',
  ascended: 'pro',
  esper: 'founders',
};

function resolvePlanDetails(tier) {
  const normalized = (tier || 'free').toString().trim().toLowerCase();
  const key = PLAN_DETAILS[normalized] ? normalized : PLAN_ALIASES[normalized] || 'free';
  const details = PLAN_DETAILS[key] || PLAN_DETAILS.free;
  return {
    plan: details.plan,
    effectiveLimits: { ...details.effectiveLimits },
    flags: [...details.flags],
    lifetime: details.lifetime,
    tier: key,
  };
}

function ensureStripeConfigured() {
  if (!stripeClient) {
    throw new HttpsError('failed-precondition', 'Stripe is not configured. Set stripe.secret_key and price IDs.');
  }
}

async function deleteCollectionDeep(collectionRef) {
  const snapshot = await collectionRef.get();
  if (snapshot.empty) {
    return;
  }

  for (const doc of snapshot.docs) {
    const nestedCollections = await doc.ref.listCollections();
    for (const nested of nestedCollections) {
      await deleteCollectionDeep(nested);
    }
  }

  let batch = db.batch();
  let writes = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    writes += 1;

    if (writes >= 400) {
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }
  }

  if (writes > 0) {
    await batch.commit();
  }
}

async function deleteQueryBatch(query) {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return;
  }

  let batch = db.batch();
  let writes = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    writes += 1;

    if (writes >= 400) {
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }
  }

  if (writes > 0) {
    await batch.commit();
  }
}

function resolvePriceMetadata(priceId, requestedTier) {
  if (priceId && stripePriceMapping.has(priceId)) {
    return stripePriceMapping.get(priceId);
  }

  if (requestedTier) {
    const normalized = String(requestedTier).toLowerCase();
    if (['premium', 'pro', 'founders'].includes(normalized)) {
      return {
        tier: normalized,
        mode: normalized === 'founders' ? 'payment' : 'subscription',
      };
    }
  }

  return null;
}

// Health check endpoint - no auth required for system monitoring
exports.healthCheck = onCall({ cors: true, invoker: 'public' }, async (request) => {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
    services: {
      firestore: 'connected',
      gemini: !!config().gemini?.api_key,
      auth: 'enabled'
    },
  };
});

exports.createStripeCheckoutSession = onCall(
  { cors: true, region: 'us-central1', enforceAppCheck: true },
  async (request) => {
    ensureStripeConfigured();

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required to start checkout.');
    }

    const priceId = request.data?.priceId;
    const requestedTier = request.data?.tier;
    const successUrlInput = request.data?.successUrl;
    const cancelUrlInput = request.data?.cancelUrl;

    if (!priceId || typeof priceId !== 'string') {
      throw new HttpsError('invalid-argument', 'priceId is required.');
    }

    if (!successUrlInput || typeof successUrlInput !== 'string') {
      throw new HttpsError('invalid-argument', 'successUrl is required.');
    }

    if (!cancelUrlInput || typeof cancelUrlInput !== 'string') {
      throw new HttpsError('invalid-argument', 'cancelUrl is required.');
    }

    const priceMeta = resolvePriceMetadata(priceId, requestedTier);
    if (!priceMeta) {
      throw new HttpsError('invalid-argument', 'Unsupported price identifier.');
    }

    const successUrl = successUrlInput.includes('{CHECKOUT_SESSION_ID}')
      ? successUrlInput
      : `${successUrlInput}${successUrlInput.includes('?') ? '&' : '?'}session_id={CHECKOUT_SESSION_ID}`;

    const cancelUrl = cancelUrlInput.includes('cancelled=')
      ? cancelUrlInput
      : `${cancelUrlInput}${cancelUrlInput.includes('?') ? '&' : '?'}cancelled=true`;

    try {
      const session = await stripeClient.checkout.sessions.create({
        mode: priceMeta.mode,
        client_reference_id: request.auth.uid,
        success_url: successUrl,
        cancel_url: cancelUrl,
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        metadata: {
          uid: request.auth.uid,
          tier: priceMeta.tier,
          priceId,
        },
        subscription_data: priceMeta.mode === 'subscription'
          ? {
              metadata: {
                uid: request.auth.uid,
                tier: priceMeta.tier,
              },
            }
          : undefined,
      });

      await db.collection('checkoutSessions').doc(session.id).set({
        uid: request.auth.uid,
        tier: priceMeta.tier,
        priceId,
        mode: priceMeta.mode,
        status: session.status,
        createdAt: FieldValue.serverTimestamp(),
        successUrl,
        cancelUrl,
      }, { merge: true });

      return {
        sessionId: session.id,
        checkoutUrl: session.url,
        expiresAt: session.expires_at ? new Date(session.expires_at * 1000).toISOString() : null,
      };
    } catch (error) {
      console.error('❌ Stripe checkout error:', error);
      throw new HttpsError('internal', error.message || 'Failed to start checkout session.');
    }
  }
);

exports.finalizeStripeCheckoutSession = onCall(
  { cors: true, region: 'us-central1', enforceAppCheck: true },
  async (request) => {
    ensureStripeConfigured();

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required to verify checkout.');
    }

    const sessionId = request.data?.sessionId;
    if (!sessionId || typeof sessionId !== 'string') {
      throw new HttpsError('invalid-argument', 'sessionId is required.');
    }

    const checkoutRef = db.collection('checkoutSessions').doc(sessionId);
    const checkoutSnap = await checkoutRef.get();

    if (checkoutSnap.exists) {
      const checkoutData = checkoutSnap.data();
      if (checkoutData.uid && checkoutData.uid !== request.auth.uid) {
        throw new HttpsError('permission-denied', 'Checkout session does not belong to this user.');
      }
    }

    try {
      const session = await stripeClient.checkout.sessions.retrieve(sessionId, {
        expand: ['line_items', 'subscription'],
      });

      if (!session) {
        throw new HttpsError('not-found', 'Checkout session not found.');
      }

      if (session.client_reference_id && session.client_reference_id !== request.auth.uid) {
        throw new HttpsError('permission-denied', 'Checkout session does not belong to this user.');
      }

      if (session.payment_status !== 'paid') {
        await checkoutRef.set({
          status: session.status,
          paymentStatus: session.payment_status,
          lastCheckedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        throw new HttpsError('failed-precondition', 'Payment is not complete yet.');
      }

      const lineItems = session.line_items && session.line_items.data ? session.line_items.data : [];
      const firstPrice = lineItems.length > 0 && lineItems[0].price ? lineItems[0].price.id : null;
      const metadata = resolvePriceMetadata(firstPrice, checkoutSnap.data()?.tier);

      if (!metadata) {
        throw new HttpsError('failed-precondition', 'Unable to determine plan for this checkout.');
      }

      let expiresAt = null;
      let willRenew = false;
      if (session.mode === 'subscription' && session.subscription) {
        const subscription = session.subscription;
        if (subscription.current_period_end) {
          expiresAt = new Date(subscription.current_period_end * 1000).toISOString();
        }
        willRenew = subscription.cancel_at_period_end === false;
      }

      const planDetails = resolvePlanDetails(metadata.tier);

      let expiresAtTimestamp = null;
      if (expiresAt) {
        const parsed = new Date(expiresAt);
        if (!Number.isNaN(parsed.getTime())) {
          expiresAtTimestamp = Timestamp.fromDate(parsed);
        }
      }

      await db.collection('users').doc(request.auth.uid).set({
        profile: {
          subscriptionTier: planDetails.plan,
          subscriptionStatus: 'active',
          subscriptionProvider: 'stripe',
          subscriptionWillRenew: willRenew,
          subscriptionExpiresAt: expiresAtTimestamp,
          subscriptionBillingTier: metadata.tier,
          subscriptionUpdatedAt: FieldValue.serverTimestamp(),
          effectiveLimits: planDetails.effectiveLimits,
        }
      }, { merge: true });

      const planDocument = {
        plan: planDetails.plan,
        billingTier: metadata.tier,
        provider: 'stripe',
        priceId: firstPrice,
        effectiveLimits: planDetails.effectiveLimits,
        flags: planDetails.flags,
        willRenew,
        lifetime: planDetails.lifetime,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (expiresAtTimestamp) {
        planDocument.expiresAt = expiresAtTimestamp;
      } else if (planDetails.lifetime) {
        planDocument.expiresAt = null;
      }

      await db.collection('users').doc(request.auth.uid)
        .collection('plan')
        .doc('active')
        .set(planDocument, { merge: true });

      await checkoutRef.set({
        status: 'completed',
        paymentStatus: session.payment_status,
        completedAt: FieldValue.serverTimestamp(),
        tier: metadata.tier,
        priceId: firstPrice,
      }, { merge: true });

      return {
        tier: metadata.tier,
        isActive: true,
        willRenew,
        expiresAt,
        sessionStatus: session.status,
        plan: planDetails.plan,
      };
    } catch (error) {
      console.error('❌ Stripe finalize error:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', error.message || 'Failed to verify checkout session.');
    }
  }
);

// Crystal identification function - requires authentication
exports.identifyCrystal = onCall(
  { cors: true, memory: '1GiB', timeoutSeconds: 60 },
  async (request) => {
    // Check authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to identify crystals');
    }

    // Use Google AI SDK with Firebase config
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(config().gemini.api_key);
    
    try {
      const { imageData } = request.data;
      const userId = request.auth.uid;
      
      if (!imageData) {
        throw new HttpsError('invalid-argument', 'Image data required');
      }

      console.log(`🔍 Starting crystal identification for user: ${userId}...`);
      
      const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-pro',
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.4,
          topP: 1,
          topK: 32
        }
      });
      
      const geminiPrompt = `
        You are a crystal identification expert. Analyze this crystal image and provide a comprehensive JSON response with the following structure:
        {
          "identification": {
            "name": "Crystal Name",
            "variety": "Specific variety if applicable",
            "confidence": 85
          },
          "description": "Detailed description of the crystal's appearance and formation",
          "metaphysical_properties": {
            "healing_properties": ["property1", "property2"],
            "primary_chakras": ["chakra1", "chakra2"],
            "energy_type": "grounding/energizing/calming",
            "planet_association": "planet name",
            "element": "earth/air/fire/water"
          },
          "care_instructions": {
            "cleansing": ["method1", "method2"],
            "charging": ["method1", "method2"],
            "storage": "storage instructions"
          }
        }
        
        Important: Return ONLY the JSON object, no additional text.
      `;

      const result = await model.generateContent([
        geminiPrompt,
        {
          inlineData: {
            mimeType: 'image/jpeg',
            data: imageData
          }
        }
      ]);

      const responseText = result.response.text();
      console.log('🤖 Gemini raw response:', responseText.substring(0, 200) + '...');

      // Parse JSON response
      const cleanJson = responseText.replace(/```json\n?|\n?```/g, '').trim();
      const crystalData = JSON.parse(cleanJson);

      const confidenceRaw = crystalData?.identification?.confidence;
      let confidence = 0;
      if (typeof confidenceRaw === 'number') {
        confidence = confidenceRaw > 1 ? confidenceRaw / 100 : confidenceRaw;
      } else if (typeof confidenceRaw === 'string') {
        const parsed = parseFloat(confidenceRaw);
        if (!Number.isNaN(parsed)) {
          confidence = parsed > 1 ? parsed / 100 : parsed;
        }
      }

      const candidateEntry = {
        name: crystalData?.identification?.name || 'Unknown',
        confidence,
        rationale: typeof crystalData?.description === 'string' ? crystalData.description : '',
        variety: crystalData?.identification?.variety || null,
      };

      const imagePath = (typeof request.data?.imagePath === 'string' && request.data.imagePath.trim().length)
        ? request.data.imagePath.trim()
        : null;

      const identificationDocument = {
        imagePath,
        candidates: [candidateEntry],
        selected: {
          name: candidateEntry.name,
          confidence: candidateEntry.confidence,
          rationale: candidateEntry.rationale,
          variety: candidateEntry.variety,
        },
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      const identificationRef = await db
        .collection('users')
        .doc(userId)
        .collection('identifications')
        .add(identificationDocument);

      console.log(`💾 Crystal identification saved for user ${userId} as ${identificationRef.id}`);

      await migrateLegacyIdentifications(userId);

      console.log('✅ Crystal identified:', crystalData.identification?.name || 'Unknown');
      
      return crystalData;

    } catch (error) {
      console.error('❌ Crystal identification error:', error);
      throw new HttpsError('internal', `Identification failed: ${error.message}`);
    }
  }
);

async function migrateLegacyIdentifications(uid) {
  try {
    const legacySnapshot = await db
      .collection('identifications')
      .where('userId', '==', uid)
      .limit(10)
      .get();

    if (legacySnapshot.empty) {
      return;
    }

    const batch = db.batch();
    let migratedCount = 0;

    legacySnapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      if (data.migrated === true) {
        return;
      }

      const legacyConfidence = typeof data?.identification?.confidence === 'number'
        ? data.identification.confidence
        : parseFloat(data?.identification?.confidence || 0);
      const normalizedConfidence = Number.isFinite(legacyConfidence)
        ? (legacyConfidence > 1 ? legacyConfidence / 100 : legacyConfidence)
        : 0;

      const candidate = {
        name: data?.identification?.name || data?.name || 'Unknown',
        confidence: normalizedConfidence,
        rationale: typeof data?.description === 'string' ? data.description : '',
        variety: data?.identification?.variety || null,
      };

      let createdAt = null;
      if (data.createdAt instanceof Timestamp) {
        createdAt = data.createdAt;
      } else if (data.timestamp instanceof Timestamp) {
        createdAt = data.timestamp;
      } else if (typeof data.timestamp === 'string' || data.createdAt) {
        const raw = data.createdAt || data.timestamp;
        const parsed = new Date(raw);
        if (!Number.isNaN(parsed.getTime())) {
          createdAt = Timestamp.fromDate(parsed);
        }
      }

      const targetRef = db
        .collection('users')
        .doc(uid)
        .collection('identifications')
        .doc(doc.id);

      batch.set(targetRef, {
        imagePath: data.imagePath || null,
        candidates: [candidate],
        selected: candidate,
        createdAt: createdAt || FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      batch.update(doc.ref, {
        migrated: true,
        migratedAt: FieldValue.serverTimestamp(),
      });

      migratedCount += 1;
    });

    if (migratedCount > 0) {
      await batch.commit();
      console.log(`🔄 Migrated ${migratedCount} legacy identification(s) for ${uid}`);
    }
  } catch (migrationError) {
    console.error('⚠️ Legacy identification migration failed:', migrationError);
  }
}

// Crystal guidance function - text-only Gemini queries, requires authentication
exports.getCrystalGuidance = onCall(
  { cors: true, memory: '256MiB', timeoutSeconds: 30 },
  async (request) => {
    // Check authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to receive crystal guidance');
    }

    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(config().gemini.api_key);
    
    try {
      const { question, intentions, experience } = request.data;
      const userId = request.auth.uid;
      
      if (!question) {
        throw new HttpsError('invalid-argument', 'Question is required');
      }

      console.log(`🔍 Starting crystal guidance for user: ${userId}...`);
      
      const model = genAI.getGenerativeModel({ 
        model: 'gemini-1.5-pro',
        generationConfig: {
          maxOutputTokens: 1024,
          temperature: 0.7,
          topP: 1,
          topK: 32
        }
      });
      
      const guidancePrompt = `
        You are a wise crystal healing advisor. A user is asking: "${question}"
        
        Their experience level: ${experience || 'beginner'}
        Their intentions: ${intentions ? intentions.join(', ') : 'general wellness'}
        
        Provide a comprehensive JSON response with the following structure:
        {
          "recommended_crystals": [
            {
              "name": "Crystal Name",
              "reason": "Why this crystal is perfect for their needs",
              "how_to_use": "Specific instructions for using this crystal"
            }
          ],
          "guidance": "Detailed spiritual guidance and advice",
          "affirmation": "A personal affirmation they can use",
          "meditation_tip": "A simple meditation practice with their chosen crystals"
        }
        
        Important: Return ONLY the JSON object, no additional text.
      `;

      const result = await model.generateContent([guidancePrompt]);
      const responseText = result.response.text();
      console.log('🤖 Gemini guidance response:', responseText.substring(0, 200) + '...');

      // Parse JSON response
      const cleanJson = responseText.replace(/```json\n?|\n?```/g, '').trim();
      const guidanceData = JSON.parse(cleanJson);

      // Save guidance session to user's collection
      const guidanceRecord = {
        question,
        intentions,
        experience,
        guidance: guidanceData,
        userId: userId,
        timestamp: new Date().toISOString(),
      };

      await db.collection('guidance_sessions').add(guidanceRecord);
      console.log('💾 Guidance session saved to user collection');

      console.log('✅ Crystal guidance provided');
      
      return guidanceData;

    } catch (error) {
      console.error('❌ Crystal guidance error:', error);
      throw new HttpsError('internal', `Guidance failed: ${error.message}`);
    }
  }
);

exports.initializeUserProfile = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in to initialize the profile.');
    }

    try {
      const uid = request.auth.uid;
      const userRecord = await auth.getUser(uid);
      const userRef = db.collection('users').doc(uid);

      const [snapshot, planSnapshot, economySnapshot] = await Promise.all([
        userRef.get(),
        userRef.collection('plan').doc('active').get(),
        userRef.collection('economy').doc('credits').get(),
      ]);

      const existingData = snapshot.exists ? snapshot.data() || {} : {};
      const existingProfile = typeof existingData.profile === 'object' ? existingData.profile || {} : {};
      const existingSettings = typeof existingData.settings === 'object' ? existingData.settings || {} : {};

      const planDetails = resolvePlanDetails(existingProfile.subscriptionTier || existingData.plan?.plan);

      const now = FieldValue.serverTimestamp();

      const defaultSettings = {
        notifications: true,
        sound: true,
        vibration: true,
        darkMode: true,
        meditationReminder: 'Daily',
        crystalReminder: 'Weekly',
        shareUsageData: true,
        contentWarnings: true,
        language: 'en',
      };

      const mergedSettings = { ...defaultSettings, ...existingSettings };

      const existingConsent = typeof existingProfile.consent === 'object' ? existingProfile.consent || {} : {};
      const consent = {
        imagesToAI: existingConsent.imagesToAI === true,
        birthDataToAstro: existingConsent.birthDataToAstro === true,
      };

      const existingStats = typeof existingProfile.stats === 'object' ? existingProfile.stats || {} : {};
      const stats = {
        crystalsIdentified: existingStats.crystalsIdentified ?? 0,
        guidanceSessions: existingStats.guidanceSessions ?? 0,
        journalEntries: existingStats.journalEntries ?? 0,
      };

      const profilePayload = {
        uid,
        displayName: userRecord.displayName || existingProfile.displayName || 'Crystal Seeker',
        photoUrl: userRecord.photoURL || existingProfile.photoUrl || null,
        subscriptionTier: existingProfile.subscriptionTier || planDetails.plan,
        subscriptionStatus: existingProfile.subscriptionStatus || 'active',
        subscriptionProvider: existingProfile.subscriptionProvider || 'bootstrap',
        subscriptionBillingTier: existingProfile.subscriptionBillingTier || planDetails.plan,
        subscriptionWillRenew: existingProfile.subscriptionWillRenew ?? !planDetails.lifetime,
        effectiveLimits: existingProfile.effectiveLimits || planDetails.effectiveLimits,
        consent,
        stats,
        lastLoginAt: now,
      };

      if (existingProfile.createdAt) {
        profilePayload.createdAt = existingProfile.createdAt;
      } else {
        profilePayload.createdAt = now;
      }

      if (existingProfile.subscriptionExpiresAt) {
        profilePayload.subscriptionExpiresAt = existingProfile.subscriptionExpiresAt;
      }

      const payload = {
        email: userRecord.email || existingData.email || '',
        profile: profilePayload,
        settings: mergedSettings,
        updatedAt: now,
      };

      if (existingData.createdAt) {
        payload.createdAt = existingData.createdAt;
      } else {
        payload.createdAt = now;
      }

      await userRef.set(payload, { merge: true });

      const planRef = userRef.collection('plan').doc('active');
      const existingPlan = planSnapshot.exists ? planSnapshot.data() || {} : {};
      const planPayload = {
        plan: existingPlan.plan || planDetails.plan,
        effectiveLimits: existingPlan.effectiveLimits || planDetails.effectiveLimits,
        flags: existingPlan.flags || planDetails.flags,
        provider: existingPlan.provider || existingProfile.subscriptionProvider || 'bootstrap',
        willRenew: existingPlan.willRenew ?? (profilePayload.subscriptionWillRenew ?? !planDetails.lifetime),
        lifetime: existingPlan.lifetime ?? planDetails.lifetime,
        updatedAt: now,
      };

      if (existingPlan.createdAt) {
        planPayload.createdAt = existingPlan.createdAt;
      } else {
        planPayload.createdAt = now;
      }

      if (existingPlan.expiresAt) {
        planPayload.expiresAt = existingPlan.expiresAt;
      } else if (profilePayload.subscriptionExpiresAt) {
        planPayload.expiresAt = profilePayload.subscriptionExpiresAt;
      }

      await planRef.set(planPayload, { merge: true });

      const economyRef = userRef.collection('economy').doc('credits');
      if (!economySnapshot.exists) {
        await economyRef.set({
          credits: 0,
          earnedLifetime: 0,
          createdAt: now,
          updatedAt: now,
          provider: 'bootstrap',
        }, { merge: true });
      } else {
        await economyRef.set({ updatedAt: now }, { merge: true });
      }

      return {
        success: true,
        plan: planPayload.plan,
        effectiveLimits: planPayload.effectiveLimits,
      };
    } catch (error) {
      console.error('❌ Failed to initialize user profile:', error);
      throw new HttpsError('internal', 'Failed to initialize user profile.');
    }
  }
);

// User Management Functions

// Triggered when a new user is created in Firebase Auth
exports.createUserDocument = onDocumentCreated('users/{userId}', async (event) => {
  try {
    const userId = event.params.userId;
    const userData = event.data?.data();
    
    if (!userData) {
      console.log(`No user data found for ${userId}`);
      return;
    }
    
    console.log(`🆕 Creating user document for ${userId}`);
    
    // Initialize user's subcollections and default data
    const userRef = db.collection('users').doc(userId);
    
    const profile = {
      uid: userId,
      displayName: userData.displayName || 'Crystal Seeker',
      photoUrl: userData.photoURL || null,
      subscriptionTier: 'free',
      subscriptionStatus: 'active',
      createdAt: FieldValue.serverTimestamp(),
      lastLoginAt: FieldValue.serverTimestamp(),
    };

    const settings = {
      notifications: true,
      sound: true,
      vibration: true,
      darkMode: true,
      meditationReminder: 'Daily',
      crystalReminder: 'Weekly',
      shareUsageData: true,
      contentWarnings: true,
      language: 'en',
    };

    await userRef.set({
      email: userData.email || '',
      profile,
      settings,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    
    // Initialize empty collections
    await userRef.collection('crystals').doc('_init').set({ created: FieldValue.serverTimestamp() });
    await userRef.collection('journal').doc('_init').set({ created: FieldValue.serverTimestamp() });
    
    console.log(`✅ User document created successfully for ${userId}`);
    
  } catch (error) {
    console.error('❌ Error creating user document:', error);
  }
});

// Update user profile - callable function
exports.updateUserProfile = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    try {
      const userId = request.auth.uid;
      const updates = request.data;
      
      // Validate allowed fields
      const allowedFields = [
        'displayName', 'photoURL', 'settings', 'birthChart', 
        'preferences', 'location', 'experience'
      ];
      
      const validUpdates = {};
      for (const [key, value] of Object.entries(updates)) {
        if (allowedFields.includes(key)) {
          validUpdates[key] = value;
        }
      }
      
      validUpdates.updatedAt = FieldValue.serverTimestamp();
      
      await db.collection('users').doc(userId).update(validUpdates);
      
      console.log(`✅ Profile updated for user ${userId}`);
      return { success: true };
      
    } catch (error) {
      console.error('❌ Error updating profile:', error);
      throw new HttpsError('internal', 'Failed to update profile');
    }
  }
);

// Get user profile data - callable function
exports.getUserProfile = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    try {
      const userId = request.auth.uid;
      const userDoc = await db.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        throw new HttpsError('not-found', 'User profile not found');
      }
      
      const userData = userDoc.data();
      
      // Remove sensitive fields
      delete userData.internalNotes;
      delete userData.adminFlags;
      
      return userData;
      
    } catch (error) {
      console.error('❌ Error getting profile:', error);
      throw new HttpsError('internal', 'Failed to get profile');
    }
  }
);

// Delete user account and all associated data - callable function
exports.deleteUserAccount = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    try {
      const userId = request.auth.uid;
      const userRef = db.collection('users').doc(userId);

      console.log(`🗑️ Starting account deletion for user ${userId}`);

      const subcollections = await userRef.listCollections();
      for (const subcollection of subcollections) {
        await deleteCollectionDeep(subcollection);
      }

      await userRef.delete();

      await Promise.all([
        deleteQueryBatch(db.collection('usage').where('userId', '==', userId)),
        deleteQueryBatch(db.collection('usage_logs').where('userId', '==', userId)),
        deleteQueryBatch(db.collection('checkoutSessions').where('uid', '==', userId)),
        deleteQueryBatch(db.collection('identifications').where('userId', '==', userId)),
      ]);

      await auth.deleteUser(userId);

      console.log(`✅ Account successfully deleted for user ${userId}`);
      return { success: true };

    } catch (error) {
      console.error('❌ Error deleting account:', error);
      throw new HttpsError('internal', 'Failed to delete account');
    }
  }
);

// Usage tracking function
exports.trackUsage = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    try {
      const userId = request.auth.uid;
      const { action, metadata } = request.data;
      
      const usageDoc = {
        userId,
        action,
        metadata: metadata || {},
        timestamp: FieldValue.serverTimestamp(),
      };
      
      await db.collection('usage_logs').add(usageDoc);
      
      // Update user stats
      const userRef = db.collection('users').doc(userId);
      
      if (action === 'crystal_identification') {
        await userRef.update({
          totalIdentifications: FieldValue.increment(1),
          monthlyIdentifications: FieldValue.increment(1),
        });
      } else if (action === 'metaphysical_query') {
        await userRef.update({
          metaphysicalQueries: FieldValue.increment(1),
        });
      }
      
      return { success: true };
      
    } catch (error) {
      console.error('❌ Error tracking usage:', error);
      throw new HttpsError('internal', 'Failed to track usage');
    }
  }
);

// Dream analysis and journaling helper
exports.analyzeDream = onCall(
  { cors: true, memory: '512MiB', timeoutSeconds: 40 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }

    const { dreamContent, userCrystals, dreamDate, mood, moonPhase } = request.data || {};

    if (!dreamContent || typeof dreamContent !== 'string' || dreamContent.trim().length < 10) {
      throw new HttpsError('invalid-argument', 'Dream content must be at least 10 characters long.');
    }

    try {
      console.log(`🌌 Analyzing dream for user ${request.auth.uid}`);

      const { GoogleGenerativeAI } = require('@google/generative-ai');
      const genAI = new GoogleGenerativeAI(config().gemini.api_key);
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

      const crystalList = Array.isArray(userCrystals) ? userCrystals.join(', ') : 'None specified';
      const phase = moonPhase || 'Current lunar cycle';

      const analysisPrompt = `You are a compassionate dream interpreter who integrates crystal healing.` +
        `\nReturn a JSON object with the following structure (no markdown):` +
        `\n{` +
        `\n  "analysis": {` +
        `\n    "summary": string,` +
        `\n    "symbols": string,` +
        `\n    "emotions": string,` +
        `\n    "spiritualMessage": string,` +
        `\n    "ritual": string` +
        `\n  },` +
        `\n  "crystalSuggestions": [{"name": string, "reason": string, "usage": string}],` +
        `\n  "affirmation": string` +
        `\n}` +
        `\nKeep guidance mystical yet grounded, avoid medical/legal advice.` +
        `\nDream: "${dreamContent}"` +
        `\nKnown crystals: ${crystalList}` +
        `\nMoon phase: ${phase}` +
        (mood ? `\nReported mood: ${mood}` : '');

      const aiResponse = await model.generateContent([analysisPrompt]);
      const rawText = aiResponse.response.text();
      const cleaned = rawText.replace(/```json\n?|```/g, '').trim();

      let structured;
      try {
        structured = JSON.parse(cleaned);
      } catch (parseError) {
        console.warn('⚠️ Dream analysis JSON parse failed, falling back to text output.');
        structured = {
          analysis: { summary: rawText },
          crystalSuggestions: Array.isArray(userCrystals) ? userCrystals.map((name) => ({
            name,
            reason: 'Personal crystal on record',
            usage: 'Hold during reflection',
          })) : [],
          affirmation: 'Breathe deeply and trust your intuition.',
        };
      }

      const analysisSections = structured.analysis || {};
      const analysisLines = [];
      if (analysisSections.summary) {
        analysisLines.push(`Summary:\n${analysisSections.summary}`);
      }
      if (analysisSections.symbols) {
        analysisLines.push(`Symbols & Themes:\n${analysisSections.symbols}`);
      }
      if (analysisSections.emotions) {
        analysisLines.push(`Emotional Currents:\n${analysisSections.emotions}`);
      }
      if (analysisSections.spiritualMessage) {
        analysisLines.push(`Spiritual Message:\n${analysisSections.spiritualMessage}`);
      }
      if (analysisSections.ritual) {
        analysisLines.push(`Integration Ritual:\n${analysisSections.ritual}`);
      }
      if (structured.affirmation) {
        analysisLines.push(`Affirmation:\n${structured.affirmation}`);
      }

      const analysisText = analysisLines.join('\n\n').trim() || rawText;
      const suggestions = Array.isArray(structured.crystalSuggestions)
        ? structured.crystalSuggestions.slice(0, 5).map((suggestion) => ({
            name: suggestion.name || 'Crystal Ally',
            reason: suggestion.reason || 'Resonates with dream symbolism',
            usage: suggestion.usage || 'Hold during meditation',
          }))
        : [];

      let dreamTimestamp = FieldValue.serverTimestamp();
      if (dreamDate) {
        const parsedDream = new Date(dreamDate);
        if (!Number.isNaN(parsedDream.getTime())) {
          dreamTimestamp = Timestamp.fromDate(parsedDream);
        }
      }

      const entry = {
        content: dreamContent,
        analysis: analysisText,
        crystalSuggestions: suggestions,
        crystalsUsed: Array.isArray(userCrystals) ? userCrystals : [],
        dreamDate: dreamTimestamp,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        mood: mood || null,
        moonPhase: moonPhase || null,
      };

      const docRef = await db
        .collection('users')
        .doc(request.auth.uid)
        .collection('dreams')
        .add(entry);

      console.log(`✅ Dream analysis saved with id ${docRef.id}`);
      return {
        analysis: analysisText,
        crystalSuggestions: suggestions,
        affirmation: structured.affirmation || null,
        entryId: docRef.id,
      };
    } catch (error) {
      console.error('❌ Dream analysis error:', error);
      throw new HttpsError('internal', `Dream analysis failed: ${error.message}`);
    }
  }
);

// Get daily crystal recommendation - public function (no auth required for daily inspiration)
exports.getDailyCrystal = onCall({
  cors: true,
  invoker: 'public',
  timeoutSeconds: 60,
  memory: '256MiB'
}, async (request) => {
  try {
    console.log('🌅 Getting daily crystal recommendation...');
    
    // Array of crystals with detailed properties for daily recommendations
    const crystalDatabase = [
      {
        name: 'Clear Quartz',
        description: 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone, Clear Quartz can be programmed with any intention and works harmoniously with all other crystals.',
        properties: ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
        metaphysical_properties: {
          healing_properties: ['Amplifies energy', 'Promotes clarity', 'Enhances spiritual growth'],
          primary_chakras: ['Crown', 'All Chakras'],
          energy_type: 'amplifying',
          element: 'air'
        },
        identification: {
          name: 'Clear Quartz',
          confidence: 95,
          variety: 'Crystalline Quartz'
        }
      },
      {
        name: 'Amethyst',
        description: 'A powerful crystal for spiritual growth, protection, and clarity. Amethyst enhances intuition and promotes peaceful energy while providing protection from negative influences.',
        properties: ['Spiritual Growth', 'Protection', 'Clarity', 'Peace', 'Intuition'],
        metaphysical_properties: {
          healing_properties: ['Enhances intuition', 'Provides protection', 'Promotes spiritual awareness'],
          primary_chakras: ['Crown', 'Third Eye'],
          energy_type: 'calming',
          element: 'air'
        },
        identification: {
          name: 'Amethyst',
          confidence: 92,
          variety: 'Purple Quartz'
        }
      },
      {
        name: 'Rose Quartz',
        description: 'The stone of unconditional love and infinite peace. Rose Quartz is the most important crystal for healing the heart and heart chakra, teaching the true essence of love.',
        properties: ['Love', 'Compassion', 'Healing', 'Peace', 'Self-Love'],
        metaphysical_properties: {
          healing_properties: ['Opens heart chakra', 'Promotes self-love', 'Attracts love'],
          primary_chakras: ['Heart'],
          energy_type: 'loving',
          element: 'water'
        },
        identification: {
          name: 'Rose Quartz',
          confidence: 90,
          variety: 'Pink Quartz'
        }
      },
      {
        name: 'Black Tourmaline',
        description: 'A powerful grounding stone that provides protection from negative energies and electromagnetic radiation. Creates a protective shield around the aura.',
        properties: ['Protection', 'Grounding', 'Purification', 'Deflection', 'Stability'],
        metaphysical_properties: {
          healing_properties: ['Provides protection', 'Grounds energy', 'Deflects negativity'],
          primary_chakras: ['Root'],
          energy_type: 'grounding',
          element: 'earth'
        },
        identification: {
          name: 'Black Tourmaline',
          confidence: 88,
          variety: 'Schorl'
        }
      },
      {
        name: 'Citrine',
        description: 'Known as the merchants stone, Citrine attracts wealth, prosperity, and success. It also promotes joy, enthusiasm, and creativity while dissipating negative energy.',
        properties: ['Abundance', 'Joy', 'Creativity', 'Success', 'Energy'],
        metaphysical_properties: {
          healing_properties: ['Attracts abundance', 'Boosts confidence', 'Enhances creativity'],
          primary_chakras: ['Solar Plexus', 'Sacral'],
          energy_type: 'energizing',
          element: 'fire'
        },
        identification: {
          name: 'Citrine',
          confidence: 91,
          variety: 'Yellow Quartz'
        }
      },
      {
        name: 'Selenite',
        description: 'A high-vibrational crystal that cleanses and charges other crystals. Selenite connects you to higher realms and promotes mental clarity and spiritual insight.',
        properties: ['Cleansing', 'Charging', 'Clarity', 'Spiritual Connection', 'Peace'],
        metaphysical_properties: {
          healing_properties: ['Cleanses energy', 'Enhances spiritual connection', 'Promotes clarity'],
          primary_chakras: ['Crown', 'Third Eye'],
          energy_type: 'cleansing',
          element: 'air'
        },
        identification: {
          name: 'Selenite',
          confidence: 89,
          variety: 'Gypsum'
        }
      }
    ];
    
    // Get current date to ensure same crystal per day
    const today = new Date();
    const dayOfYear = Math.floor((today - new Date(today.getFullYear(), 0, 0)) / 1000 / 60 / 60 / 24);
    
    // Use day of year to select crystal (ensures same crystal for same day)
    const selectedCrystal = crystalDatabase[dayOfYear % crystalDatabase.length];
    
    console.log(`✅ Daily crystal selected: ${selectedCrystal.name}`);
    
    return {
      ...selectedCrystal,
      date: today.toISOString().split('T')[0], // YYYY-MM-DD format
      dayOfYear: dayOfYear
    };
    
  } catch (error) {
    console.error('❌ Error getting daily crystal:', error);
    
    // Return fallback crystal if anything goes wrong
    return {
      name: 'Clear Quartz',
      description: 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone, Clear Quartz can be programmed with any intention and works harmoniously with all other crystals.',
      properties: ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
      metaphysical_properties: {
        healing_properties: ['Amplifies energy', 'Promotes clarity', 'Enhances spiritual growth'],
        primary_chakras: ['Crown', 'All Chakras'],
      },
      identification: {
        name: 'Clear Quartz',
        confidence: 95,
        variety: 'Crystalline Quartz'
      },
      date: new Date().toISOString().split('T')[0],
      error: 'Fallback crystal provided'
    };
  }
});

console.log('🔮 Crystal Grimoire Functions (Complete Backend) initialized');