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

const ECONOMY_EARN_RULES = {
  onboarding_complete: 3,
  daily_checkin: 2,
  share_card: 1,
  meditation_complete: 1,
  crystal_identify_new: 1,
  journal_entry: 1,
  ritual_complete: 1,
};

const ECONOMY_SPEND_RULES = {
  extra_identify: 1,
  extra_guidance: 1,
  priority_queue: 2,
  theme_unlock: 5,
};

const ECONOMY_DAILY_LIMITS = {
  share_card: 3,
  meditation_complete: 1,
  crystal_identify_new: 3,
  journal_entry: 1,
  ritual_complete: 1,
};

const CRYSTAL_LIBRARY = [
  {
    id: 'clear-quartz',
    name: 'Clear Quartz',
    variety: 'Crystalline Quartz',
    scientificName: 'Silicon Dioxide',
    description: 'The master healer that amplifies intentions, clears stagnation, and harmonizes all other crystals.',
    imageUrl: '',
    keywords: ['clarity', 'focus', 'amplify', 'manifest'],
    intents: ['clarity', 'manifestation', 'healing', 'focus'],
    colors: ['clear', 'white'],
    chakras: ['Crown', 'All Chakras'],
    zodiacSigns: ['All'],
    elements: ['Air'],
    metaphysicalProperties: {
      healing_properties: ['Amplifies energy', 'Promotes clarity', 'Energises intentions'],
      primary_chakras: ['Crown', 'All Chakras'],
      zodiac_signs: ['All'],
      elements: ['Air'],
      affirmations: ['I am a clear channel for divine light.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Hexagonal',
    },
    careInstructions: {
      cleansing: ['Smoke cleanse', 'Moonlight bath', 'Sound bowl'],
      charging: ['Sunrise light', 'Full moon exposure', 'Selenite plate'],
      storage: ['Store separate from softer stones to avoid scratches.'],
      usage: ['Meditate holding the point toward you to amplify clarity.'],
    },
    cautions: ['Avoid intense midday sun to prevent energetic overwhelm.'],
    identification: {
      name: 'Clear Quartz',
      confidence: 95,
      variety: 'Crystalline Quartz',
    },
    properties: ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
    highlight: true,
  },
  {
    id: 'amethyst',
    name: 'Amethyst',
    variety: 'Purple Quartz',
    scientificName: 'Silicon Dioxide',
    description: 'A spiritual guardian that calms the nervous system, supports intuition, and protects energetic boundaries.',
    imageUrl: '',
    keywords: ['calm', 'protect', 'dreams', 'intuition'],
    intents: ['calm', 'intuition', 'protection', 'sleep'],
    colors: ['purple', 'violet'],
    chakras: ['Third Eye', 'Crown'],
    zodiacSigns: ['Pisces', 'Virgo', 'Aquarius', 'Capricorn'],
    elements: ['Air'],
    metaphysicalProperties: {
      healing_properties: ['Encourages restful sleep', 'Protects aura', 'Deepens meditation'],
      primary_chakras: ['Third Eye', 'Crown'],
      zodiac_signs: ['Pisces', 'Virgo', 'Aquarius', 'Capricorn'],
      elements: ['Air'],
      affirmations: ['My intuition is protected and clear.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Moonlight', 'Sound bowl', 'Smoke'],
      charging: ['Moonlight', 'Amethyst cluster', 'Visualization'],
      storage: ['Keep away from prolonged direct sunlight to preserve colour.'],
      usage: ['Place on nightstand for lucid dreams and restful sleep.'],
    },
    cautions: ['Colour may fade with extended sun exposure.'],
    identification: {
      name: 'Amethyst',
      confidence: 92,
      variety: 'Purple Quartz',
    },
    properties: ['Spiritual Growth', 'Protection', 'Clarity', 'Peace', 'Intuition'],
    highlight: true,
  },
  {
    id: 'rose-quartz',
    name: 'Rose Quartz',
    variety: 'Pink Quartz',
    scientificName: 'Silicon Dioxide',
    description: 'A gentle heart healer that nurtures compassion, forgiveness, and deep self-love.',
    imageUrl: '',
    keywords: ['love', 'compassion', 'heart'],
    intents: ['love', 'compassion', 'emotional healing'],
    colors: ['pink'],
    chakras: ['Heart'],
    zodiacSigns: ['Taurus', 'Libra'],
    elements: ['Water'],
    metaphysicalProperties: {
      healing_properties: ['Opens the heart chakra', 'Invites compassion', 'Soothes grief'],
      primary_chakras: ['Heart'],
      zodiac_signs: ['Taurus', 'Libra'],
      elements: ['Water'],
      affirmations: ['I am worthy of infinite love.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Smoke cleanse', 'Moonlight', 'Gentle water rinse'],
      charging: ['Moonlight', 'Self-love meditation'],
      storage: ['Wrap in soft cloth to prevent chips.'],
      usage: ['Place over heart centre during meditation to invite compassion.'],
    },
    cautions: ['Avoid harsh cleansers; polish gently.'],
    identification: {
      name: 'Rose Quartz',
      confidence: 90,
      variety: 'Pink Quartz',
    },
    properties: ['Love', 'Compassion', 'Healing', 'Peace', 'Self-Love'],
    highlight: true,
  },
  {
    id: 'black-tourmaline',
    name: 'Black Tourmaline',
    variety: 'Schorl',
    scientificName: 'Sodium Iron Aluminium Borosilicate',
    description: 'A protective shield that grounds excess energy and transforms dense vibrations.',
    imageUrl: '',
    keywords: ['protection', 'grounding', 'shield'],
    intents: ['protection', 'grounding', 'purification'],
    colors: ['black'],
    chakras: ['Root'],
    zodiacSigns: ['Capricorn', 'Libra'],
    elements: ['Earth'],
    metaphysicalProperties: {
      healing_properties: ['Deflects negativity', 'Supports grounding', 'Stabilises anxious thoughts'],
      primary_chakras: ['Root'],
      zodiac_signs: ['Capricorn', 'Libra'],
      elements: ['Earth'],
      affirmations: ['I am protected and rooted in the Earth.'],
    },
    physicalProperties: {
      composition: 'Na(Fe,Mg)₃Al₆(BO₃)₃Si₆O₁₈(OH)₄',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Salt bed (dry)', 'Sound bowl', 'Earth burial (short term)'],
      charging: ['Moonlight', 'Sunset light'],
      storage: ['Keep near entryways or tech for EMF shielding.'],
      usage: ['Hold during meditation to release heavy emotions into the earth.'],
    },
    cautions: ['Avoid water cleansing to protect striations.'],
    identification: {
      name: 'Black Tourmaline',
      confidence: 88,
      variety: 'Schorl',
    },
    properties: ['Protection', 'Grounding', 'Purification', 'Stability'],
    highlight: true,
  },
  {
    id: 'citrine',
    name: 'Citrine',
    variety: 'Yellow Quartz',
    scientificName: 'Silicon Dioxide',
    description: 'The sun-kissed stone of joy, abundance, and creative momentum.',
    imageUrl: '',
    keywords: ['abundance', 'joy', 'confidence'],
    intents: ['abundance', 'joy', 'confidence', 'creativity'],
    colors: ['yellow', 'gold'],
    chakras: ['Solar Plexus', 'Sacral'],
    zodiacSigns: ['Gemini', 'Aries', 'Leo'],
    elements: ['Fire'],
    metaphysicalProperties: {
      healing_properties: ['Attracts prosperity', 'Boosts confidence', 'Energises creativity'],
      primary_chakras: ['Solar Plexus', 'Sacral'],
      zodiac_signs: ['Gemini', 'Aries', 'Leo'],
      elements: ['Fire'],
      affirmations: ['I radiate confident creative energy.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Sound bath', 'Smoke cleanse'],
      charging: ['Morning sunlight (short exposure)', 'Visualization'],
      storage: ['Avoid intense heat to preserve natural colour.'],
      usage: ['Place on workspace for momentum and creative focus.'],
    },
    cautions: ['Prolonged sun exposure can fade colour.'],
    identification: {
      name: 'Citrine',
      confidence: 91,
      variety: 'Yellow Quartz',
    },
    properties: ['Abundance', 'Joy', 'Creativity', 'Success', 'Energy'],
    highlight: true,
  },
  {
    id: 'selenite',
    name: 'Selenite',
    variety: 'Gypsum',
    scientificName: 'Calcium Sulfate Dihydrate',
    description: 'An angelic wand of light that purifies, uplifts, and refreshes stagnant energy.',
    imageUrl: '',
    keywords: ['cleansing', 'clarity', 'angelic'],
    intents: ['cleansing', 'clarity', 'spiritual connection'],
    colors: ['white'],
    chakras: ['Crown', 'Third Eye'],
    zodiacSigns: ['Cancer', 'Taurus'],
    elements: ['Air'],
    metaphysicalProperties: {
      healing_properties: ['Cleanses auric field', 'Activates crown chakra', 'Connects with guides'],
      primary_chakras: ['Crown', 'Third Eye'],
      zodiac_signs: ['Cancer', 'Taurus'],
      elements: ['Air'],
      affirmations: ['My energy is luminous and clear.'],
    },
    physicalProperties: {
      composition: 'CaSO₄·2H₂O',
      hardness: '2',
      crystal_system: 'Monoclinic',
    },
    careInstructions: {
      cleansing: ['Sound bowl', 'Visualization', 'Smoke'],
      charging: ['Moonlight', 'Breathwork'],
      storage: ['Keep dry; selenite is water-soluble.'],
      usage: ['Sweep the aura to clear energetic residue.'],
    },
    cautions: ['Never submerge in water. Handle gently to avoid scratching.'],
    identification: {
      name: 'Selenite',
      confidence: 89,
      variety: 'Gypsum',
    },
    properties: ['Cleansing', 'Charging', 'Clarity', 'Peace'],
    highlight: true,
  },
  {
    id: 'labradorite',
    name: 'Labradorite',
    variety: 'Feldspar',
    scientificName: 'Calcium Sodium Aluminum Silicate',
    description: 'A shimmering veil between worlds that awakens intuition and shields the aura.',
    imageUrl: '',
    keywords: ['intuition', 'magic', 'protection'],
    intents: ['intuition', 'transformation', 'protection'],
    colors: ['blue', 'green', 'gold'],
    chakras: ['Third Eye', 'Throat'],
    zodiacSigns: ['Scorpio', 'Sagittarius', 'Leo'],
    elements: ['Water'],
    metaphysicalProperties: {
      healing_properties: ['Strengthens intuition', 'Protects during transformation', 'Stimulates imagination'],
      primary_chakras: ['Third Eye', 'Throat'],
      zodiac_signs: ['Scorpio', 'Sagittarius', 'Leo'],
      elements: ['Water'],
      affirmations: ['I trust the magic within my unfolding path.'],
    },
    physicalProperties: {
      composition: '(Ca,Na)(Al,Si)₄O₈',
      hardness: '6 - 6.5',
      crystal_system: 'Triclinic',
    },
    careInstructions: {
      cleansing: ['Smoke', 'Sound', 'Moonlight'],
      charging: ['New moon intention', 'Visualization'],
      storage: ['Wrap to avoid surface scratches.'],
      usage: ['Hold during meditation to open the third eye.'],
    },
    cautions: ['Avoid chemical cleaners to preserve iridescence.'],
    identification: {
      name: 'Labradorite',
      confidence: 87,
      variety: 'Feldspar',
    },
    properties: ['Transformation', 'Intuition', 'Protection', 'Magic'],
  },
  {
    id: 'moonstone',
    name: 'Moonstone',
    variety: 'Orthoclase Feldspar',
    scientificName: 'Potassium Aluminum Silicate',
    description: 'A luminescent talisman for intuition, emotional balance, and honoring lunar cycles.',
    imageUrl: '',
    keywords: ['intuition', 'cycles', 'feminine'],
    intents: ['intuition', 'emotional balance', 'dreams'],
    colors: ['white', 'peach', 'blue'],
    chakras: ['Crown', 'Sacral'],
    zodiacSigns: ['Cancer', 'Scorpio'],
    elements: ['Water'],
    metaphysicalProperties: {
      healing_properties: ['Balances emotions', 'Enhances dreams', 'Supports new beginnings'],
      primary_chakras: ['Crown', 'Sacral'],
      zodiac_signs: ['Cancer', 'Scorpio'],
      elements: ['Water'],
      affirmations: ['I flow gracefully with life’s cycles.'],
    },
    physicalProperties: {
      composition: 'KAlSi₃O₈',
      hardness: '6 - 6.5',
      crystal_system: 'Monoclinic',
    },
    careInstructions: {
      cleansing: ['Moonlight', 'Smoke', 'Sound'],
      charging: ['Full moon', 'Meditation'],
      storage: ['Keep separate from harder stones to prevent scratches.'],
      usage: ['Place under pillow for prophetic dreams.'],
    },
    cautions: ['Avoid salt water cleansing.'],
    identification: {
      name: 'Moonstone',
      confidence: 88,
      variety: 'Orthoclase Feldspar',
    },
    properties: ['Intuition', 'Dreams', 'Emotional Balance', 'New Beginnings'],
  },
  {
    id: 'smoky-quartz',
    name: 'Smoky Quartz',
    variety: 'Brown Quartz',
    scientificName: 'Silicon Dioxide',
    description: 'A grounding ally that transmutes anxiety into centred action.',
    imageUrl: '',
    keywords: ['grounding', 'detox', 'calm'],
    intents: ['grounding', 'stress relief', 'detox'],
    colors: ['brown', 'grey'],
    chakras: ['Root'],
    zodiacSigns: ['Capricorn', 'Sagittarius'],
    elements: ['Earth'],
    metaphysicalProperties: {
      healing_properties: ['Releases fear', 'Anchors scattered energy', 'Supports detoxification'],
      primary_chakras: ['Root'],
      zodiac_signs: ['Capricorn', 'Sagittarius'],
      elements: ['Earth'],
      affirmations: ['I am grounded, secure, and present.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Smoke', 'Sound', 'Earth burial (brief)'],
      charging: ['Morning sunlight', 'Visualization'],
      storage: ['Keep near doorway to filter energy.'],
      usage: ['Hold during breathwork to release anxiety.'],
    },
    cautions: ['Rinse quickly if using water cleansing.'],
    identification: {
      name: 'Smoky Quartz',
      confidence: 86,
      variety: 'Brown Quartz',
    },
    properties: ['Grounding', 'Protection', 'Stress Relief', 'Purification'],
  },
  {
    id: 'carnelian',
    name: 'Carnelian',
    variety: 'Chalcedony',
    scientificName: 'Silicon Dioxide',
    description: 'A fiery motivator that awakens creativity, courage, and sensual vitality.',
    imageUrl: '',
    keywords: ['creativity', 'courage', 'motivation'],
    intents: ['creativity', 'courage', 'vitality'],
    colors: ['orange', 'red'],
    chakras: ['Sacral', 'Solar Plexus'],
    zodiacSigns: ['Leo', 'Virgo', 'Taurus'],
    elements: ['Fire'],
    metaphysicalProperties: {
      healing_properties: ['Inspires action', 'Boosts confidence', 'Ignites passion'],
      primary_chakras: ['Sacral', 'Solar Plexus'],
      zodiac_signs: ['Leo', 'Virgo', 'Taurus'],
      elements: ['Fire'],
      affirmations: ['My creativity flows with vibrant confidence.'],
    },
    physicalProperties: {
      composition: 'SiO₂',
      hardness: '7',
      crystal_system: 'Trigonal',
    },
    careInstructions: {
      cleansing: ['Smoke', 'Sound', 'Sunlight (gentle)'],
      charging: ['Sunrise light', 'Movement practices'],
      storage: ['Keep with creative tools for inspiration.'],
      usage: ['Hold before presentations for confident expression.'],
    },
    cautions: ['Avoid harsh chemicals; rinse with lukewarm water only.'],
    identification: {
      name: 'Carnelian',
      confidence: 87,
      variety: 'Chalcedony',
    },
    properties: ['Creativity', 'Courage', 'Vitality', 'Passion'],
  },
];

const CRYSTAL_LOOKUP = new Map();
CRYSTAL_LIBRARY.forEach((entry) => {
  CRYSTAL_LOOKUP.set(entry.name.toLowerCase(), entry);
  if (Array.isArray(entry.aliases)) {
    entry.aliases.forEach((alias) => {
      CRYSTAL_LOOKUP.set(alias.toLowerCase(), entry);
    });
  }
});

const CHAKRA_INTENT_MAP = {
  'root': ['grounding', 'stability', 'protection'],
  'sacral': ['creativity', 'pleasure', 'emotional balance'],
  'solar plexus': ['confidence', 'abundance', 'motivation'],
  'heart': ['love', 'compassion', 'healing'],
  'throat': ['communication', 'truth', 'expression'],
  'third eye': ['intuition', 'clarity', 'dreams'],
  'crown': ['spiritual connection', 'clarity', 'peace'],
};

const MOON_PHASE_TEMPLATES = {
  'New Moon': {
    focus: 'Plant seeds of intention and set clear goals.',
    energy: 'Initiation',
    timing: 'First 48 hours after the new moon exact time.',
    recommendedIntents: ['manifestation', 'clarity', 'new beginnings'],
    steps: [
      'Cleanse your space with smoke, sound, or selenite.',
      'Write three intentions you wish to manifest this lunar cycle.',
      'Charge a central crystal grid or candle while visualising the outcome.',
      'Seal with breathwork—inhale possibility, exhale doubt.',
    ],
    prompts: [
      'What am I ready to invite into my life?',
      'Which habits or thoughts must shift to support these intentions?',
    ],
    affirmation: 'I welcome luminous new beginnings.',
  },
  'Waxing Crescent': {
    focus: 'Gather resources, allies, and momentum for your goals.',
    energy: 'Expansion',
    timing: 'Days 2-5 of the lunar cycle.',
    recommendedIntents: ['momentum', 'creativity', 'confidence'],
    steps: [
      'Review your intentions and choose a single next aligned action.',
      'Create a mini altar with crystals supporting courage and focus.',
      'Spend five minutes in visualization of successful outcomes.',
    ],
    prompts: [
      'What support do I need to stay committed?',
      'Which inspired action can I take today?',
    ],
    affirmation: 'Every aligned action amplifies my manifestation.',
  },
  'First Quarter': {
    focus: 'Overcome obstacles and refine strategy.',
    energy: 'Perseverance',
    timing: 'Around day 7 of the cycle.',
    recommendedIntents: ['confidence', 'clarity', 'grounding'],
    steps: [
      'Ground with protective stones and centre your breathing.',
      'Journal about any resistance and transform it into opportunity.',
      'Perform a decisive action ritual—write a limiting belief, then transmute it into a power statement.',
    ],
    prompts: [
      'What challenge is surfacing to be resolved?',
      'How can I adapt while staying loyal to my vision?',
    ],
    affirmation: 'I meet every challenge with clarity and courage.',
  },
  'Waxing Gibbous': {
    focus: 'Polish, refine, and align before culmination.',
    energy: 'Preparation',
    timing: 'Days 10-13 of the cycle.',
    recommendedIntents: ['refinement', 'healing', 'harmonising'],
    steps: [
      'Meditate with a heart-healing crystal to align motivation with compassion.',
      'Review intentions and adjust wording for precision.',
      'Offer gratitude for what is already unfolding.',
    ],
    prompts: [
      'What needs fine-tuning before I step into visibility?',
      'Where can I soften expectations and trust the process?',
    ],
    affirmation: 'My path is refining toward graceful success.',
  },
  'Full Moon': {
    focus: 'Celebrate wins, release what is complete, and charge your field.',
    energy: 'Illumination',
    timing: 'Full moon day and the following evening.',
    recommendedIntents: ['release', 'celebration', 'clarity'],
    steps: [
      'Charge crystals and water under the moonlight.',
      'Write a release list of habits, fears, or patterns to dissolve.',
      'Practice a gratitude ritual followed by breathwork or sound bath.',
    ],
    prompts: [
      'What have I manifested since the new moon?',
      'Which stories or fears am I ready to release into moonlight?',
    ],
    affirmation: 'I radiate gratitude and release what no longer serves.',
  },
  'Waning Gibbous': {
    focus: 'Integrate lessons and share wisdom.',
    energy: 'Reflection',
    timing: 'Days 17-19 of the lunar cycle.',
    recommendedIntents: ['gratitude', 'teaching', 'service'],
    steps: [
      'Journal insights gained during the full moon peak.',
      'Share gratitude or guidance with someone in your community.',
      'Cleanse your altar and crystals in preparation for rest.',
    ],
    prompts: [
      'What wisdom am I ready to embody or teach?',
      'How can I show gratitude through action this week?',
    ],
    affirmation: 'My insights ripple outward with grace.',
  },
  'Last Quarter': {
    focus: 'Release, forgive, and create space for rest.',
    energy: 'Liberation',
    timing: 'Around day 22 of the cycle.',
    recommendedIntents: ['release', 'forgiveness', 'rest'],
    steps: [
      'Perform a cord-cutting or forgiveness ritual with supportive stones.',
      'Cleanse your home or workspace to invite renewal.',
      'Schedule restorative practices for the coming week.',
    ],
    prompts: [
      'Who or what am I ready to forgive—myself included?',
      'What boundaries support my energetic wellbeing?',
    ],
    affirmation: 'I release with love and honour the space created.',
  },
  'Waning Crescent': {
    focus: 'Rest, dream, and listen for inner guidance.',
    energy: 'Surrender',
    timing: 'Final days before the next new moon.',
    recommendedIntents: ['rest', 'dreamwork', 'intuition'],
    steps: [
      'Slow your schedule and embrace restorative sleep.',
      'Keep a dream journal by your bed for moonlit messages.',
      'Meditate with calming crystals to prepare for the next cycle.',
    ],
    prompts: [
      'What does my body and spirit need for renewal?',
      'What intuitive nudges are whispering for my attention?',
    ],
    affirmation: 'In stillness I gather luminous insight.',
  },
};

function normalizeValue(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function getCrystalByName(name) {
  if (!name) {
    return null;
  }
  const normalized = normalizeValue(name);
  if (!normalized) {
    return null;
  }
  return CRYSTAL_LOOKUP.get(normalized) || null;
}

function toCrystalResponse(entry) {
  if (!entry) return null;
  return {
    id: entry.id,
    name: entry.name,
    scientificName: entry.scientificName,
    imageUrl: entry.imageUrl || '',
    description: entry.description,
    metaphysicalProperties: entry.metaphysicalProperties,
    physicalProperties: entry.physicalProperties,
    careInstructions: entry.careInstructions,
    healingProperties: entry.metaphysicalProperties?.healing_properties || [],
    chakras: entry.metaphysicalProperties?.primary_chakras || [],
    zodiacSigns: entry.metaphysicalProperties?.zodiac_signs || [],
    elements: entry.metaphysicalProperties?.elements || [],
    properties: entry.properties || [],
    intents: entry.intents || [],
    identification: entry.identification,
  };
}

function selectCrystalsByIntent(intent, { limit = 3, exclude = [] } = {}) {
  const normalizedIntent = normalizeValue(intent);
  const excluded = new Set(exclude.map((value) => normalizeValue(value)));
  const relatedKeywords = new Set();
  if (normalizedIntent) {
    relatedKeywords.add(normalizedIntent);
    const mapped = CHAKRA_INTENT_MAP[normalizedIntent];
    if (Array.isArray(mapped)) {
      mapped.forEach((term) => relatedKeywords.add(term.toLowerCase()));
    }
  }

  const matches = CRYSTAL_LIBRARY.filter((entry) => {
    if (excluded.has(entry.id) || excluded.has(entry.name.toLowerCase())) {
      return false;
    }
    if (!normalizedIntent) {
      return true;
    }
    const pool = new Set([
      ...(entry.intents || []),
      ...(entry.keywords || []),
      ...((entry.metaphysicalProperties?.healing_properties || []).map((prop) => prop.toLowerCase())),
    ].map((value) => value.toLowerCase()));
    for (const keyword of relatedKeywords) {
      if (pool.has(keyword)) {
        return true;
      }
    }
    return false;
  });

  if (matches.length === 0) {
    return CRYSTAL_LIBRARY.filter((entry) => !excluded.has(entry.id)).slice(0, limit);
  }

  return matches.slice(0, limit);
}

function normalizePhaseName(phase) {
  const value = normalizeValue(phase);
  if (!value) {
    return null;
  }

  const normalized = value
    .replace(/moon/g, '')
    .replace(/phase/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const mapping = {
    'new': 'New Moon',
    'waxing crescent': 'Waxing Crescent',
    'first quarter': 'First Quarter',
    'waxing gibbous': 'Waxing Gibbous',
    'full': 'Full Moon',
    'waning gibbous': 'Waning Gibbous',
    'last quarter': 'Last Quarter',
    'third quarter': 'Last Quarter',
    'waning crescent': 'Waning Crescent',
  };

  return mapping[normalized] || null;
}

function calculateMoonPhase() {
  const now = new Date();
  const knownNewMoon = new Date('2024-01-11T11:57:00Z');
  const lunarCycle = 29.530589;

  const daysSince = (now.getTime() - knownNewMoon.getTime()) / (1000 * 60 * 60 * 24);
  const currentCycle = (daysSince % lunarCycle) / lunarCycle;

  let phase = 'New Moon';
  if (currentCycle < 0.0625) {
    phase = 'New Moon';
  } else if (currentCycle < 0.1875) {
    phase = 'Waxing Crescent';
  } else if (currentCycle < 0.3125) {
    phase = 'First Quarter';
  } else if (currentCycle < 0.4375) {
    phase = 'Waxing Gibbous';
  } else if (currentCycle < 0.5625) {
    phase = 'Full Moon';
  } else if (currentCycle < 0.6875) {
    phase = 'Waning Gibbous';
  } else if (currentCycle < 0.8125) {
    phase = 'Last Quarter';
  } else {
    phase = 'Waning Crescent';
  }

  const illumination = Math.round(Math.sin(currentCycle * Math.PI) * 100) / 100;

  return {
    phase,
    illumination: Math.max(0, Math.min(1, Math.abs(illumination))),
    timestamp: now.toISOString(),
    emoji: phase.includes('Full')
      ? '🌕'
      : phase.includes('New')
        ? '🌑'
        : phase.includes('Waxing')
          ? '🌔'
          : '🌘',
    cycleFraction: currentCycle,
    nextFullMoon: calculateNextPhase(0.5, currentCycle, now, lunarCycle),
    nextNewMoon: calculateNextPhase(0.0, currentCycle, now, lunarCycle),
  };
}

function calculateNextPhase(targetPhaseFraction, currentPhaseFraction, now, lunarCycle) {
  let daysUntil;
  if (targetPhaseFraction >= currentPhaseFraction) {
    daysUntil = (targetPhaseFraction - currentPhaseFraction) * lunarCycle;
  } else {
    daysUntil = (1 - currentPhaseFraction + targetPhaseFraction) * lunarCycle;
  }
  return new Date(now.getTime() + (daysUntil * 24 * 60 * 60 * 1000)).toISOString();
}

function toDailyCrystalPayload(entry) {
  return {
    name: entry.name,
    description: entry.description,
    properties: entry.properties || [],
    metaphysical_properties: entry.metaphysicalProperties,
    identification: entry.identification,
  };
}

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

exports.createListing = onCall(
  { cors: true, timeoutSeconds: 25 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to create a marketplace listing.');
    }

    const title = typeof request.data?.title === 'string' ? request.data.title.trim() : '';
    const description = typeof request.data?.description === 'string' ? request.data.description.trim() : '';
    const category = typeof request.data?.category === 'string' ? request.data.category.trim() : 'general';
    const imageUrl = typeof request.data?.imageUrl === 'string' ? request.data.imageUrl.trim() : '';
    const crystalId = typeof request.data?.crystalId === 'string' ? request.data.crystalId.trim() : '';
    const priceInput = request.data?.priceCents ?? request.data?.price ?? 0;
    const priceCents = Number(priceInput);
    const currency = typeof request.data?.currency === 'string' ? request.data.currency.trim().toLowerCase() : 'usd';
    const quantityRaw = Number(request.data?.quantity || 1);
    const quantity = Number.isInteger(quantityRaw) && quantityRaw > 0 ? quantityRaw : 1;

    if (!title) {
      throw new HttpsError('invalid-argument', 'title is required.');
    }
    if (!Number.isInteger(priceCents) || priceCents <= 0) {
      throw new HttpsError('invalid-argument', 'priceCents must be a positive integer.');
    }

    const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    const keywords = [title.toLowerCase(), category.toLowerCase(), ...(Array.isArray(request.data?.tags) ? request.data.tags : [])]
      .map((value) => value.toString().toLowerCase())
      .slice(0, 10);

    const listingRef = await db.collection('marketplace').add({
      title,
      description,
      priceCents,
      priceCurrency: currency || 'usd',
      category: category || 'general',
      sellerId: request.auth.uid,
      sellerDisplayName: request.auth.token?.name || null,
      crystalId: crystalId || slug,
      imageUrl: imageUrl || null,
      quantity,
      status: 'active',
      searchKeywords: keywords,
      shipping: typeof request.data?.shipping === 'object' ? request.data.shipping || {} : {},
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      listingId: listingRef.id,
      status: 'active',
    };
  }
);

exports.processPayment = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    ensureStripeConfigured();

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to process payments.');
    }

    const listingId = typeof request.data?.listingId === 'string' ? request.data.listingId.trim() : '';
    const amountCents = Number(request.data?.amountCents ?? request.data?.amount);
    const currency = typeof request.data?.currency === 'string' ? request.data.currency.trim().toLowerCase() : 'usd';
    const paymentMethodId = typeof request.data?.paymentMethodId === 'string' ? request.data.paymentMethodId.trim() : null;
    const customerEmail = typeof request.data?.email === 'string' ? request.data.email.trim() : null;

    if (!listingId) {
      throw new HttpsError('invalid-argument', 'listingId is required.');
    }
    if (!Number.isInteger(amountCents) || amountCents <= 0) {
      throw new HttpsError('invalid-argument', 'amountCents must be a positive integer.');
    }

    const listingSnap = await db.collection('marketplace').doc(listingId).get();
    if (!listingSnap.exists) {
      throw new HttpsError('not-found', 'Marketplace listing not found.');
    }

    const listing = listingSnap.data() || {};
    if (listing.priceCents && Number(listing.priceCents) !== amountCents) {
      throw new HttpsError('failed-precondition', 'Payment amount does not match the listing price.');
    }

    try {
      const paymentIntentParams = {
        amount: amountCents,
        currency: currency || 'usd',
        metadata: {
          uid: request.auth.uid,
          listingId,
        },
        automatic_payment_methods: { enabled: !paymentMethodId },
      };

      if (paymentMethodId) {
        paymentIntentParams.payment_method = paymentMethodId;
        paymentIntentParams.confirm = true;
        paymentIntentParams.confirmation_method = 'manual';
      }

      if (customerEmail) {
        paymentIntentParams.receipt_email = customerEmail;
      }

      const intent = await stripeClient.paymentIntents.create(paymentIntentParams);

      await db.collection('marketplace')
        .doc(listingId)
        .collection('payments')
        .doc(intent.id)
        .set({
          uid: request.auth.uid,
          amountCents,
          currency: currency || 'usd',
          status: intent.status,
          createdAt: FieldValue.serverTimestamp(),
        });

      return {
        paymentIntentId: intent.id,
        clientSecret: intent.client_secret,
        status: intent.status,
      };
    } catch (error) {
      console.error('❌ processPayment error:', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', error.message || 'Failed to process payment.');
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

exports.getCrystalRecommendations = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to receive crystal recommendations.');
    }

    const needInput = request.data?.need;
    if (typeof needInput !== 'string' || needInput.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'A need or intention description is required.');
    }

    const need = needInput.trim();
    const normalizedNeed = normalizeValue(need);
    const userProfile = typeof request.data?.userProfile === 'object' ? request.data.userProfile || {} : {};

    const keywords = normalizedNeed.split(/[^a-z0-9]+/).filter((token) => token);
    const profileIntentions = Array.isArray(userProfile.intentions)
      ? userProfile.intentions.map((value) => normalizeValue(value)).filter(Boolean)
      : [];
    const chakraFocus = Array.isArray(userProfile.chakraFocus || userProfile.focusChakras)
      ? (userProfile.chakraFocus || userProfile.focusChakras).map((value) => normalizeValue(value)).filter(Boolean)
      : [];
    const emotionalTone = normalizeValue(userProfile.emotion || userProfile.mood || '');
    const zodiacPreference = normalizeValue(
      userProfile.zodiacSign ||
      userProfile.sunSign ||
      (userProfile.zodiacProfile && userProfile.zodiacProfile.sun) ||
      (userProfile.birthChart && userProfile.birthChart.sun)
    );

    const combinedKeywords = new Set([...keywords, ...profileIntentions]);
    if (normalizedNeed.includes('stress') || normalizedNeed.includes('anx')) {
      combinedKeywords.add('calm');
    }
    if (normalizedNeed.includes('love') || normalizedNeed.includes('relationship')) {
      combinedKeywords.add('love');
    }
    if (normalizedNeed.includes('sleep')) {
      combinedKeywords.add('sleep');
      combinedKeywords.add('dreams');
    }
    if (normalizedNeed.includes('abundance') || normalizedNeed.includes('money')) {
      combinedKeywords.add('abundance');
      combinedKeywords.add('success');
    }

    const scored = CRYSTAL_LIBRARY.map((entry) => {
      let score = 0;
      const reasons = new Set();

      const entryIntents = new Set((entry.intents || []).map((value) => value.toLowerCase()));
      const entryKeywords = new Set((entry.keywords || []).map((value) => value.toLowerCase()));
      const healingProperties = new Set(
        (entry.metaphysicalProperties?.healing_properties || []).map((value) => value.toLowerCase())
      );
      const entryChakras = new Set(
        (entry.metaphysicalProperties?.primary_chakras || []).map((value) => value.toLowerCase())
      );
      const entryZodiac = new Set(
        (entry.metaphysicalProperties?.zodiac_signs || []).map((value) => value.toLowerCase())
      );

      combinedKeywords.forEach((keyword) => {
        if (entryIntents.has(keyword) || entryKeywords.has(keyword) || healingProperties.has(keyword)) {
          score += 4;
          reasons.add(`Resonates with ${keyword}`);
        }
      });

      chakraFocus.forEach((chakra) => {
        if (entryChakras.has(chakra)) {
          score += 3;
          reasons.add(`Supports your ${chakra} chakra focus`);
        }
      });

      if (zodiacPreference && entryZodiac.has(zodiacPreference)) {
        score += 2;
        reasons.add(`Harmonises with your sun sign ${userProfile.zodiacSign || userProfile.sunSign || userProfile.zodiacProfile?.sun || ''}`);
      }

      if (emotionalTone && (healingProperties.has(emotionalTone) || entryKeywords.has(emotionalTone))) {
        score += 2;
        reasons.add(`Balances emotional tone of ${emotionalTone}`);
      }

      if (normalizedNeed.includes(entry.name.toLowerCase())) {
        score += 5;
        reasons.add('Specifically mentioned in your request.');
      }

      return {
        entry,
        score,
        reasons: Array.from(reasons),
      };
    });

    scored.sort((a, b) => {
      if (b.score === a.score) {
        return a.entry.name.localeCompare(b.entry.name);
      }
      return b.score - a.score;
    });

    let recommendations = scored.filter((item) => item.score > 0).slice(0, 3);
    if (recommendations.length < 3) {
      const additional = scored
        .filter((item) => !recommendations.includes(item))
        .slice(0, 3 - recommendations.length);
      recommendations = recommendations.concat(additional);
    }

    const payload = recommendations.map((item, index) => {
      const base = toCrystalResponse(item.entry);
      const reasonText = item.reasons.length
        ? Array.from(new Set(item.reasons)).join(' • ')
        : 'A versatile ally suited to many intentions.';
      return {
        ...base,
        score: item.score,
        priority: index + 1,
        reason: reasonText,
      };
    });

    return {
      need,
      total: payload.length,
      recommendations: payload,
    };
  }
);

