# 🔮 Crystal Grimoire – Deployment Guide (Beta)

This runbook captures the minimal steps to build, configure, and deploy the current Crystal Grimoire web app + Cloud Functions stack.

## 1. Prerequisites
- Flutter 3.19 or newer (`asdf install flutter 3.22.2` recommended)
- Node.js 20 (`asdf install nodejs 20.16.0`)
- Firebase CLI (`npm install -g firebase-tools`)
- Stripe account with live/test keys and price IDs
- Google AI Studio key for Gemini (stored server-side)

## 2. Install dependencies
```bash
flutter pub get
npm --prefix functions install
```

## 3. Configure environment
Supply dart-defines for the Flutter build and runtime. Example `.env` snippet for local dev:
```
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_STORAGE_BUCKET=...
FIREBASE_MESSAGING_SENDER_ID=...
GEMINI_API_KEY=...
AI_DEFAULT_PROVIDER=gemini
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_PREMIUM_PRICE_ID=price_123
STRIPE_PRO_PRICE_ID=price_456
STRIPE_FOUNDERS_PRICE_ID=price_789
REVENUECAT_API_KEY=appl_...
TERMS_URL=https://example.com/legal/terms
PRIVACY_URL=https://example.com/legal/privacy
SUPPORT_EMAIL=support@example.com
```

Configure Cloud Functions secrets + runtime config:
```bash
firebase functions:config:set \
  stripe.secret_key=sk_test_xxx \
  stripe.premium_price_id=price_123 \
  stripe.pro_price_id=price_456 \
  stripe.founders_price_id=price_789 \
  gemini.api_key=$GEMINI_API_KEY
```
(Use `firebase functions:secrets:set` if adopting the secrets manager.)

## 4. Local validation
```bash
# Run Flutter web app
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=$FIREBASE_API_KEY \
  --dart-define=FIREBASE_APP_ID=$FIREBASE_APP_ID \
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY \
  --dart-define=STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY

# Optional: serve Functions locally
npm --prefix functions run serve
```
Verify:
1. Sign up/sign in -> Settings save
2. Add crystal to collection -> appears after refresh
3. Run dream analysis/guidance (requires Gemini key)
4. Start Stripe checkout -> confirm redirect + polling flow
5. Delete account -> Cloud Function cleans up

## 5. Build & deploy
```bash
flutter build web --release \
  --dart-define=... # repeat production defines

firebase deploy --only firestore:rules,functions,hosting
```
If using multi-environment Firebase projects, run `firebase use staging`/`firebase use production` before deploying.

## 6. Post-deploy checklist
- Confirm `EnvironmentConfig.printConfigurationStatus()` logs no missing keys in production build.
- Run smoke tests in hosted environment (sign-in, collection, guidance, dream, subscription, account deletion).
- Monitor Cloud Functions logs for Stripe/Gemini quota or error spikes.
- Backfill `crystal_library` documents if deploying to a fresh project.

## 7. Troubleshooting
| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| Settings/collection writes fail with `permission-denied` | Missing Firestore rules deploy or user not authenticated | Deploy `firestore.rules`, ensure App Check + auth configured |
| Stripe checkout stalls at polling screen | Functions config missing Stripe price IDs or secret key | Re-run `firebase functions:config:set` and redeploy | 
| Dream/guidance calls return errors | Gemini key missing/invalid | Update Functions config + dart-defines |
| Ads service logs warnings | AdMob IDs not provided | Supply `ADMOB_*` defines or ignore for staging |

Keep `DEVELOPER_HANDOFF.me`, `PROJECT_STATUS.md`, and `CLAUDE.md` updated after each deployment to inform future operators.
