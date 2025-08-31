/**
 * 🔮 Crystal Grimoire Cloud Functions
 * AI-powered crystal identification and mystical guidance system
 */

import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { GoogleGenerativeAI } from '@google/generative-ai';
import vision from '@google-cloud/vision';
import OpenAI from 'openai';
import Stripe from 'stripe';
import cors from 'cors';
import { z } from 'zod';
import sharp from 'sharp';

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const storage = getStorage();

// Initialize AI services
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || '');
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY || '' });
const visionClient = new vision.ImageAnnotatorClient();

// Initialize Stripe
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
  apiVersion: '2024-06-20',
});

// CORS middleware
const corsHandler = cors({ origin: true });

// Validation schemas
const crystalIdentificationSchema = z.object({
  imageData: z.string().min(100),
  includeMetaphysical: z.boolean().default(true),
  includeHealing: z.boolean().default(true),
  includeCare: z.boolean().default(true),
});

const crystalGuidanceSchema = z.object({
  crystalName: z.string().min(1),
  userProfile: z.object({
    sunSign: z.string().optional(),
    moonSign: z.string().optional(),
    intentions: z.array(z.string()).optional(),
  }),
  intention: z.string().optional(),
});

/**
 * 🔍 CRYSTAL IDENTIFICATION WITH AI
 * Uses Google Vision + Gemini for comprehensive crystal analysis
 */
export const identifyCrystal = onCall(
  { cors: true, memory: '1GiB', timeoutSeconds: 60 },
  async (request) => {
    try {
      const { data } = request;
      const { imageData, includeMetaphysical, includeHealing, includeCare } =
        crystalIdentificationSchema.parse(data);

      console.log('🔍 Starting crystal identification...');

      // Convert base64 to buffer
      const imageBuffer = Buffer.from(imageData.split(',')[1] || imageData, 'base64');
      
      // Optimize image for better recognition
      const optimizedImage = await sharp(imageBuffer)
        .resize(1024, 1024, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 95 })
        .toBuffer();

      // Google Vision API for initial analysis
      const [visionResult] = await visionClient.labelDetection({
        image: { content: optimizedImage },
      });

      const labels = visionResult.labelAnnotations?.map(label => ({
        description: label.description,
        score: label.score,
      })) || [];

      // Enhanced Gemini prompt with Crystal Bible knowledge
      const geminiPrompt = `
🔮 CRYSTAL IDENTIFICATION EXPERT SYSTEM

You are an expert crystal healer with deep knowledge of The Crystal Bible by Judy Hall and decades of experience in crystal identification and metaphysical properties.

ANALYZE THIS CRYSTAL IMAGE and provide a complete JSON response:

VISION LABELS DETECTED: ${JSON.stringify(labels)}

Required JSON Format:
{
  "identification": {
    "name": "Primary crystal name",
    "variety": "Specific variety if applicable",
    "scientific_name": "Chemical composition",
    "confidence": 85
  },
  "metaphysical_properties": {
    "primary_chakras": ["Root", "Heart", "Crown"],
    "zodiac_signs": ["Aries", "Leo"],
    "planetary_rulers": ["Mars", "Sun"],
    "elements": ["Fire", "Earth"],
    "healing_properties": [
      "Enhances courage and strength",
      "Promotes emotional healing",
      "Increases spiritual awareness"
    ],
    "intentions": ["Protection", "Love", "Healing", "Manifestation"]
  },
  "physical_properties": {
    "hardness": "7 (Mohs scale)",
    "crystal_system": "Hexagonal",
    "luster": "Vitreous",
    "transparency": "Transparent to translucent",
    "color_range": ["Purple", "Violet", "Clear"],
    "formation": "Igneous/Metamorphic",
    "chemical_formula": "SiO2",
    "density": "2.65 g/cm³"
  },
  "care_instructions": {
    "cleansing_methods": ["Running water", "Moonlight", "Sage smoke"],
    "charging_methods": ["Sunlight", "Crystal cluster", "Earth burial"],
    "storage_recommendations": "Keep in soft cloth away from harder stones",
    "handling_notes": "Safe for water cleansing"
  },
  "description": "Comprehensive description of the crystal's appearance, formation, and significance"
}

CRITICAL REQUIREMENTS:
- Base identification on actual visible characteristics
- Provide complete metaphysical properties from Crystal Bible knowledge
- Include specific healing applications
- Give practical care instructions
- Ensure all arrays have at least 2-3 items
- Confidence must reflect actual certainty (60-95 range)
      `;

      // Call Gemini with the image and prompt
      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });
      
      const result = await model.generateContent([
        geminiPrompt,
        {
          inlineData: {
            data: optimizedImage.toString('base64'),
            mimeType: 'image/jpeg',
          },
        },
      ]);

      const responseText = result.response.text();
      console.log('🤖 Gemini response:', responseText);

      // Parse JSON response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error('Invalid AI response format');
      }

      const crystalData = JSON.parse(jsonMatch[0]);

      // Save identification to database
      if (request.auth) {
        await db.collection('identifications').add({
          userId: request.auth.uid,
          crystalData,
          visionLabels: labels,
          timestamp: new Date(),
          confidence: crystalData.identification.confidence,
        });
      }

      console.log('✅ Crystal identification completed');
      return crystalData;

    } catch (error) {
      console.error('❌ Crystal identification error:', error);
      throw new HttpsError('internal', `Crystal identification failed: ${error.message}`);
    }
  }
);

