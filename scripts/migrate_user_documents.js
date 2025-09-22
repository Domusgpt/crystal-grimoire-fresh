#!/usr/bin/env node

/**
 * One-off migration to reshape user documents into the { email, profile, settings } structure
 * expected by the latest Firestore security rules.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/serviceAccount.json node scripts/migrate_user_documents.js
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const DEFAULT_SETTINGS = {
  notifications: true,
  newsletter: true,
  darkMode: true,
};

const TOP_LEVEL_KEYS = new Set(['email', 'profile', 'settings', 'createdAt', 'updatedAt']);
const KNOWN_LEGACY_KEYS = new Set([
  'uid',
  'name',
  'displayName',
  'photoURL',
  'photoUrl',
  'subscriptionTier',
  'subscriptionStatus',
  'subscriptionExpiresAt',
  'subscriptionWillRenew',
  'subscriptionUpdatedAt',
  'monthlyIdentifications',
  'totalIdentifications',
  'metaphysicalQueries',
  'dailyCredits',
  'totalCredits',
  'birthChart',
  'preferences',
  'favoriteCategories',
  'ownedCrystalIds',
  'stats',
  'experience',
  'location',
  'tier',
  'lastLoginAt',
  'lastActive',
]);

function asObject(value) {
  if (value && typeof value === 'object') {
    return { ...value };
  }
  return {};
}

async function migrate() {
  const snapshot = await db.collection('users').get();
  console.log(`📦 Migrating ${snapshot.size} user documents to the new profile schema...`);

  let migratedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};

    const profile = asObject(data.profile);
    profile.uid = profile.uid || doc.id;
    profile.displayName =
      profile.displayName || data.displayName || data.name || 'Crystal Seeker';
    if (profile.photoURL === undefined) {
      profile.photoURL = data.photoURL ?? data.photoUrl ?? null;
    }

    let lastLogin = profile.lastLoginAt || data.lastLoginAt || data.lastActive;
    if (!lastLogin) {
      lastLogin = FieldValue.serverTimestamp();
    }
    profile.lastLoginAt = lastLogin;

    const subscription = asObject(profile.subscription);
    subscription.tier = subscription.tier || data.subscriptionTier || data.tier || 'free';
    subscription.status = subscription.status || data.subscriptionStatus || 'active';
    if (subscription.expiresAt === undefined && data.subscriptionExpiresAt !== undefined) {
      subscription.expiresAt = data.subscriptionExpiresAt;
    }
    if (subscription.willRenew === undefined && data.subscriptionWillRenew !== undefined) {
      subscription.willRenew = data.subscriptionWillRenew;
    }
    subscription.updatedAt =
      subscription.updatedAt || data.subscriptionUpdatedAt || FieldValue.serverTimestamp();
    profile.subscription = subscription;

    const usage = asObject(profile.usage);
    usage.monthlyIdentifications =
      usage.monthlyIdentifications ?? data.monthlyIdentifications ?? 0;
    usage.totalIdentifications =
      usage.totalIdentifications ?? data.totalIdentifications ?? 0;
    usage.metaphysicalQueries =
      usage.metaphysicalQueries ?? data.metaphysicalQueries ?? 0;
    profile.usage = usage;

    const credits = asObject(profile.credits);
    credits.daily = credits.daily ?? data.dailyCredits ?? 3;
    credits.total = credits.total ?? data.totalCredits ?? 0;
    profile.credits = credits;

    if (!profile.birthChart && data.birthChart) {
      profile.birthChart = data.birthChart;
    }
    if (!profile.preferences && data.preferences) {
      profile.preferences = data.preferences;
    }
    if (!profile.favoriteCategories && data.favoriteCategories) {
      profile.favoriteCategories = data.favoriteCategories;
    }
    if (!profile.ownedCrystalIds && data.ownedCrystalIds) {
      profile.ownedCrystalIds = data.ownedCrystalIds;
    }
    if (!profile.stats && data.stats) {
      profile.stats = data.stats;
    }
    if (!profile.experience && data.experience) {
      profile.experience = data.experience;
    }
    if (!profile.location && data.location) {
      profile.location = data.location;
    }

    const settings = data.settings && typeof data.settings === 'object'
      ? { ...DEFAULT_SETTINGS, ...data.settings }
      : { ...DEFAULT_SETTINGS };

    const legacy = asObject(profile.legacy);
    for (const [key, value] of Object.entries(data)) {
      if (!TOP_LEVEL_KEYS.has(key) && !KNOWN_LEGACY_KEYS.has(key)) {
        legacy[key] = value;
      }
    }
    if (Object.keys(legacy).length > 0) {
      profile.legacy = legacy;
    } else if (profile.legacy) {
      delete profile.legacy;
    }

    const payload = {
      email: data.email || '',
      profile,
      settings,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: data.createdAt || FieldValue.serverTimestamp(),
    };

    await doc.ref.set(payload, { merge: false });
    migratedCount += 1;
    console.log(`  • Migrated ${doc.id}`);
  }

  console.log(`✅ Migration complete. Updated ${migratedCount} documents.`);
}

migrate()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Migration failed', error);
    process.exit(1);
  });
