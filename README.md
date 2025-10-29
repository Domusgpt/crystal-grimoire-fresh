# 🔮 Crystal Grimoire (Pre-MVP)

> **Status:** The repository contains a Flutter web shell backed by Firebase Auth/Firestore/Functions. Core flows (sign-in ➜ crystal identification ➜ collection) exist but several services are unfinished and the app does not compile without additional work. See [`docs/APP_ASSESSMENT.md`](docs/APP_ASSESSMENT.md) for a full audit.

## What’s Here
- Flutter 3.19+ web app with glassmorphic theming, animated backgrounds, and navigation between the planned feature modules.【F:lib/main.dart†L1-L59】【F:lib/screens/home_screen.dart†L1-L214】
- Firebase integrations for authentication, user profile bootstrap, crystal collection sync, dream journal entries, and callable Functions for AI-assisted features.【F:lib/services/app_service.dart†L1-L205】【F:functions/index.js†L200-L513】
- Cloud Functions powered by Gemini/Stripe: crystal identification, dream analysis, guidance logging, and Stripe Checkout stubs.【F:functions/index.js†L400-L799】
- Plan catalog seeding and the `getPlanStatus` callable expose dynamic plan metadata plus daily usage totals for gating the UI.【F:functions/index.js†L960-L1055】【F:scripts/seed_database.js†L1-L200】
- Plan status service caches the `getPlanStatus` callable locally so offline sessions still honor remote usage totals and tier limits.【F:lib/services/plan_status_service.dart†L1-L190】【F:lib/services/usage_tracker.dart†L1-L220】
- Monitoring pipeline with analytics-aware error capture on the client and structured logs for callable/endpoints so incidents can be triaged quickly.【F:lib/services/monitoring_service.dart†L1-L152】【F:functions/src/monitoring.js†L1-L63】【F:functions/index.js†L116-L124】【F:functions/index.js†L191-L205】
- Moon ritual planner persists intentions locally and in Firestore for cross-device continuity, and the marketplace includes an admin-only review tab for accounts with the `role=admin` claim.【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/services/ritual_preference_service.dart†L1-L200】【F:lib/screens/marketplace_screen.dart†L1-L1180】

## Major Gaps
- Stripe checkout now powers subscriptions on every platform; provide publishable/secret keys plus Stripe price IDs before building. RevenueCat dependencies were removed, so native IAP flows are no longer required.【F:lib/services/enhanced_payment_service.dart†L1-L400】【F:functions/index.js†L900-L1150】
- Callable Functions (`earnSeerCredits`, `generateHealingLayout`, `getMoonRituals`, `checkCrystalCompatibility`, etc.) now enforce per-plan quotas server-side. Provide valid Gemini/Stripe configuration and expect quota errors (`resource-exhausted`) once limits are reached.【F:functions/index.js†L830-L1175】【F:functions/index.js†L2450-L2594】
- Firestore security rules require verified email addresses and strict document schemas; unauthenticated or unverified accounts will receive `permission-denied`.【F:firestore.rules†L1-L120】
- Callable economy and Stripe flows are disabled by default. Provide Firebase Functions plus `--dart-define=ENABLE_ECONOMY_FUNCTIONS=true` and `ENABLE_STRIPE_CHECKOUT=true` before relying on Seer Credits or hosted checkout.【F:lib/services/economy_service.dart†L1-L260】【F:lib/services/enhanced_payment_service.dart†L1-L320】
- Marketplace submissions enter a pending-review queue via the callable Function; admins (custom claim `role: admin`) can approve/reject listings from the in-app review tab, but payments remain stubbed.

