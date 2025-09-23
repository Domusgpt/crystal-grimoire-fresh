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

const MOON_PHASE_ALIASES = {
  'new moon': 'new',
  new: 'new',
  'dark moon': 'new',
  'waxing crescent': 'waxing',
  'first quarter': 'waxing',
  'waxing gibbous': 'waxing',
  'growth moon': 'waxing',
  'full moon': 'full',
  full: 'full',
  'waning gibbous': 'waning',
  'last quarter': 'waning',
  'third quarter': 'waning',
  'waning crescent': 'waning',
  balsamic: 'waning',
};

const MOON_PHASE_RITUALS = {
  new: {
    label: 'New Moon',
    intention: 'Plant fresh intentions and reset your energetic field.',
    summary: 'Cleanse, write three intentions, and charge them with lunar light.',
    crystals: [
      {
        name: 'Labradorite',
        placement: 'Hold at the heart while speaking each intention.',
        mantra: 'I welcome luminous new beginnings.',
      },
      {
        name: 'Moonstone',
        placement: 'Keep near a candle to amplify intuitive guidance.',
        mantra: 'I trust the rhythm of my inner tides.',
      },
      {
        name: 'Black Tourmaline',
        placement: 'Anchor at the feet to ground new seeds.',
        mantra: 'I am protected as my dreams take root.',
      },
    ],
    steps: [
      'Smoke cleanse or sound bathe your altar for three deep breaths.',
      'Journal three intentions and speak them into your crystals.',
      'Visualize each intention already complete while holding the stones.',
    ],
    breathwork: '4-7-8 breath for four rounds to settle the nervous system.',
    journalPrompts: [
      'What am I ready to invite into this cycle?',
      'Which habits or allies will support these seeds?',
    ],
    herbalAllies: ['Mugwort', 'Blue Lotus'],
    element: 'Water',
    timing: 'Complete within 48 hours of the new moon.',
  },
  waxing: {
    label: 'Waxing Moon',
    intention: 'Build momentum and energize aligned action.',
    summary: 'Clarify next steps, move the body, and charge creative projects.',
    crystals: [
      {
        name: 'Carnelian',
        placement: 'Place over the sacral chakra to spark creativity.',
        mantra: 'I take courageous inspired action.',
      },
      {
        name: 'Citrine',
        placement: 'Keep near your workspace to magnetize prosperity.',
        mantra: 'I radiate joyful confidence.',
      },
      {
        name: 'Sunstone',
        placement: 'Hold at the solar plexus before planning sessions.',
        mantra: 'My willpower is radiant and steady.',
      },
    ],
    steps: [
      'Review your intentions and map one practical action for each.',
      'Charge your action list beneath the crystals for at least one hour.',
      'Move your body (dance, yoga, or a brisk walk) to embody momentum.',
    ],
    breathwork: 'Short fire breath rounds to stoke inner fire.',
    journalPrompts: [
      'Which projects feel most alive right now?',
      'Where can I show up with more confident energy?',
    ],
    herbalAllies: ['Ginger', 'Lemon Balm'],
    element: 'Fire',
    timing: 'Use between waxing crescent and first quarter.',
  },
  full: {
    label: 'Full Moon',
    intention: 'Celebrate wins and release outdated patterns.',
    summary: 'Amplify gratitude, illuminate insights, and clear energetic residue.',
    crystals: [
      {
        name: 'Selenite',
        placement: 'Sweep through the aura to cleanse your field.',
        mantra: 'I am clear, luminous, and open.',
      },
      {
        name: 'Clear Quartz',
        placement: 'Grid around you to magnify intentions.',
        mantra: 'I amplify my highest truths.',
      },
      {
        name: 'Amethyst',
        placement: 'Hold at the third eye during meditation.',
        mantra: 'I receive insight with grace.',
      },
    ],
    steps: [
      'List every accomplishment and blessing from this lunar cycle.',
      'Write down habits or stories ready to release and safely burn or soak the paper.',
      'Meditate under the moonlight with your crystals on the body.',
    ],
    breathwork: 'Even inhale/exhale count (6-6) to harmonize the body.',
    journalPrompts: [
      'What lessons did this cycle reveal?',
      'What am I willing to release to create more space?',
    ],
    herbalAllies: ['Rose', 'Jasmine'],
    element: 'Air',
    timing: 'Use the night of the full moon and the day after for integration.',
  },
  waning: {
    label: 'Waning Moon',
    intention: 'Rest, recalibrate, and close energetic loops.',
    summary: 'Detox stagnant energy, clear cords, and prepare for the next beginning.',
    crystals: [
      {
        name: 'Smoky Quartz',
        placement: 'Place at the root chakra or under the pillow.',
        mantra: 'I gently release what is complete.',
      },
      {
        name: 'Lepidolite',
        placement: 'Hold over the heart to dissolve anxiety.',
        mantra: 'I soften and surrender to rest.',
      },
      {
        name: 'Obsidian',
        placement: 'Keep by the door for energetic cord cutting.',
        mantra: 'I stand protected while I let go.',
      },
    ],
    steps: [
      'Take a salt bath or shower meditation to cleanse residual energy.',
      'Visualize releasing cords or obligations that drain your energy.',
      'Set intentions for rest, journaling, and gentle integration.',
    ],
    breathwork: 'Long exhale breathing (inhale 4, exhale 8) to downshift the nervous system.',
    journalPrompts: [
      'What am I ready to release before the next new moon?',
      'How can I honor rest and recovery this week?',
    ],
    herbalAllies: ['Chamomile', 'Lavender'],
    element: 'Earth',
    timing: 'Ideal from waning gibbous through balsamic moon.',
  },
};

const CHAKRA_ALIASES = {
  root: 'root',
  muladhara: 'root',
  sacral: 'sacral',
  svadhisthana: 'sacral',
  'solar plexus': 'solar',
  manipura: 'solar',
  heart: 'heart',
  anahata: 'heart',
  throat: 'throat',
  vishuddha: 'throat',
  'third eye': 'thirdEye',
  ajna: 'thirdEye',
  brow: 'thirdEye',
  crown: 'crown',
  sahasrara: 'crown',
};

