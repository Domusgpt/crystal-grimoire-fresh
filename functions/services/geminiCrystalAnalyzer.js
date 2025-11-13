'use strict';

const { GoogleGenerativeAI, SchemaType } = require('@google/generative-ai');

const DEFAULT_PROMPT = `You are a world-class gemologist and spiritual guide. Analyze the provided crystal image and respond with an in-depth report that merges geological accuracy with metaphysical insight. Follow the schema exactly and ensure values are truthful and concise.

Guidelines:
- Identify the most likely mineral or crystal. Include variety names when appropriate.
- Estimate a confidence percentage (0-100). If unsure, keep confidence low and explain uncertainty in the report.
- List dominant colors using simple color words (e.g., "violet", "clear", "blue-green").
- Focus the written report on the crystal's spiritual, healing, and energetic significance while acknowledging geological facts.
- Always provide practical care recommendations for cleansing, charging, and storage.
- Use today's date for the analysis date in ISO format (YYYY-MM-DD).
- If a crystal cannot be identified, set crystal_type to "Unknown" and explain what is visible.`;

const RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    report: {
      type: SchemaType.STRING,
      description:
        'A markdown report describing the crystal. Begin with the identified mineral name (e.g., "**Identified Mineral: Quartz (Amethyst variety)**") followed by metaphysical insights and practical advice.',
    },
    data: {
      type: SchemaType.OBJECT,
      properties: {
        crystal_type: {
          type: SchemaType.STRING,
          description: 'Most likely name of the crystal or mineral.',
        },
        variety: {
          type: SchemaType.STRING,
          description: 'Specific variety name if applicable (e.g., Rose Quartz).',
        },
        scientific_name: {
          type: SchemaType.STRING,
          description: 'Scientific or mineralogical name if known.',
        },
        confidence_percent: {
          type: SchemaType.NUMBER,
          description: 'Confidence in the identification from 0-100.',
        },
        alternative_names: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: 'Common alternative or trade names.',
        },
        colors: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: 'Dominant observed colors.',
        },
        analysis_date: {
          type: SchemaType.STRING,
          description: 'ISO 8601 date the analysis was generated.',
        },
        metaphysical_properties: {
          type: SchemaType.OBJECT,
          properties: {
            primary_chakras: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: 'Associated primary chakras.',
            },
            element: {
              type: SchemaType.STRING,
              description: 'Primary associated element (Earth, Water, Fire, Air, etc.).',
            },
            zodiac_signs: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: 'Associated zodiac signs.',
            },
            healing_properties: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: 'Key metaphysical or healing properties.',
            },
            vibration: {
              type: SchemaType.STRING,
              description: "Brief description of the crystal's energetic frequency.",
            },
          },
          required: ['primary_chakras', 'element', 'zodiac_signs', 'healing_properties'],
        },
        geological_data: {
          type: SchemaType.OBJECT,
          properties: {
            mohs_hardness: {
              type: SchemaType.STRING,
              description: 'Mohs hardness rating (e.g., "7" or "4-5").',
            },
            chemical_formula: {
              type: SchemaType.STRING,
              description: 'Chemical formula (e.g., "SiO2").',
            },
            crystal_system: {
              type: SchemaType.STRING,
              description: 'Crystal system if known (e.g., Trigonal).',
            },
          },
          required: ['mohs_hardness', 'chemical_formula'],
        },
        care_recommendations: {
          type: SchemaType.OBJECT,
          properties: {
            cleansing: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: 'Recommended cleansing methods.',
            },
            charging: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: 'Recommended charging methods.',
            },
            storage: {
              type: SchemaType.STRING,
              description: 'Best practices for storage and handling.',
            },
          },
          required: ['cleansing', 'charging', 'storage'],
        },
      },
      required: ['crystal_type', 'confidence_percent', 'metaphysical_properties', 'geological_data'],
    },
  },
  required: ['report', 'data'],
};

function cleanMarkdown(markdown) {
  if (!markdown || typeof markdown !== 'string') {
    return '';
  }
  const withoutFormatting = markdown
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\*\*/g, '')
    .replace(/\*/g, '')
    .replace(/#+\s*/g, '')
    .replace(/_+/g, '')
    .replace(/\s+/g, ' ');
  return withoutFormatting.trim();
}

function summarizeReport(markdown) {
  const cleaned = cleanMarkdown(markdown);
  if (!cleaned) {
    return '';
  }
  const sentences = cleaned.split(/(?<=[.!?])\s+/).filter(Boolean);
  return sentences.slice(0, 3).join(' ');
}

