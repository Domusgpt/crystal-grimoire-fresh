# Crystal Grimoire – Project Status (April 2025)

**Status**: Pre-MVP – core flows (auth ➜ identify ➜ collection) run end-to-end and lunar/healing guidance now calls real Cloud Functions, but payments, moderation, and deployment automation remain outstanding.

_For milestone-specific tasks see `docs/RELEASE_PLAN.md`; this status file remains a snapshot of April 2025._

## Highlights
- ✅ **Flutter UI shell** with glassmorphic theming, animated backgrounds, and routing between major modules.【F:lib/screens/home_screen.dart†L1-L214】
- ✅ **Firebase Auth + Firestore wiring** for basic profile documents, collection sync, and dream journal entries.【F:lib/services/app_service.dart†L1-L205】【F:lib/screens/dream_journal_screen.dart†L1-L203】
- ✅ **Cloud Functions** cover identification, guidance logging, dream analysis, daily crystal, moon rituals, healing layouts, marketplace listings, economy, and Stripe checkout helpers.【F:functions/index.js†L200-L2136】
- ✅ **Moon Ritual & Healing screens** hydrate from backend responses (phase metadata, narrative guidance, chakra placements, breathwork, integration).【F:lib/screens/moon_rituals_screen.dart†L1-L420】【F:lib/screens/crystal_healing_screen.dart†L1-L420】
- ⚠️ **Payments & gating**: Stripe checkout helpers exist but pricing/feature flags are not final; premium experiences surface even without an active plan.【F:lib/screens/subscription_screen.dart†L1-L360】【F:lib/services/enhanced_payment_service.dart†L1-L216】

## Risks & Blockers
| Area | Impact |
| --- | --- |
| Stripe configuration | Checkout depends on Stripe keys, price IDs, and webhook/process verification before production. |
| Feature gating | Premium/economy surfaces remain visible without entitlement checks; testers may hit errors until gating is enforced. |
| Strict security rules (require verified email, narrow field sets) | Development accounts will see `permission-denied` unless verification and schema match are handled.【F:firestore.rules†L1-L120】 |
| Node runtime drift | `firebase.json` targets Node 20 while `functions/package.json` pins Node 22—align before deploy. |
| Documentation drift | Previous guides suggested production readiness; new docs (this file, `docs/APP_ASSESSMENT.md`, `DEPLOYMENT_GUIDE.md`) reflect real status. |

## Roadmap
### MVP (internal testing)
- Seed `crystal_library` and ensure verified tester accounts exist (rules require verified email + strict schemas).
- Configure Stripe (publishable key, secret, price IDs) and exercise checkout in the emulator or staging project.
- Add smoke tests for auth ➜ identify ➜ collection, plus widget coverage for splash/navigation.

### Beta (limited audience)
- Gate premium/economy UI behind plan checks or feature flags.
- Harden Firestore rules with automated tests and improve error handling in the UI.
- Finalize Stripe web checkout (or choose an alternative) and verify plan data updates.

### Production
- Add analytics/monitoring, admin tooling for marketplace/crystal library, and automated CI/CD.
- Complete payment, moderation, and support flows; ensure legal/compliance links are set via `EnvironmentConfig`.
- Align Node runtime declarations, add CI/CD, and automate hosting deploys.

## Key References
- Architecture & gaps: `docs/APP_ASSESSMENT.md`
- Deployment steps: `DEPLOYMENT_GUIDE.md`
- Engineering handoff: `DEVELOPER_HANDOFF.me`
