# Crystal Grimoire – Claude Deployment Companion

> **Read this file, `DEVELOPER_HANDOFF.me`, and `DEPLOYMENT_GUIDE.md` in full before making any code changes.** Keep detailed notes of everything you modify and update this document (and the handoff doc) when behavior or requirements shift.

## 1. Repository snapshot
- **Primary platform:** Flutter Web with Firebase Auth/Firestore/Storage/Functions/Hosting.
- **AI stack:** Google Gemini (vision + text) via Cloud Functions, optional OpenAI/Anthropic/Groq fallbacks wired through `EnvironmentConfig` + `ApiConfig`.
- **Payments:** RevenueCat (mobile) and Stripe Checkout (web) orchestrated by `EnhancedPaymentService` and Cloud Functions (`createStripeCheckoutSession`, `finalizeStripeCheckoutSession`).
- **Key services:**
  - `AuthService` – boots via `initializeUserProfile` callable, manages SharedPreferences caches, delete-account callable, and plan snapshot sync.
  - `CollectionServiceV2` – Firestore+local hybrid cache respecting SPEC‑1 collection rules (`libraryRef`, `notes`, `tags`, timestamps only).
  - `AppState` – hydrates crystals, recent identifications, dream analytics, onboarding flags, and plan/settings caches.
  - `EnhancedPaymentService` – unified purchase/restore flows, Stripe polling for web sessions, RevenueCat normalization for mobile.

## 2. Must-have environment configuration
Provide these as `--dart-define` values (Flutter) and Firebase Functions runtime config before building or deploying.

### Flutter/Dart defines
| Key | Purpose |
| --- | --- |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID` | Firebase core bootstrap |
| `FIREBASE_MEASUREMENT_ID` | Optional analytics (web) |
| `GEMINI_API_KEY` | Primary AI provider key |
| `OPENAI_API_KEY`, `CLAUDE_API_KEY`, `GROQ_API_KEY` | Optional fallback AI providers |
| `AI_DEFAULT_PROVIDER` | `gemini`, `openai`, `claude`, `groq`, or `replicate` |
| `STRIPE_PUBLISHABLE_KEY`, `STRIPE_PREMIUM_PRICE_ID`, `STRIPE_PRO_PRICE_ID`, `STRIPE_FOUNDERS_PRICE_ID` | Web checkout |
| `REVENUECAT_API_KEY` | Mobile purchases |
| `TERMS_URL`, `PRIVACY_URL`, `SUPPORT_URL`, `SUPPORT_EMAIL` | Compliance/help surfaces |
| `BACKEND_URL`, `USE_LOCAL_BACKEND` | Optional non-Firebase API routing |
| `ADMOB_*` keys, `ADMOB_TEST_DEVICE_IDS` | AdMob (falls back to Google test IDs if omitted) |
| `HOROSCOPE_API_KEY` | Optional external astrology provider |

### Firebase Functions runtime config
```bash
firebase functions:config:set \
  stripe.secret_key=sk_live_xxx \
  stripe.premium_price_id=price_123 \
  stripe.pro_price_id=price_456 \
  stripe.founders_price_id=price_789
