# 🔮 Crystal Grimoire (Pre-MVP)

> **Status:** The repository contains a Flutter web shell backed by Firebase Auth/Firestore/Functions. Core flows (sign-in ➜ crystal identification ➜ collection) exist but several services are unfinished and the app does not compile without additional work. See [`docs/APP_ASSESSMENT.md`](docs/APP_ASSESSMENT.md) for a full audit.

## What’s Here
- Flutter 3.19+ web app with glassmorphic theming, animated backgrounds, and navigation between the planned feature modules.【F:lib/main.dart†L1-L59】【F:lib/screens/home_screen.dart†L1-L214】
- Firebase integrations for authentication, user profile bootstrap, crystal collection sync, dream journal entries, and callable Functions for AI-assisted features.【F:lib/services/app_service.dart†L1-L205】【F:functions/index.js†L200-L513】
- Cloud Functions powered by Gemini/Stripe: crystal identification, dream analysis, guidance logging, and Stripe Checkout stubs.【F:functions/index.js†L400-L799】
- Moon ritual planner persists intentions locally and in Firestore for cross-device continuity, and the marketplace includes an admin-only review tab for accounts with the `role=admin` claim.【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/services/ritual_preference_service.dart†L1-L200】【F:lib/screens/marketplace_screen.dart†L1-L1180】

## Major Gaps
- Stripe checkout now powers subscriptions on every platform; provide publishable/secret keys plus Stripe price IDs before building. RevenueCat dependencies were removed, so native IAP flows are no longer required.【F:lib/services/enhanced_payment_service.dart†L1-L400】【F:functions/index.js†L900-L1150】
- Callable Functions (`earnSeerCredits`, `generateHealingLayout`, `getMoonRituals`, `checkCrystalCompatibility`, etc.) exist but need valid config (Gemini/Stripe), quota monitoring, and error handling before exposing to real users.【F:lib/services/crystal_service.dart†L129-L276】【F:functions/index.js†L1760-L2335】
- Firestore security rules require verified email addresses and strict document schemas; unauthenticated or unverified accounts will receive `permission-denied`.【F:firestore.rules†L1-L120】
- The default widget test still references `MyApp`; update it to bootstrap `CrystalGrimoireApp` before enabling CI.【F:test/widget_test.dart†L12-L24】
- Marketplace submissions enter a pending-review queue via the callable Function; admins (custom claim `role: admin`) can approve/reject listings from the in-app review tab, but payments remain stubbed.

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