const CHAKRA_LIBRARY = {
  root: {
    name: 'Root',
    focus: 'Grounding & stability',
    color: 'Crimson Red',
    placement: ['Base of spine', 'Under each heel'],
    recommended: ['Black Tourmaline', 'Smoky Quartz', 'Hematite'],
    affirmation: 'I am grounded, safe, and supported.',
    breathwork: 'Box breathing (4-4-4-4).',
    durationMinutes: 10,
  },
  sacral: {
    name: 'Sacral',
    focus: 'Creativity & sensual flow',
    color: 'Amber Orange',
    placement: ['Two inches below the navel'],
    recommended: ['Carnelian', 'Orange Calcite', 'Moonstone'],
    affirmation: 'I honor the waters of my creativity.',
    breathwork: 'Wave breathing with slow hip sways.',
    durationMinutes: 8,
  },
  solar: {
    name: 'Solar Plexus',
    focus: 'Confidence & purpose',
    color: 'Golden Yellow',
    placement: ['Over the diaphragm'],
    recommended: ['Citrine', 'Tiger Eye', 'Pyrite'],
    affirmation: 'I act with clarity and courage.',
    breathwork: 'Short rounds of kapalabhati (fire breath).',
    durationMinutes: 9,
  },
  heart: {
    name: 'Heart',
    focus: 'Love & compassion',
    color: 'Emerald Green',
    placement: ['Center of chest', 'Between shoulder blades'],
    recommended: ['Rose Quartz', 'Green Aventurine', 'Malachite'],
    affirmation: 'I give and receive love freely.',
    breathwork: 'Coherent heart breathing (inhale 5, exhale 5).',
    durationMinutes: 11,
  },
  throat: {
    name: 'Throat',
    focus: 'Truth & expression',
    color: 'Cobalt Blue',
    placement: ['At the throat center'],
    recommended: ['Aquamarine', 'Blue Lace Agate', 'Sodalite'],
    affirmation: 'My voice is clear and compassionate.',
    breathwork: 'Ujjayi breath with gentle sound.',
    durationMinutes: 7,
  },
  thirdEye: {
    name: 'Third Eye',
    focus: 'Intuition & insight',
    color: 'Indigo',
    placement: ['Between the eyebrows'],
    recommended: ['Amethyst', 'Lapis Lazuli', 'Fluorite'],
    affirmation: 'I see with inner wisdom.',
    breathwork: 'Alternate nostril breathing for three minutes.',
    durationMinutes: 7,
  },
  crown: {
    name: 'Crown',
    focus: 'Spiritual connection',
    color: 'Violet / White Light',
    placement: ['Just above the crown of the head'],
    recommended: ['Clear Quartz', 'Selenite', 'Apophyllite'],
    affirmation: 'I am connected to divine guidance.',
    breathwork: 'Slow halo breathing (inhale 6, hold 3, exhale 6).',
    durationMinutes: 6,
  },
};