```
Optional additional keys (configure with `firebase functions:config:set` or Secrets Manager):
- `gemini.api_key`, `openai.api_key`, `anthropic.api_key`, `groq.api_key`
- `astro.api_key` (external natal calculations)
- `revenuecat.api_key` (if functions need RevenueCat webhooks)

Run `firebase functions:config:get` before deploying to verify values.

## 3. Firestore & Storage schema (SPEC‑1)
- `users/{uid}` → `{ email, profile, settings, createdAt, updatedAt }`
  - `profile` contains subscription metadata (`subscriptionTier`, `subscriptionWillRenew`, `effectiveLimits`, etc.).
  - `settings` persists toggles from Settings screen.
- `users/{uid}/collection/{entryId}` → `{ libraryRef, notes, tags, addedAt, createdAt?, updatedAt? }`
- `users/{uid}/collectionLogs/{logId}` → `UsageLog.toJson()` (`collectionEntryId`, `purpose`, `dateTime`, etc.).
- `users/{uid}/identifications/{id}` → `{ imagePath, candidates[], selected, createdAt, updatedAt, latencyMs?, model? }`
- `users/{uid}/dreams/{id}` → `{ content, analysis, crystalSuggestions[], crystalsUsed[], dreamDate, createdAt, updatedAt, mood?, moonPhase? }`
- `users/{uid}/guidance/{id}` → structured guidance output with safety flags.
- `users/{uid}/economy/{doc}` → seer credit balances.
- `users/{uid}/plan/active` → `{ plan, provider, priceId?, billingTier?, effectiveLimits, flags, willRenew, lifetime, updatedAt, expiresAt? }`
- `usage/{uid_ymd}` → `{ identifyCount, guidanceCount, ... }`
- `checkoutSessions/{sessionId}` → Stripe polling metadata.
- `crystal_library/{slug}` → canonical crystal data (admin only writes).
- Storage uploads: `/uploads/{uid}/{yyyy}/{MM}/{dd}/{uuid}.jpg` (image-only, owner read/write).

Verify `firestore.rules` and `storage.rules` before deployment. Run `firebase emulators:exec --only firestore "npm run test:rules"` if rules tests are added.

## 4. Build, test, and deploy checklist
1. **Install tooling** (see `DEVELOPER_HANDOFF.me` → Flutter 3.22.2, Node 20, Firebase CLI).
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs` (when touching generated code).
4. `flutter analyze` and `flutter test`
5. `npm --prefix functions install`
6. `npm --prefix functions run lint` and `npm --prefix functions test` (lint currently uses `eslint.config.js`).
7. Configure Functions runtime config (section 2) and deploy:
   ```bash
   firebase deploy --only functions:identifyCrystal,functions:generateGuidance,functions:createStripeCheckoutSession,functions:finalizeStripeCheckoutSession,functions:initializeUserProfile,functions:deleteUserAccount
   firebase deploy --only firestore:rules,firestore:indexes,hosting,storage
   ```
8. After deploy, smoke test:
   - Sign-up + email verification → ensure profile bootstrap completes.
   - Collection add/update/delete → verify Firestore documents match schema.
   - Crystal identification → confirm `users/{uid}/identifications` updates.
   - Dream journal entry with AI analysis.
   - Web Stripe checkout round-trip (session creation, redirect, finalize).
   - RevenueCat purchase/restore (mobile) if keys provided.

Document findings in the PR and update usage counters/plan snapshots if manual tweaks were required.

## 5. Key documents & where to look
| File | Purpose |
| --- | --- |
| `DEVELOPER_HANDOFF.me` | Deep-dive on services, flows, troubleshooting |
| `DEPLOYMENT_GUIDE.md` | Step-by-step hosting/functions deployment |
| `PROJECT_STATUS.md` | High-level progress (update if scope changes) |
| `lib/services/*` | Source of truth for client integrations |
| `functions/index.js` | Cloud Functions (Stripe, AI, bootstrap, deletion) |
| `firestore.rules` / `storage.rules` | Security posture |
| `public/index.html` | Marketing/auth landing (ensure env config matches target project) |

Always cross-reference these before editing any feature area.

## 6. Outstanding work & follow-ups
- Seed `crystal_library` with production-ready entries and imagery.
- Complete guided camera capture pipeline (currently file upload-centric on web).
- Integrate Seer Credits economy with UI spend/earn states and expose balances.
- Build marketplace moderation/admin tooling (rules allow it; UI streams listings but lacks full seller verification flow).
- Expand automated tests: widget tests for Settings/Subscription, integration tests for collection sync, and Jest coverage for Functions.
- Evaluate analytics/observability (Firebase Analytics, Crashlytics for mobile builds, Stripe webhooks for subscription lifecycle).

## 7. Collaboration etiquette
- Work from feature branches; avoid force-pushing `work` after handoff.
- Keep commits scoped and documented; reference Jira/Trello ticket IDs if applicable.
- Run all checks listed above; do not skip lint/test without noting reason.
- Update this file and `DEVELOPER_HANDOFF.me` when flows, environment requirements, or deployment steps change.
- Record manual steps taken during testing so the next agent/dev can reproduce issues.

Happy shipping! Reach out via PR comments or project chat if anything in this document is unclear or drifts from reality.
