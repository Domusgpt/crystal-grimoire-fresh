import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_grimoire_fresh/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CrystalGrimoireApp renders login shell without Firebase',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CrystalGrimoireApp());
    await tester.pumpAndSettle();

    expect(find.text('Crystal Grimoire'), findsWidgets);
    expect(find.textContaining('Welcome Back'), findsOneWidget);
  });
}