exports.generateHealingLayout = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to request a healing layout.');
    }

    const availableCrystals = Array.isArray(request.data?.availableCrystals)
      ? request.data.availableCrystals
      : [];
    const targetChakras = Array.isArray(request.data?.targetChakras) && request.data.targetChakras.length > 0
      ? request.data.targetChakras
      : ['Full Alignment'];
    const intention = typeof request.data?.intention === 'string' && request.data.intention.trim().length > 0
      ? request.data.intention.trim()
      : 'Holistic balance';

    const placements = [];
    const usedIds = new Set();
    const supplemental = new Set();

    targetChakras.forEach((chakraRaw) => {
      const chakra = chakraRaw || 'Alignment';
      const normalizedChakra = normalizeValue(chakra);
      let selection = null;

      for (const crystalName of availableCrystals) {
        const entry = getCrystalByName(crystalName);
        if (!entry || usedIds.has(entry.id)) {
          continue;
        }
        const entryChakras = (entry.metaphysicalProperties?.primary_chakras || []).map((value) => value.toLowerCase());
        if (entryChakras.includes(normalizedChakra)) {
          selection = entry;
          break;
        }
      }

      if (!selection) {
        const mappedIntents = CHAKRA_INTENT_MAP[normalizedChakra] || [];
        const searchIntent = mappedIntents.length ? mappedIntents[0] : normalizedChakra;
        const candidates = selectCrystalsByIntent(searchIntent, { limit: 1, exclude: Array.from(usedIds) });
        selection = candidates.length ? candidates[0] : CRYSTAL_LIBRARY[0];
      }

      usedIds.add(selection.id);
      supplemental.add(selection.name);

      const healingFocus = (selection.metaphysicalProperties?.healing_properties || []).slice(0, 2);
      placements.push({
        chakra,
        crystal: selection.name,
        crystalId: selection.id,
        focus: healingFocus,
        instructions: `Place ${selection.name} on the ${chakra} centre for 7 deep breaths, visualising ${healingFocus.join(' and ') || 'balanced energy'}.`,
      });
    });

    const breathwork = {
      technique: '4-7-8 Breath',
      description: 'Inhale for 4 counts, hold for 7, and exhale for 8 to settle energy between placements.',
    };

    const integration = [
      'Journal three sensations or insights after completing the layout.',
      'Drink charged water infused with clear quartz or selenite.',
      'Stretch gently and close with gratitude to seal the work.',
    ];

    await db.collection('users')
      .doc(request.auth.uid)
      .collection('healing_sessions')
      .add({
        intention,
        targetChakras,
        availableCrystals,
        placements: placements.map((placement) => ({
          chakra: placement.chakra,
          crystal: placement.crystal,
        })),
        createdAt: FieldValue.serverTimestamp(),
      });

    return {
      layout: {
        intention,
        durationMinutes: 20 + (targetChakras.length * 5),
        placements,
        breathwork,
        integration,
        affirmation: `I align my energy for ${intention.toLowerCase()}.`,
      },
      suggestedCrystals: Array.from(supplemental),
    };
  }
);

