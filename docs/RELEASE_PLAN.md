# Crystal Grimoire Release Plan

This plan distills what is required to graduate the current repository from "pre-MVP" to a production-ready release. Use it as a checklist for Claude/agents and humans before each milestone.

## Stage Overview
| Stage | Primary Goal | Definition of Done |
| --- | --- | --- |
| **MVP / Internal Test** | Restore a compilable Flutter web build that demonstrates auth → identify → collection → lunar/healing flows using seeded data. | Build succeeds (`flutter build web`), verified testers can sign in, complete key flows, and Stripe checkout runs end-to-end with staging credentials. |
| **Beta / Limited Release** | Harden entitlement gating, polish error handling, and exercise payments/credits in staging. | Premium flows are gated, Stripe & credits behave consistently, Firestore rules and Functions are validated via tests/emulator, and hosting serves the Flutter build. |
| **General Availability** | Make operations resilient for public use. | CI/CD enforces lint/tests/deploy, monitoring & support channels exist, and compliance/analytics requirements are satisfied. |

## MVP Checklist
1. **Restore the Flutter/Functions build**
   - Resolve the `FirebaseExtensionsService` → `FirebaseService` API mismatch or remove the service so `flutter analyze` and `flutter test` pass.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:lib/services/firebase_service.dart†L19-L120】
   - Align the Functions runtime declaration (Node 20 vs Node 22) and fix ESLint violations so `npm --prefix functions run lint` succeeds.【F:firebase.json†L40-L43】【F:functions/package.json†L1-L42】

2. **Configure backend secrets & data**
   - Set Functions config for `gemini.api_key`, `stripe.secret_key`, and Stripe price IDs; provide Dart defines for `GEMINI_API_KEY` and `STRIPE_PUBLISHABLE_KEY` when running the client.【F:functions/index.js†L946-L1175】【F:lib/services/environment_config.dart†L61-L164】
   - Seed `crystal_library`, `moonData`, and sample marketplace/ritual data so the new backend-driven screens return meaningful content.【F:scripts/seed_database.js†L1-L120】【F:lib/screens/moon_rituals_screen.dart†L181-L299】

3. **Stripe checkout smoke test**
   - Verify `createStripeCheckoutSession` ➜ browser redirect ➜ `finalizeStripeCheckoutSession` updates `users/{uid}/plan/active` and cached plan state locally.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:functions/index.js†L946-L1175】
   - Document fallback behaviour and user messaging for misconfigured Stripe to aid QA.【F:lib/screens/subscription_screen.dart†L198-L308】

4. **Hosting alignment**
   - Replace `public/index.html` with the Flutter `build/web` output and remove the `/api/**` rewrite unless you ship an HTTPS function named `api`.【F:public/index.html†L1-L200】【F:firebase.json†L9-L17】
   - Run `flutter build web --release` and deploy via Firebase Hosting once smoke tests pass.

## Beta Checklist
1. **Entitlement gating & UX polish**
   - Gate economy actions, dream boosts, and healing layouts by the active subscription tier; surface explanatory copy for locked content.【F:lib/services/economy_service.dart†L1-L220】【F:lib/screens/subscription_screen.dart†L61-L200】
   - Add friendly error handling for callable Functions (identify, moon rituals, healing, Stripe) so testers receive actionable feedback.【F:lib/screens/moon_rituals_screen.dart†L181-L299】【F:lib/screens/crystal_identification_screen.dart†L120-L214】

2. **Testing & automation**
   - Expand widget/integration coverage (at least splash ➜ auth ➜ home smoke test) and wire them into CI along with Functions lint/tests.【F:test/widget_test.dart†L1-L20】【F:functions/package.json†L34-L42】
   - Exercise Firestore rules via emulator scripts to ensure schema validations match client writes.【F:firestore.rules†L1-L120】

3. **Operational readiness**
   - Provide moderation tooling or review scripts for marketplace listings and crystal library edits before inviting real users.【F:lib/screens/marketplace_screen.dart†L1-L197】
   - Capture logging/metrics (Analytics, Performance, Stripe webhook monitoring) to observe tester behaviour.【F:functions/index.js†L946-L2005】

## Production Checklist
1. **Reliability & observability**
   - Instrument monitoring/alerting for Cloud Functions and Stripe webhooks; add crash/error reporting for the Flutter app.【F:functions/index.js†L946-L2005】
   - Establish backup/export procedures for critical collections (`users`, `crystal_library`, `marketplace`).

2. **Operations & compliance**
   - Finalize legal/support links (`TERMS_URL`, `PRIVACY_URL`, `SUPPORT_URL`) via `EnvironmentConfig` and ensure support workflows exist.【F:lib/services/environment_config.dart†L61-L164】
   - Implement admin tooling for marketplace moderation, credit adjustments, and crystal library curation.【F:lib/services/economy_service.dart†L1-L220】【F:scripts/seed_database.js†L1-L120】

3. **CI/CD & documentation**
   - Automate Flutter builds, Functions lint/tests, and Firebase deploys with environment-specific secrets.
   - Keep `DEPLOYMENT_GUIDE.md`, `DEVELOPER_HANDOFF.me`, and this plan in sync as the surface area evolves.

Keep this plan updated as subsystems are implemented or de-scoped. Agents should reference it alongside `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`, and `DEVELOPER_HANDOFF.me` when planning work.
