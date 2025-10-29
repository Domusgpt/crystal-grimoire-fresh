# Crystal Grimoire – Project Status (May 2025)

**Status**: Pre-MVP – the guarded app shell, Firebase callables, and Stripe scaffolding exist, but the Flutter toolchain and deployment pipeline still need hands-on validation before end-to-end testing can resume.

_For milestone-specific tasks see `docs/RELEASE_PLAN.md`; this status file now reflects verification work completed in May 2025._

## Highlights
- ✅ **Flutter UI shell** with glassmorphic theming, animated backgrounds, and routing between major modules.【F:lib/screens/home_screen.dart†L1-L214】
- ✅ **Firebase Auth + Firestore wiring** for basic profile documents, collection sync, and dream journal entries.【F:lib/services/app_service.dart†L1-L205】【F:lib/screens/dream_journal_screen.dart†L1-L203】
- ✅ **Cloud Functions** for crystal identification, guidance logging, dream analysis, Stripe checkout bootstrap, and account deletion.【F:functions/index.js†L200-L513】【F:functions/index.js†L1000-L1070】
- ✅ **Moon rituals & healing** persist the user’s intention, sync it to Firestore, surface moon metadata, and call out missing crystals so sessions highlight gaps in the collection.【F:lib/screens/moon_rituals_screen.dart†L1-L400】【F:lib/screens/crystal_healing_screen.dart†L1-L835】【F:lib/services/ritual_preference_service.dart†L1-L200】
- ⚠️ **Callable subsystems need validation**: economy/credits, moon rituals, and healing layouts reach Cloud Functions but still depend on staging config, quotas, and robust error handling before widening access.【F:lib/services/crystal_service.dart†L129-L276】【F:lib/services/economy_service.dart†L1-L220】
- ⚠️ **Build blockers**: Stripe configuration (publishable + secret keys, price IDs) must be provided before subscriptions work, and the Flutter build still needs to be validated locally after removing the RevenueCat/Firebase AI stubs.【F:lib/services/enhanced_payment_service.dart†L1-L320】【F:functions/index.js†L900-L1150】

## Verification (May 2025)
- ✅ `npm --prefix functions run lint` – Functions codebase linted successfully after reinstalling local dependencies.【3268cd†L1-L5】【5d7271†L1-L1】
- ✅ `npm --prefix functions run test:unit` – Callable/unit coverage passes; Firestore/Storage rules checks are skipped because the emulator is unavailable in this environment.【cb28c7†L1-L27】
- ⚠️ `npm --prefix functions run test:rules` – Rules suite skipped for the same emulator limitation (no failures recorded).【cfe9a7†L1-L17】
- ❌ `flutter test test/widget_test.dart` – Flutter SDK is not installed in the execution environment, preventing widget/integration tests from running.【d1c06d†L1-L3】

## Risks & Blockers
| Area | Impact |
| --- | --- |
| Missing Cloud Functions (`earnSeerCredits`, `generateHealingLayout`, etc.) | Runtime failures when UI tries to call them. |
| Strict security rules (require verified email, narrow field sets) | Development accounts will see `permission-denied` unless verification and schema match are handled.【F:firestore.rules†L1-L120】 |
| Stripe configuration | Subscription screen cannot function without publishable/secret keys and price IDs.【F:lib/services/enhanced_payment_service.dart†L1-L120】 |
| Flutter toolchain unavailable in CI/containers | No automated signal for widget/integration regressions until Flutter is installed and configured.【d1c06d†L1-L3】 |
| Functions tooling expects Node 20 | Local installs on Node 22 emit engine warnings; align toolchains to avoid subtle deploy/build issues.【98bdc4†L1-L7】【F:functions/package.json†L1-L24】 |
| Marketplace moderation | Callable enforces a queue and the Flutter app now includes an admin-only review tab; you still need to assign custom claims, define moderation policy, and wire payments before enabling sales. |
| Documentation drift | Previous guides suggested production readiness; new docs (this file, `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`) reflect real status. |

## Roadmap
### MVP (internal testing)
- Fix build by reconciling dependencies and updating tests.
- Ensure authentication ➜ crystal identification ➜ collection save cycle succeeds.
- Seed `crystal_library` and create smoke tests for the critical path.【F:scripts/seed_database.js†L1-L140】

### Beta (limited audience)
- Implement or disable economy, moon ritual, and healing layout features.
- Harden Firestore rules with automated tests and improve error handling in the UI.
- Finalize Stripe web checkout (or choose an alternative) and verify plan data updates.【F:lib/services/enhanced_payment_service.dart†L1-L160】【F:functions/index.js†L900-L1030】

### Production
- Add analytics/monitoring, admin tooling for marketplace/crystal library, and automated CI/CD.【F:lib/services/monitoring_service.dart†L1-L120】【F:scripts/export_firestore.js†L1-L120】
- Complete payment, moderation, and support flows; ensure legal/compliance links are set via `EnvironmentConfig`.

## Key References
- Architecture & gaps: `docs/APP_ASSESSMENT.md`
- Deployment steps: `DEPLOYMENT_GUIDE.md`
- Engineering handoff: `DEVELOPER_HANDOFF.me`
