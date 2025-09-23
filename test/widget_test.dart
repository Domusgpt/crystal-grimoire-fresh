import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_grimoire_fresh/screens/splash_screen.dart';
import 'package:crystal_grimoire_fresh/theme/app_theme.dart';

void main() {
  testWidgets('Splash screen renders crystal title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );

    expect(find.text('Crystal Grimoire'), findsOneWidget);
    expect(find.byType(ShaderMask), findsWidgets);
  });
}
