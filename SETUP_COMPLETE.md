# Crystal Grimoire – Setup Status

The previous version of this file claimed the project was fully configured. The updated status below reflects reality as of April 2025.

## Completed
- Flutter web project structure with themed UI, onboarding, notifications, and navigation between feature modules.【F:lib/screens/home_screen.dart†L1-L214】【F:lib/screens/onboarding_screen.dart†L1-L420】
- Firebase project skeleton with Auth/Firestore/Storage/Functions configuration files (`firebase.json`, `firestore.rules`, `storage.rules`).【F:firebase.json†L1-L33】【F:firestore.rules†L1-L120】
- Cloud Functions implementing crystal identification, dream analysis, daily crystal, moon rituals, healing layouts, economy credits, marketplace listings, and Stripe checkout helpers.【F:functions/index.js†L200-L2136】
- Moon Ritual and Crystal Healing screens now hydrate from backend responses (phase metadata, chakra placements, breathwork, integration).【F:lib/screens/moon_rituals_screen.dart†L1-L420】【F:lib/screens/crystal_healing_screen.dart†L1-L420】

## Still Required
- Seed Firestore collections (`crystal_library`, sample data) so the collection, rituals, and healing layouts have content.【F:scripts/seed_database.js†L1-L80】
- Provide Stripe configuration (publishable key, secret, price IDs) and exercise checkout before enabling subscriptions.【F:functions/index.js†L946-L1175】【F:lib/services/enhanced_payment_service.dart†L1-L216】
- Gate premium/economy surfaces behind plan checks so testers without subscriptions do not hit paid flows.【F:lib/services/economy_service.dart†L1-L220】【F:lib/screens/subscription_screen.dart†L1-L360】
- Align Node runtime declarations (Firebase targets Node 20 while `functions/package.json` currently pins 22).【F:firebase.json†L7-L20】【F:functions/package.json†L1-L17】

Treat this checklist as ongoing; update it as soon as the outstanding tasks are completed.
