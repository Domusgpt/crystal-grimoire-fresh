# Crystal Grimoire – Deployment Guide (2025 Refresh)

This guide describes the practical steps required to run the current pre-MVP build and what still needs to be finished before a real deployment.

## 1. Prerequisites
- **Flutter**: 3.19.0 or newer (Dart 3.3+). Check with `flutter --version`.
- **Node.js**: 20.x (matches Functions runtime). The repo’s `package.json` lists Node 22, but Firebase Hosting currently targets Node 20—use Node 20 until the runtime is updated.【F:functions/package.json†L1-L17】【F:firebase.json†L1-L33】
- **Firebase CLI**: `npm install -g firebase-tools`
- **Firebase project**: The configs reference `crystal-grimoire-2025`. Replace with your own project ID if needed.

## 2. One-Time Setup
1. **Install dependencies**
   ```bash
   flutter pub get
   npm install --prefix functions
   ```
2. **Select the Firebase project**
   ```bash
   firebase login
   firebase use <your-project-id>
   ```
3. **Configure callable Functions**
   ```bash
   firebase functions:config:set \
     gemini.api_key="YOUR_GEMINI_KEY" \
     stripe.secret_key="sk_live_or_test" \
     stripe.premium_price_id="price_xxx" \
     stripe.pro_price_id="price_xxx" \
     stripe.founders_price_id="price_xxx"
   ```
   Add optional providers (OpenAI, Anthropic, Groq) if you intend to use `LLMService`.
4. **Seed data**
   - Populate the `crystal_library` collection (use `scripts/seed_database.js` with a service account JSON). The UI expects canonical crystal docs for collection hydration.【F:lib/services/collection_service_v2.dart†L142-L212】
   - Create any required indexes via `firestore.indexes.json`.

## 3. Running Locally (Flutter Web)
```bash
flutter run -d chrome \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=OPENAI_API_KEY=... \
  --dart-define=CLAUDE_API_KEY=... \
  --dart-define=STRIPE_PUBLISHABLE_KEY=...
```
Additional optional defines: `GROQ_API_KEY`, `TERMS_URL`, `PRIVACY_URL`, `SUPPORT_URL`. These map to `EnvironmentConfig`.【F:lib/services/environment_config.dart†L61-L164】

During development you may want to relax Firestore security rules or verify the signed-in user’s email to avoid `permission-denied` errors (rules require `email_verified`).【F:firestore.rules†L1-L40】

## 4. Cloud Functions
- **Local emulation**: `firebase emulators:start --only functions,firestore` (requires `.env`/config values above).
- **Deployment**: Once missing APIs are implemented and tests pass,
  ```bash
  npm --prefix functions run lint   # optional when lint config is ready
  npm --prefix functions test       # placeholder; no tests today
  firebase deploy --only functions
  ```
- Exercise `identifyCrystal`, `getDailyCrystal`, `getMoonRituals`, `generateHealingLayout`, and Stripe checkout helpers in the emulator or staging project before shipping. Add fallback messaging for misconfigured secrets so testers understand failures.【F:functions/index.js†L946-L1904】【F:lib/services/enhanced_payment_service.dart†L88-L216】

## 5. Building & Hosting Flutter Web
1. **Fix build blockers** (resolve the `FirebaseExtensionsService` compile error) so `flutter analyze`/`flutter test` succeed. The default widget test now renders `SplashScreen` as a smoke check.【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:test/widget_test.dart†L1-L20】
2. **Build**:
   ```bash
   flutter build web --release --dart-define=... (same defines as above)
   ```
3. **Deploy hosting**:
   ```bash
   firebase deploy --only hosting
   ```
   Hosting rewrites currently send all routes to `/index.html`; `/api/**` rewrites to a non-existent `api` function. Remove or implement that rewrite before production.【F:firebase.json†L7-L25】

## 6. Post-Deployment Checklist
- Confirm authentication works and that Firestore rules permit expected writes (user profile, collection, dreams).
- Test callable Functions via the live site (identify crystal, dream analysis). Monitor with `firebase functions:log`.
- Validate that Stripe checkout sessions are created and `users/{uid}/plan/active` is updated after `finalizeStripeCheckoutSession`.【F:functions/index.js†L200-L399】
- Review Firestore for required documents:
  - `users/{uid}` contains `profile` and `settings`.
  - `users/{uid}/collection` entries include `libraryRef`, `notes`, `tags` only (per security rules).【F:firestore.rules†L37-L76】
  - `crystal_library` is populated.

## 7. Preparing for a Real Release
Before inviting external testers, finish the backlog described in `docs/APP_ASSESSMENT.md`:
- Gate premium/economy surfaces until Stripe keys and price IDs are configured and tested.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:lib/services/economy_service.dart†L1-L220】
- Seed Firestore collections (`crystal_library`, `moonData`, marketplace samples) and verify strict security rules with verified tester accounts.【F:scripts/seed_database.js†L1-L120】【F:firestore.rules†L1-L120】
- Restore automated checks (`flutter analyze`, `flutter test`, `npm --prefix functions run lint`) once compile blockers are resolved.【F:test/widget_test.dart†L1-L20】【F:functions/package.json†L34-L42】
- Instrument error logging/monitoring (Analytics, Performance, Stripe webhook metrics) before inviting beta users.【F:functions/index.js†L946-L2005】

Keep this guide updated as deployment steps change.
