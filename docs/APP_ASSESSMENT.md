# Crystal Grimoire Codebase Assessment

## 1. Current Overview
- **Platform**: Flutter web client with Firebase Auth/Firestore/Storage/Functions plus a static Firebase Hosting landing page at `public/index.html`. The Flutter bundle is bootstrapped through `CrystalGrimoireApp` which wires Providers for auth, collections, app state, and the crystal/economy services.【F:lib/main.dart†L1-L59】【F:public/index.html†L1-L160】
- **Status**: Pre-MVP. Screens render and some Firebase flows exist, but large portions of the app target backends that do not exist. The Flutter build fails because of missing packages and compile-time errors; the backend functions and Firestore rules assume production-level configuration that is not present for developers.
- **Entry points**: `AuthWrapper` gates the app to `HomeScreen`. The static hosting page offers a Firebase Auth demo that is unrelated to the Flutter shell, so aligning hosting with the compiled build will require cleanup.【F:lib/screens/home_screen.dart†L1-L214】【F:firebase.json†L1-L25】

## 2. Architecture Snapshot
### Client Layers
- **Navigation & Screens**: The home dashboard links to Identification, Collection, Moon Rituals, Healing, Dream Journal, Sound Bath, Marketplace, Settings, and Subscriptions. Moon ritual and healing flows now call their Cloud Functions with graceful fallbacks, persist the last personal intention, sync it to Firestore for cross-device continuity, surface moon metadata chips, and flag when a user lacks the required crystals; Marketplace creation routes through a callable Function that enforces cooldowns and now exposes an in-app review queue for users with the `admin` claim while payments remain stubbed.【F:lib/screens/home_screen.dart†L1-L214】【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/screens/crystal_healing_screen.dart†L1-L835】【F:lib/screens/marketplace_screen.dart†L1-L1180】
- **Firebase-facing services**:
  - `AppService` provides thin wrappers around Auth/Firestore/Functions and powers profile + collection fetches.【F:lib/services/app_service.dart†L1-L205】
  - `AuthService` handles email/password, Google, and Apple sign-in, depending on callable Functions (`initializeUserProfile`, `deleteUserAccount`). Google/Apple flows assume platform configuration but lack platform guards for the web build.【F:lib/services/auth_service.dart†L1-L402】
  - `CollectionServiceV2` caches `users/{uid}/collection` locally and hydrates references from `crystal_library`; without seeded data the UI renders empty shells.【F:lib/services/collection_service_v2.dart†L1-L212】
    - `CrystalService` and `EconomyService` call callable Functions such as `generateHealingLayout`, `getMoonRituals`, `earnSeerCredits`, and `spendSeerCredits`; these routes exist but depend on Functions config and should surface friendly errors when quotas/auth fail.【F:lib/services/crystal_service.dart†L129-L276】【F:lib/services/economy_service.dart†L1-L220】
- **Advanced/experimental services**: `UnifiedAIService`, `FirebaseExtensionsService`, and `BackendService` target custom APIs (OpenAI/Claude/Gemini vision, Firebase Extensions, bespoke REST backend). These require API keys plus endpoints that are not part of the repo. `FirebaseExtensionsService` attempts to reference `FirebaseService.currentUserToken`, which is private—compilation fails unless the API surface is amended.【F:lib/services/unified_ai_service.dart†L1-L120】【F:lib/services/firebase_extensions_service.dart†L34-L120】【F:lib/services/firebase_service.dart†L1-L160】

### Backend & Infrastructure
- **Cloud Functions**: `functions/index.js` implements Stripe checkout setup, dream analysis, crystal identification via Gemini, guidance logging, user bootstrap, moon rituals, healing layouts, and deletion.【F:functions/index.js†L200-L513】【F:functions/index.js†L1760-L2038】 Callable surfaces for credits, compatibility, care, and crystal search exist but still require configuration, rate-limit handling, and end-to-end testing before exposing widely.
- **Configuration drift**: `firebase.json` declares the Functions runtime as Node 20, yet `functions/package.json` pins Node 22. Deployment will fail until versions align.【F:firebase.json†L1-L33】【F:functions/package.json†L1-L24】
- **Firestore rules**: Highly restrictive rules require verified emails (`email_verified == true`), enforce strict schema validation, and block writes outside Cloud Functions for economy/transactions. Local development will repeatedly hit `permission-denied` unless the tester uses a verified account or temp rules.【F:firestore.rules†L1-L120】
- **Data bootstrapping**: `scripts/seed_database.js` expects a local service account JSON and hard-codes the production project ID, so it cannot run out of the box. Index definitions only cover part of the schema (collection, dreams, marketplace).【F:scripts/seed_database.js†L1-L80】【F:firestore.indexes.json†L1-L33】

