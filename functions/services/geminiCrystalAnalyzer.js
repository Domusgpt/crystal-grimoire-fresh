"use strict";

const { GoogleGenerativeAI, SchemaType } = require("@google/generative-ai");

const DEFAULT_PROMPT = `You are a world-class gemologist and spiritual guide. Analyze the provided image to identify any crystals, minerals, or stones. Your response must be a JSON object that strictly adheres to the provided schema.

In the 'report' field, write a detailed analysis in markdown format. Start the report by clearly stating the official mineral name for clarity (e.g., "**Identified Mineral: Quartz (Amethyst variety)**"). Then, the primary focus should be on the metaphysical and spiritual information. Include the standard geological details but weave them into a more mystical narrative.

In the 'data' field, populate the structured information accurately based on your identification. For 'analysis_date', use today's date.

If no crystals are apparent, the 'crystal_type' should be 'Unknown' and the report should explain what is seen instead.`;

const RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    report: {
      type: SchemaType.STRING,
      description:
        "A detailed report in markdown format focusing on metaphysical insight while acknowledging geological facts.",
    },
    data: {
      type: SchemaType.OBJECT,
      properties: {
        crystal_type: {
          type: SchemaType.STRING,
          description: "The most likely name of the crystal or mineral.",
        },
        colors: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Dominant colors observed in the image.",
        },
        analysis_date: {
          type: SchemaType.STRING,
          description: "The current date of the analysis in ISO 8601 format (YYYY-MM-DD).",
        },
        metaphysical_properties: {
          type: SchemaType.OBJECT,
          properties: {
            primary_chakras: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: "Associated primary chakras (e.g., 'Root', 'Heart').",
            },
            element: {
              type: SchemaType.STRING,
              description: "Associated element (e.g., 'Earth', 'Water').",
            },
            zodiac_signs: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: "Associated zodiac signs (e.g., 'Aries', 'Taurus').",
            },
            healing_properties: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: "Key spiritual and healing properties.",
            },
          },
          required: [
            "primary_chakras",
            "element",
            "zodiac_signs",
            "healing_properties",
          ],
        },
        geological_data: {
          type: SchemaType.OBJECT,
          properties: {
            mohs_hardness: {
              type: SchemaType.STRING,
              description: "Mohs hardness scale rating (e.g., '7', '4-5').",
            },
            chemical_formula: {
              type: SchemaType.STRING,
              description: "Chemical formula (e.g., 'SiO2').",
            },
          },
          required: ["mohs_hardness", "chemical_formula"],
        },
        confidence_percent: {
          type: SchemaType.NUMBER,
          description: "Optional confidence estimate from 0-100.",
        },
        variety: {
          type: SchemaType.STRING,
          description: "Specific variety name if applicable (e.g., Rose Quartz).",
        },
        scientific_name: {
          type: SchemaType.STRING,
          description: "Scientific or mineralogical name if known.",
        },
        alternative_names: {
          type: SchemaType.ARRAY,
          items: { type: SchemaType.STRING },
          description: "Common alternative or trade names.",
        },
        care_recommendations: {
          type: SchemaType.OBJECT,
          properties: {
            cleansing: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: "Recommended cleansing methods.",
            },
            charging: {
              type: SchemaType.ARRAY,
              items: { type: SchemaType.STRING },
              description: "Recommended charging methods.",
            },
            storage: {
              type: SchemaType.STRING,
              description: "Best practices for storage and handling.",
            },
          },
        },
      },
      required: [
        "crystal_type",
        "colors",
        "analysis_date",
        "metaphysical_properties",
        "geological_data",
      ],
    },
  },
  required: ["report", "data"],
};

function cleanMarkdown(markdown) {
  if (!markdown || typeof markdown !== "string") {
    return "";
  }

  const withoutFormatting = markdown
    .replace(/```[\s\S]*?```/g, "")
    .replace(/\*\*/g, "")
    .replace(/\*/g, "")
    .replace(/#+\s*/g, "")
    .replace(/_+/g, "")
    .replace(/\s+/g, " ");

  return withoutFormatting.trim();
}

function summarizeReport(markdown) {
  const cleaned = cleanMarkdown(markdown);
  if (!cleaned) {
    return "";
  }

  const sentences = cleaned.split(/(?<=[.!?])\s+/).filter(Boolean);
  return sentences.slice(0, 3).join(" ");
}

function toStringArray(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => (typeof item === "string" ? item.trim() : String(item || "").trim()))
      .filter((item) => item.length > 0);
  }

  if (typeof value === "string" && value.trim().length > 0) {
    return [value.trim()];
  }

  return [];
}

