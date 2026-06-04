import 'package:ai_vocabulary_camera/app/app.dart';
import 'package:ai_vocabulary_camera/app/routes.dart';
import 'package:ai_vocabulary_camera/app/theme.dart';
import 'package:ai_vocabulary_camera/data/mock_data.dart';
import 'package:ai_vocabulary_camera/features/dictation/providers/dictation_provider.dart';
import 'package:ai_vocabulary_camera/features/dictation/services/dictation_firestore_service.dart';
import 'package:ai_vocabulary_camera/features/dictation/services/dictation_service.dart';
import 'package:ai_vocabulary_camera/providers/auth_provider.dart';
import 'package:ai_vocabulary_camera/providers/quiz_provider.dart';
import 'package:ai_vocabulary_camera/providers/scan_provider.dart';
import 'package:ai_vocabulary_camera/providers/vocabulary_provider.dart';
import 'package:ai_vocabulary_camera/services/ai_service.dart';
import 'package:ai_vocabulary_camera/services/ai_dictionary_service.dart';
import 'package:ai_vocabulary_camera/services/auth_service.dart';
import 'package:ai_vocabulary_camera/services/firestore_service.dart';
import 'package:ai_vocabulary_camera/services/quiz_service.dart';
import 'package:ai_vocabulary_camera/services/storage_service.dart';
import 'package:ai_vocabulary_camera/services/tts_service.dart';
import 'package:ai_vocabulary_camera/services/vocabulary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final routes = <String>[
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.home,
    AppRoutes.scan,
    AppRoutes.aiResult,
    AppRoutes.vocabulary,
    AppRoutes.vocabularyDetail,
    AppRoutes.quiz,
    AppRoutes.quizResult,
    AppRoutes.profile,
    AppRoutes.dictation,
    AppRoutes.dictationPractice,
  ];

  for (final size in const [Size(393, 852), Size(360, 640)]) {
    testWidgets(
      'main screens do not overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = 1;

        for (final route in routes) {
          await tester.pumpWidget(_RouteHost(initialRoute: route));
          await tester.pumpAndSettle();

          final exception = tester.takeException();
          expect(exception, isNull, reason: '$route overflowed at $size');
        }

        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      },
    );
  }
}

class _RouteHost extends StatefulWidget {
  const _RouteHost({required this.initialRoute});

  final String initialRoute;

  @override
  State<_RouteHost> createState() => _RouteHostState();
}

class _RouteHostState extends State<_RouteHost> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final vocabularyProvider = VocabularyProvider(
      vocabularyService: VocabularyService(
        firestore: firestore,
        storage: StorageService(),
      ),
      aiDictionaryService: const AiDictionaryService(),
      ttsService: TtsService(),
    )..items = MockData.vocabulary;

    return ThemeController(
      themeMode: _themeMode,
      setDarkMode: (value) {
        setState(() => _themeMode = value ? ThemeMode.dark : ThemeMode.light);
      },
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(AuthService(firestore: firestore)),
          ),
          ChangeNotifierProvider.value(value: vocabularyProvider),
          ChangeNotifierProvider(
            create: (_) => QuizProvider(QuizService(firestore: firestore)),
          ),
          ChangeNotifierProvider(create: (_) => ScanProvider(AiService())),
          ChangeNotifierProvider(
            create:
                (_) => DictationProvider(
                  dictationService: DictationService(),
                  firestoreService: DictationFirestoreService(),
                ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          initialRoute: widget.initialRoute,
          onGenerateInitialRoutes:
              (_) => [
                AppRoutes.onGenerateRoute(
                  RouteSettings(name: widget.initialRoute),
                ),
              ],
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
