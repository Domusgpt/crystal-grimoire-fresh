/**
 * Firebase Authentication Setup Script
 * Sets up email/password and Google OAuth authentication
 */

const admin = require('firebase-admin');

async function setupFirebaseAuth() {
  try {
    console.log('🔧 Setting up Firebase Authentication...');

    // Initialize Firebase Admin
    admin.initializeApp({
      projectId: 'crystal-grimoire-2025'
    });

    console.log('✅ Firebase Admin initialized');

    // Create a test user for development
    const testUser = {
      email: 'test@crystalgrimoire.com',
      password: 'CrystalTest123!',
      emailVerified: true,
      displayName: 'Crystal Test User'
    };

    try {
      const userRecord = await admin.auth().createUser(testUser);
      console.log('✅ Test user created:', userRecord.uid);
    } catch (error) {
      if (error.code === 'auth/email-already-exists') {
        console.log('ℹ️  Test user already exists');
        const existingUser = await admin.auth().getUserByEmail(testUser.email);
        console.log('✅ Using existing test user:', existingUser.uid);
      } else {
        throw error;
      }
    }

    // Set custom claims for the test user (optional)
    const user = await admin.auth().getUserByEmail(testUser.email);
    await admin.auth().setCustomUserClaims(user.uid, {
      role: 'premium',
      plan: 'pro',
      createdAt: new Date().toISOString()
    });

    console.log('✅ Custom claims set for test user');

    console.log('🎉 Firebase Authentication setup complete!');
    console.log('📧 Test user email:', testUser.email);
    console.log('🔑 Test user password:', testUser.password);

    return true;

  } catch (error) {
    console.error('❌ Firebase Auth setup failed:', error);
    return false;
  }
}

// Run the setup
setupFirebaseAuth().then((success) => {
  if (success) {
    console.log('🎉 Setup completed successfully');
    process.exit(0);
  } else {
    console.error('💥 Setup failed');
    process.exit(1);
  }
}).catch(error => {
  console.error('💥 Unexpected error:', error);
  process.exit(1);
});