import 'package:cloud_firestore/cloud_firestore.dart';

import '../../activity/services/learning_activity_service.dart';
import '../../home/services/home_stats_service.dart';
import '../models/dashboard_stats.dart';

class DashboardService {
  DashboardService({
    FirebaseFirestore? firestore,
    LearningActivityService? activityService,
    HomeStatsService? homeStatsService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _activityService = activityService ?? LearningActivityService(),
       _homeStatsService =
           homeStatsService ?? HomeStatsService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final LearningActivityService _activityService;
  final HomeStatsService _homeStatsService;

  Future<DashboardStats> getDashboardStats(String uid) async {
    if (uid.trim().isEmpty) return DashboardStats.empty();

    final vocabularyOverview = await _homeStatsService
        .getVocabularyOverviewStats(uid);
    final quizSnapshot = await _userRef(uid).collection('quizResults').get();
    final dictationSnapshot =
        await _userRef(uid).collection('dictationSessions').get();

    final currentStreak = await _activityService.calculateCurrentStreak(uid);
    final longestStreak = await _activityService.calculateLongestStreak(uid);
    final totalLearningDays = await _activityService.countLearningDays(uid);

    return DashboardStats(
      totalWords: vocabularyOverview.totalLearned,
      favoriteWords: vocabularyOverview.favoriteWords,
      masteredWords: vocabularyOverview.mastered,
      temporaryWords: vocabularyOverview.temporary,
      unknownWords: vocabularyOverview.unknown,
      todayReviewCount: vocabularyOverview.todayReviewCount,
      wordsLearnedToday: vocabularyOverview.wordsToday,
      reviewedWordsToday: vocabularyOverview.reviewedToday,
      quizCompleted: quizSnapshot.docs.length,
      dictationSessions: dictationSnapshot.docs.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalLearningDays: totalLearningDays,
    );
  }

  Future<void> updateDashboardSummary(String uid) async {
    if (uid.trim().isEmpty) return;
    final stats = await getDashboardStats(uid);
    final now = DateTime.now();

    await _userRef(uid).collection('dashboard').doc('summary').set({
      'totalWords': stats.totalWords,
      'favoriteWords': stats.favoriteWords,
      'masteredWords': stats.masteredWords,
      'temporaryWords': stats.temporaryWords,
      'unknownWords': stats.unknownWords,
      'todayReviewCount': stats.todayReviewCount,
      'currentStreak': stats.currentStreak,
      'longestStreak': stats.longestStreak,
      'totalLearningDays': stats.totalLearningDays,
      'wordsLearnedToday': stats.wordsLearnedToday,
      'reviewedWordsToday': stats.reviewedWordsToday,
      'quizCompleted': stats.quizCompleted,
      'dictationSessions': stats.dictationSessions,
      'lastActiveDate': LearningActivityService.formatDateId(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }
}
