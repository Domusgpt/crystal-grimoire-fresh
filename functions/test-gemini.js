/**
 * Test script to validate Gemini integration
 */

const {
  analyzeCrystalImage,
  normalizeAnalysisResponse,
  DEFAULT_PROMPT,
} = require('./services/geminiCrystalAnalyzer');

async function testGeminiIntegration() {
  console.log('🧪 Testing Gemini integration...');

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'test-key') {
    console.log('❌ No Gemini API key found');
    console.log('Set GEMINI_API_KEY environment variable');
    return false;
  }
  
  try {
    const sampleImageBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

    const rawAnalysis = await analyzeCrystalImage({
      apiKey,
      imageData: sampleImageBase64,
      mimeType: 'image/png',
      prompt: `${DEFAULT_PROMPT}\n\nNote: This is a minimal sample image used for integration testing. If no crystal is detected, respond with Unknown.`,
    });

    const crystalData = normalizeAnalysisResponse(rawAnalysis);

    console.log('✅ Gemini API working!');
    console.log('Crystal identified as:', crystalData.identification.name || 'Unknown');
    console.log('Confidence:', crystalData.identification.confidence, '%');

    return true;
  } catch (error) {
    console.error('❌ Gemini API error:', error.message);
    return false;
  }
}

// Run test
testGeminiIntegration().then(success => {
  process.exit(success ? 0 : 1);
});