function normalizeMetaphysical(meta = {}) {
  const healing = Array.isArray(meta.healing_properties)
    ? meta.healing_properties
    : meta.healing_properties
      ? [meta.healing_properties].flat()
      : [];
  const chakras = Array.isArray(meta.primary_chakras) ? meta.primary_chakras : [];
  const zodiac = Array.isArray(meta.zodiac_signs) ? meta.zodiac_signs : [];
  const elementValue = meta.element || '';
  const elements = Array.isArray(elementValue) ? elementValue : elementValue ? [elementValue] : [];

  return {
    healing_properties: healing,
    primary_chakras: chakras,
    zodiac_signs: zodiac,
    element: Array.isArray(elementValue) ? elementValue.join(', ') : elementValue,
    elements,
    vibration: meta.vibration || '',
    report_markdown: meta.report_markdown,
  };
}

function normalizeCare(care = {}) {
  const cleansing = Array.isArray(care.cleansing)
    ? care.cleansing
    : care.cleansing
      ? [care.cleansing]
      : [];
  const charging = Array.isArray(care.charging)
    ? care.charging
    : care.charging
      ? [care.charging]
      : [];
  return {
    cleansing,
    charging,
    storage: care.storage || '',
  };
}

function normalizeGeological(geo = {}) {
  return {
    mohs_hardness: geo.mohs_hardness || '',
    chemical_formula: geo.chemical_formula || '',
    crystal_system: geo.crystal_system || '',
  };
}

function normalizeAnalysisResponse(raw) {
  if (!raw || typeof raw !== 'object') {
    return {
      identification: {
        name: 'Unknown',
        confidence: 0,
        variety: '',
        scientific_name: '',
        alternative_names: [],
      },
      description: '',
      metaphysical_properties: {
        healing_properties: [],
        primary_chakras: [],
        zodiac_signs: [],
        element: '',
        elements: [],
        vibration: '',
        report_markdown: '',
      },
      physical_properties: {
        mohs_hardness: '',
        chemical_formula: '',
        crystal_system: '',
      },
      care_instructions: {
        cleansing: [],
        charging: [],
        storage: '',
      },
      report_markdown: '',
      analysis_date: null,
      colors: [],
      structured_data: {},
    };
  }

  const data = raw.data || {};
  const report = typeof raw.report === 'string' ? raw.report.trim() : '';
  const description = summarizeReport(report);
  const metaphysical = normalizeMetaphysical({ ...data.metaphysical_properties, report_markdown: report });
  const care = normalizeCare(data.care_recommendations || {});
  const geological = normalizeGeological(data.geological_data || {});

  const confidence = typeof data.confidence_percent === 'number'
    ? Math.max(0, Math.min(100, Math.round(data.confidence_percent)))
    : 0;

  return {
    identification: {
      name: data.crystal_type || 'Unknown',
      variety: data.variety || '',
      scientific_name: data.scientific_name || '',
      confidence,
      alternative_names: Array.isArray(data.alternative_names) ? data.alternative_names : [],
    },
    description,
    metaphysical_properties: metaphysical,
    physical_properties: geological,
    care_instructions: care,
    report_markdown: report,
    analysis_date: data.analysis_date || null,
    colors: Array.isArray(data.colors) ? data.colors : [],
    structured_data: data,
  };
}

async function analyzeCrystalImage({
  apiKey,
  imageData,
  mimeType = 'image/jpeg',
  prompt = DEFAULT_PROMPT,
  model = 'gemini-1.5-pro-latest',
}) {
  if (!apiKey) {
    throw new Error('Gemini API key is required for crystal analysis');
  }
  if (!imageData) {
    throw new Error('Image data is required for crystal analysis');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const generativeModel = genAI.getGenerativeModel({
    model,
    systemInstruction:
      'You are an expert gemologist providing detailed mineral identification and metaphysical properties in a structured JSON format.',
    generationConfig: {
      temperature: 0.3,
      topP: 0.9,
      topK: 32,
      maxOutputTokens: 2048,
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
    },
  });

  const result = await generativeModel.generateContent({
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          { inlineData: { mimeType, data: imageData } },
        ],
      },
    ],
  });

  const response = result?.response;
  const text = typeof response?.text === 'function' ? response.text() : '';
  if (!text) {
    throw new Error('Gemini returned an empty response');
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new Error(`Unable to parse Gemini response: ${error.message || error}`);
  }

  return parsed;
}

module.exports = {
  analyzeCrystalImage,
  normalizeAnalysisResponse,
  summarizeReport,
  DEFAULT_PROMPT,
};
