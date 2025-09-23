# Crystal Grimoire Codebase Assessment

## 1. Current Overview
- **Platform**: Flutter web client with Firebase Auth/Firestore/Storage/Functions plus a static Firebase Hosting landing page. `CrystalGrimoireApp` wires Providers for auth, collections, app state, economy, and crystal services before handing off to the splash ➜ auth wrapper flow.【F:lib/main.dart†L1-L75】【F:public/index.html†L1-L200】
- **Status**: Pre-MVP. Core experiences (sign-in ➜ crystal identification ➜ collection, dream journal, moon rituals, healing layouts) work against Cloud Functions, but Stripe configuration, entitlement gating, strict security rules, and a lingering `FirebaseExtensionsService` compile blocker must be resolved before external testing.【F:lib/services/enhanced_payment_service.dart†L14-L216】【F:firestore.rules†L1-L120】【F:lib/services/firebase_extensions_service.dart†L30-L120】
- **Entry points**: `SplashScreen` shows first, then `AuthWrapper` routes to the login or home flow. Firebase Hosting still serves the static landing page unless the Flutter build overwrites it, so deployment requires aligning hosting with the compiled app.【F:lib/main.dart†L58-L74】【F:firebase.json†L1-L43】

## 2. Architecture Snapshot
### Client Layers
- **Navigation & Screens**: `HomeScreen` links to Identification, Collection, Moon Rituals, Healing, Dream Journal, Sound Bath, Marketplace, Settings, Notifications, Help, and Subscriptions. Moon Ritual and Healing screens now hydrate from callable Functions with graceful fallbacks when the backend is unreachable.【F:lib/screens/home_screen.dart†L1-L214】【F:lib/screens/moon_rituals_screen.dart†L168-L299】【F:lib/screens/crystal_healing_screen.dart†L106-L259】
- **Firebase-facing services**:
  - `AppService` orchestrates profile bootstrap, daily crystal caching, and network status, exposing change notifiers across the app.【F:lib/services/app_service.dart†L1-L205】
  - `AuthService` handles email/password plus Google/Apple sign-in via callable Functions (`initializeUserProfile`, `deleteUserAccount`) and expects proper OAuth configuration.【F:lib/services/auth_service.dart†L1-L402】
  - `CollectionServiceV2` synchronizes `users/{uid}/collection`, hydrates metadata from `crystal_library`, and persists copies to `SharedPreferences` for offline use.【F:lib/services/collection_service_v2.dart†L120-L220】
  - `CrystalService` wraps callable Functions for identification, moon rituals, healing layouts, compatibility, care, and daily crystal recommendations.【F:lib/services/crystal_service.dart†L179-L260】
  - `EconomyService` manages the Seer Credits economy by reading Firestore documents and invoking `earnSeerCredits` / `spendSeerCredits` Functions.【F:lib/services/economy_service.dart†L1-L220】
  - `EnhancedPaymentService` now exposes Stripe-only checkout helpers and caches plan state locally for signed-out users.【F:lib/services/enhanced_payment_service.dart†L14-L216】
- **Advanced/experimental services**: `FirebaseExtensionsService` still references `currentUserToken` / `currentUserId`, which are private in `FirebaseService`, leaving a compile error unless the API is adjusted or the service is removed.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:lib/services/firebase_service.dart†L19-L64】

### Backend & Infrastructure
- **Cloud Functions**: `functions/index.js` implements Stripe checkout (`createStripeCheckoutSession`, `finalizeStripeCheckoutSession`), user bootstrap/deletion, crystal identification, dream analysis, crystal guidance, daily crystal, moon rituals, healing layouts, compatibility checks, care guidance, marketplace listings, and the credits economy.【F:functions/index.js†L946-L2005】
- **Configuration drift**: `firebase.json` declares the runtime as Node 20 while `functions/package.json` pins Node 22; reconcile before deploying to avoid runtime failures.【F:firebase.json†L40-L43】【F:functions/package.json†L1-L24】
- **Firestore rules**: Highly restrictive security rules demand verified emails and strict schema validation, rejecting writes from unverified testers or mismatched document shapes.【F:firestore.rules†L1-L120】
- **Data bootstrapping**: `scripts/seed_database.js` requires a local service account JSON and still hard-codes the production project ID. Populate `crystal_library`, `moonData`, and marketplace samples before demos, and extend indexes as queries expand.【F:scripts/seed_database.js†L1-L120】【F:firestore.indexes.json†L1-L33】