const CRYSTAL_RECOMMENDATIONS = {
  grounding: [
    {
      id: 'black-tourmaline',
      name: 'Black Tourmaline',
      scientificName: 'Schorl',
      imageUrl: 'https://images.crystalgrimoire.app/black-tourmaline.jpg',
      metaphysicalProperties: {
        healingProperties: ['Grounding', 'Protection'],
        primaryChakras: ['Root'],
        affirmations: ['I am rooted and safe.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Black',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight', 'Earth'],
        storage: 'Store with quartz or hematite to keep clear.',
      },
      healingProperties: ['Grounding', 'Protection'],
      chakras: ['Root'],
      zodiacSigns: ['Capricorn', 'Scorpio'],
      elements: ['Earth'],
      description: 'Stabilizes scattered energy and shields the aura while manifesting intentions.',
    },
    {
      id: 'smoky-quartz',
      name: 'Smoky Quartz',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/smoky-quartz.jpg',
      metaphysicalProperties: {
        healingProperties: ['Transmutation', 'Grounding'],
        primaryChakras: ['Root'],
        affirmations: ['I gently release what no longer serves me.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Brown to Black',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Earth', 'Moonlight'],
        storage: 'Keep away from harsh sunlight to preserve color.',
      },
      healingProperties: ['Grounding', 'Detoxification'],
      chakras: ['Root'],
      zodiacSigns: ['Sagittarius', 'Capricorn'],
      elements: ['Earth'],
      description: 'Transmutes dense energy into usable light and anchors spiritual work.',
    },
  ],
  love: [
    {
      id: 'rose-quartz',
      name: 'Rose Quartz',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/rose-quartz.jpg',
      metaphysicalProperties: {
        healingProperties: ['Self Love', 'Compassion'],
        primaryChakras: ['Heart'],
        affirmations: ['I welcome love with an open heart.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Soft Pink',
      },
      careInstructions: {
        cleansing: ['Moonlight', 'Smoke'],
        charging: ['Moonlight', 'Sound'],
        storage: 'Avoid prolonged sunlight to prevent fading.',
      },
      healingProperties: ['Love', 'Harmony'],
      chakras: ['Heart'],
      zodiacSigns: ['Taurus', 'Libra'],
      elements: ['Water'],
      description: 'Softens the heart and restores compassion for yourself and others.',
    },
    {
      id: 'rhodonite',
      name: 'Rhodonite',
      scientificName: 'Manganese Inosilicate',
      imageUrl: 'https://images.crystalgrimoire.app/rhodonite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Forgiveness', 'Emotional Balance'],
        primaryChakras: ['Heart'],
        affirmations: ['I release old stories and embrace compassion.'],
      },
      physicalProperties: {
        hardness: '5.5 - 6.5',
        color: 'Pink with Black Veins',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Store wrapped to avoid scratches.',
      },
      healingProperties: ['Forgiveness', 'Balance'],
      chakras: ['Heart'],
      zodiacSigns: ['Taurus', 'Leo'],
      elements: ['Earth'],
      description: 'Balances emotional highs and lows while encouraging compassionate dialogue.',
    },
  ],
  protection: [
    {
      id: 'black-obsidian',
      name: 'Black Obsidian',
      scientificName: 'Volcanic Glass',
      imageUrl: 'https://images.crystalgrimoire.app/black-obsidian.jpg',
      metaphysicalProperties: {
        healingProperties: ['Protection', 'Cord Cutting'],
        primaryChakras: ['Root'],
        affirmations: ['I stand in my power and release attachments.'],
      },
      physicalProperties: {
        hardness: '5',
        color: 'Jet Black',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Handle carefully—edges can be sharp.',
      },
      healingProperties: ['Protection', 'Release'],
      chakras: ['Root'],
      zodiacSigns: ['Scorpio', 'Sagittarius'],
      elements: ['Fire'],
      description: 'Creates a mirrored shield and assists with shadow integration.',
    },
    {
      id: 'amethyst',
      name: 'Amethyst',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/amethyst.jpg',
      metaphysicalProperties: {
        healingProperties: ['Spiritual Protection', 'Calm'],
        primaryChakras: ['Third Eye', 'Crown'],
        affirmations: ['My aura is wrapped in violet light.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Purple',
      },
      careInstructions: {
        cleansing: ['Moonlight', 'Smoke'],
        charging: ['Moonlight', 'Sound'],
        storage: 'Keep out of strong sun to avoid fading.',
      },
      healingProperties: ['Protection', 'Intuition'],
      chakras: ['Third Eye', 'Crown'],
      zodiacSigns: ['Pisces', 'Aquarius'],
      elements: ['Air'],
      description: 'Guards against energetic overwhelm and deepens meditation practice.',
    },
  ],
  creativity: [
    {
      id: 'carnelian',
      name: 'Carnelian',
      scientificName: 'Chalcedony',
      imageUrl: 'https://images.crystalgrimoire.app/carnelian.jpg',
      metaphysicalProperties: {
        healingProperties: ['Creativity', 'Confidence'],
        primaryChakras: ['Sacral'],
        affirmations: ['My creative fire burns bright.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Orange',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Sunlight', 'Moonlight'],
        storage: 'Store separately to avoid scratches.',
      },
      healingProperties: ['Creativity', 'Courage'],
      chakras: ['Sacral'],
      zodiacSigns: ['Leo', 'Virgo'],
      elements: ['Fire'],
      description: 'Ignites passion and movement when projects feel stuck.',
    },
    {
      id: 'orange-calcite',
      name: 'Orange Calcite',
      scientificName: 'Calcium Carbonate',
      imageUrl: 'https://images.crystalgrimoire.app/orange-calcite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Inspiration', 'Flow'],
        primaryChakras: ['Sacral'],
        affirmations: ['Inspiration rises effortlessly within me.'],
      },
      physicalProperties: {
        hardness: '3',
        color: 'Translucent Orange',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Keep dry—calcite is water sensitive.',
      },
      healingProperties: ['Creativity', 'Playfulness'],
      chakras: ['Sacral'],
      zodiacSigns: ['Cancer', 'Leo'],
      elements: ['Fire'],
      description: 'Encourages playful experimentation and dissolves creative blocks.',
    },
  ],
  abundance: [
    {
      id: 'pyrite',
      name: 'Pyrite',
      scientificName: 'Iron Sulfide',
      imageUrl: 'https://images.crystalgrimoire.app/pyrite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Prosperity', 'Protection'],
        primaryChakras: ['Solar Plexus'],
        affirmations: ['I magnetize aligned abundance.'],
      },
      physicalProperties: {
        hardness: '6 - 6.5',
        color: 'Brassy Gold',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Sunlight'],
        storage: 'Keep dry to avoid oxidation.',
      },
      healingProperties: ['Abundance', 'Confidence'],
      chakras: ['Solar Plexus'],
      zodiacSigns: ['Leo', 'Aries'],
      elements: ['Earth'],
      description: 'Boosts willpower and magnetizes high-impact opportunities.',
    },
    {
      id: 'citrine',
      name: 'Citrine',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/citrine.jpg',
      metaphysicalProperties: {
        healingProperties: ['Abundance', 'Joy'],
        primaryChakras: ['Solar Plexus', 'Sacral'],
        affirmations: ['I embody luminous prosperity.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Golden Yellow',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Sunlight'],
        storage: 'Store away from intense heat to preserve color.',
      },
      healingProperties: ['Abundance', 'Confidence'],
      chakras: ['Solar Plexus', 'Sacral'],
      zodiacSigns: ['Gemini', 'Leo'],
      elements: ['Fire'],
      description: 'Radiates positivity and keeps abundance practices energized.',
    },
  ],
  clarity: [
    {
      id: 'clear-quartz',
      name: 'Clear Quartz',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/clear-quartz.jpg',
      metaphysicalProperties: {
        healingProperties: ['Amplification', 'Clarity'],
        primaryChakras: ['All'],
        affirmations: ['My mind is clear and receptive.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Clear',
      },
      careInstructions: {
        cleansing: ['Running Water', 'Smoke', 'Sound'],
        charging: ['Sunlight', 'Moonlight'],
        storage: 'Program intentionally and cleanse regularly.',
      },
      healingProperties: ['Clarity', 'Amplification'],
      chakras: ['All'],
      zodiacSigns: ['All'],
      elements: ['All'],
      description: 'Acts as an energetic tuning fork and amplifies any intention.',
    },
    {
      id: 'fluorite',
      name: 'Fluorite',
      scientificName: 'Calcium Fluoride',
      imageUrl: 'https://images.crystalgrimoire.app/fluorite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Focus', 'Mental Order'],
        primaryChakras: ['Third Eye'],
        affirmations: ['I stay organized and attentive.'],
      },
      physicalProperties: {
        hardness: '4',
        color: 'Green/Violet',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Keep away from prolonged sunlight to prevent fading.',
      },
      healingProperties: ['Clarity', 'Focus'],
      chakras: ['Third Eye'],
      zodiacSigns: ['Pisces', 'Capricorn'],
      elements: ['Air'],
      description: 'Organizes scattered thoughts and supports study sessions.',
    },
  ],
  sleep: [
    {
      id: 'lepidolite',
      name: 'Lepidolite',
      scientificName: 'Lithium Mica',
      imageUrl: 'https://images.crystalgrimoire.app/lepidolite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Calm', 'Sleep'],
        primaryChakras: ['Heart', 'Third Eye'],
        affirmations: ['I drift into restorative rest.'],
      },
      physicalProperties: {
        hardness: '2.5 - 3',
        color: 'Lavender',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Keep dry as it can flake.',
      },
      healingProperties: ['Sleep', 'Calm'],
      chakras: ['Heart', 'Third Eye'],
      zodiacSigns: ['Libra', 'Pisces'],
      elements: ['Water'],
      description: 'Soothes the nervous system and encourages deep sleep.',
    },
    {
      id: 'blue-lace-agate',
      name: 'Blue Lace Agate',
      scientificName: 'Chalcedony',
      imageUrl: 'https://images.crystalgrimoire.app/blue-lace-agate.jpg',
      metaphysicalProperties: {
        healingProperties: ['Calm Communication', 'Sleep'],
        primaryChakras: ['Throat'],
        affirmations: ['My inner voice is soft and peaceful.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Pale Blue',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Store with soft cloth to protect banding.',
      },
      healingProperties: ['Calm', 'Rest'],
      chakras: ['Throat'],
      zodiacSigns: ['Pisces', 'Gemini'],
      elements: ['Air'],
      description: 'Releases anxious dialogue and invites tranquil dreams.',
    },
  ],
  anxiety: [
    {
      id: 'howlite',
      name: 'Howlite',
      scientificName: 'Calcium Borosilicate Hydroxide',
      imageUrl: 'https://images.crystalgrimoire.app/howlite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Calm', 'Patience'],
        primaryChakras: ['Crown'],
        affirmations: ['I slow down and breathe.'],
      },
      physicalProperties: {
        hardness: '3.5',
        color: 'White with Grey Veins',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Handle gently to avoid scratches.',
      },
      healingProperties: ['Calm', 'Stress Relief'],
      chakras: ['Crown'],
      zodiacSigns: ['Gemini', 'Virgo'],
      elements: ['Air'],
      description: 'Encourages patience and quiets racing thoughts.',
    },
    {
      id: 'amazonite',
      name: 'Amazonite',
      scientificName: 'Microcline Feldspar',
      imageUrl: 'https://images.crystalgrimoire.app/amazonite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Calm', 'Communication'],
        primaryChakras: ['Heart', 'Throat'],
        affirmations: ['I speak with ease and grace.'],
      },
      physicalProperties: {
        hardness: '6 - 6.5',
        color: 'Teal',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Store away from prolonged sunlight.',
      },
      healingProperties: ['Calm', 'Balance'],
      chakras: ['Heart', 'Throat'],
      zodiacSigns: ['Virgo', 'Aquarius'],
      elements: ['Water'],
      description: 'Balances anxious emotion and supports honest communication.',
    },
  ],
  focus: [
    {
      id: 'tigers-eye',
      name: "Tiger's Eye",
      scientificName: 'Quartz with Crocidolite',
      imageUrl: 'https://images.crystalgrimoire.app/tigers-eye.jpg',
      metaphysicalProperties: {
        healingProperties: ['Focus', 'Courage'],
        primaryChakras: ['Solar Plexus'],
        affirmations: ['I focus with determination.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Golden Brown',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Sunlight'],
        storage: 'Store separately to avoid scratches.',
      },
      healingProperties: ['Focus', 'Confidence'],
      chakras: ['Solar Plexus'],
      zodiacSigns: ['Leo', 'Capricorn'],
      elements: ['Fire'],
      description: 'Balances logic and intuition to keep projects on track.',
    },
    {
      id: 'blue-apatite',
      name: 'Blue Apatite',
      scientificName: 'Calcium Phosphate',
      imageUrl: 'https://images.crystalgrimoire.app/blue-apatite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Focus', 'Motivation'],
        primaryChakras: ['Third Eye', 'Throat'],
        affirmations: ['I stay inspired and on task.'],
      },
      physicalProperties: {
        hardness: '5',
        color: 'Blue-Green',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Handle carefully; it can chip.',
      },
      healingProperties: ['Focus', 'Inspiration'],
      chakras: ['Third Eye', 'Throat'],
      zodiacSigns: ['Gemini', 'Libra'],
      elements: ['Air'],
      description: 'Boosts motivation and sharpens mental clarity for big projects.',
    },
  ],
  intuition: [
    {
      id: 'labradorite',
      name: 'Labradorite',
      scientificName: 'Feldspar',
      imageUrl: 'https://images.crystalgrimoire.app/labradorite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Intuition', 'Protection'],
        primaryChakras: ['Third Eye'],
        affirmations: ['I honor the whispers of my intuition.'],
      },
      physicalProperties: {
        hardness: '6 - 6.5',
        color: 'Iridescent Blue/Green',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Moonlight'],
        charging: ['Moonlight'],
        storage: 'Wrap gently to avoid scratches.',
      },
      healingProperties: ['Intuition', 'Protection'],
      chakras: ['Third Eye'],
      zodiacSigns: ['Sagittarius', 'Leo'],
      elements: ['Water'],
      description: 'Enhances psychic sight while keeping your aura protected.',
    },
    {
      id: 'iolite',
      name: 'Iolite',
      scientificName: 'Cordierite',
      imageUrl: 'https://images.crystalgrimoire.app/iolite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Inner Vision', 'Journeying'],
        primaryChakras: ['Third Eye'],
        affirmations: ['I navigate the unseen realms with grace.'],
      },
      physicalProperties: {
        hardness: '7 - 7.5',
        color: 'Violet-Blue',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Store carefully to prevent scratches.',
      },
      healingProperties: ['Intuition', 'Insight'],
      chakras: ['Third Eye'],
      zodiacSigns: ['Libra', 'Sagittarius'],
      elements: ['Air'],
      description: 'Supports meditation, dreamwork, and shamanic exploration.',
    },
  ],
  transformation: [
    {
      id: 'malachite',
      name: 'Malachite',
      scientificName: 'Copper Carbonate Hydroxide',
      imageUrl: 'https://images.crystalgrimoire.app/malachite.jpg',
      metaphysicalProperties: {
        healingProperties: ['Transformation', 'Protection'],
        primaryChakras: ['Heart', 'Solar Plexus'],
        affirmations: ['I embrace transformation with courage.'],
      },
      physicalProperties: {
        hardness: '3.5 - 4',
        color: 'Green',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Keep dry; copper-based stones can be sensitive to water.',
      },
      healingProperties: ['Transformation', 'Courage'],
      chakras: ['Heart', 'Solar Plexus'],
      zodiacSigns: ['Scorpio', 'Capricorn'],
      elements: ['Earth'],
      description: 'Accelerates growth and protects your aura during rapid change.',
    },
    {
      id: 'moonstone',
      name: 'Rainbow Moonstone',
      scientificName: 'Orthoclase Feldspar',
      imageUrl: 'https://images.crystalgrimoire.app/rainbow-moonstone.jpg',
      metaphysicalProperties: {
        healingProperties: ['Transformation', 'Intuition'],
        primaryChakras: ['Sacral', 'Third Eye'],
        affirmations: ['I flow with cycles of change.'],
      },
      physicalProperties: {
        hardness: '6 - 6.5',
        color: 'Milky with Flash',
      },
      careInstructions: {
        cleansing: ['Moonlight', 'Smoke'],
        charging: ['Moonlight'],
        storage: 'Store separately to avoid scratches.',
      },
      healingProperties: ['Intuition', 'Calm Change'],
      chakras: ['Sacral', 'Third Eye'],
      zodiacSigns: ['Cancer', 'Libra'],
      elements: ['Water'],
      description: 'Supports gentle evolution and aligns you with lunar rhythms.',
    },
  ],
  balance: [
    {
      id: 'clear-quartz-balance',
      name: 'Clear Quartz',
      scientificName: 'Silicon Dioxide',
      imageUrl: 'https://images.crystalgrimoire.app/clear-quartz.jpg',
      metaphysicalProperties: {
        healingProperties: ['Balance', 'Amplification'],
        primaryChakras: ['All'],
        affirmations: ['I am balanced and aligned.'],
      },
      physicalProperties: {
        hardness: '7',
        color: 'Clear',
      },
      careInstructions: {
        cleansing: ['Running Water', 'Smoke'],
        charging: ['Sunlight', 'Moonlight'],
        storage: 'Cleanse often to reset programming.',
      },
      healingProperties: ['Balance', 'Amplification'],
      chakras: ['All'],
      zodiacSigns: ['All'],
      elements: ['All'],
      description: 'Acts as a tuning fork, harmonizing the aura and other stones.',
    },
    {
      id: 'aquamarine',
      name: 'Aquamarine',
      scientificName: 'Beryl',
      imageUrl: 'https://images.crystalgrimoire.app/aquamarine.jpg',
      metaphysicalProperties: {
        healingProperties: ['Balance', 'Calm Communication'],
        primaryChakras: ['Throat'],
        affirmations: ['I speak from centered calm.'],
      },
      physicalProperties: {
        hardness: '7.5 - 8',
        color: 'Aqua Blue',
      },
      careInstructions: {
        cleansing: ['Smoke', 'Sound'],
        charging: ['Moonlight'],
        storage: 'Store away from strong sunlight.',
      },
      healingProperties: ['Balance', 'Calm'],
      chakras: ['Throat'],
      zodiacSigns: ['Pisces', 'Aquarius'],
      elements: ['Water'],
      description: 'Restores equilibrium to the nervous system and supports clear dialogue.',
    },
  ],
};