exports.getMoonRituals = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to receive moon ritual guidance.');
    }

    const requestedPhase = typeof request.data?.moonPhase === 'string' ? request.data.moonPhase : '';
    const userCrystals = Array.isArray(request.data?.userCrystals) ? request.data.userCrystals : [];
    const userProfile = typeof request.data?.userProfile === 'object' ? request.data.userProfile || {} : {};
    const personalIntention = typeof request.data?.intention === 'string' && request.data.intention.trim().length > 0
      ? request.data.intention.trim()
      : null;

    const moonData = calculateMoonPhase();
    const resolvedPhase = normalizePhaseName(requestedPhase) || moonData.phase;
    const template = MOON_PHASE_TEMPLATES[resolvedPhase] || MOON_PHASE_TEMPLATES[moonData.phase];

    const recommended = [];
    const used = new Set();

    userCrystals.forEach((name) => {
      const entry = getCrystalByName(name);
      if (entry && !used.has(entry.id)) {
        recommended.push(toCrystalResponse(entry));
        used.add(entry.id);
      }
    });

    const recommendationIntents = template?.recommendedIntents || [];
    recommendationIntents.forEach((intent) => {
      const matches = selectCrystalsByIntent(intent, { limit: 1, exclude: Array.from(used) });
      matches.forEach((entry) => {
        if (!used.has(entry.id)) {
          recommended.push(toCrystalResponse(entry));
          used.add(entry.id);
        }
      });
    });

    if (recommended.length === 0) {
      const fallback = CRYSTAL_LIBRARY.slice(0, 3);
      fallback.forEach((entry) => {
        recommended.push(toCrystalResponse(entry));
        used.add(entry.id);
      });
    }

    let ritualNarrative = null;
    if (config().gemini?.api_key) {
      try {
        const { GoogleGenerativeAI } = require('@google/generative-ai');
        const genAI = new GoogleGenerativeAI(config().gemini.api_key);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
        const prompt = `You are a crystal priestess crafting a ${resolvedPhase} moon ritual. Phase focus: ${template?.focus}.` +
          ` User crystals: ${userCrystals.join(', ') || 'none specified'}.` +
          ` Personal intention: ${personalIntention || 'follow the phase focus'}.` +
          ' Provide a poetic paragraph (120-160 words) guiding them through the ritual, including atmosphere, crystal placement, and closing gratitude.';
        const response = await model.generateContent([prompt]);
        ritualNarrative = response.response.text();
      } catch (error) {
        console.warn('⚠️ Gemini narrative generation failed:', error.message);
      }
    }

    await db.collection('moonData').doc('current').set({
      phase: resolvedPhase,
      lastQueriedAt: FieldValue.serverTimestamp(),
      lastQueriedBy: request.auth.uid,
      illumination: moonData.illumination,
      nextFullMoon: moonData.nextFullMoon,
      nextNewMoon: moonData.nextNewMoon,
    }, { merge: true });

    await db.collection('users')
      .doc(request.auth.uid)
      .collection('rituals')
      .add({
        phase: resolvedPhase,
        intention: personalIntention || template?.focus || '',
        recommendedCrystals: recommended.map((item) => item?.name).filter(Boolean),
        createdAt: FieldValue.serverTimestamp(),
      });

    return {
      moonData: {
        phase: resolvedPhase,
        emoji: moonData.emoji,
        illumination: moonData.illumination,
        timestamp: moonData.timestamp,
        nextFullMoon: moonData.nextFullMoon,
        nextNewMoon: moonData.nextNewMoon,
      },
      ritual: {
        focus: template?.focus || 'Attune to lunar wisdom',
        energy: template?.energy || 'Reflection',
        timing: template?.timing || 'Anytime under the moon',
        steps: template?.steps || [],
        journalingPrompts: template?.prompts || [],
        affirmation: template?.affirmation || 'I honour the wisdom of the moon.',
        narrative: ritualNarrative,
        intention: personalIntention || template?.focus || 'Lunar alignment',
        recommendedCrystals: recommended,
      },
      userCrystals,
    };
  }
);