## 3. Build & Dependency Health
- **Compile blockers**: `FirebaseExtensionsService` still fails to compile because it accesses non-existent getters on `FirebaseService`; decide whether to expose safe accessors or remove the feature for the web build.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:lib/services/firebase_service.dart†L19-L120】
- **Testing**: The widget smoke test now pumps `SplashScreen`, but broader widget/integration coverage is absent. Restore `flutter analyze`, `flutter test`, and emulator-based checks once compile blockers are addressed.【F:test/widget_test.dart†L1-L20】
- **Hosting assets**: The `public/` directory contains a standalone landing page that conflicts with the Flutter build output. Replace it with the compiled bundle and remove the `/api/**` rewrite unless an HTTPS function named `api` ships with the release.【F:public/index.html†L1-L200】【F:firebase.json†L9-L17】
- **Functions toolchain**: ESLint exists but fails due to legacy style violations; add lint fixes/tests so Functions deploys gate on automated checks.【F:functions/package.json†L34-L42】

## 4. Feature Coverage Summary
| Area | Current State | Blocking Gaps |
| --- | --- | --- |
| Authentication | Email/password flows work, and Google/Apple providers are coded via callable Functions. | Firestore rules require `email_verified == true`, and OAuth configuration for Google/Apple must be supplied per project.【F:lib/services/auth_service.dart†L129-L294】【F:firestore.rules†L1-L120】 |
| Crystal Identification | UI uploads an image and calls `identifyCrystal`, returning crystal metadata and metaphysical insights. | Requires configured Gemini key and Storage bucket; add error UX for quota/timeouts.【F:lib/screens/crystal_identification_screen.dart†L120-L214】【F:functions/index.js†L1309-L1464】 |
| Collection | Syncs `users/{uid}/collection`, hydrates with `crystal_library`, and caches locally. | Needs seeded `crystal_library` documents; schema mismatches trigger rule violations.【F:lib/services/collection_service_v2.dart†L120-L220】【F:firestore.rules†L46-L76】 |
| Moon Rituals / Healing | Screens call `getMoonRituals` / `generateHealingLayout` and fall back to templates if Functions fail. | Requires seeded lunar data, verified accounts, and Stripe gating to avoid exposing premium content without entitlements.【F:lib/screens/moon_rituals_screen.dart†L181-L299】【F:lib/screens/crystal_healing_screen.dart†L116-L259】【F:functions/index.js†L1741-L1904】 |
| Dream Journal | Writes to `users/{uid}/dreams` and can append AI analysis via `analyzeDream`. | Verified email + schema adherence needed; add user-facing messaging for permission errors.【F:lib/screens/dream_journal_screen.dart†L1-L203】【F:functions/index.js†L1020-L1195】 |
| Marketplace | Client creates and streams marketplace listings directly from Firestore. | Lacks moderation, payments, and Storage upload validation; production launch requires admin tooling and stricter rules.【F:lib/screens/marketplace_screen.dart†L1-L197】【F:firestore.rules†L96-L120】 |
| Economy / Credits | `EconomyService` invokes `earnSeerCredits` / `spendSeerCredits` and logs transactions. | Needs gating so free users cannot trigger premium earn/spend actions; requires Stripe plan documents to reflect limits.【F:lib/services/economy_service.dart†L1-L220】【F:functions/index.js†L2209-L2323】 |
| Subscriptions | Stripe checkout launches via callable Functions and caches plan status locally. | Publishable/secret keys and price IDs must be configured; add gating/UI states for unpaid tiers before exposure.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:functions/index.js†L946-L1175】 |

