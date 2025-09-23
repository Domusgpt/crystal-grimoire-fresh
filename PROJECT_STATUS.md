# Crystal Grimoire – Project Status (April 2025)

**Status**: Pre-MVP – core flows exist but the app does not compile or run end-to-end without additional work.

_For milestone-specific tasks see `docs/RELEASE_PLAN.md`; this status file remains a snapshot of April 2025._

## Highlights
- ✅ **Flutter UI shell** with glassmorphic theming, animated backgrounds, and routing between major modules.【F:lib/screens/home_screen.dart†L1-L214】
- ✅ **Firebase Auth + Firestore wiring** for basic profile documents, collection sync, and dream journal entries.【F:lib/services/app_service.dart†L1-L205】【F:lib/screens/dream_journal_screen.dart†L1-L203】
- ✅ **Cloud Functions** for crystal identification, guidance logging, dream analysis, Stripe checkout bootstrap, and account deletion.【F:functions/index.js†L200-L513】【F:functions/index.js†L1000-L1070】
- ⚠️ **Multiple subsystems are stubs**: economy/credits, moon rituals, healing layouts, and premium AI services reference callable Functions that are not implemented.【F:lib/services/crystal_service.dart†L203-L276】【F:lib/services/economy_service.dart†L1-L174】
- ❌ **Build blockers**: `purchases_flutter` and `firebase_ai` packages are missing, and widget tests reference the wrong root widget.【F:lib/services/enhanced_payment_service.dart†L1-L16】【F:test/widget_test.dart†L12-L24】

## Risks & Blockers
| Area | Impact |
| --- | --- |
| Missing Cloud Functions (`earnSeerCredits`, `generateHealingLayout`, etc.) | Runtime failures when UI tries to call them. |
| Strict security rules (require verified email, narrow field sets) | Development accounts will see `permission-denied` unless verification and schema match are handled.【F:firestore.rules†L1-L120】 |
| Stripe/RevenueCat dependencies | Subscription screen cannot compile until SDKs/config are provided. |
| Documentation drift | Previous guides suggested production readiness; new docs (this file, `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`) reflect real status. |

## Roadmap
### MVP (internal testing)
- Fix build by reconciling dependencies and updating tests.
- Ensure authentication ➜ crystal identification ➜ collection save cycle succeeds.
- Seed `crystal_library` and create smoke tests for the critical path.

### Beta (limited audience)
- Implement or disable economy, moon ritual, and healing layout features.
- Harden Firestore rules with automated tests and improve error handling in the UI.
- Finalize Stripe web checkout (or choose an alternative) and verify plan data updates.

### Production
- Add analytics/monitoring, admin tooling for marketplace/crystal library, and automated CI/CD.
- Complete payment, moderation, and support flows; ensure legal/compliance links are set via `EnvironmentConfig`.

## Key References
- Architecture & gaps: `docs/APP_ASSESSMENT.md`
- Deployment steps: `DEPLOYMENT_GUIDE.md`
- Engineering handoff: `DEVELOPER_HANDOFF.me`
