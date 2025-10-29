const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const assert = require('node:assert/strict');
const { test, before, after, beforeEach } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

let testEnv;
let skipRulesTests = false;

before(async () => {
  try {
    testEnv = await initializeTestEnvironment({
      projectId: 'demo-crystal-grimoire',
      firestore: {
        rules: readFileSync(join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
      },
      storage: {
        rules: readFileSync(join(__dirname, '..', '..', 'storage.rules'), 'utf8'),
      },
    });
  } catch (error) {
    if (String(error.message || error).includes('firestore emulator')) {
      console.warn('⚠️ Firestore emulator not detected; skipping security rules tests.');
      skipRulesTests = true;
      return;
    }
    throw error;
  }
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (skipRulesTests) {
    return;
  }
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

test('dream journal access allows owner and admin, rejects other users', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }
  const ownerContext = testEnv.authenticatedContext('dreamer', {
    email_verified: true,
  });
  const ownerDb = ownerContext.firestore();

  await assertSucceeds(
    ownerDb
      .collection('users')
      .doc('dreamer')
      .collection('dreams')
      .doc('entry-1')
      .set({
        content: 'Dreaming under the moon.',
        analysis: 'Symbolism of clarity',
        crystalSuggestions: [
          { name: 'Amethyst', reason: 'Soothing' },
        ],
        dreamDate: new Date().toISOString(),
        crystalsUsed: ['Amethyst'],
        mood: 'Calm',
        moonPhase: 'full_moon',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      })
  );

  const strangerDb = testEnv.authenticatedContext('stranger', {
    email_verified: true,
  }).firestore();

  await assertFails(
    strangerDb
      .collection('users')
      .doc('dreamer')
      .collection('dreams')
      .doc('entry-1')
      .get()
  );

  const adminDb = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).firestore();

  const snapshot = await assertSucceeds(
    adminDb
      .collection('users')
      .doc('dreamer')
      .collection('dreams')
      .doc('entry-1')
      .get()
  );

  assert.equal(snapshot.exists, true);
});

test('marketplace rules require pending review on create and allow admin moderation', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }
  const sellerContext = testEnv.authenticatedContext('seller-1', {
    email_verified: true,
  });
  const sellerDb = sellerContext.firestore();

  await assertSucceeds(
    sellerDb.collection('marketplace').doc('listing-1').set({
      title: 'Radiant Clear Quartz',
      crystalId: 'clear-quartz',
      priceCents: 4200,
      sellerId: 'seller-1',
      status: 'pending_review',
      description: 'Hand-polished point for clarity work.',
      sellerName: 'Seller One',
      category: 'Clusters',
      imageUrl: 'https://example.com/quartz.jpg',
      isVerifiedSeller: false,
      rating: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    })
  );

  await assertFails(
    sellerDb.collection('marketplace').doc('listing-2').set({
      title: 'Instant Approve Listing',
      crystalId: 'amethyst',
      priceCents: 2500,
      sellerId: 'seller-1',
      status: 'active',
      description: 'Should fail because status is active.',
      sellerName: 'Seller One',
      category: 'Clusters',
      imageUrl: 'https://example.com/amethyst.jpg',
      isVerifiedSeller: false,
      rating: null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    })
  );

  await assertSucceeds(
    sellerDb.collection('marketplace').doc('listing-1').update({
      priceCents: 3900,
      updatedAt: new Date().toISOString(),
      status: 'inactive',
    })
  );

  const adminDb = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).firestore();

  await assertSucceeds(
    adminDb.collection('marketplace').doc('listing-1').update({
      status: 'active',
      moderation: {
        status: 'approved',
        reviewerId: 'admin-user',
      },
      moderationHistory: [
        {
          reviewerId: 'admin-user',
          decision: 'approved',
        },
      ],
      updatedAt: new Date().toISOString(),
    })
  );
});

