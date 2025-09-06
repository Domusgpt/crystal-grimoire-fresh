// Crystal Grimoire Database Seeding Script
// Seeds the Firestore database with essential data for launch

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  // Use service account key for initialization
  const serviceAccount = require('../firebase-service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://crystal-grimoire-2025.firebaseio.com'
  });
}

const db = admin.firestore();

// SPEC-1 Compliant Crystal Library Data
const crystalLibraryData = [
  {
    id: 'clear-quartz',
    name: 'Clear Quartz',
    aliases: ['Rock Crystal', 'Master Healer'],
    scientificName: 'Silicon Dioxide (SiO2)',
    intents: ['Amplification', 'Clarity', 'Healing', 'Manifestation'],
    chakras: ['Crown', 'All Chakras'],
    zodiacSigns: ['All Signs', 'Aries', 'Leo'],
    elements: ['Spirit', 'All Elements'],
    physicalProperties: {
      hardness: '7',
      color: 'Clear/Transparent',
      luster: 'Vitreous',
      transparency: 'Transparent to Translucent'
    },
    metaphysicalProperties: {
      healingProperties: ['Amplifies energy', 'Enhances clarity', 'Supports all healing'],
      emotionalSupport: ['Emotional balance', 'Mental clarity', 'Spiritual connection'],
      spiritualUses: ['Meditation', 'Energy work', 'Manifestation']
    },
    careInstructions: {
      cleansing: ['Running water', 'Moonlight', 'Sage smoke', 'Sound vibrations'],
      charging: ['Sunlight', 'Full moon', 'Crystal clusters', 'Earth burial'],
      cautions: ['Generally safe', 'May amplify negative energy if not cleansed']
    },
    imageUrl: '/assets/crystals/clear-quartz.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'amethyst',
    name: 'Amethyst',
    aliases: ['Purple Quartz', 'Stone of Sobriety'],
    scientificName: 'Silicon Dioxide (SiO2)',
    intents: ['Spiritual Protection', 'Intuition', 'Calming', 'Meditation'],
    chakras: ['Crown', 'Third Eye'],
    zodiacSigns: ['Pisces', 'Virgo', 'Aquarius', 'Capricorn'],
    elements: ['Air', 'Water'],
    physicalProperties: {
      hardness: '7',
      color: 'Purple to Lavender',
      luster: 'Vitreous',
      transparency: 'Transparent to Translucent'
    },
    metaphysicalProperties: {
      healingProperties: ['Calms the mind', 'Enhances intuition', 'Promotes spiritual growth'],
      emotionalSupport: ['Stress relief', 'Addiction recovery', 'Emotional stability'],
      spiritualUses: ['Meditation', 'Dream work', 'Psychic protection']
    },
    careInstructions: {
      cleansing: ['Moonlight', 'Sage smoke', 'Sound cleansing'],
      charging: ['Full moon', 'Amethyst clusters', 'Meditation'],
      cautions: ['Avoid prolonged sunlight - may fade', 'Handle gently']
    },
    imageUrl: '/assets/crystals/amethyst.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'rose-quartz',
    name: 'Rose Quartz',
    aliases: ['Love Stone', 'Heart Stone'],
    scientificName: 'Silicon Dioxide (SiO2)',
    intents: ['Love', 'Self-Love', 'Emotional Healing', 'Compassion'],
    chakras: ['Heart'],
    zodiacSigns: ['Taurus', 'Libra'],
    elements: ['Earth', 'Water'],
    physicalProperties: {
      hardness: '7',
      color: 'Pink to Rose',
      luster: 'Vitreous',
      transparency: 'Translucent'
    },
    metaphysicalProperties: {
      healingProperties: ['Opens heart chakra', 'Promotes self-love', 'Heals emotional wounds'],
      emotionalSupport: ['Unconditional love', 'Forgiveness', 'Compassion'],
      spiritualUses: ['Heart healing', 'Relationship work', 'Self-acceptance']
    },
    careInstructions: {
      cleansing: ['Running water', 'Moonlight', 'Rose petals'],
      charging: ['Dawn sunlight', 'Full moon', 'Heart meditation'],
      cautions: ['Avoid harsh chemicals', 'May fade in direct sunlight']
    },
    imageUrl: '/assets/crystals/rose-quartz.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'black-tourmaline',
    name: 'Black Tourmaline',
    aliases: ['Schorl', 'Protection Stone'],
    scientificName: 'Sodium Iron Aluminum Borosilicate',
    intents: ['Protection', 'Grounding', 'EMF Protection', 'Cleansing'],
    chakras: ['Root'],
    zodiacSigns: ['Capricorn', 'Scorpio'],
    elements: ['Earth'],
    physicalProperties: {
      hardness: '7-7.5',
      color: 'Black',
      luster: 'Vitreous',
      transparency: 'Opaque'
    },
    metaphysicalProperties: {
      healingProperties: ['Absorbs negative energy', 'Provides grounding', 'EMF protection'],
      emotionalSupport: ['Anxiety relief', 'Emotional stability', 'Confidence'],
      spiritualUses: ['Protection rituals', 'Grounding meditation', 'Space clearing']
    },
    careInstructions: {
      cleansing: ['Running water', 'Earth burial', 'Sage smoke'],
      charging: ['Earth connection', 'Hematite', 'Root chakra meditation'],
      cautions: ['May absorb negative energy - cleanse regularly', 'Generally very safe']
    },
    imageUrl: '/assets/crystals/black-tourmaline.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'citrine',
    name: 'Citrine',
    aliases: ['Success Stone', 'Merchant Stone'],
    scientificName: 'Silicon Dioxide (SiO2)',
    intents: ['Abundance', 'Success', 'Confidence', 'Manifestation'],
    chakras: ['Solar Plexus', 'Sacral'],
    zodiacSigns: ['Gemini', 'Aries', 'Leo', 'Libra'],
    elements: ['Fire'],
    physicalProperties: {
      hardness: '7',
      color: 'Yellow to Golden',
      luster: 'Vitreous',
      transparency: 'Transparent to Translucent'
    },
    metaphysicalProperties: {
      healingProperties: ['Boosts confidence', 'Attracts abundance', 'Enhances creativity'],
      emotionalSupport: ['Self-esteem', 'Motivation', 'Joy'],
      spiritualUses: ['Manifestation work', 'Abundance rituals', 'Solar plexus healing']
    },
    careInstructions: {
      cleansing: ['Sunlight', 'Running water', 'Citrine clusters'],
      charging: ['Sunlight', 'Citrine clusters', 'Success meditation'],
      cautions: ['Natural citrine is rare - most is heat-treated amethyst', 'Generally safe']
    },
    imageUrl: '/assets/crystals/citrine.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'moonstone',
    name: 'Moonstone',
    aliases: ['Moon Stone', 'Feminine Stone'],
    scientificName: 'Potassium Aluminum Silicate',
    intents: ['Intuition', 'Feminine Energy', 'Cycles', 'New Beginnings'],
    chakras: ['Crown', 'Third Eye', 'Sacral'],
    zodiacSigns: ['Cancer', 'Libra', 'Scorpio'],
    elements: ['Water'],
    physicalProperties: {
      hardness: '6-6.5',
      color: 'White, Cream, Peach, Gray',
      luster: 'Vitreous',
      transparency: 'Transparent to Opaque'
    },
    metaphysicalProperties: {
      healingProperties: ['Enhances intuition', 'Balances emotions', 'Supports feminine cycles'],
      emotionalSupport: ['Emotional balance', 'Nurturing energy', 'Inner wisdom'],
      spiritualUses: ['Moon rituals', 'Intuitive work', 'Goddess connection']
    },
    careInstructions: {
      cleansing: ['Moonlight', 'Sage smoke', 'Spring water'],
      charging: ['Full moon', 'Moonlight meditation', 'Lunar rituals'],
      cautions: ['Softer stone - handle carefully', 'Avoid harsh chemicals']
    },
    imageUrl: '/assets/crystals/moonstone.jpg',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
  // Add more crystals as needed...
];

// Feature flags for launch
const featureFlagsData = [
  {
    id: 'crystal_identification',
    enabled: true,
    rollout: 100,
    description: 'AI-powered crystal identification feature'
  },
  {
    id: 'guidance_generation',
    enabled: true,
    rollout: 100,
    description: 'Structured mystical guidance generation'
  },
  {
    id: 'seer_credits',
    enabled: true,
    rollout: 100,
    description: 'Seer Credits economy system'
  },
  {
    id: 'marketplace',
    enabled: false,
    rollout: 0,
    description: 'Crystal marketplace (beta feature)'
  },
  {
    id: 'advanced_astrology',
    enabled: false,
    rollout: 0,
    description: 'Advanced astrology features (premium)'
  }
];

// System notifications for users
const systemNotificationsData = [
  {
    id: 'welcome_alpha',
    title: 'Welcome to Crystal Grimoire Alpha!',
    message: 'Thank you for being part of our mystical community. Start by identifying your first crystal!',
    type: 'welcome',
    priority: 'high',
    active: true,
    validUntil: new Date('2025-12-31'),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    id: 'new_moon_ritual',
    title: '🌑 New Moon Energy Available',
    message: 'The new moon brings powerful intention-setting energy. Check your personalized ritual guidance.',
    type: 'lunar',
    priority: 'medium',
    active: true,
    validUntil: null, // Recurring notification
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

// Analytics initial structure
const analyticsData = {
  id: 'daily_metrics_template',
  structure: {
    date: '2025-01-01',
    users: {
      daily_active: 0,
      new_registrations: 0,
      returning_users: 0
    },
    features: {
      crystal_identifications: 0,
      guidance_generations: 0,
      seer_credits_earned: 0,
      seer_credits_spent: 0
    },
    performance: {
      avg_identification_time: 0,
      avg_guidance_time: 0,
      error_rate: 0
    }
  }
};

// Main seeding function
async function seedDatabase() {
  console.log('🔮 Starting Crystal Grimoire database seeding...');
  
  try {
    // Seed crystal library
    console.log('📚 Seeding crystal library...');
    const batch1 = db.batch();
    
    for (const crystal of crystalLibraryData) {
      const docRef = db.collection('crystal_library').doc(crystal.id);
      const { id, ...crystalData } = crystal;
      batch1.set(docRef, crystalData);
    }
    
    await batch1.commit();
    console.log(`✅ Seeded ${crystalLibraryData.length} crystals to library`);
    
    // Seed feature flags
    console.log('🚩 Seeding feature flags...');
    const batch2 = db.batch();
    
    for (const flag of featureFlagsData) {
      const docRef = db.collection('feature_flags').doc(flag.id);
      const { id, ...flagData } = flag;
      batch2.set(docRef, {
        ...flagData,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch2.commit();
    console.log(`✅ Seeded ${featureFlagsData.length} feature flags`);
    
    // Seed system notifications
    console.log('📢 Seeding system notifications...');
    const batch3 = db.batch();
    
    for (const notification of systemNotificationsData) {
      const docRef = db.collection('system_notifications').doc(notification.id);
      const { id, ...notificationData } = notification;
      batch3.set(docRef, notificationData);
    }
    
    await batch3.commit();
    console.log(`✅ Seeded ${systemNotificationsData.length} system notifications`);
    
    // Seed analytics template
    console.log('📊 Seeding analytics template...');
    await db.collection('analytics').doc('template').set(analyticsData);
    console.log('✅ Seeded analytics template');
    
    // Create indexes hint document
    await db.collection('_indexes_info').doc('required_indexes').set({
      message: 'Ensure composite indexes are created for optimal performance',
      indexes: [
        'users/{userId}/collection: [addedAt, desc]',
        'users/{userId}/identifications: [createdAt, desc]', 
        'users/{userId}/guidance: [createdAt, desc]',
        'marketplace: [status, createdAt, desc]',
        'crystal_library: [name, asc]',
        'usage: [userId, date]',
        'error_logs: [severity, timestamp, desc]'
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('🎉 Database seeding completed successfully!');
    console.log('\n📋 Next steps:');
    console.log('1. Verify Firestore indexes are created in Firebase Console');
    console.log('2. Upload crystal images to Firebase Storage');
    console.log('3. Configure Firebase Authentication providers');
    console.log('4. Set up Cloud Functions with environment variables');
    console.log('5. Deploy security rules');
    
  } catch (error) {
    console.error('❌ Error seeding database:', error);
    throw error;
  }
}

// Utility function to clean database (use with caution!)
async function cleanDatabase() {
  console.log('🧹 WARNING: This will delete all seeded data!');
  
  const collections = [
    'crystal_library',
    'feature_flags', 
    'system_notifications',
    'analytics',
    '_indexes_info'
  ];
  
  for (const collectionName of collections) {
    const snapshot = await db.collection(collectionName).get();
    const batch = db.batch();
    
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`🗑️ Cleaned collection: ${collectionName}`);
  }
  
  console.log('✅ Database cleaning completed');
}

// Run the seeding process
if (require.main === module) {
  const action = process.argv[2] || 'seed';
  
  if (action === 'seed') {
    seedDatabase()
      .then(() => {
        console.log('🎯 Seeding process finished');
        process.exit(0);
      })
      .catch((error) => {
        console.error('💥 Seeding failed:', error);
        process.exit(1);
      });
  } else if (action === 'clean') {
    cleanDatabase()
      .then(() => {
        console.log('🧽 Cleaning process finished');
        process.exit(0);
      })
      .catch((error) => {
        console.error('💥 Cleaning failed:', error);
        process.exit(1);
      });
  } else {
    console.log('Usage: node seed_database.js [seed|clean]');
    process.exit(1);
  }
}

module.exports = {
  seedDatabase,
  cleanDatabase,
  crystalLibraryData,
  featureFlagsData
};