## 3. Build & Dependency Health
- **Payments**: RevenueCat stubs were removed; subscriptions now rely entirely on Stripe Checkout. Supply publishable/secret keys and price IDs via `EnvironmentConfig`/Functions config before exercising the flow, and consider feature-flagging the subscription screen until keys are present.【F:lib/services/enhanced_payment_service.dart†L1-L400】【F:functions/index.js†L900-L1150】【F:lib/services/environment_config.dart†L61-L132】
- **Compile-time errors**: `FirebaseExtensionsService` references `currentUserToken`/`currentUserId`, which are private in `FirebaseService`. The project will not build until you expose getters or remove that service.【F:lib/services/firebase_extensions_service.dart†L34-L88】【F:lib/services/firebase_service.dart†L1-L120】
- **Tests**: `test/widget_test.dart` still pumps `MyApp`; `CrystalGrimoireApp` should be the smoke-test target once the build is restored.【F:test/widget_test.dart†L12-L24】【F:lib/main.dart†L31-L59】
- **Hosting assets**: The Flutter `web/` directory has manifests/icons but no `index.html`. Hosting rewrites everything to `/index.html`, so you must ensure `firebase deploy --only hosting` serves the Flutter build instead of the static landing page. Remove or implement the `/api/**` rewrite to avoid 404s.【F:web†L1-L4】【F:firebase.json†L7-L25】
- **Functions toolchain**: The repo installs `@google-ai/generativelanguage`, `@google-cloud/vertexai`, `sharp`, etc., but no lint/test scripts are wired up. Align Node version, add lint/test to CI, and validate cold-start behaviour before release.【F:functions/package.json†L1-L36】

## 4. Feature Coverage Summary
| Area | Current State | Blocking Gaps |
| --- | --- | --- |
| Authentication | Email/password flows work; Google/Apple stubs require OAuth config and may not operate on web without guards. | Firestore writes require verified emails; Apple redirect URI is hard-coded to production hosting and will fail in other projects.【F:lib/services/auth_service.dart†L129-L208】【F:firestore.rules†L1-L40】 |
| Crystal Identification | UI captures an image and calls `identifyCrystal`. | Requires configured `gemini.api_key`, Firebase Storage path, and seeding of `crystal_library` to hydrate results; needs error handling for quota/timeouts.【F:lib/screens/crystal_identification_screen.dart†L1-L190】【F:functions/index.js†L400-L513】 |
| Collection | Offline cache syncs `users/{uid}/collection` with Firestore and hydrates from `crystal_library`. | No admin tooling; seeding script relies on absent service account; security rules restrict fields to `libraryRef`, `tags`, `notes`.【F:lib/services/collection_service_v2.dart†L96-L212】【F:firestore.rules†L37-L76】 |
| Moon Rituals / Healing | UI requests `getMoonRituals`/`generateHealingLayout`, persists the most recent intention locally, syncs it to `users/{uid}/ritual_preferences/moon`, surfaces moon metadata chips, and flags when a user lacks the required crystals while falling back to curated copy if Functions fail. | Ensure callable configs (Gemini API key) exist and provide user crystals/profile context; validate Firestore access to `ritual_preferences` (rules require verified email) and keep UX graceful when quotas/auth fail.【F:lib/services/crystal_service.dart†L165-L276】【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/services/ritual_preference_service.dart†L1-L200】 |
| Dream Journal | Reads/writes `users/{uid}/dreams` and optionally calls `analyzeDream`. | Works only with verified emails and matching schema; add UX for permission failures.【F:lib/screens/dream_journal_screen.dart†L1-L203】【F:firestore.rules†L84-L109】 |
| Marketplace | Streams Firestore `marketplace` docs and creates listings via a callable Function that enforces a 12-hour cooldown and stores submissions as `pending_review`. Admins (custom claim `role: admin`) now see a review tab to approve/reject listings. | Payments remain stubbed and moderation still depends on assigning admin claims + policy enforcement; tighten Firestore rules once the moderated lifecycle is finalised.【F:lib/screens/marketplace_screen.dart†L1-L1180】【F:functions/index.js†L1171-L1420】【F:firestore.rules†L96-L120】 |
| Economy / Credits | `EconomyService` calls `earnSeerCredits`/`spendSeerCredits`. | Cloud Functions missing; UI should hide the feature until implemented to avoid runtime errors.【F:lib/services/economy_service.dart†L153-L220】 |
| Subscriptions | `SubscriptionScreen` launches Stripe Checkout for every platform. | Provide publishable/secret keys and Stripe price IDs; the flow depends on `createStripeCheckoutSession` ➜ `finalizeStripeCheckoutSession` wiring and will fail without them. Consider hiding the screen when keys are absent.【F:lib/screens/subscription_screen.dart†L1-L360】【F:lib/services/enhanced_payment_service.dart†L1-L320】【F:functions/index.js†L900-L1150】 |