/**
 * 🌟 PERSONALIZED CRYSTAL GUIDANCE
 * AI-powered guidance based on birth chart and intentions
 */
export const getCrystalGuidance = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    try {
      const { data } = request;
      const { crystalName, userProfile, intention } = crystalGuidanceSchema.parse(data);

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      console.log(`🌟 Generating guidance for ${crystalName}`);

      // Get user's complete profile from Firestore
      const userDoc = await db.collection('users').doc(request.auth.uid).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      // Enhanced personalized prompt
      const guidancePrompt = `
🔮 PERSONALIZED CRYSTAL GUIDANCE SYSTEM

You are a wise crystal healer providing personalized guidance.

CRYSTAL: ${crystalName}
USER PROFILE:
- Sun Sign: ${userProfile.sunSign || userData.birthChart?.sunSign || 'Unknown'}
- Moon Sign: ${userProfile.moonSign || userData.birthChart?.moonSign || 'Unknown'}
- Current Intentions: ${userProfile.intentions?.join(', ') || 'General wellness'}
- Specific Request: ${intention || 'General guidance'}

Provide personalized guidance addressing:
1. How this crystal specifically supports their astrological profile
2. Recommended usage based on their intentions
3. Meditation or ritual suggestions
4. Timing recommendations (moon phases, etc.)
5. Complementary crystals they might consider

Keep the tone mystical but practical, around 200-300 words.
      `;

      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const result = await model.generateContent(guidancePrompt);
      const guidance = result.response.text();

      // Save guidance session
      await db.collection('users').doc(request.auth.uid)
        .collection('guidance_sessions').add({
          crystalName,
          guidance,
          intention,
          timestamp: new Date(),
        });

      console.log('✅ Guidance generated successfully');
      return { guidance };

    } catch (error) {
      console.error('❌ Guidance generation error:', error);
      throw new HttpsError('internal', `Guidance generation failed: ${error.message}`);
    }
  }
);

/**
 * 🌙 MOON RITUALS & PHASE CALCULATIONS
 * Astronomical calculations with personalized ritual recommendations
 */
export const getMoonRituals = onCall(
  { cors: true, timeoutSeconds: 20 },
  async (request) => {
    try {
      const { moonPhase, userCrystals, userProfile } = request.data;

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      console.log(`🌙 Generating ${moonPhase} rituals`);

      // Calculate current moon phase data
      const moonData = calculateMoonPhase();
      
      // Get user's crystal collection
      const userCrystalDocs = await db.collection('users')
        .doc(request.auth.uid)
        .collection('crystals')
        .get();
      
      const ownedCrystals = userCrystalDocs.docs.map(doc => doc.data().name);

      const ritualPrompt = `
🌙 MOON RITUAL RECOMMENDATIONS

Current Moon Phase: ${moonData.phase}
User's Crystals: ${ownedCrystals.join(', ') || 'None yet - suggest basic crystals'}
User Profile: ${JSON.stringify(userProfile)}

Create personalized moon ritual recommendations including:

1. RITUAL PURPOSE: What this moon phase supports
2. CRYSTAL SELECTION: Which of their crystals to use (or suggest acquiring)
3. RITUAL STEPS: Step-by-step ritual guide
4. TIMING: Best time during this moon phase
5. AFFIRMATIONS: Phase-specific affirmations
6. JOURNAL PROMPTS: Questions for reflection

Make it practical and achievable, around 300 words.
      `;

      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const result = await model.generateContent(ritualPrompt);
      const rituals = result.response.text();

      // Update moon data in database
      await db.collection('moonData').doc('current').set({
        ...moonData,
        lastUpdated: new Date(),
      });

      console.log('✅ Moon rituals generated');
      return {
        moonData,
        rituals,
        userCrystals: ownedCrystals,
      };

    } catch (error) {
      console.error('❌ Moon ritual error:', error);
      throw new HttpsError('internal', `Moon ritual generation failed: ${error.message}`);
    }
  }
);

/**
 * 💎 CRYSTAL HEALING LAYOUT GENERATOR
 * AI-powered healing session layouts based on chakras and intentions
 */
