# Crystal Grimoire – Setup Status

The previous version of this file claimed the project was fully configured. The updated status below reflects reality as of April 2025.

## Completed
- Flutter web project structure with themed UI and navigation.【F:lib/screens/home_screen.dart†L1-L214】
- Firebase project skeleton with Auth/Firestore/Storage/Functions configuration files (`firebase.json`, `firestore.rules`, `storage.rules`).【F:firebase.json†L1-L33】【F:firestore.rules†L1-L120】
- Cloud Functions scaffold implementing crystal identification, dream analysis, guidance logging, Stripe checkout stubs, and account deletion.【F:functions/index.js†L200-L513】【F:functions/index.js†L1000-L1070】

## Still Required
- Resolve missing Flutter dependencies (`purchases_flutter`, `firebase_ai`) or remove the unused services that reference them.【F:lib/services/enhanced_payment_service.dart†L1-L16】【F:lib/services/firebase_ai_service.dart†L1-L40】
- Implement or disable callable Functions referenced by the client but not yet written (`earnSeerCredits`, `generateHealingLayout`, `getMoonRituals`, `checkCrystalCompatibility`, etc.).【F:lib/services/crystal_service.dart†L203-L276】
- Seed Firestore collections (`crystal_library`, sample data) so the collection and guidance features have content.【F:scripts/seed_database.js†L1-L80】
- Provide Stripe/RevenueCat configuration before enabling subscription flows.【F:functions/index.js†L200-L399】
- Update automated tests (`test/widget_test.dart`) to reflect `CrystalGrimoireApp`.【F:test/widget_test.dart†L12-L24】

Treat this checklist as ongoing; update it as soon as the outstanding tasks are completed.
