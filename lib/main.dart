import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'features/activity/services/learning_activity_service.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/services/dashboard_service.dart';
import 'features/dictation/providers/dictation_provider.dart';
import 'features/dictation/services/dictation_firestore_service.dart';
import 'features/dictation/services/dictation_service.dart';
import 'features/settings/providers/reminder_provider.dart';
import 'features/system_vocabulary/providers/system_vocabulary_provider.dart';
import 'features/system_vocabulary/services/system_vocabulary_service.dart';
import 'features/vocabulary/providers/word_list_provider.dart';
import 'features/vocabulary/services/word_list_service.dart';
import 'features/vocabulary_learning/providers/vocabulary_learning_provider.dart';
import 'features/vocabulary_learning/services/vocabulary_learning_service.dart';
import 'providers/auth_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/vocabulary_provider.dart';
import 'services/ai_dictionary_service.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/firebase_app_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/quiz_service.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';
import 'services/vocabulary_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await FirebaseAppService.initialize();
  await NotificationService.instance.init();

  final firestore = FirestoreService();
  final storage = StorageService();
  final tts = TtsService();
  final wordListService = WordListService();
  final activityService = LearningActivityService();
  final dashboardService = DashboardService(activityService: activityService);

  final authProvider = AuthProvider(AuthService(firestore: firestore));
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  await authProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(
          create:
              (_) => VocabularyProvider(
                vocabularyService: VocabularyService(
                  firestore: firestore,
                  storage: storage,
                  wordListService: wordListService,
                ),
                aiDictionaryService: const AiDictionaryService(),
                ttsService: tts,
                activityService: activityService,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) => WordListProvider(wordListService: wordListService),
        ),
        ChangeNotifierProvider(create: (_) => ScanProvider(AiService())),
        ChangeNotifierProvider(
          create:
              (_) => QuizProvider(
                QuizService(firestore: firestore),
                activityService: activityService,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(dashboardService: dashboardService),
        ),
        ChangeNotifierProvider(
          create:
              (_) => SystemVocabularyProvider(
                systemVocabularyService: SystemVocabularyService(),
              ),
        ),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(
          create:
              (_) => VocabularyLearningProvider(
                learningService: VocabularyLearningService(),
                ttsService: tts,
                activityService: activityService,
              ),
        ),
        ChangeNotifierProvider(
          create:
              (_) => DictationProvider(
                dictationService: DictationService(),
                firestoreService: DictationFirestoreService(),
                activityService: activityService,
              ),
        ),
      ],
      child: const AIEnglishVocabularyApp(),
    ),
  );
}
