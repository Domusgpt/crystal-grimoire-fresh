// Crystal Grimoire Database Seeding Script
// Seeds the Firestore database with essential data for launch

const fs = require('fs');
const path = require('path');

let admin;
try {
  // Prefer a top-level installation so the script can run independently
  admin = require('firebase-admin');
} catch (error) {
  const fallbackPath = path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin');
  try {
    admin = require(fallbackPath);
  } catch (innerError) {
    console.error('❌ firebase-admin is not installed. Run "npm install firebase-admin" or install dependencies in functions/.');
    throw error;
  }
}

const {
  PLAN_DETAILS,
  PLAN_ALIASES,
  PLAN_CATALOG_METADATA,
} = require('../functions/src/plan_catalog');

const args = process.argv.slice(2);
const options = args.reduce((acc, arg) => {
  if (arg.startsWith('--project=')) {
    acc.project = arg.split('=')[1];
  } else if (arg.startsWith('--serviceAccount=')) {
    acc.serviceAccount = arg.split('=')[1];
  } else if (arg === '--dry-run') {
    acc.dryRun = true;
  }
  return acc;
}, { dryRun: false });

function loadServiceAccount() {
  if (options.serviceAccount) {
    const resolvedPath = path.resolve(options.serviceAccount);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`Service account file not found: ${resolvedPath}`);
    }
    return JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT && fs.existsSync(process.env.FIREBASE_SERVICE_ACCOUNT)) {
    return JSON.parse(fs.readFileSync(process.env.FIREBASE_SERVICE_ACCOUNT, 'utf8'));
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    return JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));
  }

  return null;
}

function initializeFirebase() {
  if (admin.apps.length) {
    return;
  }

  const serviceAccount = loadServiceAccount();
  const projectId = options.project
    || process.env.FIREBASE_PROJECT_ID
    || serviceAccount?.project_id
    || process.env.GCLOUD_PROJECT
    || 'crystal-grimoire-dev';

  const initConfig = {
    projectId,
  };

  if (serviceAccount) {
    initConfig.credential = admin.credential.cert(serviceAccount);
  } else {
    initConfig.credential = admin.credential.applicationDefault();
  }

  initConfig.databaseURL = `https://${projectId}.firebaseio.com`;

  admin.initializeApp(initConfig);
  console.log(`🔮 Initialized Firebase Admin for project: ${projectId}`);
}

initializeFirebase();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

async function commitBatch(batch, description) {
  if (options.dryRun) {
    console.log(`🛑 Dry run: skipping commit for ${description}`);
    return;
  }
  await batch.commit();
  console.log(`✅ ${description}`);
}

async function setDocument(ref, data, description, merge = true) {
  if (options.dryRun) {
    console.log(`🛑 Dry run: skipping write for ${description}`);
    return;
  }
  if (merge) {
    await ref.set(data, { merge: true });
  } else {
    await ref.set(data);
  }
  console.log(`✅ ${description}`);
}

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

const ECONOMY_DAILY_LIMITS = {
  share_card: 3,
  meditation_complete: 1,
  crystal_identify_new: 3,
  journal_entry: 1,
  ritual_complete: 1,
};

