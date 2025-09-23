# Crystal Grimoire – Project Status (April 2025)

**Status**: Pre-MVP – core flows exist but the app does not compile or run end-to-end without additional work.

_For milestone-specific tasks see `docs/RELEASE_PLAN.md`; this status file remains a snapshot of April 2025._

## Highlights
- ✅ **Flutter UI shell** with glassmorphic theming, animated backgrounds, and routing between major modules.【F:lib/screens/home_screen.dart†L1-L214】
- ✅ **Firebase Auth + Firestore wiring** for basic profile documents, collection sync, and dream journal entries.【F:lib/services/app_service.dart†L1-L205】【F:lib/screens/dream_journal_screen.dart†L1-L203】
- ✅ **Cloud Functions** for crystal identification, guidance logging, dream analysis, Seer credit economy, Stripe checkout bootstrap, and account deletion.【F:functions/index.js†L200-L2374】
- ⚠️ **Economy credits available but gated by config** – callable Functions enforce daily caps and expect seeded economy docs; moon ritual and healing layouts require seeded `crystal_library` data and Gemini config to produce results.【F:lib/services/crystal_service.dart†L19-L276】【F:lib/services/economy_service.dart†L1-L220】
- ❌ **Build blockers**: `FirebaseExtensionsService` references private getters, and widget tests still reference the wrong root widget. Resolve before enabling CI.【F:lib/services/firebase_extensions_service.dart†L34-L88】【F:lib/services/firebase_service.dart†L1-L160】【F:test/widget_test.dart†L12-L24】

## Risks & Blockers
| Area | Impact |
| --- | --- |
| Seer credit configuration | Quota rejections bubble to the UI if daily limits are exceeded; seed `users/{uid}/economy/credits` for testers.【F:functions/index.js†L2203-L2374】 |
| Strict security rules (require verified email, narrow field sets) | Development accounts will see `permission-denied` unless verification and schema match are handled.【F:firestore.rules†L1-L120】 |
| Stripe configuration | Subscription screen requires Stripe price IDs and secrets to exercise checkout/webhook flows.【F:lib/services/enhanced_payment_service.dart†L1-L220】 |
| Documentation drift | Previous guides suggested production readiness; new docs (this file, `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`) reflect real status. |

## Roadmap
### MVP (internal testing)
- Fix build by removing/guarding services that reference unavailable backends and updating tests.
- Ensure authentication ➜ crystal identification ➜ collection save cycle succeeds.
- Seed `crystal_library` and create smoke tests for the critical path.

### Beta (limited audience)
- Exercise economy credit earning/spend flows and surface quota messaging.
- Harden Firestore rules with automated tests and improve error handling in the UI.
- Finalize Stripe web checkout (or choose an alternative) and verify plan data updates.

### Production
- Add analytics/monitoring, admin tooling for marketplace/crystal library, and automated CI/CD.
- Complete payment, moderation, and support flows; ensure legal/compliance links are set via `EnvironmentConfig`.

## Key References
- Architecture & gaps: `docs/APP_ASSESSMENT.md`
- Deployment steps: `DEPLOYMENT_GUIDE.md`
- Engineering handoff: `DEVELOPER_HANDOFF.me`