## 5. Deployment & Environment Requirements
1. **Tooling**: Flutter 3.19+, Dart 3.3+, Node 20 to match the Firebase runtime, Firebase CLI. Align local Node with the `firebase.json` runtime or update both to Node 22 if supported.【F:pubspec.yaml†L5-L22】【F:firebase.json†L1-L33】
2. **Runtime secrets**: Provide `--dart-define` flags for Gemini/OpenAI/Claude/Groq and Stripe/RevenueCat keys; Cloud Functions require `firebase functions:config:set gemini.api_key=... stripe.secret_key=... price ids`. Optional providers (OpenAI/Anthropic/Groq) feed `LLMService` but are not necessary for MVP.【F:lib/services/environment_config.dart†L1-L200】【F:functions/index.js†L1-L120】
3. **Data setup**: Seed `crystal_library`, ensure indexes exist, and create test data for dreams/marketplace. Adjust or temporarily relax Firestore rules if using unverified accounts.【F:lib/services/collection_service_v2.dart†L136-L212】【F:firestore.rules†L1-L120】
4. **Hosting**: Build the Flutter web bundle to `build/web` and update hosting rewrites so `/` serves the Flutter `index.html`. Remove the `/api/**` rewrite unless you deploy an HTTPS function named `api`. Confirm the static landing page is retired to avoid confusion.【F:firebase.json†L7-L25】【F:public/index.html†L1-L160】
5. **Functions deployment**: Resolve missing callable endpoints before `firebase deploy --only functions`. Ensure `stripeClient` is configured and test `identifyCrystal`, `analyzeDream`, `getDailyCrystal`, and the Stripe lifecycle using the emulator or staging project.【F:functions/index.js†L200-L799】

## 6. Key Risks & Recommendations
1. **Restore build green**: Remove or implement services that rely on absent packages, surface compile errors (e.g., `FirebaseExtensionsService`), and update tests. Without this, CI/CD cannot start.
2. **Guard unfinished features**: Feature-flag or hide UI elements that call missing Functions/services (economy, advanced AI, marketplace approvals) until the backend exists.
3. **Security ergonomics**: Provide a dev ruleset or verified seed users. The current rules enforce strict schema + email verification, which slows iteration.【F:firestore.rules†L1-L120】
4. **Documentation & hosting cleanup**: Replace the static hosting demo with the Flutter build to prevent confusion, and document environment variables + seeding flows in the Deployment Guide.
5. **Testing strategy**: After the smoke test is fixed, add integration tests covering Auth → Identify → Collection. Cloud Functions should gain unit tests around Stripe and `identifyCrystal` to avoid regressions.

## 7. Suggested Roadmap
- **MVP (internal testing)**:
  - Remove blocking dependencies or add them properly; expose getters needed by remaining services.
  - Implement or stub the callable Functions the app actually calls (daily crystal, identify, dream analysis) and guard the rest.
  - Seed Firestore (`crystal_library`, sample marketplace listings) and verify rules using verified dev accounts.
  - Replace the widget test with a `CrystalGrimoireApp` smoke test and set up emulator-based manual testing.
- **Beta (limited testers)**:
  - Implement economy/ritual/healing callable Functions or hide those feature tiles.
  - Finish Stripe checkout end-to-end (session creation ➜ webhook ➜ plan document) and decide on RevenueCat vs Stripe-only for subscriptions.
  - Add moderation/admin tooling for marketplace listings and audit Firestore/Storage rules with automated tests.
  - Instrument logging/monitoring (Analytics, Performance, error reporting) across client and Functions.
- **Production**:
  - Migrate hosting to CI-built Flutter assets, add CI/CD (lint, tests, deploy gates).
  - Harden observability (error reporting, Stripe webhook monitoring), create support workflows, and finalize legal links via `EnvironmentConfig`.
  - Document recovery procedures, backfill tests for Cloud Functions, and ensure data backup/retention policies are in place.

Refer to `DEPLOYMENT_GUIDE.md`, `DEVELOPER_HANDOFF.me`, `docs/RELEASE_PLAN.md`, and `claude.md` for actionable follow-up tasks.
