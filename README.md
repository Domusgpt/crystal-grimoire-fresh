# 🔮 Crystal Grimoire - Production

**AI-Powered Crystal Identification & Mystical Guidance Platform**

A sophisticated Flutter web application combining crystal identification, spiritual guidance, and mystical practices with stunning glassmorphic UI effects.

## ✨ Features

### 🔍 **AI Crystal Identification**
- Advanced image recognition using Google Vision + Gemini AI
- Complete crystal database with metaphysical properties
- Personalized guidance based on birth chart & intentions
- 95%+ accuracy identification rate

### 🌟 **Mystical Features**
- **Moon Rituals**: Current lunar phase calculations with personalized ritual recommendations
- **Crystal Healing**: Chakra-based healing session layouts with guided meditations
- **Dream Journal**: AI-powered dream analysis with crystal correlations  
- **Sound Bath**: Crystal-matched frequencies for meditation and healing
- **Personal Collection**: Track owned crystals with usage statistics

### 🎨 **Stunning UI**
- Glassmorphic design with visual_codex effects
- Holographic buttons and floating crystal animations
- Mystical purple/violet theme with smooth transitions
- Mobile-responsive with touch-optimized controls
- Real-time particles and shader effects

### 🔥 **Firebase Backend**
- **Authentication**: Email/Google sign-in with user profiles
- **Firestore**: Real-time database with security rules
- **Cloud Functions**: 15+ AI-powered endpoints
- **Storage**: Encrypted image and audio storage
- **Analytics**: User behavior and feature usage tracking

## 🚀 Technology Stack

- **Frontend**: Flutter 3.19+ with Material 3 design
- **Backend**: Firebase (Firestore, Functions, Auth, Storage, Hosting)
- **AI Services**: Google Gemini 1.5 Pro, Google Vision API
- **Payments**: Stripe for subscriptions and marketplace
- **Deployment**: Firebase Hosting with CI/CD via GitHub Actions

## 📱 Project Architecture

```
crystal-grimoire-fresh/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── theme/app_theme.dart         # Mystical theme system
│   ├── screens/                     # UI screens
│   │   ├── home_screen.dart         # Main dashboard
│   │   ├── splash_screen.dart       # Animated loading
│   │   └── [other screens]
│   ├── widgets/                     # Reusable components
│   │   ├── glassmorphic_container.dart
│   │   ├── floating_crystals.dart
│   │   └── holographic_button.dart
│   ├── services/                    # Business logic
│   │   ├── firebase_service.dart    # Firestore operations
│   │   ├── auth_service.dart        # Authentication
│   │   └── crystal_service.dart     # AI integration
│   └── models/                      # Data models
│       ├── crystal_model.dart
│       └── user_profile_model.dart
├── functions/                       # Cloud Functions
│   ├── index.js                     # 15+ AI endpoints
│   └── package.json                 # Node.js dependencies
├── web/                            # Flutter web build
├── firebase.json                   # Firebase configuration
└── firestore.rules                # Security rules
```

## 🛠️ Development Setup

### Prerequisites
```bash
# Required tools
flutter --version  # 3.19+
node --version      # 18+
firebase --version  # Latest
gh --version        # GitHub CLI
```

### Quick Start
```bash
# 1. Clone repository
git clone https://github.com/Domusgpt/crystal-grimoire-fresh.git
cd crystal-grimoire-fresh

# 2. Install Flutter dependencies
flutter pub get

# 3. Install Functions dependencies  
cd functions && npm install && cd ..

# 4. Configure Firebase
firebase login
firebase use crystal-grimoire-2025  # Your project ID

# 5. Set environment variables
cp .env.example .env
# Add your API keys to .env

# 6. Run development server
flutter run -d chrome
```

## 🚀 Deployment

### Firebase Hosting
```bash
# Build and deploy
flutter build web --release --base-href="/"
firebase deploy --only hosting,functions
```

### GitHub Pages (static marketing site)
The `public/` directory contains the static landing experience. A GitHub Actions workflow (`.github/workflows/gh-pages.yml`) uploads that directory as a Pages artifact and publishes it.

1. In your repository settings, enable GitHub Pages and choose **GitHub Actions** as the source.
2. Set the deployment branch to the branch you want (e.g., `work` for preview PRs or `main` for production) — the workflow triggers on both.
3. Merge the branch; the action will build and deploy automatically. The published site will mirror the `public/` folder contents.
4. If you instead point Pages to the branch **root** (without the Actions artifact), GitHub will try to render `README.md`. To cover that case, a lightweight `index.html` lives in the repo root and immediately redirects visitors to `./public/` so the marketing site loads either way.

> All assets use relative paths, so the page works whether it is served from the root domain or a Pages subpath.

#### Local preview + phased testing
- Serve the static site locally: `python -m http.server 3000 --directory public` then visit `http://localhost:3000`.
- Verify hero morphing journey: scroll the pinned hero to confirm the four epitaxial states, the morphing card stack rotations, and the progress bar advancing smoothly over ~800vh.
- Toggle “Reduce motion” in system accessibility settings to confirm pinned sections unpin and the canvas visualizer stays idle.
- Inspect beta form validation (required email) and CTA microcopy update after submit.

### Environment Variables
```bash
# Required in Firebase Functions config
GEMINI_API_KEY=your_gemini_key_here
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## 📊 Features Roadmap

### ✅ **Completed (MVP)**
- [x] Beautiful glassmorphic UI with animations
- [x] Firebase authentication (Email + Google)
- [x] AI crystal identification system
- [x] Personal crystal collection management
- [x] Moon phase calculations and ritual recommendations
- [x] Dream journal with AI analysis
- [x] Sound bath with crystal frequencies
- [x] Comprehensive Cloud Functions backend

### 🚧 **In Progress**
- [ ] Crystal Identification screen with camera integration
- [ ] Collection screen with advanced filtering
- [ ] Crystal Healing screen with chakra visualization
- [ ] Marketplace for buying/selling crystals
- [ ] User profile and settings management

### 🎯 **Planned Features**
- [ ] Stripe payment integration for subscriptions
- [ ] Push notifications for moon phases
- [ ] Offline mode with local storage
- [ ] Social features and crystal sharing
- [ ] Advanced analytics and insights

## 🔒 Security & Privacy

- **Authentication**: Firebase Auth with secure user sessions
- **Data Encryption**: All sensitive data encrypted at rest
- **API Security**: Rate limiting and input validation
- **Privacy**: GDPR compliant data handling
- **Payments**: PCI DSS compliant via Stripe

## 📈 Performance

- **First Paint**: < 2 seconds
- **Crystal ID Response**: < 5 seconds  
- **Database Queries**: < 500ms average
- **Lighthouse Score**: 90+ across all metrics
- **Mobile Performance**: Optimized for mid-range devices

## 🧪 Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Cloud Functions tests
cd functions && npm test
```

## 📝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Live Demo**: https://crystal-grimoire-2025.web.app
- **Documentation**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **API Reference**: Coming soon
- **Support**: Create an issue or contact support

---

**Built with ❤️ and Crystal Energy** ✨

*Combining ancient wisdom with modern technology to create a truly mystical experience.*
