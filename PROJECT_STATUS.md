# 🔮 Crystal Grimoire – Project Status

**Updated:** 22 September 2025

## 📌 Snapshot
- **Platform:** Flutter Web + Firebase (Auth, Firestore, Storage, Functions)
- **Current release train:** Alpha ➝ Beta hardening
- **Deployment target:** Firebase Hosting with Stripe-powered web checkout and RevenueCat mobile entitlements

The application boots end-to-end: authenticated users can manage their crystal collection, request Gemini-powered identifications and dream analyses, hear the procedural sound bath, and purchase upgrades through Stripe. Settings, plan metadata, and usage counters persist in Firestore, and SharedPreferences mirrors keep the app responsive offline.

## ✅ Completed since last review
- **Subscriptions:** Stripe checkout & confirmation Cloud Functions write `effectiveLimits`, renewal flags, and cached plan snapshots. RevenueCat flows reuse the same entitlement helper.
- **Settings & profile:** Settings screen persists toggles/privacy options, sign-out delegates to `AuthService`, and the account screen reads live plan + usage documents.
- **Collection & journal:** `CollectionServiceV2` syncs to `users/{uid}/collection` with usage logs; dream journal entries stream from Firestore with Gemini analysis fallbacks.
- **Marketplace:** Listings load from Firestore with category filters, seller gating, and creation dialogs using server timestamps.
- **Docs & config:** `EnvironmentConfig` removes all in-source secrets and `DEVELOPER_HANDOFF.me` enumerates required `--dart-define` values plus Stripe/Firebase setup steps.

## 🚧 Active work / open risks
- **Economy rewards:** Credit earning/spending tables exist, but reward sinks beyond extra IDs/guidance remain feature-flagged. Define final redemption catalogue or hide unused options in UI.
- **Marketplace compliance:** Listing moderation, payments/escrow, and dispute resolution are out of scope for this build. Gate marketplace access until policies and payout flows are finalised.
- **Cloud Functions cost controls:** Rate limiting and App Check enforcement are enabled, but usage analytics and alerting still need to be tuned before GA.
- **Landing site:** Static `public/index.html` now mirrors the authenticated experience without demo shortcuts, but marketing copy/design should be refreshed before launch.

## 🎯 Next steps toward Beta
1. **Provision production secrets** – Populate Firebase Functions config with Stripe/Gemini keys and supply Dart defines for hosting build pipelines.
2. **Harden Firestore rules** – Marketplace rules should validate seller ownership and enforce allowed fields (`title`, `priceCents`, etc.) for create/update.
3. **Economy polish** – Finalise Seer Credit redemption UX, expose balance in primary navigation, and add audit logging for credit deductions.
4. **QA sweep** – Run `flutter test`, `flutter analyze`, and manual flows (checkout, dream analysis, identification) against staging before inviting testers.

## 🔭 Nice-to-haves (post-Beta)
- Push notifications for lunar events and identification completion
- Offline-first mode for collection viewing and cached rituals
- Social sharing and invite codes for Esper tier roll-out
- Marketplace payment integration (Stripe Connect or on-chain alternative)

For deployment instructions and data schemas see [DEVELOPER_HANDOFF.me](DEVELOPER_HANDOFF.me).