exports.checkCrystalCompatibility = onCall(
  { cors: true, timeoutSeconds: 25 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to analyse crystal compatibility.');
    }

    const crystalNames = Array.isArray(request.data?.crystalNames)
      ? request.data.crystalNames
      : [];
    if (crystalNames.length === 0) {
      throw new HttpsError('invalid-argument', 'Provide at least one crystal name.');
    }

    const userProfile = typeof request.data?.userProfile === 'object' ? request.data.userProfile || {} : {};
    const rawPurpose = typeof request.data?.purpose === 'string' ? request.data.purpose.trim() : '';
    const derivedPurpose = rawPurpose
      || (Array.isArray(userProfile.intentions) && userProfile.intentions.length > 0
        ? String(userProfile.intentions[0]).trim()
        : '');
    const purpose = derivedPurpose;
    const analyzed = [];
    const missing = [];

    crystalNames.forEach((name) => {
      const entry = getCrystalByName(name);
      if (entry) {
        analyzed.push({ name, entry });
      } else {
        missing.push(name);
      }
    });

    if (analyzed.length === 0) {
      return {
        score: 0,
        synergies: [],
        cautions: [],
        recommendedAdditions: [],
        missing,
        purpose,
      };
    }

    let scoreTotal = 0;
    let comparisons = 0;
    const synergyInsights = [];
    const cautionaryNotes = [];
    const chakraFrequency = new Map();
    const elementFrequency = new Map();

    const toSet = (list) => new Set((list || []).map((value) => value.toLowerCase()));

    for (let i = 0; i < analyzed.length; i += 1) {
      const first = analyzed[i];
      const firstEntry = first.entry;
      const firstChakras = toSet(firstEntry.metaphysicalProperties?.primary_chakras);
      const firstElements = toSet(firstEntry.metaphysicalProperties?.elements);

      firstChakras.forEach((chakra) => {
        chakraFrequency.set(chakra, (chakraFrequency.get(chakra) || 0) + 1);
      });
      firstElements.forEach((element) => {
        elementFrequency.set(element, (elementFrequency.get(element) || 0) + 1);
      });

      for (let j = i + 1; j < analyzed.length; j += 1) {
        const second = analyzed[j];
        const secondEntry = second.entry;
        const secondChakras = toSet(secondEntry.metaphysicalProperties?.primary_chakras);
        const secondElements = toSet(secondEntry.metaphysicalProperties?.elements);

        comparisons += 1;
        let pairScore = 55; // neutral baseline

        const sharedChakras = [...firstChakras].filter((chakra) => secondChakras.has(chakra));
        const sharedElements = [...firstElements].filter((element) => secondElements.has(element));

        if (sharedChakras.length > 0) {
          pairScore += sharedChakras.length * 10;
          synergyInsights.push(`${first.entry.name} and ${second.entry.name} harmonise through the ${sharedChakras.join(', ')} chakra${sharedChakras.length > 1 ? 's' : ''}.`);
        }

        if (sharedElements.length > 0) {
          pairScore += sharedElements.length * 8;
          synergyInsights.push(`${first.entry.name} and ${second.entry.name} share ${sharedElements.join(' & ')} element energy.`);
        }

        if (sharedChakras.length === 0 && sharedElements.length === 0) {
          cautionaryNotes.push(`${first.entry.name} and ${second.entry.name} work on different spectrums—pair with a bridging stone for coherence.`);
        }

        if (purpose) {
          const intents = new Set([
            ...(firstEntry.intents || []),
            ...(firstEntry.keywords || []),
            ...(firstEntry.metaphysicalProperties?.healing_properties || []),
            ...(secondEntry.intents || []),
            ...(secondEntry.keywords || []),
            ...(secondEntry.metaphysicalProperties?.healing_properties || []),
          ].map((value) => value.toLowerCase()));
          if (intents.has(purpose.toLowerCase())) {
            pairScore += 6;
            synergyInsights.push(`${first.entry.name} and ${second.entry.name} both amplify your focus on ${purpose}.`);
          }
        }

        if ((firstElements.has('fire') && secondElements.has('water')) || (firstElements.has('water') && secondElements.has('fire'))) {
          pairScore -= 5;
          cautionaryNotes.push(`${first.entry.name} and ${second.entry.name} mix opposing fire and water currents—introduce a grounding stone to mediate.`);
        }

        scoreTotal += Math.max(20, Math.min(100, pairScore));
      }
    }

    const averageScore = comparisons > 0 ? Math.round(scoreTotal / comparisons) : 75;
    const dominantChakra = [...chakraFrequency.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || null;
    const dominantElement = [...elementFrequency.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || null;

    const additionSuggestions = purpose
      ? selectCrystalsByIntent(purpose, {
          limit: 2,
          exclude: analyzed.map((item) => item.entry.id),
        })
      : [];

    return {
      score: averageScore,
      synergies: Array.from(new Set(synergyInsights)).slice(0, 6),
      cautions: Array.from(new Set(cautionaryNotes)).slice(0, 4),
      recommendedAdditions: additionSuggestions.map((entry) => toCrystalResponse(entry)),
      analyzedCrystals: analyzed.map((item) => ({
        name: item.entry.name,
        intents: item.entry.intents,
        chakras: item.entry.metaphysicalProperties?.primary_chakras || [],
        elements: item.entry.metaphysicalProperties?.elements || [],
      })),
      dominantChakra,
      dominantElement,
      missing,
      purpose,
    };
  }
);

exports.getCrystalCare = onCall(
  { cors: true, timeoutSeconds: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to retrieve crystal care information.');
    }

    const crystalName = typeof request.data?.crystalName === 'string' ? request.data.crystalName.trim() : '';
    if (!crystalName) {
      throw new HttpsError('invalid-argument', 'crystalName is required.');
    }

    const entry = getCrystalByName(crystalName);
    if (!entry) {
      return {
        name: crystalName,
        care: {
          cleansing: ['Smoke cleanse or sound bath'],
          charging: ['Moonlight', 'Visualization'],
          storage: ['Keep wrapped in a soft cloth until the library entry is available.'],
          usage: ['Handle gently and note any energetic impressions in your journal.'],
        },
        cautions: ['Crystal not yet catalogued—use gentle cleansing and charging methods only.'],
        recommendedCompanions: [],
      };
    }

    const companions = selectCrystalsByIntent(entry.intents?.[0] || '', {
      limit: 2,
      exclude: [entry.id],
    }).map((item) => toCrystalResponse(item));

    return {
      name: entry.name,
      care: entry.careInstructions,
      cautions: entry.cautions || [],
      cleansing: entry.careInstructions?.cleansing || [],
      charging: entry.careInstructions?.charging || [],
      storage: entry.careInstructions?.storage || [],
      usage: entry.careInstructions?.usage || [],
      recommendedCompanions: companions,
    };
  }
);

