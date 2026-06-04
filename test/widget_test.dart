import 'package:ai_vocabulary_camera/app/routes.dart';
import 'package:ai_vocabulary_camera/features/splash/splash_screen.dart';
import 'package:ai_vocabulary_camera/providers/auth_provider.dart';
import 'package:ai_vocabulary_camera/services/auth_service.dart';
import 'package:ai_vocabulary_camera/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(AuthService(firestore: FirestoreService())),
        child: MaterialApp(
          routes: {AppRoutes.onboarding: (_) => const SizedBox()},
          home: const SplashScreen(),
        ),
      ),
    );

    expect(find.text('AI Vocabulary Camera'), findsOneWidget);
    expect(
      find.text('Learn English from everything around you'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