## 5. Deployment & Environment Requirements
1. **Tooling**: Flutter 3.19+, Dart 3.3+, Node 20 (or update both runtime declarations to 22), Firebase CLI.【F:pubspec.yaml†L5-L22】【F:firebase.json†L40-L43】【F:functions/package.json†L1-L24】
2. **Runtime secrets**: Provide Dart defines for `GEMINI_API_KEY`, `STRIPE_PUBLISHABLE_KEY`, and optional AI providers; set Functions config for `gemini.api_key` and Stripe secret/price IDs before emulation or deploy.【F:lib/services/environment_config.dart†L61-L164】【F:functions/index.js†L946-L1175】
3. **Data setup**: Seed `crystal_library`, `moonData`, sample marketplace listings, and create composite indexes as needed.【F:scripts/seed_database.js†L1-L120】【F:firestore.indexes.json†L1-L33】
4. **Hosting**: Build Flutter web to `build/web`, copy to Hosting, and remove the `/api/**` rewrite unless the `api` function ships.【F:firebase.json†L9-L43】
5. **Functions deployment**: Align runtime versions, fix lint issues, and verify callable Functions via emulator or staging before `firebase deploy --only functions`.【F:functions/package.json†L34-L42】【F:functions/index.js†L946-L2005】

## 6. Key Risks & Recommendations
1. **Stripe configuration & entitlement gating**: Without publishable/secret keys and proper gating, checkout fails and premium surfaces expose paid actions to free users.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:lib/screens/subscription_screen.dart†L201-L360】
2. **Strict security rules & data requirements**: Verified emails and exact schema adherence are mandatory; provide seeded data and verified tester accounts or temporary relaxed rules for development.【F:firestore.rules†L1-L120】【F:lib/services/collection_service_v2.dart†L120-L220】
3. **Compile/test readiness**: Resolve the `FirebaseExtensionsService` compile blocker, then restore `flutter analyze`, `flutter test`, and Functions lint to green before enabling CI.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:test/widget_test.dart†L1-L20】
4. **Hosting & operational clarity**: Retire the static landing page, document deployment steps, and add monitoring/logging for the expanded Functions surface before inviting testers.【F:public/index.html†L1-L200】【F:functions/index.js†L946-L2005】

## 7. Suggested Roadmap
- **MVP (internal testing)**:
  - Resolve compile blockers and align Node runtime declarations so Flutter and Functions builds succeed.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:functions/package.json†L1-L24】
  - Configure Stripe keys/price IDs, seed `crystal_library`, and ensure verified tester accounts exist to exercise moon/healing flows.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:scripts/seed_database.js†L1-L120】
  - Replace the static hosting page with the Flutter build and run `flutter analyze`, `flutter test`, and Functions lint before merging.【F:firebase.json†L9-L25】【F:test/widget_test.dart†L1-L20】
- **Beta (limited testers)**:
  - Implement entitlement gating for premium/economy actions and add user-facing messaging for restricted features.【F:lib/services/economy_service.dart†L1-L220】【F:lib/screens/subscription_screen.dart†L61-L200】
  - Harden error handling around callable Functions (Stripe, moon rituals, healing) and add moderation tooling for marketplace listings.【F:lib/screens/moon_rituals_screen.dart†L181-L299】【F:lib/screens/marketplace_screen.dart†L1-L197】
  - Expand automated tests (widget/integration + Functions) and configure emulator-based workflows.【F:functions/package.json†L34-L42】
- **Production**:
  - Instrument analytics/performance monitoring, automate deploys, and ensure support/legal surfaces are populated via `EnvironmentConfig`.【F:lib/services/environment_config.dart†L61-L164】【F:functions/index.js†L946-L2005】
  - Finalize Stripe webhook handling, add admin tooling for crystal library/marketplace, and document recovery/rollback procedures.【F:functions/index.js†L946-L1175】【F:scripts/seed_database.js†L1-L120】

Refer to `DEPLOYMENT_GUIDE.md`, `DEVELOPER_HANDOFF.me`, `docs/RELEASE_PLAN.md`, and `claude.md` for execution details as these tasks progress.
