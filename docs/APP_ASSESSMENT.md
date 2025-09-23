# Crystal Grimoire Codebase Assessment

## 1. Current Overview
- **Platform**: Flutter web client with Firebase Auth/Firestore/Storage/Functions plus a static Firebase Hosting landing page at `public/index.html`. The Flutter bundle is bootstrapped through `CrystalGrimoireApp` which wires Providers for auth, collections, app state, and the crystal/economy services.【F:lib/main.dart†L1-L59】【F:public/index.html†L1-L160】
- **Status**: Pre-MVP. Screens render and most Firebase flows now call real callable Functions, but several advanced services still point at backends that do not exist. The Flutter build is closer to green after removing missing package imports, yet compile-time errors remain (see §3) and the backend/Firestore configuration still assumes production data.
- **Entry points**: `AuthWrapper` gates the app to `HomeScreen`. The static hosting page offers a Firebase Auth demo that is unrelated to the Flutter shell, so aligning hosting with the compiled build will require cleanup.【F:lib/screens/home_screen.dart†L1-L214】【F:firebase.json†L1-L25】

## 2. Architecture Snapshot
### Client Layers
- **Navigation & Screens**: The home dashboard links to Identification, Collection, Moon Rituals, Healing, Dream Journal, Sound Bath, Marketplace, Settings, and Subscriptions. Moon ritual and healing flows now call callable Functions for dynamic guidance/layouts, while Marketplace reads Firestore listings created through the callable listing API (moderation and payments remain TODO).【F:lib/screens/home_screen.dart†L1-L214】【F:lib/screens/moon_rituals_screen.dart†L1-L320】【F:lib/screens/marketplace_screen.dart†L1-L197】
- **Firebase-facing services**:
  - `AppService` provides thin wrappers around Auth/Firestore/Functions and powers profile + collection fetches.【F:lib/services/app_service.dart†L1-L205】
  - `AuthService` handles email/password, Google, and Apple sign-in, depending on callable Functions (`initializeUserProfile`, `deleteUserAccount`). Google/Apple flows assume platform configuration but lack platform guards for the web build.【F:lib/services/auth_service.dart†L1-L402】
  - `CollectionServiceV2` caches `users/{uid}/collection` locally and hydrates references from `crystal_library`; without seeded data the UI renders empty shells.【F:lib/services/collection_service_v2.dart†L1-L212】
  - `CrystalService` fronts callable Functions for crystal identification, moon rituals, healing layouts, compatibility checks, and care guidance. These endpoints depend on `gemini.api_key` and seeded `crystal_library` data to return meaningful results.【F:lib/services/crystal_service.dart†L19-L276】【F:functions/index.js†L1280-L2130】 `EconomyService` now calls the implemented `earnSeerCredits`/`spendSeerCredits` Functions; quotas/daily resets are enforced server-side so UI error handling is still required.【F:lib/services/economy_service.dart†L1-L220】【F:functions/index.js†L2203-L2374】
- **Advanced/experimental services**: `UnifiedAIService`, `FirebaseExtensionsService`, and `BackendService` target custom APIs (OpenAI/Claude/Gemini vision, Firebase Extensions, bespoke REST backend). These require API keys plus endpoints that are not part of the repo. `FirebaseExtensionsService` attempts to reference `FirebaseService.currentUserToken`, which is private—compilation fails unless the API surface is amended.【F:lib/services/unified_ai_service.dart†L1-L120】【F:lib/services/firebase_extensions_service.dart†L34-L120】【F:lib/services/firebase_service.dart†L1-L160】

### Backend & Infrastructure
- **Cloud Functions**: `functions/index.js` implements Stripe checkout setup, dream analysis, crystal identification via Gemini, guidance logging, user bootstrap, moon ritual guidance, healing layouts, compatibility analysis, care lookups, crystal search, marketplace listing creation, and the Seer Credit economy endpoints.【F:functions/index.js†L200-L2374】 Daily credit caps are enforced in `earnSeerCredits`, so callers must surface quota messaging.
- **Configuration drift**: `firebase.json` declares the Functions runtime as Node 20, yet `functions/package.json` pins Node 22. Deployment will fail until versions align.【F:firebase.json†L1-L33】【F:functions/package.json†L1-L24】
- **Firestore rules**: Highly restrictive rules require verified emails (`email_verified == true`), enforce strict schema validation, and block writes outside Cloud Functions for economy/transactions. Local development will repeatedly hit `permission-denied` unless the tester uses a verified account or temp rules.【F:firestore.rules†L1-L120】
- **Data bootstrapping**: `scripts/seed_database.js` expects a local service account JSON and hard-codes the production project ID, so it cannot run out of the box. Index definitions only cover part of the schema (collection, dreams, marketplace).【F:scripts/seed_database.js†L1-L80】【F:firestore.indexes.json†L1-L33】