## Quick Start (development)
1. Install prerequisites: Flutter 3.19+, Node 20, Firebase CLI.
   - **One-liner setup:** `./scripts/setup_flutter_firebase_tools.sh` clones Flutter (stable) into `~/.local/flutter`, adds it to the current shell `PATH`, and installs the Firebase CLI via npm. Override the install location with `FLUTTER_HOME=/custom/path` or select a different channel with `FLUTTER_CHANNEL=beta`.
   - **Manual setup:** follow [Flutter’s Linux install guide](https://docs.flutter.dev/get-started/install/linux) and `npm install -g firebase-tools --no-progress`, then ensure `flutter --version` and `firebase --version` succeed before continuing.
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
     stripe.secret_key=... stripe.premium_price_id=... stripe.pro_price_id=... stripe.founders_price_id=... \
     stripe.webhook_secret=...
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --data-file <(echo -n "whsec_...")
   ```
4. Seed Firestore with starter data:
   ```bash
   node scripts/seed_database.js --project <your-project-id>
   # add --serviceAccount=path/to/key.json when not using application default credentials
   # add --dry-run to preview without writing
   ```
   The script populates the crystal library, feature flags, plan catalog (including alias mappings), a demo user, moon ritual preferences, and a pending marketplace listing.【F:scripts/seed_database.js†L1-L360】
5. Export production collections as part of your backup cadence:
   ```bash
   npm run export:firestore -- --project <your-project-id> --serviceAccount path/to/admin.json
   ```
   This writes JSON snapshots into `backups/<project>-<timestamp>` for `users`, `crystal_library`, `marketplace`, `plans`, and `feature_flags`. Pass `--collections` to customise the list.【F:scripts/export_firestore.js†L1-L147】
6. Triage support tickets from the command line (service account or ADC required):
   ```bash
   FIREBASE_PROJECT_ID=<your-project-id> \
   GOOGLE_APPLICATION_CREDENTIALS=./admin.json \
   node scripts/support_ticket_cli.js list --status=open
   ```
   Use `assign <ticketId> <assigneeId>` to delegate work or `close <ticketId>` once resolved.【F:scripts/support_ticket_cli.js†L1-L196】
7. Run the app with the required Dart defines:
   ```bash
   flutter run -d chrome \
     --dart-define=GEMINI_API_KEY=... \
     --dart-define=STRIPE_PUBLISHABLE_KEY=... \
     --dart-define=OPENAI_API_KEY=... (optional) \
     --dart-define=ENABLE_ECONOMY_FUNCTIONS=true (when Firebase Functions deployed) \
     --dart-define=ENABLE_STRIPE_CHECKOUT=true (when Stripe checkout configured) \
     --dart-define=ENABLE_SUPPORT_TICKETS=true (to sync support tickets instead of local-only drafts)
   ```
Additional keys (Claude, Groq, RevenueCat) map to `EnvironmentConfig` if you plan to exercise those services.【F:lib/services/environment_config.dart†L1-L200】

Refer to [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md) for full setup/deployment instructions, [`docs/RELEASE_PLAN.md`](docs/RELEASE_PLAN.md) for milestone checklists, and [`DEVELOPER_HANDOFF.me`](DEVELOPER_HANDOFF.me) for engineering context.

## Continuous Integration

- GitHub Actions (`.github/workflows/ci.yml`) validates Firebase Functions lint/unit tests with Node 20 and runs targeted Flutter analysis/tests (`flutter analyze`, plan status unit test, widget smoke test).【F:.github/workflows/ci.yml†L1-L44】

## Operations & Monitoring

- `MonitoringService` captures app boot, callable usage, and crash reports in Analytics while gracefully degrading when Firebase is disabled, giving operators signal even in beta environments.【F:lib/services/monitoring_service.dart†L1-L152】【F:lib/main.dart†L1-L70】
- Cloud Functions emit structured log entries (start/success/failure, duration) for all critical endpoints, simplifying alert rules and debugging in Cloud Logging.【F:functions/src/monitoring.js†L1-L63】【F:functions/index.js†L116-L205】【F:functions/index.js†L325-L339】
- `scripts/export_firestore.js` provides a one-line JSON backup workflow for the primary collections so on-call engineers can recover data during incidents.【F:scripts/export_firestore.js†L1-L147】
- Support callables (`createSupportTicket`, `addSupportTicketComment`, `updateSupportTicketStatus`) centralise ticket intake, audit trails, and operations workflows; pair them with the CLI above for manual triage or automation.【F:functions/index.js†L1900-L2148】【F:scripts/support_ticket_cli.js†L1-L196】
- `SupportService` mirrors the callable transitions client-side so QA can create tickets, add comments, retry updates offline, and call `synchronizePending` once Firebase comes back online to push drafts to production.【F:lib/services/support_service.dart†L1-L940】【F:test/services/support_service_test.dart†L1-L126】
- See `docs/OPERATIONS_RUNBOOK.md` for monitoring dashboards, incident workflows, and backup restoration guidance.【F:docs/OPERATIONS_RUNBOOK.md†L1-L53】

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
