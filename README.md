# 🔮 Crystal Grimoire

Crystal Grimoire is a Flutter web application backed by Firebase that helps crystal enthusiasts identify stones, log personal collections, capture dreams, and unlock guided rituals. The project pairs a glassmorphic interface with Google Gemini powered cloud functions, Stripe web checkout, and RevenueCat mobile entitlements.

## 📦 What’s in this repository

- **Flutter Web client** – Responsive UI with Provider-based state, crystal collection management, dream journal, marketplace browsing, immersive sound bath, and a `/subscription` paywall tied to shared `PlanEntitlements`.
- **Firebase integration** – Email/Google/Apple authentication, user settings persisted in `users/{uid}`, synchronized collections and usage logs, cached plan snapshots, and Firestore-driven usage meters on the account screen.
- **Cloud Functions (Node 20+)** – Callable endpoints for crystal identification, dream analysis, Stripe checkout orchestration, and entitlement finalization. Functions write plan metadata back into Firestore and respect App Check.
- **Configuration tooling** – `EnvironmentConfig` centralises all API keys, Stripe price IDs, AdMob units, and support URLs through `--dart-define` values so secrets never live in source control.
- **Documentation** – `DEVELOPER_HANDOFF.me`, `DEPLOYMENT_GUIDE.md`, and `PROJECT_STATUS.md` describe setup, data contracts, and deployment expectations for future maintainers.

## ✅ Current feature set

| Area | Highlights |
| --- | --- |
| **Authentication & profile** | Email/password, Google, and Apple sign-in flows with first-party Firestore profile provisioning. Settings (notifications, language, privacy toggles) persist for each user and hydrate on launch. |
| **Crystal tools** | Crystal identification uploads images to Cloud Functions/Gemini and stores per-user results at `users/{uid}/identifications`. Collections sync to Firestore with offline SharedPreferences cache, usage logging, and search/filter helpers. |
| **Guidance & journaling** | Dream journal entries stream from Firestore, trigger Gemini analysis, and respect mood/moon metadata. Ritual reminders and moon data hydrate dashboards via shared services. |
| **Economy & subscriptions** | Seer Credits economy tracks earn/spend actions, while Stripe checkout (web) and RevenueCat (mobile) share entitlement logic via `EnhancedPaymentService`. Successful purchases update `users/{uid}` and `plan/active` with `effectiveLimits`, renewal flags, and cache snapshots. |
| **Marketplace** | Live Firestore-backed listings with category filters, creation dialogs, and seller validation. |
| **Audio experiences** | Procedural sound bath synthesizes ambience on the fly—no bundled binaries required. |

## 🚧 Remaining work at a glance

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for a detailed breakdown. In short, ensure production Firebase/Stripe credentials are supplied, tighten marketplace vetting for real-money launches, and complete feature-flagged economy rewards before GA.

## 🏗 Architecture overview

```
Flutter Web (lib/)
├── screens/ – feature screens (auth wrapper, collection, marketplace, dream journal, subscription, settings)
├── services/ – auth, AI, payments, economy, collection sync, shared AppState cache
├── config/ – API/env configuration & entitlement constants
├── widgets/ – reusable glassmorphic cards, buttons, particles
└── theme/ – app-wide theming & gradients

Firebase
├── Auth (email/google/apple)
├── Firestore (users/{uid}, plan/active, usage, collection, dreams, marketplace)
├── Storage (image uploads)
└── Cloud Functions (functions/index.js)
```

## ⚙️ Local setup

1. Install **Flutter 3.19+**, **Node 20+**, and the **Firebase CLI**.
2. Run `flutter pub get` and `npm install` inside `functions/`.
3. Supply the required defines when running or building Flutter (see table below or `DEVELOPER_HANDOFF.me`). Example:
   ```bash
   flutter run -d chrome \
     --dart-define=FIREBASE_API_KEY=... \
     --dart-define=FIREBASE_PROJECT_ID=... \
     --dart-define=GEMINI_API_KEY=... \
     --dart-define=STRIPE_PUBLISHABLE_KEY=... \
     --dart-define=REVENUECAT_API_KEY=...
   ```
4. Configure Cloud Functions secrets before invoking checkout:
   ```bash
   firebase functions:config:set \
     gemini.api_key=YOUR_KEY \
     stripe.secret_key=sk_live_... \
     stripe.premium_price_id=price_... \
     stripe.pro_price_id=price_... \
     stripe.founders_price_id=price_...
   ```

### Runtime configuration (partial list)

| Define | Purpose |
| --- | --- |
| `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID` | Core Firebase bootstrap |
| `GEMINI_API_KEY`, `OPENAI_API_KEY`, `CLAUDE_API_KEY`, `GROQ_API_KEY` | AI provider credentials (only keys you use are required) |
| `AI_DEFAULT_PROVIDER` | Default AI selection (`gemini`, `openai`, etc.) |
| `REVENUECAT_API_KEY` | Mobile subscription support |
| `STRIPE_PUBLISHABLE_KEY`, `STRIPE_PREMIUM_PRICE_ID`, `STRIPE_PRO_PRICE_ID`, `STRIPE_FOUNDERS_PRICE_ID` | Web checkout pricing |
| `TERMS_URL`, `PRIVACY_URL`, `SUPPORT_URL`, `SUPPORT_EMAIL` | Settings “About” links |
| `ADMOB_*` identifiers | Optional AdMob inventory (falls back to Google test IDs) |
| `BACKEND_URL`, `USE_LOCAL_BACKEND` | Optional non-Firebase backend routing |

Consult `DEVELOPER_HANDOFF.me` for the full matrix, data-contract notes, and troubleshooting tips.

## 🧪 Testing & validation

- `flutter analyze` – Static analysis (requires Flutter SDK locally).
- `flutter test` – Widget/unit tests.
- `npm run lint` (inside `functions/`) – Cloud Functions linting.

CI/CD can reuse these commands before deploying to Firebase Hosting (`flutter build web` → `firebase deploy --only hosting,functions`).

## 📚 Additional documentation

- [DEVELOPER_HANDOFF.me](DEVELOPER_HANDOFF.me) – Deep-dive setup, data contracts, and deployment checklist.
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) – Step-by-step Firebase project bootstrap.
- [PROJECT_STATUS.md](PROJECT_STATUS.md) – Current alpha/beta roadmap and outstanding work.

For support or clarifications, open an issue or reach out via the configured support email in `EnvironmentConfig`.