const RECOMMENDATION_ALIASES = {
  stress: 'anxiety',
  anxious: 'anxiety',
  calm: 'anxiety',
  sleep: 'sleep',
  rest: 'sleep',
  love: 'love',
  romance: 'love',
  relationships: 'love',
  money: 'abundance',
  prosperity: 'abundance',
  success: 'abundance',
  creativity: 'creativity',
  inspiration: 'creativity',
  focus: 'focus',
  study: 'focus',
  clarity: 'clarity',
  protection: 'protection',
  psychic: 'intuition',
  intuition: 'intuition',
  change: 'transformation',
  transformation: 'transformation',
  grounding: 'grounding',
  stability: 'grounding',
  balance: 'balance',
};

const MARKETPLACE_CATEGORIES = ['All', 'Raw', 'Tumbled', 'Clusters', 'Jewelry', 'Rare'];

function resolveRecommendationKey(input) {
  if (!input) {
    return null;
  }
  const normalized = input.toString().trim().toLowerCase();
  if (!normalized) {
    return null;
  }
  if (CRYSTAL_RECOMMENDATIONS[normalized]) {
    return normalized;
  }
  if (RECOMMENDATION_ALIASES[normalized]) {
    return RECOMMENDATION_ALIASES[normalized];
  }
  const fuzzy = Object.keys(CRYSTAL_RECOMMENDATIONS).find((key) => key.includes(normalized));
  return fuzzy || null;
}

