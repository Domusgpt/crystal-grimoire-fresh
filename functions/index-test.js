const { onCall } = require('firebase-functions/v2/https');

exports.test = onCall({ cors: true }, async (request) => {
  return { success: true, message: 'Functions working!', timestamp: new Date().toISOString() };
});

console.log('Test function loaded');