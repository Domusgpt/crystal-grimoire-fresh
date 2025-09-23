# Crystal Grimoire – Claude Launch Pad

## 1. Read Me First
- Start with `docs/APP_ASSESSMENT.md` for the authoritative audit of what works, what is missing, and known build blockers.
- Use `docs/RELEASE_PLAN.md` to understand what is required for MVP, Beta, and Production readiness. Treat it as the up-to-date checklist for planning your slice.
- Deployment/runtime specifics live in `DEPLOYMENT_GUIDE.md`; engineering history and context live in `DEVELOPER_HANDOFF.me`.
- Ignore any legacy claims of "production ready"—the repository is **pre-MVP** until the tasks in the assessment and release plan are complete.

## 2. Restore-the-Build Checklist (MVP gate)
1. Install Flutter 3.19+ and Node 20. Run `flutter pub get` and `npm install --prefix functions`.
2. Resolve compile blockers by fixing or removing `FirebaseExtensionsService` (it references private members on `FirebaseService`) and align the Functions runtime (Node 20 vs Node 22).【F:lib/services/firebase_extensions_service.dart†L30-L120】【F:functions/package.json†L1-L24】
3. Run `flutter analyze` and the widget smoke test (`flutter test`) once the compile blocker is gone—the default test now renders `SplashScreen`.【F:test/widget_test.dart†L1-L20】
4. Seed Firestore (`crystal_library`, `moonData`) and configure Functions secrets via `firebase functions:config:set gemini.api_key=... stripe.secret_key=... price ids`. Verified accounts are required because of strict rules.【F:scripts/seed_database.js†L1-L120】【F:firestore.rules†L1-L120】【F:functions/index.js†L946-L1175】
5. Replace the static hosting page with the Flutter `build/web` output and remove the `/api/**` rewrite unless you add an `api` Function.【F:public/index.html†L1-L200】【F:firebase.json†L9-L17】

## 3. Known Gaps & Safe Defaults
- Stripe checkout helpers are wired but require publishable/secret keys and price IDs; gate premium/economy UI until plans and entitlements are configured.【F:lib/services/enhanced_payment_service.dart†L88-L216】【F:lib/services/economy_service.dart†L1-L220】
- Marketplace listings write directly from the client with no moderation or payment enforcement—keep the tab hidden for external users until tooling exists.【F:lib/screens/marketplace_screen.dart†L1-L197】
- Hosting currently serves `public/index.html`, not the Flutter build. Update hosting before validating deployments.【F:public/index.html†L1-L200】【F:firebase.json†L9-L17】
- Firestore rules enforce verified emails and strict schemas; expect `permission-denied` unless you seed data and use verified accounts.【F:firestore.rules†L1-L120】

## 4. Working Rhythm for Agents
- Pull one milestone from `docs/RELEASE_PLAN.md` at a time. MVP work should focus on restoring the build, configuring Stripe, and seeding Firestore.
- Document any schema changes, Functions updates, or rule tweaks in `DEVELOPER_HANDOFF.me` so the next agent inherits accurate information.
- Before committing, run `flutter analyze`, the repaired `flutter test`, and `npm --prefix functions run lint`. Capture results in the PR.
- If you touch security rules, Functions, or data shape, verify against the Firebase emulator or staging project before landing the change.

Log discrepancies, new blockers, or follow-up tasks in `DEVELOPER_HANDOFF.me` to keep everyone aligned.
