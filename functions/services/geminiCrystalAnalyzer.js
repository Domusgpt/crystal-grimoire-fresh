const { config } = require('firebase-functions/v1');
const { HttpsError } = require('firebase-functions/v2/https');
const { GoogleGenerativeAI, SchemaType } = require('@google/generative-ai');

let cachedModelPromise = null;

function buildResponseSchema() {
  return {
    type: SchemaType.OBJECT,
    properties: {
      report: {
        type: SchemaType.STRING,
        description:
          "A detailed report in markdown format prioritising metaphysical and spiritual insights with geological context.",
      },
      data: {
        type: SchemaType.OBJECT,
        properties: {
          crystal_type: {
            type: SchemaType.STRING,
            description: 'The identified crystal or mineral name, or Unknown if unclear.',
          },
          colors: {
            type: SchemaType.ARRAY,
            items: { type: SchemaType.STRING },
            description: 'Dominant colours observed in the crystal image.',
          },
          analysis_date: {
            type: SchemaType.STRING,
            description: 'ISO 8601 date for when the analysis was generated.',
          },
          metaphysical_properties: {
            type: SchemaType.OBJECT,
            properties: {
              primary_chakras: {
                type: SchemaType.ARRAY,
                items: { type: SchemaType.STRING },
                description: 'Primary chakras associated with the crystal.',
              },
              element: {
                type: SchemaType.STRING,
                description: 'Element most closely aligned with the crystal.',
              },
              zodiac_signs: {
                type: SchemaType.ARRAY,
                items: { type: SchemaType.STRING },
                description: 'Zodiac correspondences.',
              },
              healing_properties: {
                type: SchemaType.ARRAY,
                items: { type: SchemaType.STRING },
                description: 'Key metaphysical or healing properties.',
              },
            },
            required: ['primary_chakras', 'element', 'zodiac_signs', 'healing_properties'],
          },
          geological_data: {
            type: SchemaType.OBJECT,
            properties: {
              mohs_hardness: {
                type: SchemaType.STRING,
                description: 'Mohs hardness rating.',
              },
              chemical_formula: {
                type: SchemaType.STRING,
                description: 'Chemical formula of the crystal.',
              },
            },
            required: ['mohs_hardness', 'chemical_formula'],
          },
        },
        required: ['crystal_type', 'colors', 'analysis_date', 'metaphysical_properties', 'geological_data'],
      },
    },
    required: ['report', 'data'],
  };
}

function sanitiseMarkdown(text) {
  if (!text || typeof text !== 'string') {
    return '';
  }
  return text.replace(/`+/g, '').replace(/\*{1,2}([^*]+)\*{1,2}/g, '$1').trim();
}

function extractSummary(report) {
  const plain = sanitiseMarkdown(report);
  if (!plain) {
    return '';
  }
  const sections = plain.split(/\n{2,}/).map((segment) => segment.trim()).filter(Boolean);
  if (sections.length === 0) {
    return plain;
  }
  return sections[0];
}

async function getModel() {
  if (!cachedModelPromise) {
    cachedModelPromise = (async () => {
      const apiKey = config().gemini?.api_key;
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'Gemini API key is not configured.');
      }

      const client = new GoogleGenerativeAI(apiKey);
      return client.getGenerativeModel({
        model: 'gemini-2.0-pro-exp-02-05',
        systemInstruction:
          'You are an expert gemologist providing detailed mineral identification and metaphysical properties in structured JSON.',
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.35,
          topP: 0.9,
          topK: 32,
          responseMimeType: 'application/json',
          responseSchema: buildResponseSchema(),
        },
      });
    })();
  }

  return cachedModelPromise;
}

function normaliseAnalysis(analysis) {
  if (!analysis || typeof analysis !== 'object') {
    throw new HttpsError('internal', 'Gemini analysis returned an unexpected format.');
  }

  const report = typeof analysis.report === 'string' ? analysis.report.trim() : '';
  const data = (analysis.data && typeof analysis.data === 'object') ? analysis.data : {};
  const metaphysical = (data.metaphysical_properties && typeof data.metaphysical_properties === 'object')
    ? data.metaphysical_properties
    : {};
  const colours = Array.isArray(data.colors) ? data.colors.filter(Boolean).map(String) : [];

  const element = metaphysical.element ? String(metaphysical.element) : null;
  const elementsList = element ? [element] : [];

  const metaphysicalProperties = {
    ...metaphysical,
    element,
    elements: elementsList,
    primary_chakras: Array.isArray(metaphysical.primary_chakras)
      ? metaphysical.primary_chakras.map(String)
      : [],
    healing_properties: Array.isArray(metaphysical.healing_properties)
      ? metaphysical.healing_properties.map(String)
      : [],
    zodiac_signs: Array.isArray(metaphysical.zodiac_signs)
      ? metaphysical.zodiac_signs.map(String)
      : [],
  };

  const geological = (data.geological_data && typeof data.geological_data === 'object')
    ? data.geological_data
    : {};

  const description = extractSummary(report);

  return {
    report,
    description,
    structuredData: {
      ...data,
      metaphysical_properties: metaphysicalProperties,
      colors: colours,
      geological_data: geological,
    },
    identification: {
      name: data.crystal_type ? String(data.crystal_type) : 'Unknown Crystal',
      variety: null,
      confidence: null,
    },
    metaphysical_properties: metaphysicalProperties,
    colors: colours,
    geological_data: geological,
  };
}

async function analyzeCrystalImage(imageBase64) {
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    throw new HttpsError('invalid-argument', 'Image data must be provided as a base64 string.');
  }

  const model = await getModel();

  const prompt = `You are a world-class gemologist and spiritual guide. Analyse the provided image to identify any crystals, minerals, or stones. ` +
    `Your response must be a JSON object that strictly adheres to the provided schema. In the 'report' field write a detailed analysis ` +
    `in markdown format beginning with the official mineral name for clarity. Focus on metaphysical and spiritual information while ` +
    `including geological details. If no crystal is apparent, set crystal_type to "Unknown" and explain what is visible.`;

  const response = await model.generateContent([
    {
      role: 'user',
      parts: [
        { text: prompt },
        {
          inlineData: {
            mimeType: 'image/jpeg',
            data: imageBase64,
          },
        },
      ],
    },
  ]);

  let rawText = null;
  if (response?.response?.text) {
    rawText = response.response.text();
  } else if (typeof response?.text === 'function') {
    rawText = response.text();
  } else if (typeof response?.text === 'string') {
    rawText = response.text;
  }

  if (!rawText) {
    throw new HttpsError('internal', 'Gemini returned an empty response.');
  }

  const cleaned = rawText
    .toString()
    .replace(/```json\s*/g, '')
    .replace(/```/g, '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (error) {
    console.error('Failed to parse Gemini response:', cleaned);
    throw new HttpsError('internal', 'Unable to parse Gemini analysis response.');
  }

  return normaliseAnalysis(parsed);
}

module.exports = {
  analyzeCrystalImage,
};