export const generateHealingLayout = onCall(
  { cors: true, timeoutSeconds: 25 },
  async (request) => {
    try {
      const { availableCrystals, targetChakras, intention } = request.data;

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      console.log('💎 Generating healing layout');

      const layoutPrompt = `
💎 CRYSTAL HEALING LAYOUT GENERATOR

Available Crystals: ${availableCrystals.join(', ')}
Target Chakras: ${targetChakras.join(', ')}
Healing Intention: ${intention || 'General balance and wellness'}

Create a personalized crystal healing layout with:

1. CRYSTAL PLACEMENT: Specific body positions for each crystal
2. CHAKRA ALIGNMENT: How crystals support targeted chakras
3. SESSION DURATION: Recommended time (typically 15-30 minutes)
4. PREPARATION: Setting up the space and mindset
5. GUIDED MEDITATION: Short meditation to accompany the layout
6. INTEGRATION: Post-session practices

Format as a clear, step-by-step guide that's easy to follow.
      `;

      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const result = await model.generateContent(layoutPrompt);
      const layout = result.response.text();

      // Save healing session
      await db.collection('users').doc(request.auth.uid)
        .collection('healing_sessions').add({
          availableCrystals,
          targetChakras,
          intention,
          layout,
          timestamp: new Date(),
          completed: false,
        });

      console.log('✅ Healing layout generated');
      return { layout };

    } catch (error) {
      console.error('❌ Healing layout error:', error);
      throw new HttpsError('internal', `Healing layout generation failed: ${error.message}`);
    }
  }
);

/**
 * 🌌 DREAM ANALYSIS WITH CRYSTAL CORRELATIONS
 * AI dream interpretation with crystal recommendations
 */
export const analyzeDream = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    try {
      const { dreamContent, userCrystals, dreamDate } = request.data;

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      console.log('🌌 Analyzing dream');

      const analysisPrompt = `
🌌 DREAM ANALYSIS & CRYSTAL CORRELATION

Dream Content: "${dreamContent}"
User's Crystals: ${userCrystals?.join(', ') || 'None specified'}
Dream Date: ${dreamDate || 'Recent'}

Provide comprehensive dream analysis including:

1. SYMBOLIC INTERPRETATION: Key symbols and their meanings
2. EMOTIONAL THEMES: Underlying emotional patterns
3. SPIRITUAL MESSAGE: Deeper spiritual significance
4. CRYSTAL RECOMMENDATIONS: Which crystals support dream themes
5. INTEGRATION PRACTICES: How to work with dream insights
6. JOURNAL PROMPTS: Questions for deeper exploration

Keep analysis insightful but avoid overly specific predictions.
      `;

      const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
      const result = await model.generateContent(analysisPrompt);
      const analysis = result.response.text();

      // Save dream entry
      await db.collection('users').doc(request.auth.uid)
        .collection('dreams').add({
          content: dreamContent,
          analysis,
          crystalsUsed: userCrystals || [],
          dreamDate: dreamDate ? new Date(dreamDate) : new Date(),
          timestamp: new Date(),
        });

      console.log('✅ Dream analysis completed');
      return { analysis };

    } catch (error) {
      console.error('❌ Dream analysis error:', error);
      throw new HttpsError('internal', `Dream analysis failed: ${error.message}`);
    }
  }
);

/**
 * 💰 STRIPE PAYMENT PROCESSING
 * Handle subscription upgrades and marketplace purchases
 */
export const createPaymentIntent = onCall(
  { cors: true, timeoutSeconds: 15 },
  async (request) => {
    try {
      const { amount, currency = 'usd', type = 'subscription' } = request.data;

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      console.log(`💰 Creating payment intent for $${amount/100}`);

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        customer: request.auth.uid, // Will create customer if doesn't exist
        metadata: {
          userId: request.auth.uid,
          type,
        },
      });

      return {
        clientSecret: paymentIntent.client_secret,
      };

    } catch (error) {
      console.error('❌ Payment intent error:', error);
      throw new HttpsError('internal', `Payment processing failed: ${error.message}`);
    }
  }
);

/**
 * 🎵 SOUND FREQUENCY RECOMMENDATIONS
 * Crystal-matched sound bath frequencies
 */
