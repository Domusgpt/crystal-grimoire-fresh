# Crystal Grimoire – Setup Status

The previous version of this file claimed the project was fully configured. The updated status below reflects reality as of April 2025.

## Completed
- Flutter web project structure with themed UI and navigation.【F:lib/screens/home_screen.dart†L1-L214】
- Firebase project skeleton with Auth/Firestore/Storage/Functions configuration files (`firebase.json`, `firestore.rules`, `storage.rules`).【F:firebase.json†L1-L33】【F:firestore.rules†L1-L120】
- Cloud Functions implementing crystal identification, dream analysis, guidance logging, Stripe checkout, marketplace listings, and the Seer credit economy.【F:functions/index.js†L200-L2374】

## Still Required
- Remove or guard services that reference unavailable backends (e.g., Firebase Extensions) so the Flutter build succeeds.【F:lib/services/firebase_extensions_service.dart†L34-L88】
- Seed Firestore collections (`crystal_library`, economy docs) so collection, ritual, and credit features have content.【F:scripts/seed_database.js†L1-L80】【F:functions/index.js†L2203-L2374】
- Provide Stripe configuration (Functions config, publishable key) before enabling subscription flows; document webhook handling.【F:functions/index.js†L912-L1188】【F:lib/services/enhanced_payment_service.dart†L1-L220】
- Update automated tests (`test/widget_test.dart`) to reflect `CrystalGrimoireApp`.【F:test/widget_test.dart†L12-L24】

Treat this checklist as ongoing; update it as soon as the outstanding tasks are completed.
