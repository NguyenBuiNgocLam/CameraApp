import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vocabulary_overview_stats.dart';

class HomeStatsService {
  HomeStatsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<VocabularyOverviewStats> getVocabularyOverviewStats(String uid) async {
    if (uid.trim().isEmpty) return VocabularyOverviewStats.empty();

    final userVocabularySnapshot =
        await _userRef(uid).collection('vocabulary').get();
    final systemProgressSnapshot =
        await _userRef(uid).collection('systemVocabularyProgress').get();

    final todayRange = _todayRange();
    final userStats = _countStats(
      userVocabularySnapshot.docs.map((doc) => doc.data()),
      todayRange: todayRange,
      countFavorites: true,
    );
    final systemStats = _countStats(
      systemProgressSnapshot.docs.map((doc) => doc.data()),
      todayRange: todayRange,
    );

    return VocabularyOverviewStats(
      totalLearned: userStats.learned + systemStats.learned,
      mastered: userStats.mastered + systemStats.mastered,
      temporary: userStats.temporary + systemStats.temporary,
      unknown: userStats.unknown + systemStats.unknown,
      todayReviewCount: userStats.dueToday + systemStats.dueToday,
      wordsToday: userStats.reviewedToday + systemStats.reviewedToday,
      reviewedToday: userStats.reviewedToday + systemStats.reviewedToday,
      userVocabularyLearned: userStats.learned,
      systemVocabularyLearned: systemStats.learned,
      userDueToday: userStats.dueToday,
      systemDueToday: systemStats.dueToday,
      favoriteWords: userStats.favorite,
    );
  }

  _StatsAccumulator _countStats(
    Iterable<Map<String, dynamic>> documents, {
    required _TodayRange todayRange,
    bool countFavorites = false,
  }) {
    final stats = _StatsAccumulator();

    for (final data in documents) {
      final learned = _isLearned(data);
      final lastReviewedAt = _readNullableDate(data['lastReviewedAt']);
      final nextReviewAt = _readNullableDate(data['nextReviewAt']);

      if (learned) {
        stats.learned++;
        switch (_readString(data['learningLevel']).toLowerCase()) {
          case 'mastered':
            stats.mastered++;
            break;
          case 'temporary':
            stats.temporary++;
            break;
          default:
            stats.unknown++;
            break;
        }
      }

      if (learned &&
          nextReviewAt != null &&
          !nextReviewAt.isAfter(todayRange.end)) {
        stats.dueToday++;
      }

      if (lastReviewedAt != null &&
          !lastReviewedAt.isBefore(todayRange.start) &&
          !lastReviewedAt.isAfter(todayRange.end)) {
        stats.reviewedToday++;
      }

      if (countFavorites && data['isFavorite'] == true) {
        stats.favorite++;
      }
    }

    return stats;
  }

  bool _isLearned(Map<String, dynamic> data) {
    return data['hasSeenFlashcard'] == true ||
        _readNullableDate(data['lastReviewedAt']) != null ||
        _readInt(data['correctCount']) > 0 ||
        _readInt(data['wrongCount']) > 0;
  }

  int _readInt(dynamic value) {
    return (value as num?)?.toInt() ?? 0;
  }

  String _readString(dynamic value) {
    final text = value as String?;
    if (text == null || text.trim().isEmpty) return 'unknown';
    return text.trim();
  }

  DateTime? _readNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  _TodayRange _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return _TodayRange(start: start, end: end);
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }
}

class _StatsAccumulator {
  int learned = 0;
  int mastered = 0;
  int temporary = 0;
  int unknown = 0;
  int dueToday = 0;
  int reviewedToday = 0;
  int favorite = 0;
}

class _TodayRange {
  const _TodayRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
