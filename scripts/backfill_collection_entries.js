/**
 * Backfill user collection documents to match the constrained Firestore schema.
 *
 * The security rules only allow the following fields on collection entries:
 *   - libraryRef (string path to the crystal library document)
 *   - notes (string, <= 1000 chars)
 *   - tags (array of strings)
 *   - addedAt (timestamp)
 *   - createdAt (timestamp)
 *   - updatedAt (timestamp)
 *
 * Older documents may contain a full snapshot of the crystal metadata. This
 * script collapses those documents to the allowed shape while attempting to
 * preserve user-generated content such as notes or tags.
 */

const admin = require('firebase-admin');

function initializeApp() {
  if (admin.apps.length) {
    return admin.app();
  }

  try {
    const serviceAccount = require('../firebase-service-account-key.json');
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } catch (error) {
    console.error('Failed to initialize Firebase Admin SDK.');
    console.error('Ensure firebase-service-account-key.json is available.');
    throw error;
  }
}

function asStringList(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => (item ?? '').toString().trim())
      .filter((item) => item.length > 0);
  }

  if (typeof value === 'string' && value.trim().length > 0) {
    return [value.trim()];
  }

  return [];
}

function normalizeTimestamp(adminInstance, value, fallback) {
  if (!value) {
    return fallback ?? adminInstance.firestore.FieldValue.serverTimestamp();
  }

  if (value instanceof adminInstance.firestore.Timestamp) {
    return value;
  }

  if (value.toDate) {
    return value;
  }

  const candidate = new Date(value);
  if (!Number.isNaN(candidate.getTime())) {
    return candidate;
  }

  return fallback ?? adminInstance.firestore.FieldValue.serverTimestamp();
}

function inferLibraryRef(data) {
  if (typeof data.libraryRef === 'string' && data.libraryRef.trim().length > 0) {
    return data.libraryRef.trim();
  }

  const crystalId = data.crystalId || (data.crystal && data.crystal.id);
  if (typeof crystalId === 'string' && crystalId.trim().length > 0) {
    return `crystal_library/${crystalId.trim()}`;
  }

  return null;
}

async function backfillCollectionEntries() {
  const app = initializeApp();
  const firestore = app.firestore();
  const batchSize = 100;

  const usersSnapshot = await firestore.collection('users').get();
  let processed = 0;
  let updated = 0;

  for (const userDoc of usersSnapshot.docs) {
    const collectionSnapshot = await userDoc.ref.collection('collection').get();
    const writes = [];

    collectionSnapshot.forEach((entryDoc) => {
      const data = entryDoc.data() || {};
      const libraryRef = inferLibraryRef(data);

      if (!libraryRef) {
        console.warn(`Skipping ${entryDoc.ref.path} - unable to determine libraryRef`);
        return;
      }

      const notes = typeof data.notes === 'string' ? data.notes : (data.personalNotes || '');
      const tags = asStringList(data.tags || data.primaryUses);

      const addedAt = normalizeTimestamp(admin, data.addedAt, null);
      const createdAt = normalizeTimestamp(admin, data.createdAt, addedAt);
      const payload = {
        libraryRef,
        notes: notes || '',
        tags,
        addedAt: addedAt || admin.firestore.FieldValue.serverTimestamp(),
        createdAt: createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      writes.push({ ref: entryDoc.ref, data: payload });
    });

    while (writes.length) {
      const chunk = writes.splice(0, batchSize);
      const batch = firestore.batch();
      chunk.forEach(({ ref, data }) => {
        batch.set(ref, data, { merge: false });
        updated += 1;
      });
      await batch.commit();
    }

    processed += collectionSnapshot.size;
  }

  console.log(`Processed ${processed} collection documents.`);
  console.log(`Updated ${updated} documents to the constrained schema.`);
}

backfillCollectionEntries()
  .then(() => {
    console.log('Backfill complete.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exit(1);
  });
