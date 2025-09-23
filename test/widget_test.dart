import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:crystal_grimoire_fresh/screens/auth/authentication_screen.dart';
import 'package:crystal_grimoire_fresh/services/app_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppService.instance.initialize();
  });

  testWidgets('authentication flow renders entry points', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppService.instance,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AuthenticationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Crystal Grimoire'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });
}