exports.searchCrystals = onCall(
  { cors: true, timeoutSeconds: 25 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to search the crystal library.');
    }

    const keyword = typeof request.data?.keyword === 'string' ? request.data.keyword.trim().toLowerCase() : '';
    const chakra = typeof request.data?.chakra === 'string' ? request.data.chakra.trim().toLowerCase() : '';
    const zodiac = typeof request.data?.zodiacSign === 'string' ? request.data.zodiacSign.trim().toLowerCase() : '';
    const healingProperty = typeof request.data?.healingProperty === 'string' ? request.data.healingProperty.trim().toLowerCase() : '';
    const element = typeof request.data?.element === 'string' ? request.data.element.trim().toLowerCase() : '';
    const color = typeof request.data?.color === 'string' ? request.data.color.trim().toLowerCase() : '';
    const intentFilter = typeof request.data?.intent === 'string' ? request.data.intent.trim().toLowerCase() : '';
    const limitRaw = Number(request.data?.limit || 10);
    const limit = Number.isInteger(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 25) : 10;

    const results = CRYSTAL_LIBRARY.filter((entry) => {
      const entryChakras = (entry.metaphysicalProperties?.primary_chakras || []).map((value) => value.toLowerCase());
      const entryZodiac = (entry.metaphysicalProperties?.zodiac_signs || []).map((value) => value.toLowerCase());
      const entryElements = (entry.metaphysicalProperties?.elements || []).map((value) => value.toLowerCase());
      const entryHealings = (entry.metaphysicalProperties?.healing_properties || []).map((value) => value.toLowerCase());
      const entryIntents = (entry.intents || []).map((value) => value.toLowerCase());
      const entryColors = (entry.colors || []).map((value) => value.toLowerCase());
      const entryKeywords = (entry.keywords || []).map((value) => value.toLowerCase());

      if (chakra && !entryChakras.includes(chakra)) {
        return false;
      }
      if (zodiac && !entryZodiac.includes(zodiac)) {
        return false;
      }
      if (healingProperty && !entryHealings.includes(healingProperty)) {
        return false;
      }
      if (element && !entryElements.includes(element)) {
        return false;
      }
      if (color && !entryColors.includes(color)) {
        return false;
      }
      if (intentFilter && !entryIntents.includes(intentFilter)) {
        const mapped = CHAKRA_INTENT_MAP[intentFilter];
        if (!(mapped && mapped.some((value) => entryIntents.includes(value)))) {
          return false;
        }
      }

      if (keyword) {
        const haystack = [
          entry.name.toLowerCase(),
          entry.scientificName?.toLowerCase() || '',
          entry.description?.toLowerCase() || '',
          ...entryKeywords,
          ...entryIntents,
          ...entryHealings,
          ...entryElements,
        ].join(' ');
        if (!haystack.includes(keyword)) {
          return false;
        }
      }

      return true;
    });

    return {
      total: results.length,
      results: results.slice(0, limit).map((entry) => toCrystalResponse(entry)),
    };
  }
);