export const getSoundFrequencies = onCall(
  { cors: true, timeoutSeconds: 10 },
  async (request) => {
    try {
      const { crystalName, intention } = request.data;

      console.log(`🎵 Getting sound frequencies for ${crystalName}`);

      // Crystal-to-frequency mapping based on chakra resonance
      const crystalFrequencies = {
        'Amethyst': { frequency: 426.7, note: 'G', chakra: 'Crown' },
        'Rose Quartz': { frequency: 341.3, note: 'F', chakra: 'Heart' },
        'Citrine': { frequency: 528, note: 'C', chakra: 'Solar Plexus' },
        'Clear Quartz': { frequency: 963, note: 'B', chakra: 'Crown' },
        // Add more crystal frequencies...
      };

      const frequency = crystalFrequencies[crystalName] || 
        { frequency: 432, note: 'A', chakra: 'All Chakras' };

      return {
        crystal: crystalName,
        frequency: frequency.frequency,
        note: frequency.note,
        chakra: frequency.chakra,
        intention,
        audioFiles: [
          `${frequency.frequency}hz_pure_tone.mp3`,
          `${frequency.frequency}hz_nature_blend.mp3`,
          `${frequency.frequency}hz_crystal_bowl.mp3`,
        ],
      };

    } catch (error) {
      console.error('❌ Sound frequency error:', error);
      throw new HttpsError('internal', `Sound frequency lookup failed: ${error.message}`);
    }
  }
);

/**
 * ⏰ SCHEDULED FUNCTIONS
 */

// Daily reset of user credits
export const dailyCreditsReset = onSchedule(
  { schedule: '0 4 * * *', timeZone: 'America/New_York' },
  async () => {
    console.log('⏰ Starting daily credits reset');
    
    const batch = db.batch();
    const usersSnapshot = await db.collection('users')
      .where('subscriptionTier', '==', 'free')
      .get();

    usersSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        dailyCredits: 3,
        lastCreditReset: new Date(),
      });
    });

    await batch.commit();
    console.log(`✅ Reset credits for ${usersSnapshot.size} free users`);
  }
);

// Update moon phase data daily
export const updateMoonPhase = onSchedule(
  { schedule: '0 6 * * *', timeZone: 'UTC' },
  async () => {
    console.log('🌙 Updating moon phase data');
    
    const moonData = calculateMoonPhase();
    await db.collection('moonData').doc('current').set({
      ...moonData,
      lastUpdated: new Date(),
    });

    console.log(`✅ Updated moon phase: ${moonData.phase}`);
  }
);

/**
 * 🧮 HELPER FUNCTIONS
 */

function calculateMoonPhase() {
  const now = new Date();
  const knownNewMoon = new Date('2024-01-11T11:57:00Z');
  const lunarCycle = 29.530589; // days
  
  const daysSince = (now.getTime() - knownNewMoon.getTime()) / (1000 * 60 * 60 * 24);
  const currentCycle = (daysSince % lunarCycle) / lunarCycle;
  
  let phase, emoji, illumination;
  
  if (currentCycle < 0.0625) {
    phase = 'New Moon';
    emoji = '🌑';
    illumination = 0;
  } else if (currentCycle < 0.1875) {
    phase = 'Waxing Crescent';
    emoji = '🌒';
    illumination = 0.25;
  } else if (currentCycle < 0.3125) {
    phase = 'First Quarter';
    emoji = '🌓';
    illumination = 0.5;
  } else if (currentCycle < 0.4375) {
    phase = 'Waxing Gibbous';
    emoji = '🌔';
    illumination = 0.75;
  } else if (currentCycle < 0.5625) {
    phase = 'Full Moon';
    emoji = '🌕';
    illumination = 1.0;
  } else if (currentCycle < 0.6875) {
    phase = 'Waning Gibbous';
    emoji = '🌖';
    illumination = 0.75;
  } else if (currentCycle < 0.8125) {
    phase = 'Last Quarter';
    emoji = '🌗';
    illumination = 0.5;
  } else {
    phase = 'Waning Crescent';
    emoji = '🌘';
    illumination = 0.25;
  }
  
  return {
    phase,
    emoji,
    illumination,
    timestamp: now.toISOString(),
    nextFullMoon: calculateNextPhase(0.5, currentCycle, now, lunarCycle),
    nextNewMoon: calculateNextPhase(0.0, currentCycle, now, lunarCycle),
  };
}

function calculateNextPhase(targetPhase, currentPhase, now, lunarCycle) {
  let daysUntil;
  if (targetPhase >= currentPhase) {
    daysUntil = (targetPhase - currentPhase) * lunarCycle;
  } else {
    daysUntil = (1 - currentPhase + targetPhase) * lunarCycle;
  }
  
  const nextPhaseDate = new Date(now.getTime() + (daysUntil * 24 * 60 * 60 * 1000));
  return nextPhaseDate.toISOString();
}

// Health check endpoint
export const healthCheck = onRequest({ cors: true }, (req, res) => {
  corsHandler(req, res, () => {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        firestore: 'connected',
        gemini: !!process.env.GEMINI_API_KEY,
        stripe: !!process.env.STRIPE_SECRET_KEY,
      },
    });
  });
});

console.log('🔮 Crystal Grimoire Cloud Functions initialized');