function collectRecommendationKeys(data) {
  const keys = new Set();
  const push = (value) => {
    const resolved = resolveRecommendationKey(value);
    if (resolved) {
      keys.add(resolved);
    }
  };

  push(data?.need);
  push(data?.intention);
  push(data?.focus);
  push(data?.mood);

  if (Array.isArray(data?.intentions)) {
    data.intentions.forEach(push);
  }

  if (Array.isArray(data?.tags)) {
    data.tags.forEach(push);
  }

  if (!keys.size) {
    keys.add('balance');
  }

  return Array.from(keys).slice(0, 10);
}

function dedupeCrystalsById(crystals) {
  const seen = new Map();

  crystals.forEach((crystal) => {
    if (!crystal || typeof crystal !== 'object') {
      return;
    }

    const id = getCrystalId(crystal);
    const next = {
      ...crystal,
      id,
      metaphysicalProperties: {
        ...(crystal.metaphysicalProperties || {}),
      },
      physicalProperties: {
        ...(crystal.physicalProperties || {}),
      },
      careInstructions: {
        ...(crystal.careInstructions || {}),
      },
    };

    const intents = new Set();
    if (Array.isArray(crystal.matchedIntents)) {
      crystal.matchedIntents.forEach((intent) => intents.add(intent));
    }
    if (typeof crystal.intent === 'string' && crystal.intent.trim().length) {
      intents.add(crystal.intent.trim());
    }

    if (seen.has(id)) {
      const existing = seen.get(id);
      if (Array.isArray(existing.matchedIntents)) {
        existing.matchedIntents.forEach((intent) => intents.add(intent));
      }

      seen.set(id, {
        ...existing,
        ...next,
        metaphysicalProperties: {
          ...(existing.metaphysicalProperties || {}),
          ...next.metaphysicalProperties,
        },
        physicalProperties: {
          ...(existing.physicalProperties || {}),
          ...next.physicalProperties,
        },
        careInstructions: {
          ...(existing.careInstructions || {}),
          ...next.careInstructions,
        },
        matchedIntents: Array.from(intents).filter(Boolean),
      });
    } else {
      const matchedIntents = Array.from(intents).filter(Boolean);
      if (matchedIntents.length) {
        next.matchedIntents = matchedIntents;
      }
      delete next.intent;
      seen.set(id, next);
    }
  });

  return Array.from(seen.values());
}

function annotateOwnedCrystals(crystals, ownedList) {
  if (!Array.isArray(ownedList) || ownedList.length === 0) {
    return crystals;
  }

  const ownedSet = new Set(
    ownedList
      .map((name) => (typeof name === 'string' ? name.trim().toLowerCase() : null))
      .filter((name) => name && name.length)
  );

  if (!ownedSet.size) {
    return crystals;
  }

  return crystals.map((crystal) => {
    const name = (crystal.name || '').toString().trim().toLowerCase();
    return {
      ...crystal,
      owned: name ? ownedSet.has(name) : false,
    };
  });
}

function toTitleCase(value) {
  if (!value) {
    return '';
  }
  return value
    .toString()
    .trim()
    .toLowerCase()
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function getCrystalId(crystal) {
  if (!crystal) {
    return slugify('crystal');
  }
  if (crystal.id && typeof crystal.id === 'string') {
    return crystal.id;
  }
  if (crystal.name && typeof crystal.name === 'string') {
    return slugify(crystal.name);
  }
  return slugify(`crystal-${Date.now()}`);
}

function slugify(value) {
  return value
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+/, '')
    .replace(/-+$/, '')
    .slice(0, 80);
}

function resolveMarketplaceCategory(input) {
  if (!input || typeof input !== 'string') {
    return 'All';
  }

  const normalized = input.trim().toLowerCase();
  const match = MARKETPLACE_CATEGORIES.find((category) => category.toLowerCase() === normalized);
  return match || 'All';
}

function parseAmountToCents(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value) || value <= 0) {
      return null;
    }
    if (value >= 1000 && Number.isInteger(value)) {
      return Math.floor(value);
    }
    if (value >= 1 && Number.isInteger(value)) {
      return Math.round(value * 100);
    }
    return Math.round(value * 100);
  }

  if (typeof value === 'string') {
    const cleaned = value.replace(/[^0-9.]/g, '').trim();
    if (!cleaned) {
      return null;
    }
    const parsed = Number.parseFloat(cleaned);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return null;
    }
    return parseAmountToCents(parsed);
  }

  return null;
}

function normalizeMoonPhase(phase) {
  if (!phase || typeof phase !== 'string') {
    return null;
  }
  const normalized = phase.trim().toLowerCase();
  return MOON_PHASE_ALIASES[normalized] || null;
}

function buildPersonalizedMoonMessage(profile, phaseLabel, availableCrystals) {
  try {
    if (!profile || typeof profile !== 'object') {
      return `Harness the ${phaseLabel.toLowerCase()} energy to stay aligned with your intentions.`;
    }
    const displayName = (profile.displayName || profile.name || 'Seeker').toString();
    const moonSign = (profile.moonSign || profile?.astrology?.moonSign || '').toString();
    const coreIntention = (profile.primaryIntention || profile.intention || '').toString();
    const parts = [`${displayName}, the ${phaseLabel.toLowerCase()} invites you to realign with your path.`];
    if (moonSign) {
      parts.push(`As a ${moonSign}, lean into rituals that honor your emotional tides.`);
    }
    if (coreIntention) {
      parts.push(`Anchor your ceremony around the intention of ${coreIntention.toLowerCase()}.`);
    }
    if (Array.isArray(availableCrystals) && availableCrystals.length) {
      parts.push(`You already have ${availableCrystals.join(', ')}—perfect allies for this work.`);
    } else {
      parts.push('Consider inviting one of the suggested crystals into your space.');
    }
    return parts.join(' ');
  } catch (error) {
    console.warn('⚠️ Failed to build moon ritual message:', error);
    return `Harness the ${phaseLabel.toLowerCase()} energy to stay aligned with your intentions.`;
  }
}

function normalizeChakraKey(chakra) {
  if (!chakra) {
    return 'root';
  }
  const normalized = chakra.toString().trim().toLowerCase();
  return CHAKRA_ALIASES[normalized] || normalized.replace(/\s+/g, '') || 'root';
}

