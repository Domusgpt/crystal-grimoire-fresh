/**
 * Test script to validate Gemini integration
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testGeminiIntegration() {
  console.log('🧪 Testing Gemini integration...');
  
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey === 'test-key') {
    console.log('❌ No Gemini API key found');
    console.log('Set GEMINI_API_KEY environment variable');
    return false;
  }
  
  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });
    
    const result = await model.generateContent([
      'Identify this crystal and provide a brief description in JSON format with fields: name, description, healing_properties (array), metaphysical_properties (object with chakras array and energy_type)',
      'Crystal description: A clear, six-sided pointed crystal with high clarity'
    ]);
    
    const response = result.response.text();
    console.log('✅ Gemini API working!');
    console.log('Response preview:', response.substring(0, 200) + '...');
    
    // Try to parse JSON
    try {
      const cleanJson = response.replace(/```json\n?|\n?```/g, '').trim();
      const parsed = JSON.parse(cleanJson);
      console.log('✅ JSON parsing successful');
      console.log('Crystal identified as:', parsed.name || 'Unknown');
      return true;
    } catch (parseError) {
      console.log('⚠️  JSON parsing failed, but API works');
      return true;
    }
    
  } catch (error) {
    console.error('❌ Gemini API error:', error.message);
    return false;
  }
}

// Run test
testGeminiIntegration().then(success => {
  process.exit(success ? 0 : 1);
});