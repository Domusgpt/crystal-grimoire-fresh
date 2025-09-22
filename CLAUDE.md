# Crystal Grimoire – Claude Deployment Brief

Welcome! This document condenses the essentials you need before deploying/testing this repo.

## Read first
1. `README.md` – project overview, prerequisites, env vars.
2. `DEVELOPER_HANDOFF.me` – deep dive into data contracts, workflows, troubleshooting.
3. `DEPLOYMENT_GUIDE.md` – step-by-step runbook for building & deploying.
4. `PROJECT_STATUS.md` – current roadmap/risks.

Please review these end-to-end before making changes. Update the docs if you discover inaccuracies.

## Environment checklist
- **Flutter 3.19+** (`asdf install flutter 3.22.2` recommended)
- **Node 20 + npm install** under `functions/`
- **Firebase CLI** logged into the correct project
- **Stripe keys & price IDs** (publishable + secret)
- **Gemini API key** (Functions config + dart-define)
- Optional: AdMob IDs, RevenueCat key, Horoscope provider key

All runtime config is pulled from dart-defines / Firebase Functions config via `EnvironmentConfig`. Run `EnvironmentConfig.printConfigurationStatus()` at startup to confirm nothing is missing.

## Key commands
```bash
flutter pub get
npm --prefix functions install

flutter run -d chrome --dart-define=...
npm --prefix functions run serve  # optional emulator

flutter build web --release --dart-define=...
firebase deploy --only firestore:rules,functions,hosting
```
Run `npm --prefix functions run lint` and `flutter analyze` when the toolchains are available.

## Critical flows to test
- Auth signup/login + Settings persistence
- Collection add/remove + offline reload (SharedPreferences cache)
- Dream analysis + guidance callable Functions
- Stripe checkout (create + finalize) and RevenueCat restore/purchase (mobile)
- Account deletion via callable

## Outstanding work (from status doc)
- Backfill `crystal_library` content and marketing copy
- Expand AI safety/prompt tuning
- Implement analytics/telemetry + push notifications
- Add automated tests around paywall and AI workflows

## Contribution expectations
- Read touched files entirely before editing.
- Keep Firestore schema within the SPEC-1 contract documented in `DEVELOPER_HANDOFF.me`.
- Document any new behaviors in the docs above and summarize changes in your PR/commit message.
- Leave the tree clean: `git status` should show no stray files when done.

Thank you for carrying the deployment/testing baton! Reach out in the project channel if new blockers appear.
