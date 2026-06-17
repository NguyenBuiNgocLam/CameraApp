import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/dictation/screens/dictation_home_screen.dart';
import '../features/dictation/screens/dictation_practice_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quiz/quiz_result_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/review/screens/today_review_screen.dart';
import '../features/scan/ai_result_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/system_vocabulary/models/system_vocabulary_set.dart';
import '../features/system_vocabulary/screens/system_vocabulary_detail_screen.dart';
import '../features/system_vocabulary/screens/system_vocabulary_learning_result_screen.dart';
import '../features/system_vocabulary/screens/system_vocabulary_learning_screen.dart';
import '../features/system_vocabulary/screens/system_vocabulary_sets_screen.dart';
import '../features/vocabulary/my_vocabulary_screen.dart';
import '../features/vocabulary/vocabulary_detail_screen.dart';
import '../features/vocabulary/models/word_list.dart';
import '../features/vocabulary/screens/word_list_detail_screen.dart';
import '../features/vocabulary/screens/word_list_screen.dart';
import '../features/vocabulary_learning/screens/vocabulary_learning_home_screen.dart';
import '../features/vocabulary_learning/screens/vocabulary_learning_practice_screen.dart';
import '../features/vocabulary_learning/screens/vocabulary_learning_result_screen.dart';
import '../models/vocabulary_item.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const scan = '/scan';
  static const aiResult = '/ai-result';
  static const vocabulary = '/vocabulary';
  static const vocabularyDetail = '/vocabulary-detail';
  static const wordListDetail = '/word-list-detail';
  static const quiz = '/quiz';
  static const quizResult = '/quiz-result';
  static const profile = '/profile';
  static const dictation = '/dictation';
  static const dictationHome = '/dictation-home';
  static const dictationPractice = '/dictation-practice';
  static const vocabularyLearning = '/vocabulary-learning';
  static const vocabularyLearningPractice = '/vocabulary-learning-practice';
  static const vocabularyLearningResult = '/vocabulary-learning-result';
  static const todayReview = '/today-review';
  static const systemVocabulary = '/system-vocabulary';
  static const systemVocabularyDetail = '/system-vocabulary-detail';
  static const systemVocabularyLearning = '/system-vocabulary-learning';
  static const systemVocabularyLearningResult =
      '/system-vocabulary-learning-result';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _route(const SplashScreen());
      case onboarding:
        return _route(const OnboardingScreen());
      case login:
        return _route(const LoginScreen());
      case register:
        return _route(const RegisterScreen());
      case forgotPassword:
        final initialEmail = settings.arguments as String? ?? '';
        return _route(ForgotPasswordScreen(initialEmail: initialEmail));
      case verifyEmail:
        return _route(const VerifyEmailScreen());
      case home:
        return _route(const HomeScreen());
      case scan:
        return _route(const ScanScreen());
      case aiResult:
        return _route(const AIResultScreen());
      case vocabulary:
        return _route(const WordListScreen());
      case vocabularyDetail:
        final item = settings.arguments as VocabularyItem?;
        if (item == null) return _route(const MyVocabularyScreen());
        return _route(VocabularyDetailScreen(item: item));
      case wordListDetail:
        final list = settings.arguments as WordList?;
        if (list == null) return _route(const WordListScreen());
        return _route(WordListDetailScreen(list: list));
      case quiz:
        return _route(const QuizScreen());
      case quizResult:
        final score = settings.arguments as int? ?? 4;
        return _route(QuizResultScreen(score: score));
      case profile:
        return _route(const ProfileScreen());
      case dictation:
      case dictationHome:
        return _route(const DictationHomeScreen());
      case dictationPractice:
        return _route(const DictationPracticeScreen());
      case vocabularyLearning:
        return _route(const VocabularyLearningHomeScreen());
      case vocabularyLearningPractice:
        return _route(const VocabularyLearningPracticeScreen());
      case vocabularyLearningResult:
        return _route(const VocabularyLearningResultScreen());
      case todayReview:
        final autoStart = settings.arguments as bool? ?? false;
        return _route(TodayReviewScreen(autoStart: autoStart));
      case systemVocabulary:
        return _route(const SystemVocabularySetsScreen());
      case systemVocabularyDetail:
        final set = settings.arguments as SystemVocabularySet?;
        if (set == null) return _route(const SystemVocabularySetsScreen());
        return _route(SystemVocabularyDetailScreen(set: set));
      case systemVocabularyLearning:
        return _route(const SystemVocabularyLearningScreen());
      case systemVocabularyLearningResult:
        return _route(const SystemVocabularyLearningResultScreen());
      default:
        return _route(const LoginScreen());
    }
  }

  static MaterialPageRoute<dynamic> _route(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}