## 3. Build & Dependency Health
- **Payment & AI service dependencies**: `EnhancedPaymentService` now delegates to Stripe callable Functions, and `FirebaseAIService` proxies to `identifyCrystal`/`getCrystalGuidance`, so no additional Flutter packages are required. Stripe price IDs and Functions config must be supplied before testing checkout.【F:lib/services/enhanced_payment_service.dart†L1-L220】【F:lib/services/firebase_ai_service.dart†L1-L64】【F:functions/index.js†L912-L1188】
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
| Moon Rituals / Healing | UI requests moon-phase guidance and chakra layouts via callable Functions. | Requires configured Gemini key, seeded crystal library, and graceful handling when Functions throttle or return fallbacks.【F:lib/screens/moon_rituals_screen.dart†L1-L320】【F:lib/screens/crystal_healing_screen.dart†L1-L760】【F:functions/index.js†L1760-L2130】 |
| Dream Journal | Reads/writes `users/{uid}/dreams` and optionally calls `analyzeDream`. | Works only with verified emails and matching schema; add UX for permission failures.【F:lib/screens/dream_journal_screen.dart†L1-L203】【F:firestore.rules†L84-L109】 |
| Marketplace | Streams Firestore `marketplace` docs and creates listings through the callable API. | No moderation or payments; Firestore rules demand strict schema, and checkout still relies on unfinished Stripe UI.【F:lib/screens/marketplace_screen.dart†L1-L197】【F:functions/index.js†L1100-L1280】 |
| Economy / Credits | `EconomyService` calls the economy Functions for earning/spending credits with local transaction logging. | Ensure quota messaging is surfaced when `earnSeerCredits` rejects daily caps; seed `users/{uid}/economy/credits` for new testers.【F:lib/services/economy_service.dart†L1-L220】【F:functions/index.js†L2203-L2374】 |
| Subscriptions | `SubscriptionScreen` uses `EnhancedPaymentService` to start Stripe Checkout sessions and confirm them on return. | Stripe publishable/secret keys plus price IDs are required; Flow still lacks webhook reconciliation and mobile in-app purchase parity.【F:lib/screens/subscription_screen.dart†L1-L320】【F:lib/services/enhanced_payment_service.dart†L1-L220】【F:functions/index.js†L912-L1188】 |

## 5. Deployment & Environment Requirements
1. **Tooling**: Flutter 3.19+, Dart 3.3+, Node 20 to match the Firebase runtime, Firebase CLI. Align local Node with the `firebase.json` runtime or update both to Node 22 if supported.【F:pubspec.yaml†L5-L22】【F:firebase.json†L1-L33】
2. **Runtime secrets**: Provide `--dart-define` flags for Gemini/OpenAI/Claude/Groq and Stripe/RevenueCat keys; Cloud Functions require `firebase functions:config:set gemini.api_key=... stripe.secret_key=... price ids`. Optional providers (OpenAI/Anthropic/Groq) feed `LLMService` but are not necessary for MVP.【F:lib/services/environment_config.dart†L1-L200】【F:functions/index.js†L1-L120】
3. **Data setup**: Seed `crystal_library`, ensure indexes exist, and create test data for dreams/marketplace. Adjust or temporarily relax Firestore rules if using unverified accounts.【F:lib/services/collection_service_v2.dart†L136-L212】【F:firestore.rules†L1-L120】
4. **Hosting**: Build the Flutter web bundle to `build/web` and update hosting rewrites so `/` serves the Flutter `index.html`. Remove the `/api/**` rewrite unless you deploy an HTTPS function named `api`. Confirm the static landing page is retired to avoid confusion.【F:firebase.json†L7-L25】【F:public/index.html†L1-L160】
5. **Functions deployment**: Resolve missing callable endpoints before `firebase deploy --only functions`. Ensure `stripeClient` is configured and test `identifyCrystal`, `analyzeDream`, `getDailyCrystal`, and the Stripe lifecycle using the emulator or staging project.【F:functions/index.js†L200-L799】

## 6. Key Risks & Recommendations
1. **Restore build green**: Remove or implement services that rely on absent packages, surface compile errors (e.g., `FirebaseExtensionsService`), and update tests. Without this, CI/CD cannot start.
2. **Guard unfinished features**: Feature-flag or hide UI elements that depend on unimplemented services (economy credits, advanced AI extensions, production payments) until the backend exists.
3. **Security ergonomics**: Provide a dev ruleset or verified seed users. The current rules enforce strict schema + email verification, which slows iteration.【F:firestore.rules†L1-L120】
4. **Documentation & hosting cleanup**: Replace the static hosting demo with the Flutter build to prevent confusion, and document environment variables + seeding flows in the Deployment Guide.
5. **Testing strategy**: After the smoke test is fixed, add integration tests covering Auth → Identify → Collection. Cloud Functions should gain unit tests around Stripe and `identifyCrystal` to avoid regressions.

## 7. Suggested Roadmap
- **MVP (internal testing)**:
  - Finish removing or guarding code that references unavailable services (e.g., Firebase Extensions, bespoke backend stubs) so the Flutter build succeeds.
  - Implement or stub the callable Functions the app actually calls (daily crystal, identify, dream analysis) and guard the rest.
  - Seed Firestore (`crystal_library`, sample marketplace listings) and verify rules using verified dev accounts.
  - Replace the widget test with a `CrystalGrimoireApp` smoke test and set up emulator-based manual testing.
- **Beta (limited testers)**:
  - Implement economy credit callable Functions or hide those feature tiles.
  - Finish Stripe checkout end-to-end (session creation ➜ webhook ➜ plan document) and decide on RevenueCat vs Stripe-only for subscriptions.
  - Add moderation/admin tooling for marketplace listings and audit Firestore/Storage rules with automated tests.
  - Instrument logging/monitoring (Analytics, Performance, error reporting) across client and Functions.
- **Production**:
  - Migrate hosting to CI-built Flutter assets, add CI/CD (lint, tests, deploy gates).
  - Harden observability (error reporting, Stripe webhook monitoring), create support workflows, and finalize legal links via `EnvironmentConfig`.
  - Document recovery procedures, backfill tests for Cloud Functions, and ensure data backup/retention policies are in place.

Refer to `DEPLOYMENT_GUIDE.md`, `DEVELOPER_HANDOFF.me`, `docs/RELEASE_PLAN.md`, and `claude.md` for actionable follow-up tasks.
