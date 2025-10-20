# Crystal Grimoire Release Plan

This plan distills what is required to graduate the current repository from "pre-MVP" to a production-ready release. Use it as a checklist for Claude/agents and humans before each milestone.

## Stage Overview
| Stage | Primary Goal | Definition of Done |
| --- | --- | --- |
| **MVP / Internal Test** | Restore a compilable Flutter web build that demonstrates auth → identify → collection flows against Firebase. | Build succeeds (`flutter build web`), verified testers can sign in, identify a crystal via Functions, and add it to their collection using seeded library data. |
| **Beta / Limited Release** | Enable gated experiences (dream journal, daily crystal, subscriptions) with working backends, guard unfinished flows, and exercise payments in staging. | Callable Functions are complete or feature-flagged, Stripe checkout succeeds end-to-end, Firestore rules have automated coverage, and testers can complete the happy paths without console errors. |
| **General Availability** | Harden reliability, observability, and operations so a public launch is safe. | CI/CD enforces lint/tests/deploy, monitoring + analytics are configured, support/admin tools exist for marketplace & collections, and documentation reflects the shipped surface area. |

## MVP Checklist
1. **Restore the Flutter build**
   - Configure Stripe keys (`STRIPE_PUBLISHABLE_KEY`, `stripe.secret_key`, price IDs) and verify the new Stripe-only `EnhancedPaymentService` builds cleanly.【F:lib/services/enhanced_payment_service.dart†L1-L320】【F:functions/index.js†L900-L1150】【F:lib/services/environment_config.dart†L61-L132】
   - Fix compile errors by either exposing `currentUserToken` in `FirebaseService` or deleting `FirebaseExtensionsService` until its backend exists.【F:lib/services/firebase_extensions_service.dart†L34-L120】【F:lib/services/firebase_service.dart†L1-L160】
   - Update `test/widget_test.dart` to pump `CrystalGrimoireApp` as a smoke test so CI can run.【F:test/widget_test.dart†L12-L24】【F:lib/main.dart†L31-L59】

2. **Implement the minimum backend surface**
   - Verify callable Functions used by the MVP (`identifyCrystal`, `getDailyCrystal`, `analyzeDream`, `getCrystalGuidance`, `getMoonRituals`, `generateHealingLayout`) succeed locally/in staging with real config. Feature-flag optional surfaces (`earnSeerCredits`, compatibility, care, search) until tested.【F:functions/index.js†L200-L2038】【F:lib/services/crystal_service.dart†L129-L276】
   - Align the Functions runtime with the declared Node version before deploying (currently Node 22 vs Node 20 mismatch).【F:functions/package.json†L1-L24】【F:firebase.json†L1-L33】

3. **Seed Firestore with required data**
   - Populate `crystal_library` using the seeding script or manual import; update the script to accept a configurable project/service account instead of the hard-coded production ID.【F:scripts/seed_database.js†L1-L80】【F:lib/services/collection_service_v2.dart†L136-L212】
   - Create any composite indexes needed for collection, dreams, and marketplace queries (extend `firestore.indexes.json` if additional queries are introduced).【F:firestore.indexes.json†L1-L33】

4. **Tame security rules for development**
   - Provide verified test accounts or add a relaxed ruleset for local projects; current rules block unverified users and enforce strict schemas.【F:firestore.rules†L1-L120】
   - Document the expected Firestore document shapes in `DEVELOPER_HANDOFF.me` when adding data so the rules stay in sync.

5. **Align hosting with the Flutter app**
   - Replace the static `public/index.html` landing page with the Flutter build output and remove the `/api/**` rewrite unless an HTTPS function named `api` is implemented.【F:firebase.json†L7-L25】【F:public/index.html†L1-L160】

## Beta Checklist
1. **Feature completeness & safeguards**
   - Exercise and monitor callable Functions (economy credits, moon rituals, healing layout, compatibility, care) in staging; provide UX fallbacks when Functions reject requests.【F:lib/services/economy_service.dart†L1-L220】【F:lib/services/crystal_service.dart†L165-L276】
   - Build graceful error messaging around Firestore permission failures and Function exceptions so testers receive feedback instead of silent console errors.【F:lib/screens/crystal_identification_screen.dart†L1-L190】【F:lib/screens/marketplace_screen.dart†L1-L197】

2. **Payments & subscriptions**
   - Decide on a payments strategy: Stripe-only (web-first) or Stripe + RevenueCat (mobile). Remove dead code for the unused stack and ensure Stripe publishable/secret keys are provided via `EnvironmentConfig`/Functions config.【F:lib/services/enhanced_payment_service.dart†L1-L200】【F:lib/services/environment_config.dart†L1-L200】【F:functions/index.js†L200-L399】
   - Exercise the full Stripe flow (checkout session ➜ success redirect ➜ `finalizeStripeCheckoutSession`) in the emulator or staging project.

3. **Testing & automation**
   - Add integration/widget tests covering Auth → Identify → Collection with mock services or the Firebase emulator.
   - Start a Functions test suite (at least for Stripe + identifyCrystal) so deploys fail fast on regressions.【F:functions/index.js†L200-L799】

4. **Data governance & tooling**
    - Provide admin tooling or scripts for marketplace moderation and crystal library edits; listings now land in a `pending_review` queue and the Flutter app includes an admin-only review tab, but you still need to provision custom claims, moderation policy, and any supporting automation.【F:lib/screens/marketplace_screen.dart†L1-L1180】【F:functions/index.js†L1171-L1420】
   - Audit Storage uploads (marketplace images, identification photos) and ensure the rules align with expected usage.【F:storage.rules†L1-L80】

## Production Checklist
1. **Reliability & observability**
 - Instrument client and Functions logging (Analytics, Crashlytics/Performance, custom logging) and set up monitoring/alerting for Stripe webhooks and Function failures.【F:functions/index.js†L200-L799】
  - Leverage `MonitoringService` analytics hooks and the Cloud Logging wrappers added in `functions/src/monitoring.js` to build latency/error dashboards; configure alerting thresholds for identifyCrystal, analyzeDream, and Stripe flows.【F:lib/services/monitoring_service.dart†L1-L152】【F:functions/src/monitoring.js†L1-L63】
  - Add automated backups or export scripts for critical collections (`users`, `crystal_library`, `marketplace`).
  - Schedule the new `scripts/export_firestore.js` backup job (daily) and store artifacts in long-term storage for disaster recovery.【F:scripts/export_firestore.js†L1-L147】

2. **Operations & support**
   - Build moderation and support workflows (e.g., flagging marketplace listings, handling refund/support requests).
   - Ensure legal/support URLs surfaced via `EnvironmentConfig` are populated before launch.【F:lib/services/environment_config.dart†L61-L132】

3. **CI/CD & documentation**
   - Introduce CI pipelines that run `flutter analyze`, widget/integration tests, and Functions lint/tests before deploys.
   - Automate Flutter web builds and Firebase deploys with environment-specific configs; document the process in `DEPLOYMENT_GUIDE.md`.

Keep this plan updated as subsystems are implemented or de-scoped. Agents should reference it alongside `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`, and `DEVELOPER_HANDOFF.me` when planning work.
