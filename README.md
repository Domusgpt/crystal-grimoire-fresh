# 🔮 Crystal Grimoire

AI-assisted crystal identification, guidance, and collection tracking built with Flutter Web and Firebase.

## Overview
Crystal Grimoire pairs a glassmorphic Flutter experience with Firebase Authentication, Firestore, Cloud Functions, and runtime-configurable AI/commerce services. The app now targets a beta-ready feature set:

- **Crystal tools** – Upload photos for Gemini-powered identifications, store results per user, and maintain a Firestore-backed personal collection with offline caching.
- **Guidance & dreams** – Generate structured guidance and dream analyses through callable Functions while persisting entries, moods, and moon phase metadata in Firestore.
- **Accounts & settings** – Manage preferences, privacy toggles, and subscription status from Settings and Account screens with optimistic UI feedback and SharedPreferences snapshots.
- **Subscriptions** – Stripe checkout for web, RevenueCat for mobile, and shared entitlement math (`lib/config/plan_entitlements.dart`) keep `users/{uid}.profile` and `plan/active` in sync.
- **Sound bath** – Procedural audio scenes render at runtime so no binary assets ship with the repo.

## Repository layout
```
lib/
  config/                # Environment + entitlement helpers
  models/                # Crystal, collection, plan, guidance, dream
  screens/               # Flutter UI (collection, profile, settings, paywall…)
  services/              # AppState, AuthService, AI/collection/payment helpers
  widgets/               # Shared UI components & animations
functions/               # Cloud Functions (Stripe checkout, AI, account cleanup)
public/                  # Marketing landing page
storage.rules            # Firebase Storage rules
firestore.rules          # Firestore rules tightened for SPEC-1
DEVELOPER_HANDOFF.me     # Engineering handoff reference
DEPLOYMENT_GUIDE.md      # Deployment runbook (updated)
PROJECT_STATUS.md        # Current state + roadmap snapshot
CLAUDE.md                # Agent-focused quick start
```

## Prerequisites
| Tool | Notes |
| ---- | ----- |
| Flutter 3.19+ | Install via `asdf` or Flutter installer. |
| Node.js 20 | Required for Cloud Functions (`npm install` inside `functions/`). |
| Firebase CLI | `npm install -g firebase-tools`, then `firebase login`. |
| Stripe account | Provide publishable/secret keys + price IDs. |
| Google AI Studio | Gemini API key stored in Functions config or dart-define. |

## Configuration
All secrets and runtime switches are read from environment defines or Functions config. Provide these before running or building:

| Key | Purpose |
| --- | --- |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID` | Firebase initialization |
| `GEMINI_API_KEY` (+ optional `OPENAI_API_KEY`, `CLAUDE_API_KEY`, `GROQ_API_KEY`) | LLM providers |
| `AI_DEFAULT_PROVIDER` | Selects default AI backend (`gemini` recommended) |
| `REVENUECAT_API_KEY` | Mobile purchases |
| `STRIPE_PUBLISHABLE_KEY`, `STRIPE_PREMIUM_PRICE_ID`, `STRIPE_PRO_PRICE_ID`, `STRIPE_FOUNDERS_PRICE_ID` | Web checkout |
| `BACKEND_URL`, `USE_LOCAL_BACKEND` | Optional REST backend routing |
| `TERMS_URL`, `PRIVACY_URL`, `SUPPORT_URL`, `SUPPORT_EMAIL` | Compliance links |
| `ADMOB_*` keys | AdMob production units (defaults to Google test IDs) |
| `HOROSCOPE_API_KEY` | Optional external astrology provider |

Set Stripe credentials for Functions:
```bash
firebase functions:config:set \
  stripe.secret_key=sk_live_xxx \
  stripe.premium_price_id=price_123 \
  stripe.pro_price_id=price_456 \
  stripe.founders_price_id=price_789
```

## Getting started
```bash
flutter pub get
(cd functions && npm install)

# Supply dart-defines or use .vscode/launch.json style configs
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=STRIPE_PUBLISHABLE_KEY=...
```

To run Cloud Functions locally or deploy:
```bash
# Local emulator (requires env vars/secrets)
npm --prefix functions run serve

# Deploy firestore rules, hosting, and functions
firebase deploy --only firestore:rules,functions,hosting
```

## Testing & quality
- `flutter analyze` – Static analysis (requires Flutter SDK).
- `flutter test` – Widget/unit tests (add coverage as features expand).
- `npm --prefix functions run lint` – ESLint for Cloud Functions.

Document outstanding gaps and fixes in `PROJECT_STATUS.md` and `CLAUDE.md` before handoff.

## Roadmap snapshot
See `PROJECT_STATUS.md` for the current backlog. Key focus areas heading into beta:
- Backfill crystal library content and marketing assets.
- Harden Stripe/RevenueCat error flows and add integration tests.
- Expand dream/ritual prompts with additional safety filters.
- Finalize push notifications + App Check enforcement before GA.