function personalizeRecommendations(recommendations, profile) {
  if (!profile || typeof profile !== 'object') {
    return recommendations;
  }
  const zodiac = (profile.zodiacSign || profile?.astrology?.sunSign || '').toString().toLowerCase();
  const focusChakra = (profile.focusChakra || profile.primaryChakra || '').toString().toLowerCase();
  const element = (profile.element || profile.preferredElement || '').toString().toLowerCase();

  const scored = recommendations.map((crystal) => ({
    crystal,
    score: scoreCrystalForProfile(crystal, { zodiac, focusChakra, element }),
  }));

  scored.sort((a, b) => b.score - a.score);
  return scored.map((entry) => entry.crystal);
}

function scoreCrystalForProfile(crystal, profile) {
  let score = 0;
  if (profile.zodiac && Array.isArray(crystal.zodiacSigns)) {
    if (crystal.zodiacSigns.some((sign) => sign.toLowerCase() === profile.zodiac)) {
      score += 2;
    }
  }
  if (profile.focusChakra && Array.isArray(crystal.chakras)) {
    if (crystal.chakras.some((chakra) => chakra.toLowerCase().includes(profile.focusChakra))) {
      score += 1.5;
    }
  }
  if (profile.element && Array.isArray(crystal.elements)) {
    if (crystal.elements.some((el) => el.toLowerCase() === profile.element)) {
      score += 1;
    }
  }
  return score;
}

function mapFirestoreCrystalDoc(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    name: data.name || 'Crystal Ally',
    scientificName: data.scientificName || '',
    imageUrl: data.imageUrl || '',
    metaphysicalProperties: data.metaphysicalProperties || {},
    physicalProperties: data.physicalProperties || {},
    careInstructions: data.careInstructions || {},
    healingProperties: Array.isArray(data.healingProperties) ? data.healingProperties : [],
    chakras: Array.isArray(data.chakras) ? data.chakras : [],
    zodiacSigns: Array.isArray(data.zodiacSigns) ? data.zodiacSigns : [],
    elements: Array.isArray(data.elements) ? data.elements : [],
    description: data.description || '',
  };
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

exports.getMoonRituals = onCall(
  { cors: true, memory: '512MiB', timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to receive personalized moon rituals.');
    }

    const userId = request.auth.uid;
    const moonPhaseInput = request.data?.moonPhase;
    const userCrystalsRaw = request.data?.userCrystals;
    const userProfile = request.data?.userProfile || {};

    let normalizedPhase = normalizeMoonPhase(moonPhaseInput);
    let astronomy = null;

    try {
      const moonSnapshot = await db.collection('moonData').doc('current').get();
      if (moonSnapshot.exists) {
        astronomy = moonSnapshot.data() || null;
        if (!normalizedPhase && astronomy && astronomy.phase) {
          normalizedPhase = normalizeMoonPhase(astronomy.phase);
        }
      }
    } catch (error) {
      console.warn('⚠️ Unable to read moonData/current:', error.message);
    }

    if (!normalizedPhase) {
      normalizedPhase = 'full';
    }

    const template = MOON_PHASE_RITUALS[normalizedPhase] || MOON_PHASE_RITUALS.full;
    const userCrystals = Array.isArray(userCrystalsRaw)
      ? userCrystalsRaw.map((name) => name.toString())
      : [];
    const availableSet = new Set(userCrystals.map((name) => name.toLowerCase()));

    const crystals = template.crystals.map((entry) => ({
      ...entry,
      available: availableSet.has(entry.name.toLowerCase()),
    }));

    const response = {
      phase: template.label,
      normalizedPhase,
      intention: template.intention,
      summary: template.summary,
      steps: template.steps,
      crystals,
      breathwork: template.breathwork,
      journalPrompts: template.journalPrompts,
      herbalAllies: template.herbalAllies,
      element: template.element,
      recommendedTiming: template.timing,
      personalizedMessage: buildPersonalizedMoonMessage(
        userProfile,
        template.label,
        crystals.filter((crystal) => crystal.available).map((crystal) => crystal.name),
      ),
      astrology: astronomy
        ? {
            phase: astronomy.phase || template.label,
            illumination: astronomy.illumination ?? null,
            nextPhases: astronomy.nextPhases || null,
            moonrise: astronomy.moonrise || null,
            moonset: astronomy.moonset || null,
          }
        : null,
    };

    try {
      await db
        .collection('users')
        .doc(userId)
        .collection('rituals')
        .add({
          ...response,
          crystals: crystals.map((crystal) => ({
            name: crystal.name,
            available: crystal.available,
          })),
          createdAt: FieldValue.serverTimestamp(),
          source: 'getMoonRituals',
        });
    } catch (error) {
      console.warn('⚠️ Unable to persist moon ritual record:', error.message);
    }

    return response;
  }
);