exports.earnSeerCredits = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to earn Seer Credits.');
    }

    const action = typeof request.data?.action === 'string' ? request.data.action.trim() : '';
    const creditsToEarn = Number(request.data?.creditsToEarn);
    if (!action || !ECONOMY_EARN_RULES[action]) {
      throw new HttpsError('invalid-argument', 'Unsupported earn action.');
    }
    if (!Number.isInteger(creditsToEarn) || creditsToEarn <= 0) {
      throw new HttpsError('invalid-argument', 'creditsToEarn must be a positive integer.');
    }
    if (creditsToEarn !== ECONOMY_EARN_RULES[action]) {
      throw new HttpsError('invalid-argument', 'creditsToEarn does not match server rules.');
    }

    const uid = request.auth.uid;
    const economyRef = db.collection('users').doc(uid).collection('economy').doc('credits');

    try {
      let updatedState = null;
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(economyRef);
        const data = snapshot.exists ? snapshot.data() || {} : {};

        let credits = data.credits || 0;
        let lifetime = data.lifetimeEarned || data.lifetimeCreditsEarned || 0;
        let dailyEarnCount = data.dailyEarnCount || {};
        const dailyLimits = { ...ECONOMY_DAILY_LIMITS, ...(data.dailyLimits || {}) };

        const today = new Date().toISOString().split('T')[0];
        const lastReset = data.lastResetDate || today;
        if (lastReset !== today) {
          dailyEarnCount = {};
        }

        const limit = dailyLimits[action];
        if (limit && (dailyEarnCount[action] || 0) >= limit) {
          throw new HttpsError('resource-exhausted', `Daily limit reached for ${action}.`);
        }

        credits += creditsToEarn;
        lifetime += creditsToEarn;
        dailyEarnCount[action] = (dailyEarnCount[action] || 0) + 1;

        transaction.set(economyRef, {
          credits,
          lifetimeEarned: lifetime,
          lifetimeCreditsEarned: lifetime,
          dailyEarnCount,
          dailyLimits,
          lastResetDate: today,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        updatedState = { credits, lifetime, dailyEarnCount };
      });

      return {
        success: true,
        newCredits: updatedState.credits,
        lifetimeEarned: updatedState.lifetime,
        dailyEarnCount: updatedState.dailyEarnCount,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error('❌ earnSeerCredits error:', error);
      throw new HttpsError('internal', 'Failed to earn Seer Credits.');
    }
  }
);

