/**
 * 🧪 TEST FUNCTION EXPORTS
 * Verify all Cloud Functions are properly exported
 * Run with: node test-exports.js
 */

// Initialize Firebase Admin for testing
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'test-project',
    databaseURL: 'http://localhost:8080'
  });
}

console.log('🧪 Testing Function Exports...\n');

// Mock config for Gemini API
process.env.GCLOUD_PROJECT = 'test-project';

const functions = require('./index-gamified');

const expectedFunctions = [
  'dailyCheckIn',
  'identifyCrystalGamified',
  'addToCollection',
  'getUserDashboard',
  'getMyReferralCode',
  'applyReferralCode',
  'getMyAchievements',
  'resetStreakFreezes'
];

console.log('📦 CHECKING EXPORTED FUNCTIONS\n');

let allExist = true;

for (const funcName of expectedFunctions) {
  if (functions[funcName]) {
    console.log(`✅ ${funcName} - exported`);
  } else {
    console.log(`❌ ${funcName} - MISSING`);
    allExist = false;
  }
}

console.log('\n' + '='.repeat(60));

if (allExist) {
  console.log('✅ ALL FUNCTIONS EXPORTED CORRECTLY\n');
  console.log('Ready for deployment!\n');
  process.exit(0);
} else {
  console.log('❌ SOME FUNCTIONS MISSING\n');
  process.exit(1);
}