async function seedPlanCatalog() {
  console.log('🏷️ Seeding plan catalog metadata...');

  await setDocument(
    db.collection('config').doc('plan_aliases'),
    {
      aliasMap: PLAN_ALIASES,
      updatedAt: FieldValue.serverTimestamp(),
    },
    'Updated plan alias map'
  );

  const planOrder = Object.keys(PLAN_DETAILS);
  for (const planId of planOrder) {
    const plan = PLAN_DETAILS[planId];
    const metadata = PLAN_CATALOG_METADATA[planId] || {};
    const features = Array.isArray(metadata.features) ? [...metadata.features] : [];

    await setDocument(
      db.collection('plan_catalog').doc(planId),
      {
        planId,
        displayName: metadata.displayName || planId,
        tagline: metadata.tagline || '',
        displayPrice: metadata.displayPrice || (planId === 'free' ? 'Free' : 'Configure in Stripe'),
        stripePriceId: metadata.stripePriceId || '',
        recommended: metadata.recommended === true,
        billingCycle: metadata.billingCycle || (plan.lifetime ? 'lifetime' : 'recurring'),
        lifetime: plan.lifetime === true,
        features,
        effectiveLimits: plan.effectiveLimits,
        flags: plan.flags,
        sortOrder: typeof metadata.sortOrder === 'number' ? metadata.sortOrder : planOrder.indexOf(planId),
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      `Seeded plan catalog entry ${planId}`
    );
  }
}

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
    
    await commitBatch(batch1, `Seeded ${crystalLibraryData.length} crystals to library`);
    
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
    
    await commitBatch(batch2, `Seeded ${featureFlagsData.length} feature flags`);

    await seedPlanCatalog();

    // Seed system notifications
    console.log('📢 Seeding system notifications...');
    const batch3 = db.batch();
    
    for (const notification of systemNotificationsData) {
      const docRef = db.collection('system_notifications').doc(notification.id);
      const { id, ...notificationData } = notification;
      batch3.set(docRef, notificationData);
    }
    
    await commitBatch(batch3, `Seeded ${systemNotificationsData.length} system notifications`);
    
    // Seed analytics template
    console.log('📊 Seeding analytics template...');
    await setDocument(
      db.collection('analytics').doc('template'),
      analyticsData,
      'Seeded analytics template',
      false
    );

    // Create indexes hint document
    await setDocument(
      db.collection('_indexes_info').doc('required_indexes'),
      {
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
        createdAt: FieldValue.serverTimestamp()
      },
      'Documented required indexes'
    );

    // Seed demo user and dependent data
    const demoUid = 'demo-user';
    console.log('👤 Seeding demo user and starter content...');
    await setDocument(
      db.collection('users').doc(demoUid),
      {
        email: 'demo@crystalgrimoire.app',
        profile: {
          displayName: 'Demo Mystic',
          subscriptionTier: 'free',
          subscriptionStatus: 'active',
          subscriptionProvider: 'manual',
          subscriptionUpdatedAt: FieldValue.serverTimestamp(),
          effectiveLimits: {
            identifyPerDay: 3,
            guidancePerDay: 1,
            dreamAnalysesPerDay: 1,
            recommendationsPerDay: 2,
            moonRitualsPerDay: 1,
            journalMax: 50,
            collectionMax: 50,
          },
        },
        settings: {
          theme: 'lunar',
          notifications: true,
          locale: 'en',
        },
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Created demo user profile'
    );

    await setDocument(
      db.collection('users').doc(demoUid).collection('collection').doc('clear-quartz-demo'),
      {
        libraryRef: 'clear-quartz',
        notes: 'First crystal in the demo collection.',
        tags: ['clarity', 'amplify'],
        addedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Seeded demo collection entry'
    );

    await setDocument(
      db.collection('users').doc(demoUid).collection('dreams').doc('demo-dream'),
      {
        content: 'I was walking through a moonlit forest holding a glowing amethyst.',
        analysis: 'Themes of intuition and protection surround this dream. Lean into trust.',
        crystalSuggestions: [
          { name: 'Amethyst', reason: 'Supports intuitive clarity', usage: 'Keep beside the bed' },
          { name: 'Moonstone', reason: 'Harmonises lunar energy', usage: 'Wear as a pendant overnight' },
        ],
        dreamDate: FieldValue.serverTimestamp(),
        crystalsUsed: ['Amethyst'],
        mood: 'Curious',
        moonPhase: 'waxing_gibbous',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Seeded demo dream journal entry'
    );

    await setDocument(
      db.collection('users').doc(demoUid).collection('ritual_preferences').doc('lunar-reset'),
      {
        phase: 'full_moon',
        intention: 'Release stagnation and recharge',
        moonMetadata: {
          hemisphere: 'northern',
          favoriteCrystals: ['Clear Quartz', 'Moonstone'],
        },
        submittedBy: demoUid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Seeded demo ritual preference'
    );

    await setDocument(
      db.collection('users').doc(demoUid).collection('economy').doc('credits'),
      {
        credits: 5,
        lifetimeEarned: 12,
        lifetimeCreditsEarned: 12,
        dailyEarnCount: { daily_checkin: 1 },
        dailyLimits: ECONOMY_DAILY_LIMITS,
        lastResetDate: new Date().toISOString().split('T')[0],
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Seeded demo Seer Credits wallet'
    );

    await setDocument(
      db.collection('users').doc(demoUid).collection('plan').doc('active'),
      {
        plan: 'free',
        billingTier: 'free',
        provider: 'manual',
        priceId: null,
        effectiveLimits: {
          identifyPerDay: 3,
          guidancePerDay: 1,
          dreamAnalysesPerDay: 1,
          recommendationsPerDay: 2,
          moonRitualsPerDay: 1,
          journalMax: 50,
          collectionMax: 50,
        },
        flags: ['free'],
        willRenew: false,
        lifetime: false,
        status: 'active',
        updatedAt: FieldValue.serverTimestamp(),
      },
      'Seeded demo subscription record'
    );

    console.log('🛍️ Seeding marketplace listing prototype...');
    await setDocument(
      db.collection('marketplace').doc('clear-quartz-demo-listing'),
      {
        title: 'Clarity Beacon Clear Quartz',
        crystalId: 'clear-quartz',
        priceCents: 3800,
        sellerId: demoUid,
        status: 'pending_review',
        description: 'Hand-selected clear quartz point programmed for clarity rituals.',
        sellerName: 'Demo Mystic',
        category: 'Clusters',
        imageUrl: 'https://example.com/images/clear-quartz.jpg',
        isVerifiedSeller: false,
        rating: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        moderation: {
          status: 'pending',
          submittedAt: FieldValue.serverTimestamp(),
        },
      },
      'Seeded marketplace sample listing'
    );

    await setDocument(
      db.collection('moonData').doc('current'),
      {
        phase: 'waxing_gibbous',
        emoji: '🌔',
        illumination: 78,
        timestamp: new Date().toISOString(),
        nextFullMoon: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
        nextNewMoon: new Date(Date.now() + 18 * 24 * 60 * 60 * 1000).toISOString(),
        lastSeededAt: FieldValue.serverTimestamp(),
      },
      'Seeded current moon data snapshot'
    );

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
    '_indexes_info',
    'plan_catalog',
    'config'
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
  const action = args.find((value) => !value.startsWith('--')) || 'seed';
  
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