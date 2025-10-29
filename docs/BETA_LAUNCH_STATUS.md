# Beta & Launch Readiness Report (May 2025)

This report captures the verification work completed in May 2025, outstanding fixes, and the remaining scope required for beta and launch readiness.

## 1. Verification Summary
- `npm --prefix functions run lint` ✔️ – Lints succeed once local dependencies are installed.【3268cd†L1-L5】【5d7271†L1-L1】
- `npm --prefix functions run test:unit` ✔️ – Unit tests for plan catalog, support helpers, and callable guards pass; Firestore/Storage rules tests are skipped because the emulator is absent.【cb28c7†L1-L27】
- `npm --prefix functions run test:rules` ⚠️ – Entire suite skipped for the same emulator limitation; no coverage of Firestore/Storage rules is exercised in CI yet.【cfe9a7†L1-L17】
- `flutter test test/widget_test.dart` ❌ – Flutter SDK is not present in the container, so widget/integration tests cannot run.【d1c06d†L1-L3】
- `npm --prefix functions install` warns about the Node 20 engine requirement while the container runs Node 22; align toolchains to avoid future deploy errors.【98bdc4†L1-L7】【F:functions/package.json†L1-L24】
- `npm --prefix functions audit` reports one high (Axios DoS) and one moderate (Nodemailer) vulnerability; upgrades are available.【09353e†L1-L58】

## 2. Immediate Fixes & Improvements
### Tooling & Infrastructure
- Install and pin the Flutter SDK for CI/local containers so smoke/widget tests become actionable signals.【d1c06d†L1-L3】
- Ensure development environments use Node 20 (or adjust the Functions runtime) to silence engine warnings and match deployment expectations.【98bdc4†L1-L7】【F:functions/package.json†L1-L24】
- Provision Firebase emulators (Firestore + Storage) in local/CI flows so the security rules suite stops skipping and enforces coverage.【cb28c7†L14-L27】【cfe9a7†L5-L17】
- Patch or upgrade vulnerable packages: Axios ≥1.12.0 and Nodemailer ≥7.0.10 to address the audit findings.【09353e†L1-L58】

### Backend & Configuration
- Provide Stripe publishable/secret keys and price IDs, then validate the Stripe-backed checkout/session finalization flows before beta.【F:lib/services/enhanced_payment_service.dart†L1-L160】【F:functions/index.js†L900-L1030】
- Seed the plan catalog and crystal library via `scripts/seed_database.js`, ensuring staging/production projects reference the generated plan metadata consumed by `getPlanStatus`.【F:scripts/seed_database.js†L1-L140】【F:functions/index.js†L960-L1020】
- Audit callable coverage—`identifyCrystal`, dream analysis, moon rituals, economy, and support ticket handlers require staging credentials and quota checks before wider rollout.【F:functions/index.js†L1700-L1810】【F:lib/services/crystal_service.dart†L129-L276】
- Populate environment flags and API keys through `EnvironmentConfig` (`ENABLE_STRIPE_CHECKOUT`, `ENABLE_SUPPORT_TICKETS`, LLM keys, etc.) so gated features activate intentionally during beta.【F:lib/services/environment_config.dart†L1-L120】【F:lib/services/support_service.dart†L1-L120】
- Replace or implement the `/api/**` hosting rewrite—`firebase.json` still points to an `api` HTTPS function that does not exist in `functions/index.js`, so deploys will route to 404s unless addressed.【F:firebase.json†L1-L29】

### Frontend & UX
- Re-enable widget/integration smoke tests (`test/widget_test.dart`, offline flows) after the Flutter toolchain is installed to guard navigation and service initialization.【d1c06d†L1-L3】【F:test/widget_test.dart†L1-L40】
- Exercise subscription, plan gating, and support ticket flows in staging to verify the client-side fallbacks (`PlanStatusService`, `SupportService`) behave correctly when Firebase is configured.【F:lib/services/plan_status_service.dart†L1-L200】【F:lib/services/support_service.dart†L1-L200】
- Harden user-facing error handling around callable failures so testers get actionable feedback during beta (economy, rituals, dream analysis, payments).【F:lib/services/economy_service.dart†L1-L220】【F:lib/screens/moon_rituals_screen.dart†L1-L400】

## 3. Beta Exit Checklist
- ✅ Deploy and smoke test Stripe checkout (`startCheckout`, `finalizeStripeCheckoutSession`) with real staging credentials and confirm Firestore updates subscription tiers.【F:functions/index.js†L900-L1100】【F:lib/services/enhanced_payment_service.dart†L80-L160】
- ✅ Seed and publish plan catalog / usage documents so `getPlanStatus` enforces quotas in beta builds.【F:functions/index.js†L960-L1030】【F:lib/services/plan_status_service.dart†L120-L200】
- ✅ Validate high-frequency callables (identify crystal, dream analysis, moon rituals) end-to-end, including quota enforcement and monitoring hooks.【F:functions/index.js†L1700-L1810】【F:functions/src/monitoring.js†L1-L63】
- ✅ Enable support ticket syncing (`ENABLE_SUPPORT_TICKETS=true`) and confirm comments/assignments sync between the app and Cloud Functions.【F:lib/services/environment_config.dart†L49-L80】【F:lib/services/support_service.dart†L140-L220】
- ✅ Run Firestore/Storage rules tests with emulators in CI before inviting beta users.【cb28c7†L14-L27】【cfe9a7†L5-L17】

## 4. Launch (GA) Focus Areas
- Instrument analytics/monitoring dashboards using the client `MonitoringService` and the Cloud Functions logging helpers so production can detect callable failures quickly.【F:lib/services/monitoring_service.dart†L1-L120】【F:functions/src/monitoring.js†L1-L63】
- Automate backups for critical collections (`scripts/export_firestore.js`) and document restore procedures for ops readiness.【F:scripts/export_firestore.js†L1-L120】
- Finalize marketplace moderation, subscription management, and support escalation runbooks—custom claims plus CLI tooling exist but still require human policy/process definition.【F:lib/services/support_service.dart†L1-L200】【F:scripts/support_ticket_cli.js†L1-L160】
- Ensure legal/support URLs and payment disclosures are populated through `EnvironmentConfig` before GA to avoid blank links in the UI.【F:lib/services/environment_config.dart†L20-L120】

Keep this report alongside `PROJECT_STATUS.md` and `docs/RELEASE_PLAN.md` when planning the next execution cycle.