function normalizeMetaphysical(meta = {}) {
  const healing = toStringArray(meta.healing_properties);
  const chakras = toStringArray(meta.primary_chakras);
  const zodiac = toStringArray(meta.zodiac_signs);
  const elementsArray = toStringArray(meta.element || meta.elements);

  return {
    healing_properties: healing,
    primary_chakras: chakras,
    zodiac_signs: zodiac,
    element: elementsArray.join(", "),
    elements: elementsArray,
    vibration: typeof meta.vibration === "string" ? meta.vibration : "",
    report_markdown: meta.report_markdown,
  };
}

function normalizeCare(care = {}) {
  return {
    cleansing: toStringArray(care.cleansing),
    charging: toStringArray(care.charging),
    storage: typeof care.storage === "string" ? care.storage : "",
  };
}

function normalizeGeological(geo = {}) {
  return {
    mohs_hardness: typeof geo.mohs_hardness === "string" ? geo.mohs_hardness : geo.mohs_hardness ? String(geo.mohs_hardness) : "",
    chemical_formula:
      typeof geo.chemical_formula === "string"
        ? geo.chemical_formula
        : geo.chemical_formula
        ? String(geo.chemical_formula)
        : "",
    crystal_system:
      typeof geo.crystal_system === "string"
        ? geo.crystal_system
        : geo.crystal_system
        ? String(geo.crystal_system)
        : "",
  };
}

function normalizeAnalysisResponse(raw) {
  if (!raw || typeof raw !== "object") {
    return {
      identification: {
        name: "Unknown",
        confidence: 0,
        variety: "",
        scientific_name: "",
        alternative_names: [],
      },
      description: "",
      metaphysical_properties: {
        healing_properties: [],
        primary_chakras: [],
        zodiac_signs: [],
        element: "",
        elements: [],
        vibration: "",
        report_markdown: "",
      },
      physical_properties: {
        mohs_hardness: "",
        chemical_formula: "",
        crystal_system: "",
      },
      care_instructions: {
        cleansing: [],
        charging: [],
        storage: "",
      },
      report_markdown: "",
      analysis_date: null,
      colors: [],
      structured_data: {},
    };
  }

  const data = raw.data && typeof raw.data === "object" ? raw.data : {};
  const report = typeof raw.report === "string" ? raw.report.trim() : "";

  const metaphysical = normalizeMetaphysical({
    ...data.metaphysical_properties,
    report_markdown: report,
  });
  const care = normalizeCare(data.care_recommendations || {});
  const geological = normalizeGeological(data.geological_data || {});

  const confidenceRaw = data.confidence_percent;
  const confidence = Number.isFinite(confidenceRaw)
    ? Math.max(0, Math.min(100, Math.round(Number(confidenceRaw))))
    : 0;

  const name = typeof data.crystal_type === "string" && data.crystal_type.trim().length
    ? data.crystal_type.trim()
    : "Unknown";

  return {
    identification: {
      name,
      confidence,
      variety: typeof data.variety === "string" ? data.variety : "",
      scientific_name: typeof data.scientific_name === "string" ? data.scientific_name : "",
      alternative_names: toStringArray(data.alternative_names),
    },
    description: summarizeReport(report),
    metaphysical_properties: metaphysical,
    physical_properties: geological,
    care_instructions: care,
    report_markdown: report,
    analysis_date: typeof data.analysis_date === "string" ? data.analysis_date : null,
    colors: toStringArray(data.colors),
    structured_data: data,
  };
}

async function analyzeCrystalImage({
  apiKey,
  imageData,
  mimeType = "image/jpeg",
  prompt = DEFAULT_PROMPT,
  model = "gemini-2.5-pro",
}) {
  if (!apiKey) {
    throw new Error("Gemini API key is required for crystal analysis");
  }

  if (!imageData) {
    throw new Error("Image data is required for crystal analysis");
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const generativeModel = genAI.getGenerativeModel({
    model,
    systemInstruction:
      "You are an expert gemologist providing detailed mineral identification and metaphysical properties in a structured JSON format.",
    generationConfig: {
      temperature: 0.3,
      topP: 0.9,
      topK: 32,
      maxOutputTokens: 2048,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  });

  const result = await generativeModel.generateContent({
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          { inlineData: { mimeType, data: imageData } },
        ],
      },
    ],
  });

  const response = result?.response;
  const text = typeof response?.text === "function" ? response.text() : "";
  if (!text) {
    throw new Error("Gemini returned an empty response");
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Unable to parse Gemini response: ${error.message || error}`);
  }
}

module.exports = {
  analyzeCrystalImage,
  normalizeAnalysisResponse,
  summarizeReport,
  DEFAULT_PROMPT,
};
