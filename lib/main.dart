import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/crystal_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const CrystalGrimoireApp());
}

class CrystalGrimoireApp extends StatelessWidget {
  const CrystalGrimoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CrystalService()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
      ],
      child: MaterialApp(
        title: 'Crystal Grimoire',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}