# Crystal Grimoire – Project Status (April 2025)

**Status**: Pre-MVP – core flows exist but the app does not compile or run end-to-end without additional work.

_For milestone-specific tasks see `docs/RELEASE_PLAN.md`; this status file remains a snapshot of April 2025._

## Highlights
- ✅ **Flutter UI shell** with glassmorphic theming, animated backgrounds, and routing between major modules.【F:lib/screens/home_screen.dart†L1-L214】
- ✅ **Firebase Auth + Firestore wiring** for basic profile documents, collection sync, and dream journal entries.【F:lib/services/app_service.dart†L1-L205】【F:lib/screens/dream_journal_screen.dart†L1-L203】
- ✅ **Cloud Functions** for crystal identification, guidance logging, dream analysis, Stripe checkout bootstrap, and account deletion.【F:functions/index.js†L200-L513】【F:functions/index.js†L1000-L1070】
- ✅ **Moon rituals & healing** now persist the user’s intention, sync it to Firestore for cross-device continuity, surface moon metadata, and call out missing crystals so sessions highlight gaps in the collection.【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/screens/crystal_healing_screen.dart†L1-L835】【F:lib/services/ritual_preference_service.dart†L1-L200】
- ⚠️ **Callable subsystems need validation**: economy/credits, moon rituals, and healing layouts now hit Cloud Functions but still depend on staging config, quotas, and robust error handling before widening access.【F:lib/services/crystal_service.dart†L129-L276】【F:lib/services/economy_service.dart†L1-L220】
- ⚠️ **Build blockers**: Stripe configuration (publishable + secret keys, price IDs) must be provided before subscriptions work, and the Flutter build still needs to be validated locally after removing the RevenueCat/Firebase AI stubs.【F:lib/services/enhanced_payment_service.dart†L1-L400】【F:functions/index.js†L900-L1150】

## Risks & Blockers
| Area | Impact |
| --- | --- |
| Missing Cloud Functions (`earnSeerCredits`, `generateHealingLayout`, etc.) | Runtime failures when UI tries to call them. |
| Strict security rules (require verified email, narrow field sets) | Development accounts will see `permission-denied` unless verification and schema match are handled.【F:firestore.rules†L1-L120】 |
| Stripe configuration | Subscription screen cannot function without publishable/secret keys and price IDs. |
| Marketplace moderation | Callable enforces a queue and the Flutter app now includes an admin-only review tab; you still need to assign custom claims, define moderation policy, and wire payments before enabling sales. |
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