exports.spendSeerCredits = onCall(
  { cors: true, timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to spend Seer Credits.');
    }

    const action = typeof request.data?.action === 'string' ? request.data.action.trim() : '';
    const creditsToSpend = Number(request.data?.creditsToSpend);
    if (!action || !ECONOMY_SPEND_RULES[action]) {
      throw new HttpsError('invalid-argument', 'Unsupported spend action.');
    }
    if (!Number.isInteger(creditsToSpend) || creditsToSpend <= 0) {
      throw new HttpsError('invalid-argument', 'creditsToSpend must be a positive integer.');
    }
    if (creditsToSpend !== ECONOMY_SPEND_RULES[action]) {
      throw new HttpsError('invalid-argument', 'creditsToSpend does not match server rules.');
    }

    const uid = request.auth.uid;
    const economyRef = db.collection('users').doc(uid).collection('economy').doc('credits');

    try {
      let updatedState = null;
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(economyRef);
        const data = snapshot.exists ? snapshot.data() || {} : {};

        const credits = data.credits || 0;
        if (credits < creditsToSpend) {
          throw new HttpsError('failed-precondition', 'Insufficient Seer Credits.');
        }

        transaction.set(economyRef, {
          credits: credits - creditsToSpend,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        updatedState = { credits: credits - creditsToSpend };
      });

      return {
        success: true,
        newCredits: updatedState.credits,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error('❌ spendSeerCredits error:', error);
      throw new HttpsError('internal', 'Failed to spend Seer Credits.');
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
  memory: '256MiB',
}, async (request) => {
  try {
    console.log('🌅 Getting daily crystal recommendation...');

    const today = new Date();
    const startOfYear = new Date(Date.UTC(today.getUTCFullYear(), 0, 0));
    const dayOfYear = Math.floor((today - startOfYear) / (1000 * 60 * 60 * 24));

    const requestedIntent = normalizeValue(request.data?.intent || request.data?.intention);
    const requestedChakra = normalizeValue(request.data?.chakra || request.data?.focusChakra);
    const requestedMood = normalizeValue(request.data?.mood || request.data?.emotion);

    let pool = CRYSTAL_LIBRARY.filter((entry) => entry.highlight);
    if (pool.length === 0) {
      pool = [...CRYSTAL_LIBRARY];
    }

    if (requestedIntent) {
      const intentMatches = selectCrystalsByIntent(requestedIntent, { limit: CRYSTAL_LIBRARY.length });
      if (intentMatches.length > 0) {
        pool = intentMatches;
      }
    }

    if (requestedChakra) {
      const chakraMatches = pool.filter((entry) =>
        (entry.metaphysicalProperties?.primary_chakras || []).some((chakra) => normalizeValue(chakra) === requestedChakra),
      );
      if (chakraMatches.length > 0) {
        pool = chakraMatches;
      }
    }

    if (requestedMood) {
      const moodMatches = pool.filter((entry) => {
        const healing = (entry.metaphysicalProperties?.healing_properties || []).map((value) => normalizeValue(value));
        const keywords = (entry.keywords || []).map((value) => normalizeValue(value));
        return healing.includes(requestedMood) || keywords.includes(requestedMood);
      });
      if (moodMatches.length > 0) {
        pool = moodMatches;
      }
    }

    if (pool.length === 0) {
      throw new Error('Crystal library is empty after filtering');
    }

    const selection = pool[dayOfYear % pool.length];
    const base = toCrystalResponse(selection);

    const moonPhase = calculateMoonPhase();
    const ritualTemplate = MOON_PHASE_TEMPLATES[moonPhase.phase] || null;

    const response = {
      ...base,
      keywords: selection.keywords || [],
      colors: selection.colors || [],
      highlight: !!selection.highlight,
      date: today.toISOString().split('T')[0],
      dayOfYear,
      selectionCriteria: {
        intent: requestedIntent || null,
        chakra: requestedChakra || null,
        mood: requestedMood || null,
      },
      moonPhase,
      ritualSuggestion: ritualTemplate
        ? {
            phase: moonPhase.phase,
            focus: ritualTemplate.focus,
            energy: ritualTemplate.energy,
            affirmation: ritualTemplate.affirmation,
            recommendedIntents: ritualTemplate.recommendedIntents,
          }
        : null,
    };

    console.log(`✅ Daily crystal selected: ${selection.name} (pool size ${pool.length})`);
    return response;
  } catch (error) {
    console.error('❌ Error getting daily crystal:', error);

    const fallbackEntry = CRYSTAL_LIBRARY[0];
    if (!fallbackEntry) {
      return {
        name: 'Clear Quartz',
        description: 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone.',
        properties: ['Amplification', 'Healing', 'Clarity', 'Energy', 'Purification'],
        date: new Date().toISOString().split('T')[0],
        error: 'Crystal dataset unavailable',
      };
    }

    return {
      ...toCrystalResponse(fallbackEntry),
      keywords: fallbackEntry.keywords || [],
      colors: fallbackEntry.colors || [],
      highlight: !!fallbackEntry.highlight,
      date: new Date().toISOString().split('T')[0],
      error: 'Fallback crystal provided',
    };
  }
});

console.log('🔮 Crystal Grimoire Functions (Complete Backend) initialized');