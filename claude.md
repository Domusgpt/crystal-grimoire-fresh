# Crystal Grimoire – Claude Launch Pad

## 1. Read Me First
- Start with `docs/APP_ASSESSMENT.md` for the authoritative audit of what works, what is missing, and known build blockers.
- Use `docs/RELEASE_PLAN.md` to understand what is required for MVP, Beta, and Production readiness. Treat it as the up-to-date checklist for planning your slice.
- Deployment/runtime specifics live in `DEPLOYMENT_GUIDE.md`; engineering history and context live in `DEVELOPER_HANDOFF.me`.
- Ignore any legacy claims of "production ready"—the repository is **pre-MVP** until the tasks in the assessment and release plan are complete.

## 2. Restore-the-Build Checklist (MVP gate)
1. Install Flutter 3.19+ and Node 20. Run `flutter pub get` and `npm install --prefix functions`.
2. Resolve compile blockers by removing or properly integrating `purchases_flutter` and the placeholder Firebase AI SDK, and by fixing the `FirebaseExtensionsService` → `FirebaseService` API mismatch.【F:lib/services/enhanced_payment_service.dart†L1-L200】【F:lib/services/firebase_ai_service.dart†L1-L80】【F:lib/services/firebase_extensions_service.dart†L34-L120】
3. Update `test/widget_test.dart` to bootstrap `CrystalGrimoireApp` so `flutter test` becomes a smoke test instead of a failure.【F:test/widget_test.dart†L12-L24】【F:lib/main.dart†L31-L59】
4. Seed Firestore (at least `crystal_library`) and configure Functions secrets (`firebase functions:config:set gemini.api_key=... stripe.secret_key=...`). Verify your Firebase user has `email_verified == true` or use relaxed dev rules.【F:scripts/seed_database.js†L1-L80】【F:firestore.rules†L1-L120】
5. Align the Functions runtime (Node 20 vs Node 22) before deploying; otherwise `firebase deploy` will fail.【F:functions/package.json†L1-L24】【F:firebase.json†L1-L33】

## 3. Known Gaps & Safe Defaults
- Disable or hide UI that calls unimplemented Functions (`earnSeerCredits`, `generateHealingLayout`, `getMoonRituals`, compatibility/care) until the backend is written.【F:lib/services/crystal_service.dart†L165-L276】【F:lib/services/economy_service.dart†L1-L220】
- Marketplace listings are written directly from the client; there is no moderation or payments. Keep that tab off for real users until admin tooling exists.【F:lib/screens/marketplace_screen.dart†L1-L197】
- Hosting currently serves `public/index.html`, not the Flutter build. When validating deployments, ensure the Flutter `build/web` output replaces it and remove the `/api/**` rewrite unless you ship an `api` function.【F:firebase.json†L7-L25】【F:public/index.html†L1-L160】
- Firestore rules require strict schemas and verified emails; expect `permission-denied` without seeding proper documents.【F:firestore.rules†L1-L120】

## 4. Working Rhythm for Agents
- Pull one milestone from `docs/RELEASE_PLAN.md` at a time. MVP work should focus on restoring the auth → identify → collection loop and cleaning up hosting.
- Document any schema changes, Functions updates, or rule tweaks in `DEVELOPER_HANDOFF.me` so the next agent inherits accurate information.
- Before committing, run `flutter analyze`, the repaired `flutter test`, and any Functions checks relevant to your changes. Capture results in the PR.
- If you touch security rules, Functions, or data shape, verify against the Firebase emulator or staging project before landing the change.

Log discrepancies, new blockers, or follow-up tasks in `DEVELOPER_HANDOFF.me` to keep everyone aligned.