exports.getCrystalRecommendations = onCall(
  { cors: true, memory: '512MiB', timeoutSeconds: 45 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to receive crystal recommendations.');
    }

    const data = request.data || {};
    const userId = request.auth.uid;
    const keys = collectRecommendationKeys(data);
    const fallbackUsed = !data?.need && keys.length > 0 && keys[0] === 'balance';
    const limit = Number.isInteger(data?.limit)
      ? Math.max(1, Math.min(data.limit, 20))
      : 10;

    const userProfile = (data.userProfile && typeof data.userProfile === 'object')
      ? data.userProfile
      : {};

    const baseRecommendations = keys.flatMap((key) => {
      const entries = CRYSTAL_RECOMMENDATIONS[key] || [];
      return entries.map((entry) => ({
        ...entry,
        source: 'static',
        matchedIntents: [key],
      }));
    });

    let libraryMatches = [];
    try {
      const firestoreKeys = keys.map(toTitleCase).filter(Boolean).slice(0, 10);
      if (firestoreKeys.length) {
        const snapshot = await db
          .collection('crystal_library')
          .where('intents', 'array-contains-any', firestoreKeys)
          .limit(15)
          .get();

        libraryMatches = snapshot.docs.map((doc) => {
          const mapped = mapFirestoreCrystalDoc(doc);
          const raw = doc.data() || {};
          let matchedIntents = [];
          if (Array.isArray(raw.intents)) {
            matchedIntents = raw.intents
              .map((intent) => intent && intent.toString())
              .filter(Boolean)
              .map((intent) => intent.toLowerCase())
              .filter((intent) => keys.includes(intent));
          }

          return {
            ...mapped,
            source: 'library',
            matchedIntents,
          };
        });
      }
    } catch (error) {
      console.warn('⚠️ Unable to load Firestore crystal recommendations:', error.message);
    }

    const combined = dedupeCrystalsById([...baseRecommendations, ...libraryMatches]);

    const profileContext = {
      zodiac: (userProfile.zodiacSign || userProfile?.astrology?.sunSign || '').toString().toLowerCase(),
      focusChakra: (userProfile.focusChakra || userProfile.primaryChakra || '').toString().toLowerCase(),
      element: (userProfile.element || userProfile.preferredElement || '').toString().toLowerCase(),
    };

    const sorted = personalizeRecommendations(combined, userProfile);
    const enriched = sorted.map((crystal) => {
      const score = scoreCrystalForProfile(crystal, profileContext);
      const matchedIntents = Array.isArray(crystal.matchedIntents)
        ? Array.from(new Set(crystal.matchedIntents.map((intent) => intent.toString().toLowerCase())))
        : [];

      return {
        ...crystal,
        score: Math.round(score * 100) / 100,
        matchedIntents,
        source: crystal.source || 'static',
      };
    });

    const ownedCrystals = (() => {
      const raw = Array.isArray(data.ownedCrystals)
        ? data.ownedCrystals
        : Array.isArray(data.userCrystals)
          ? data.userCrystals
          : Array.isArray(data.collection)
            ? data.collection
            : [];
      return raw
        .map((entry) => {
          if (typeof entry === 'string') {
            return entry;
          }
          if (entry && typeof entry === 'object') {
            if (typeof entry.name === 'string') {
              return entry.name;
            }
            if (typeof entry.crystalName === 'string') {
              return entry.crystalName;
            }
          }
          return null;
        })
        .filter((value) => value && value.length);
    })();

    const annotated = annotateOwnedCrystals(enriched, ownedCrystals);
    const limited = annotated.slice(0, limit);

    try {
      await db
        .collection('users')
        .doc(userId)
        .collection('recommendations')
        .add({
          requestedNeed: data.need || null,
          normalizedNeed: keys[0] || null,
          resolvedNeeds: keys,
          fallbackUsed,
          recommendations: limited.map((crystal) => ({
            id: getCrystalId(crystal),
            name: crystal.name || '',
            score: crystal.score || 0,
            matchedIntents: crystal.matchedIntents || [],
            owned: !!crystal.owned,
            source: crystal.source || 'static',
          })),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.warn('⚠️ Unable to persist recommendation snapshot:', error.message);
    }

    const sourceCounts = limited.reduce((acc, crystal) => {
      const source = crystal.source || 'static';
      acc[source] = (acc[source] || 0) + 1;
      return acc;
    }, {});

    console.log(`🔮 Served ${limited.length} crystal recommendations for ${userId} (${keys.join(', ')})`);

    return {
      recommendations: limited,
      metadata: {
        requestedNeed: data.need || null,
        resolvedNeeds: keys,
        limit,
        fallbackUsed,
        sourceCounts,
      },
    };
  }
);

exports.generateHealingLayout = onCall(
  { cors: true, memory: '256MiB', timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to generate a healing layout.');
    }

    const uid = request.auth.uid;
    const data = request.data || {};

    const availableCrystals = Array.isArray(data.availableCrystals)
      ? data.availableCrystals.map((name) => name.toString()).filter((name) => name && name.length)
      : [];

    const targetChakras = Array.isArray(data.targetChakras)
      ? data.targetChakras
      : [];

    const intention = typeof data.intention === 'string'
      ? data.intention.trim()
      : '';

    const fallbackChakras = ['root', 'sacral', 'solar', 'heart', 'throat', 'thirdEye', 'crown'];
    const normalizedChakras = (targetChakras.length ? targetChakras : fallbackChakras)
      .map((chakra) => normalizeChakraKey(chakra))
      .filter((key, index, array) => key && CHAKRA_LIBRARY[key] && array.indexOf(key) === index);

    if (!normalizedChakras.length) {
      normalizedChakras.push('root');
    }

    const availableSet = new Set(
      availableCrystals
        .map((name) => name.toLowerCase().trim())
        .filter((name) => name && name.length)
    );

    const sections = normalizedChakras.map((chakraKey, index) => {
      const chakra = CHAKRA_LIBRARY[chakraKey];
      const recommended = Array.isArray(chakra.recommended) ? chakra.recommended : [];
      const matched = recommended.filter((name) => availableSet.has(name.toLowerCase()));

      return {
        chakraKey,
        chakra: chakra.name,
        focus: chakra.focus,
        placement: chakra.placement,
        affirmation: chakra.affirmation,
        breathwork: chakra.breathwork,
        durationMinutes: chakra.durationMinutes,
        recommendedCrystals: recommended.map((name) => ({
          name,
          available: availableSet.has(name.toLowerCase()),
        })),
        selectedCrystal: matched[0] || recommended[0] || null,
        step: index + 1,
      };
    });

    const duration = sections.reduce((total, section) => total + (section.durationMinutes || 0), 0);

    const layout = {
      intention: intention || 'Holistic chakra realignment',
      totalDurationMinutes: duration + 5,
      sequence: sections,
      summary: intention
        ? `Focus on ${intention.toLowerCase()} while moving energy through ${sections.length} chakra point${sections.length === 1 ? '' : 's'}.`
        : `Guided alignment across ${sections.length} chakra point${sections.length === 1 ? '' : 's'} for full-body harmony.`,
      preparation: [
        'Cleanse your space with smoke, sound, or breath before beginning.',
        'Lay out a comfortable surface and gather each crystal within easy reach.',
        'Silence notifications and set a gentle timer to hold the session container.',
      ],
      integration: [
        'Journal sensations and insights immediately after completing the layout.',
        'Hydrate with mineral-rich water and take a slow grounding walk.',
        'Cleanse and recharge the crystals you used within the next day.',
      ],
      breathwork: 'Begin with three rounds of 4-4-6 breathing to settle the nervous system before placing crystals.',
      chakraKeys: normalizedChakras,
      createdAt: new Date().toISOString(),
    };

    try {
      await db
        .collection('users')
        .doc(uid)
        .collection('healing_sessions')
        .add({
          ...layout,
          availableCrystals,
          status: 'generated',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.warn('⚠️ Unable to persist healing layout:', error.message);
    }

    console.log(`💎 Generated healing layout for ${uid} targeting ${normalizedChakras.join(', ')}`);

    return { layout };
  }
);

exports.createListing = onCall(
  { cors: true, region: 'us-central1', enforceAppCheck: true, timeoutSeconds: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to create a marketplace listing.');
    }

    const data = request.data || {};
    const uid = request.auth.uid;

    if (!data.title || typeof data.title !== 'string' || data.title.trim().length < 5) {
      throw new HttpsError('invalid-argument', 'Listing title must be at least 5 characters long.');
    }

    const title = data.title.trim().slice(0, 80);
    const description = typeof data.description === 'string'
      ? data.description.trim().slice(0, 2000)
      : '';

    let priceCents = parseAmountToCents(data.priceCents);
    if (priceCents === null) {
      priceCents = parseAmountToCents(data.price);
    }
    if (priceCents === null) {
      priceCents = parseAmountToCents(data.amount);
    }

    if (!priceCents || priceCents <= 0) {
      throw new HttpsError('invalid-argument', 'A positive price is required to publish a listing.');
    }

    if (priceCents > 100000) {
      throw new HttpsError('invalid-argument', 'Listings are limited to $1,000 USD.');
    }

    const category = resolveMarketplaceCategory(data.category);
    const currency = typeof data.currency === 'string' && /^[A-Za-z]{3}$/.test(data.currency.trim())
      ? data.currency.trim().toUpperCase()
      : 'USD';
    const imageUrl = typeof data.imageUrl === 'string' && data.imageUrl.trim().length
      ? data.imageUrl.trim()
      : null;
    const crystalId = typeof data.crystalId === 'string' && data.crystalId.trim().length
      ? data.crystalId.trim()
      : slugify(title);

    const inventory = Number.isFinite(data.inventory)
      ? Math.max(1, Math.min(Math.floor(data.inventory), 99))
      : 1;

    const condition = typeof data.condition === 'string' && data.condition.trim().length
      ? data.condition.trim()
      : 'good';

    const sellerName = typeof data.sellerName === 'string' && data.sellerName.trim().length
      ? data.sellerName.trim()
      : request.auth.token?.name || request.auth.token?.email || 'Crystal Seller';

    const listingPayload = {
      title,
      description,
      priceCents,
      sellerId: uid,
      sellerName,
      status: 'active',
      category,
      crystalId,
      currency,
      imageUrl,
      isVerifiedSeller: Boolean(data.isVerifiedSeller && request.auth.token?.admin === true),
      rating: typeof data.rating === 'number'
        ? Math.min(Math.max(data.rating, 0), 5)
        : 5,
      inventory,
      condition,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (!listingPayload.imageUrl) {
      delete listingPayload.imageUrl;
    }

    const tags = Array.isArray(data.tags)
      ? Array.from(new Set(
          data.tags
            .map((tag) => (typeof tag === 'string' ? tag.trim() : null))
            .filter((tag) => tag && tag.length)
        )).slice(0, 10)
      : [];

    if (tags.length) {
      listingPayload.tags = tags;
    }

    if (data.shipping && typeof data.shipping === 'object') {
      const shipping = { ...data.shipping };
      if (Array.isArray(shipping.regions)) {
        shipping.regions = Array.from(new Set(
          shipping.regions
            .map((region) => (typeof region === 'string' ? region.trim() : null))
            .filter((region) => region && region.length)
        )).slice(0, 10);
      }
      listingPayload.shipping = shipping;
    }

    const listingRef = await db.collection('marketplace').add(listingPayload);

    try {
      await db
        .collection('users')
        .doc(uid)
        .collection('marketplaceListings')
        .doc(listingRef.id)
        .set({
          listingId: listingRef.id,
          title,
          priceCents,
          currency,
          category,
          status: 'active',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    } catch (error) {
      console.warn('⚠️ Unable to write marketplace listing summary for user:', error.message);
    }

    console.log(`🛒 Marketplace listing ${listingRef.id} created by ${uid}`);

    return {
      listingId: listingRef.id,
      status: 'active',
      priceCents,
      currency,
      category,
      crystalId,
    };
  }
);

exports.processPayment = onCall(
  { cors: true, region: 'us-central1', enforceAppCheck: true, timeoutSeconds: 30 },
  async (request) => {
    ensureStripeConfigured();

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to process payments.');
    }

    const data = request.data || {};
    const uid = request.auth.uid;

    let amountCents = parseAmountToCents(data.amountCents);
    if (amountCents === null) {
      amountCents = parseAmountToCents(data.amount);
    }
    if (amountCents === null) {
      amountCents = parseAmountToCents(data.priceCents);
    }

    const listingId = typeof data.listingId === 'string' && data.listingId.trim().length
      ? data.listingId.trim()
      : null;

    let listingData = null;
    if (listingId) {
      try {
        const snapshot = await db.collection('marketplace').doc(listingId).get();
        if (snapshot.exists) {
          listingData = snapshot.data() || null;
          if (!amountCents) {
            amountCents = parseAmountToCents(listingData?.priceCents);
          }
        } else {
          console.warn(`⚠️ Listing ${listingId} not found while processing payment.`);
        }
      } catch (error) {
        console.warn('⚠️ Unable to fetch marketplace listing for payment:', error.message);
      }
    }

    if (!amountCents || amountCents <= 0) {
      throw new HttpsError('invalid-argument', 'A positive amount is required to process payment.');
    }

    if (amountCents > 200000) {
      throw new HttpsError('invalid-argument', 'Payments above $2,000 are not supported at this time.');
    }

    const currency = typeof data.currency === 'string' && /^[A-Za-z]{3}$/.test(data.currency.trim())
      ? data.currency.trim().toLowerCase()
      : (listingData?.currency ? String(listingData.currency).toLowerCase() : 'usd');

    const paymentMethodId = typeof data.paymentMethodId === 'string' && data.paymentMethodId.trim().length
      ? data.paymentMethodId.trim()
      : null;

    const purpose = typeof data.purpose === 'string' && data.purpose.trim().length
      ? data.purpose.trim()
      : (listingId ? 'marketplace' : 'subscription');

    const receiptEmail = typeof data.receiptEmail === 'string' && data.receiptEmail.trim().length
      ? data.receiptEmail.trim()
      : request.auth.token?.email || null;

    const metadata = {
      uid,
      purpose,
      listingId: listingId || '',
      source: 'processPayment',
    };

    if (listingData?.sellerId) {
      metadata.sellerId = listingData.sellerId;
    }

    const paymentParams = {
      amount: amountCents,
      currency,
      automatic_payment_methods: { enabled: true },
      metadata,
    };

    if (listingData?.title) {
      paymentParams.description = `Crystal Marketplace • ${listingData.title}`;
    } else if (typeof data.description === 'string' && data.description.trim().length) {
      paymentParams.description = data.description.trim();
    }

    if (paymentMethodId) {
      paymentParams.payment_method = paymentMethodId;
      paymentParams.confirm = true;
    }

    const customerId = typeof data.customerId === 'string' && data.customerId.trim().length
      ? data.customerId.trim()
      : null;
    if (customerId) {
      paymentParams.customer = customerId;
    }

    if (receiptEmail) {
      paymentParams.receipt_email = receiptEmail;
    }

    try {
      const paymentIntent = await stripeClient.paymentIntents.create(paymentParams);

      const paymentRecord = {
        paymentIntentId: paymentIntent.id,
        amountCents,
        currency: currency.toUpperCase(),
        status: paymentIntent.status,
        purpose,
        listingId,
        sellerId: listingData?.sellerId || null,
        listingPriceCents: listingData?.priceCents || null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await db
        .collection('users')
        .doc(uid)
        .collection('payments')
        .doc(paymentIntent.id)
        .set(paymentRecord, { merge: true });

      if (listingId) {
        try {
          await db
            .collection('marketplace_orders')
            .doc(paymentIntent.id)
            .set({
              listingId,
              buyerId: uid,
              sellerId: listingData?.sellerId || null,
              amountCents,
              currency: currency.toUpperCase(),
              status: paymentIntent.status,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
        } catch (error) {
          console.warn('⚠️ Unable to persist marketplace order record:', error.message);
        }
      }

      console.log(`💸 Processed payment intent ${paymentIntent.id} for ${uid}`);

      return {
        paymentIntentId: paymentIntent.id,
        clientSecret: paymentIntent.client_secret,
        status: paymentIntent.status,
        requiresAction: paymentIntent.status === 'requires_action',
      };
    } catch (error) {
      console.error('❌ Payment processing error:', error);
      throw new HttpsError('internal', error.message || 'Failed to process payment.');
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