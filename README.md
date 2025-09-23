# 🔮 Crystal Grimoire (Pre-MVP)

> **Status:** The repository contains a Flutter web shell backed by Firebase Auth/Firestore/Functions. Core flows (sign-in ➜ crystal identification ➜ collection) run end-to-end and the moon ritual / healing screens now consume real Cloud Functions, but several production tasks remain. See [`docs/APP_ASSESSMENT.md`](docs/APP_ASSESSMENT.md) for a full audit.

## What’s Here
- Flutter 3.19+ web app with glassmorphic theming, animated backgrounds, and navigation between the planned feature modules.【F:lib/main.dart†L1-L59】【F:lib/screens/home_screen.dart†L1-L214】
- Firebase integrations for authentication, user profile bootstrap, crystal collection sync, dream journal entries, and callable Functions for AI-assisted features.【F:lib/services/app_service.dart†L1-L205】【F:functions/index.js†L200-L799】
- Cloud Functions powered by Gemini/Stripe: crystal identification, dream analysis, daily crystal, moon rituals, healing layouts, credits, and Stripe checkout helpers.【F:functions/index.js†L400-L2136】
- Moon Ritual and Crystal Healing screens hydrate their UI from the new backend responses (phase guidance, chakra layouts, breathwork, integration actions).【F:lib/screens/moon_rituals_screen.dart†L1-L420】【F:lib/screens/crystal_healing_screen.dart†L1-L420】

## Major Gaps
- Stripe checkout still requires live configuration (publishable key, secret, price IDs) and end-to-end testing before launch.【F:functions/index.js†L946-L1175】【F:lib/services/enhanced_payment_service.dart†L1-L216】
- Economy/billing guardrails exist server-side, but the UI does not yet feature-flag paid experiences—hide or gate premium flows until pricing is finalised.【F:lib/services/economy_service.dart†L1-L220】【F:lib/screens/subscription_screen.dart†L1-L360】
- Firestore security rules require verified email addresses and strict document schemas; unauthenticated or unverified accounts will receive `permission-denied`.【F:firestore.rules†L1-L120】
- Align the Functions runtime and repository Node version before deployment (Firebase targets Node 20, `functions/package.json` defaults to 22).【F:firebase.json†L7-L20】【F:functions/package.json†L1-L17】

## Quick Start (development)
1. Install prerequisites: Flutter 3.19+, Node 20, Firebase CLI.
2. Install dependencies:
   ```bash
   flutter pub get
   npm install --prefix functions
   ```
3. Configure Firebase:
   ```bash
   firebase login
   firebase use <your-project-id>
   firebase functions:config:set \
     gemini.api_key=... \
     stripe.secret_key=... stripe.premium_price_id=... stripe.pro_price_id=... stripe.founders_price_id=...
   ```
4. Seed Firestore (`crystal_library`) using `scripts/seed_database.js` or manual uploads.
5. Run the app with the required Dart defines:
   ```bash
   flutter run -d chrome \
     --dart-define=GEMINI_API_KEY=... \
     --dart-define=STRIPE_PUBLISHABLE_KEY=... \
     --dart-define=OPENAI_API_KEY=... (optional)
   ```
   Additional keys (Claude, Groq) map to `EnvironmentConfig`; RevenueCat fields only matter if you resurrect the legacy mobile purchase flow.【F:lib/services/environment_config.dart†L61-L164】

Refer to [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) for full setup/deployment instructions, [`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md) for milestone checklists, and [`DEVELOPER_HANDOFF.me`](DEVELOPER_HANDOFF.me) for engineering context.

## Directory Overview
```
crystal-grimoire-fresh/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── screens/                  # Feature screens (Home, Identification, Collection, Journal, etc.)
│   ├── services/                 # Firebase/AI/payment services (many are stubs)
│   ├── widgets/                  # Shared UI components
│   └── config/                   # Theme, plan entitlements, API config
├── functions/                    # Firebase Functions (Gemini, Stripe, bootstrap helpers)
├── public/                       # Static landing page used by Firebase Hosting
├── docs/                         # Updated assessment and documentation (added 2025)
├── firebase.json / firestore.rules / storage.rules
└── scripts/                      # Deployment helpers, Firestore seeding script
```

## Contributing
- Work in small, testable slices. Restore the build before adding new features.
- Document changes in `docs/APP_ASSESSMENT.md` or `DEVELOPER_HANDOFF.me` so the next contributor stays informed.
- Run `flutter analyze` and (after fixing the test harness) `flutter test` before committing.

## Roadmap Snapshot
| Phase | Focus |
| --- | --- |
| MVP | Fix build, deliver sign-in ➜ identify ➜ collection loop, seed Firestore, add smoke tests. |
| Beta | Implement/disable missing Functions, harden security rules, finalize Stripe flow, improve error handling. |
| Production | Monitoring/analytics, admin tooling, full payment & marketplace workflows, CI/CD. |

Questions? Check the updated documentation or leave notes in `DEVELOPER_HANDOFF.me`.
