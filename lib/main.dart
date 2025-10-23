import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/app_service.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/collection_service_v2.dart';
import 'services/crystal_service.dart';
import 'services/economy_service.dart';
import 'services/environment_config.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/help_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('⚠️  Firebase initialization skipped: $e');
  }

  if (!firebaseReady && EnvironmentConfig.instance.hasFirebaseConfiguration) {
    debugPrint(
      '⚠️  Firebase configuration was provided but initialization still failed. ',
    );
  }

  // Initialize app service (async, non-blocking)
  AppService.instance.initialize();
  await MonitoringService.instance.initialize();
  unawaited(MonitoringService.instance.logEvent('app_boot', parameters: {
    'firebase_ready': firebaseReady,
  }));

  runApp(const CrystalGrimoireApp());
}

class CrystalGrimoireApp extends StatelessWidget {
  const CrystalGrimoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppService.instance),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CrystalService()),
        ChangeNotifierProvider(
          create: (_) => AppState()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => EconomyService()),
        ChangeNotifierProvider(
          create: (_) {
            final service = CollectionServiceV2();
            service.initialize();
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Crystal Grimoire',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
        routes: {
          '/auth-check': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/subscription': (context) => const SubscriptionScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/notifications': (context) => const NotificationScreen(),
          '/help': (context) => const HelpScreen(),
        },
      ),
    );
  }
}