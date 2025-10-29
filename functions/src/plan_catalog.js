"use strict";

const PLAN_DETAILS = Object.freeze({
  free: {
    plan: "free",
    effectiveLimits: {
      identifyPerDay: 3,
      guidancePerDay: 1,
      dreamAnalysesPerDay: 1,
      recommendationsPerDay: 2,
      moonRitualsPerDay: 1,
      journalMax: 50,
      collectionMax: 50,
    },
    flags: ["free"],
    lifetime: false,
  },
  premium: {
    plan: "premium",
    effectiveLimits: {
      identifyPerDay: 15,
      guidancePerDay: 5,
      dreamAnalysesPerDay: 5,
      recommendationsPerDay: 8,
      moonRitualsPerDay: 5,
      journalMax: 200,
      collectionMax: 250,
    },
    flags: ["priority_support", "stripe"],
    lifetime: false,
  },
  pro: {
    plan: "pro",
    effectiveLimits: {
      identifyPerDay: 40,
      guidancePerDay: 15,
      dreamAnalysesPerDay: 20,
      recommendationsPerDay: 25,
      moonRitualsPerDay: 20,
      journalMax: 500,
      collectionMax: 1000,
    },
    flags: ["priority_support", "advanced_ai", "stripe"],
    lifetime: false,
  },
  founders: {
    plan: "founders",
    effectiveLimits: {
      identifyPerDay: 999,
      guidancePerDay: 200,
      dreamAnalysesPerDay: 200,
      recommendationsPerDay: 300,
      moonRitualsPerDay: 200,
      journalMax: 2000,
      collectionMax: 2000,
    },
    flags: ["lifetime", "founder", "priority_support", "stripe"],
    lifetime: true,
  },
});

const PLAN_ALIASES = Object.freeze({
  explorer: "free",
  emissary: "premium",
  ascended: "pro",
  esper: "founders",
});

const USAGE_LIMIT_MAPPING = Object.freeze({
  crystal_identification: {
    limitKey: "identifyPerDay",
    usageField: "crystalIdentification",
    description: "crystal identifications",
  },
  crystal_guidance: {
    limitKey: "guidancePerDay",
    usageField: "crystalGuidance",
    description: "crystal guidance requests",
  },
  crystal_recommendations: {
    limitKey: "recommendationsPerDay",
    usageField: "recommendations",
    description: "recommendations",
  },
  healing_layout: {
    limitKey: "recommendationsPerDay",
    usageField: "healingLayouts",
    description: "healing layout requests",
  },
  moon_ritual: {
    limitKey: "moonRitualsPerDay",
    usageField: "moonRituals",
    description: "moon ritual lookups",
  },
  dream_analysis: {
    limitKey: "dreamAnalysesPerDay",
    usageField: "dreamAnalyses",
    description: "dream analyses",
  },
});

const PLAN_CATALOG_METADATA = Object.freeze({
  free: {
    displayName: "Explorer",
    tagline: "Track your crystals, journal dreams, and sample AI rituals.",
    displayPrice: "Free",
    billingCycle: "freemium",
    recommended: false,
    features: [
      "3 identifications each day",
      "Dream journal sync with verified email",
      "Starter rituals and moon reminders",
    ],
    sortOrder: 0,
  },
  premium: {
    displayName: "Emissary",
    tagline: "Daily guidance, richer rituals, and expanded journal space.",
    displayPrice: "$8.99 / month",
    billingCycle: "monthly",
    recommended: true,
    features: [
      "15 identifications every day",
      "Priority AI guidance responses",
      "Moon rituals synced across devices",
      "Curated healing layouts with intent presets",
    ],
    sortOrder: 1,
  },
  pro: {
    displayName: "Ascended",
    tagline: "Advanced AI ceremonies and deep-dive guidance for collectors.",
    displayPrice: "$19.99 / month",
    billingCycle: "monthly",
    recommended: false,
    features: [
      "40 identifications per day",
      "Extended dream and ritual insights",
      "Crystal compatibility matrix and export tools",
      "Weekly moon and chakra ceremony scripts",
    ],
    sortOrder: 2,
  },
  founders: {
    displayName: "Founders Circle",
    tagline: "Lifetime access to every ritual, ceremony, and beta release.",
    displayPrice: "$499 one-time",
    billingCycle: "lifetime",
    recommended: false,
    features: [
      "Unlimited identifications and rituals",
      "Founders badge and Discord role",
      "Priority feature voting and concierge support",
    ],
    sortOrder: 3,
  },
});

function normalizePlanId(input) {
  if (!input) {
    return "free";
  }
  const normalized = String(input).trim().toLowerCase();
  if (PLAN_DETAILS[normalized]) {
    return normalized;
  }
  if (PLAN_ALIASES[normalized]) {
    return PLAN_ALIASES[normalized];
  }
  return "free";
}

function resolvePlanDetails(tier) {
  const normalized = normalizePlanId(tier);
  const details = PLAN_DETAILS[normalized] || PLAN_DETAILS.free;
  return {
    plan: details.plan,
    tier: normalized,
    effectiveLimits: { ...details.effectiveLimits },
    flags: [...details.flags],
    lifetime: details.lifetime,
  };
}

function coerceUsageSnapshot(raw) {
  if (!raw || typeof raw !== "object") {
    return {
      dailyCounts: {},
      lifetimeCounts: {},
      lastResetDate: null,
      updatedAt: null,
    };
  }

  const dailyCounts = raw.dailyCounts && typeof raw.dailyCounts === "object"
    ? { ...raw.dailyCounts }
    : {};
  const lifetimeCounts = raw.lifetimeCounts && typeof raw.lifetimeCounts === "object"
    ? { ...raw.lifetimeCounts }
    : {};

  return {
    dailyCounts,
    lifetimeCounts,
    lastResetDate: raw.lastResetDate || null,
    updatedAt: raw.updatedAt || null,
  };
}

function buildPlanStatusResponse(planDetails, usageData) {
  const usage = coerceUsageSnapshot(usageData);

  return {
    plan: planDetails.plan,
    tier: planDetails.tier,
    lifetime: planDetails.lifetime,
    flags: [...planDetails.flags],
    limits: { ...planDetails.effectiveLimits },
    usage: {
      daily: usage.dailyCounts,
      lifetime: usage.lifetimeCounts,
      lastResetDate: usage.lastResetDate,
      updatedAt: usage.updatedAt,
    },
  };
}

module.exports = {
  PLAN_DETAILS,
  PLAN_ALIASES,
  USAGE_LIMIT_MAPPING,
  PLAN_CATALOG_METADATA,
  normalizePlanId,
  resolvePlanDetails,
  coerceUsageSnapshot,
  buildPlanStatusResponse,
};
