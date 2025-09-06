/**
 * 🔮 Crystal Grimoire Cloud Functions - Complete Backend System
 * Authentication, user management, and crystal identification with Gemini AI
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { config } = require('firebase-functions/v1');

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const auth = getAuth();

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

      // Save identification to user's collection
      const identificationRecord = {
        ...crystalData,
        userId: userId,
        timestamp: new Date().toISOString(),
        imageData: imageData.substring(0, 100) + '...', // Store truncated version for reference
      };

      await db.collection('identifications').add(identificationRecord);
      console.log('💾 Crystal identification saved to user collection');

      console.log('✅ Crystal identified:', crystalData.identification?.name || 'Unknown');
      
      return crystalData;

    } catch (error) {
      console.error('❌ Crystal identification error:', error);
      throw new HttpsError('internal', `Identification failed: ${error.message}`);
    }
  }
);

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
    
    // Set default user profile data
    const defaultProfile = {
      uid: userId,
      email: userData.email || '',
      displayName: userData.displayName || 'Crystal Seeker',
      photoURL: userData.photoURL || null,
      createdAt: FieldValue.serverTimestamp(),
      lastLoginAt: FieldValue.serverTimestamp(),
      subscriptionTier: 'free',
      subscriptionStatus: 'active',
      monthlyIdentifications: 0,
      totalIdentifications: 0,
      metaphysicalQueries: 0,
      settings: {
        notifications: true,
        newsletter: true,
        darkMode: true,
      },
    };
    
    await userRef.set(defaultProfile, { merge: true });
    
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
      
      console.log(`🗑️ Starting account deletion for user ${userId}`);
      
      // Delete user's subcollections
      const collections = ['crystals', 'journal', 'identifications', 'guidance'];
      
      for (const collectionName of collections) {
        const collectionRef = db.collection('users').doc(userId).collection(collectionName);
        const snapshot = await collectionRef.get();
        
        for (const doc of snapshot.docs) {
          await doc.ref.delete();
        }
      }
      
      // Delete main user document
      await db.collection('users').doc(userId).delete();
      
      // Delete from Firebase Auth
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