test('support ticket access and comments enforce visibility', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await adminDb.collection('support_tickets').doc('ticket-1').set({
      userId: 'user-1',
      subject: 'Help with crystal pairing',
      description: 'Need assistance matching crystals to intentions.',
      status: 'open',
      priority: 'medium',
      channel: 'app',
      tags: ['pairing'],
      createdAt: new Date(),
      updatedAt: new Date(),
      lastActivityAt: new Date(),
    });

    await adminDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .doc('public-comment')
      .set({
        authorId: 'user-1',
        authorRole: 'customer',
        visibility: 'public',
        message: 'Following up on my request.',
        createdAt: new Date(),
      });

    await adminDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .doc('internal-comment')
      .set({
        authorId: 'support-agent',
        authorRole: 'support',
        visibility: 'internal',
        message: 'Assign to moonstone specialist.',
        createdAt: new Date(),
      });
  });

  const ownerDb = testEnv.authenticatedContext('user-1', {
    email_verified: true,
  }).firestore();

  await assertSucceeds(ownerDb.collection('support_tickets').doc('ticket-1').get());

  await assertSucceeds(
    ownerDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .doc('public-comment')
      .get()
  );

  await assertFails(
    ownerDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .doc('internal-comment')
      .get()
  );

  await assertFails(
    ownerDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .add({
        authorId: 'user-1',
        authorRole: 'customer',
        visibility: 'public',
        message: 'Direct write should fail.',
        createdAt: new Date(),
      })
  );

  const strangerDb = testEnv.authenticatedContext('user-2', {
    email_verified: true,
  }).firestore();

  await assertFails(strangerDb.collection('support_tickets').doc('ticket-1').get());

  const adminDb = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).firestore();

  await assertSucceeds(
    adminDb
      .collection('support_tickets')
      .doc('ticket-1')
      .collection('comments')
      .doc('internal-comment')
      .get()
  );
});

test('storage rules allow owners and admins but block other users', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }
  const sellerStorage = testEnv.authenticatedContext('seller-1', {
    email_verified: true,
  }).storage();

  await assertSucceeds(
    sellerStorage.bucket().file('marketplace/seller-1/demo.jpg').save(Buffer.from('image'))
  );

  const otherStorage = testEnv.authenticatedContext('intruder', {
    email_verified: true,
  }).storage();

  await assertFails(
    otherStorage.bucket().file('marketplace/seller-1/demo.jpg').save(Buffer.from('oops'))
  );

  const adminStorage = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).storage();

  await assertSucceeds(
    adminStorage.bucket().file('users/another-user/avatar.png').save(Buffer.from('avatar'))
  );
});

test('plan catalog is publicly readable and admin writable', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }
  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(
    anonDb.collection('plan_catalog').doc('premium').get()
  );

  const userDb = testEnv.authenticatedContext('regular-user', {
    email_verified: true,
  }).firestore();

  await assertFails(
    userDb.collection('plan_catalog').doc('premium').set({
      displayName: 'Test Premium',
    })
  );

  const adminDb = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).firestore();

  await assertSucceeds(
    adminDb.collection('plan_catalog').doc('premium').set({
      displayName: 'Premium',
      updatedAt: new Date().toISOString(),
    })
  );
});

test('plan alias configuration is readable and restricted to admins', async (t) => {
  if (skipRulesTests) {
    t.skip('Firestore emulator not available.');
    return;
  }
  const anonDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(
    anonDb.collection('config').doc('plan_aliases').get()
  );

  const userDb = testEnv.authenticatedContext('regular-user', {
    email_verified: true,
  }).firestore();

  await assertFails(
    userDb.collection('config').doc('plan_aliases').set({
      aliasMap: { explorer: 'free' },
    })
  );

  const adminDb = testEnv.authenticatedContext('admin-user', {
    role: 'admin',
    email_verified: true,
  }).firestore();

  await assertSucceeds(
    adminDb.collection('config').doc('plan_aliases').set({
      aliasMap: { explorer: 'free' },
      updatedAt: new Date().toISOString(),
    })
  );
});
