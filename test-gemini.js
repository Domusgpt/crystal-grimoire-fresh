/**
 * Test Gemini integration with deployed Firebase Functions
 */

const { initializeApp } = require('firebase-admin/app');
const { getFunctions } = require('firebase-admin/functions');
const { httpsCallable } = require('firebase/functions');
const { initializeApp: clientInit } = require('firebase/app');
const { getAuth } = require('firebase/auth');
const { getFunctions: getClientFunctions } = require('firebase/functions');

async function testGeminiIntegration() {
  console.log('🧪 Testing Gemini integration with deployed functions...');
  
  try {
    // Initialize Firebase client
    const firebaseConfig = {
      apiKey: "AIzaSyBdL9qT-9xoZsJTyKWPCMrKYhHnYsUz6U0",
      authDomain: "crystal-grimoire-2025.firebaseapp.com",
      projectId: "crystal-grimoire-2025",
      storageBucket: "crystal-grimoire-2025.firebasestorage.app",
      messagingSenderId: "513072589861",
      appId: "1:513072589861:web:7dab7c0ebc5ab6b6b0e3ff"
    };

    const app = clientInit(firebaseConfig);
    const functions = getClientFunctions(app, 'us-central1');
    
    console.log('✅ Firebase client initialized');

    // Test crystal guidance function (simpler test first)
    console.log('🔍 Testing getCrystalGuidance function...');
    
    const getCrystalGuidance = httpsCallable(functions, 'getCrystalGuidance');
    const guidanceResult = await getCrystalGuidance({
      question: "What crystal would help with meditation and inner peace?",
      intentions: ["meditation", "peace", "spirituality"],
      experience: "beginner"
    });
    
    console.log('✅ Crystal Guidance Result:', JSON.stringify(guidanceResult.data, null, 2));
    
    console.log('🎉 Gemini integration test completed successfully!');
    return true;
    
  } catch (error) {
    console.error('❌ Gemini integration test failed:', error.message);
    console.error('Error details:', error);
    return false;
  }
}

testGeminiIntegration().then((success) => {
  if (success) {
    console.log('🎉 All tests passed');
    process.exit(0);
  } else {
    console.error('💥 Tests failed');
    process.exit(1);
  }
}).catch(error => {
  console.error('💥 Unexpected error:', error.message);
  process.exit(1);
});