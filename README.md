# 🔮 Crystal Grimoire (Pre-MVP)

> **Status:** The repository contains a Flutter web shell backed by Firebase Auth/Firestore/Functions. Core flows (sign-in ➜ crystal identification ➜ collection) exist but several services are unfinished and the app does not compile without additional work. See [`docs/APP_ASSESSMENT.md`](docs/APP_ASSESSMENT.md) for a full audit.

## What’s Here
- Flutter 3.19+ web app with glassmorphic theming, animated backgrounds, and navigation between the planned feature modules.【F:lib/main.dart†L1-L59】【F:lib/screens/home_screen.dart†L1-L214】
- Firebase integrations for authentication, user profile bootstrap, crystal collection sync, dream journal entries, and callable Functions for AI-assisted features.【F:lib/services/app_service.dart†L1-L205】【F:functions/index.js†L200-L513】
- Cloud Functions powered by Gemini/Stripe: crystal identification, dream analysis, guidance logging, and Stripe Checkout stubs.【F:functions/index.js†L400-L799】

## Major Gaps
- `FirebaseExtensionsService` still references private getters in `FirebaseService`, causing compile errors until the API surface is adjusted or the service is removed.【F:lib/services/firebase_extensions_service.dart†L34-L88】【F:lib/services/firebase_service.dart†L1-L160】
- Callable Functions now exist for moon rituals, healing layouts, compatibility checks, marketplace listings, and Seer credit earning/spending, but they require seeded data plus Gemini/Stripe config and must handle quota errors gracefully in the UI.【F:lib/services/crystal_service.dart†L19-L276】【F:functions/index.js†L912-L2374】
- Firestore security rules require verified email addresses and strict document schemas; unauthenticated or unverified accounts will receive `permission-denied`.【F:firestore.rules†L1-L120】
- The default widget test still references `MyApp`; update it to bootstrap `CrystalGrimoireApp` before enabling CI.【F:test/widget_test.dart†L12-L24】

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
   Additional keys (Claude, Groq, RevenueCat) map to `EnvironmentConfig` if you plan to exercise those services.【F:lib/services/environment_config.dart†L1-L200】

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
