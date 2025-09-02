/**
 * Test Vertex AI integration directly
 */

const { VertexAI } = require('@google-cloud/vertexai');

async function testVertexAI() {
  console.log('🧪 Testing Vertex AI integration...');
  
  try {
    const vertex_ai = new VertexAI({
      project: 'crystal-grimoire-2025',
      location: 'us-central1'
    });
    
    const model = vertex_ai.getGenerativeModel({ 
      model: 'gemini-1.5-pro',
      generation_config: {
        max_output_tokens: 100,
        temperature: 0.4,
        top_p: 1,
        top_k: 32
      }
    });
    
    const result = await model.generateContent(['Tell me about quartz crystals in JSON format with name and description fields only.']);
    const response = result.response.text();
    
    console.log('✅ Vertex AI working!');
    console.log('Response:', response);
    
    // Try to parse JSON
    try {
      const parsed = JSON.parse(response);
      console.log('✅ JSON parsing successful');
      console.log('Crystal:', parsed.name);
    } catch (parseError) {
      console.log('⚠️  JSON parsing failed, but API works');
    }
    
  } catch (error) {
    console.error('❌ Vertex AI error:', error.message);
    throw error;
  }
}

testVertexAI().then(() => {
  console.log('🎉 Test completed successfully');
  process.exit(0);
}).catch(error => {
  console.error('💥 Test failed:', error.message);
  process.exit(1);
});