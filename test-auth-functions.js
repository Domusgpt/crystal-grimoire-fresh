/**
 * Test authenticated Firebase Functions
 * Tests Gemini integration with proper Firebase Authentication
 */

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFunctions, httpsCallable } = require('firebase/functions');

async function testAuthenticatedFunctions() {
  console.log('🧪 Testing authenticated Firebase Functions...');
  
  try {
    // Initialize Firebase client
    const firebaseConfig = {
      projectId: "crystal-grimoire-2025",
      appId: "1:513072589861:web:9168cf06b3bda7bbbce3cc",
      storageBucket: "crystal-grimoire-2025.firebasestorage.app",
      apiKey: "AIzaSyCJmhjH8HS3yHwwoZ9qCSKyNPCR5XRVxTI",
      authDomain: "crystal-grimoire-2025.firebaseapp.com",
      messagingSenderId: "513072589861"
    };

    const app = initializeApp(firebaseConfig);
    const auth = getAuth(app);
    const functions = getFunctions(app, 'us-central1');
    
    console.log('✅ Firebase client initialized');

    // Test user credentials
    const testUser = {
      email: 'test@crystalgrimoire.com',
      password: 'CrystalTest123!'
    };

    // Try to sign in, create user if doesn't exist
    let userCredential;
    try {
      console.log('🔐 Attempting to sign in existing user...');
      userCredential = await signInWithEmailAndPassword(auth, testUser.email, testUser.password);
      console.log('✅ Signed in existing user:', userCredential.user.uid);
    } catch (error) {
      if (error.code === 'auth/user-not-found' || error.code === 'auth/invalid-credential') {
        console.log('👤 Creating new test user...');
        userCredential = await createUserWithEmailAndPassword(auth, testUser.email, testUser.password);
        console.log('✅ Created new user:', userCredential.user.uid);
      } else {
        throw error;
      }
    }

    // Get ID token for authenticated requests
    const idToken = await userCredential.user.getIdToken();
    console.log('🎟️ Got authentication token');

    // Test 1: Health Check (public function)
    console.log('🏥 Testing health check...');
    const healthCheck = httpsCallable(functions, 'healthCheck');
    const healthResult = await healthCheck({});
    console.log('✅ Health Check Result:', JSON.stringify(healthResult.data, null, 2));

    // Test 2: Crystal Guidance (authenticated function)
    console.log('🔮 Testing authenticated crystal guidance...');
    const getCrystalGuidance = httpsCallable(functions, 'getCrystalGuidance');
    const guidanceResult = await getCrystalGuidance({
      question: "What crystal would help with meditation and inner peace?",
      intentions: ["meditation", "peace", "spirituality"],
      experience: "beginner"
    });
    
    console.log('✅ Crystal Guidance Result:', JSON.stringify(guidanceResult.data, null, 2));

    console.log('🎉 All authenticated function tests passed!');
    
    // Sign out
    await auth.signOut();
    console.log('👋 Signed out successfully');
    
    return true;
    
  } catch (error) {
    console.error('❌ Authenticated function test failed:', error.message);
    console.error('Error code:', error.code);
    console.error('Full error:', error);
    return false;
  }
}

testAuthenticatedFunctions().then((success) => {
  if (success) {
    console.log('🎉 All tests passed - Firebase Functions with Authentication working!');
    process.exit(0);
  } else {
    console.error('💥 Tests failed');
    process.exit(1);
  }
}).catch(error => {
  console.error('💥 Unexpected error:', error.message);
  process.exit(1);
});