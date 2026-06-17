import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/vocabulary_item.dart';

class SpacedRepetitionService {
  SpacedRepetitionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DateTime calculateNextReviewDate({
    required String learningLevel,
    required bool isCorrect,
    required int correctCount,
    required int wrongCount,
  }) {
    final now = DateTime.now();
    final normalizedLevel = learningLevel.trim().toLowerCase();
    final nextCorrectCount = correctCount + (isCorrect ? 1 : 0);
    final nextWrongCount = wrongCount + (isCorrect ? 0 : 1);

    if (!isCorrect || normalizedLevel == 'unknown') {
      return now.add(const Duration(days: 1));
    }

    if (nextWrongCount >= 3 && nextWrongCount >= nextCorrectCount) {
      return now.add(const Duration(days: 1));
    }

    if (normalizedLevel == 'temporary') {
      return now.add(const Duration(days: 3));
    }

    if (normalizedLevel == 'mastered') {
      if (nextWrongCount >= 2 && nextWrongCount > nextCorrectCount / 2) {
        return now.add(const Duration(days: 3));
      }
      return now.add(const Duration(days: 7));
    }

    return now.add(const Duration(days: 1));
  }

  Future<List<VocabularyItem>> getTodayReviewWords({
    required String uid,
    String? listId,
    int limit = 20,
  }) async {
    final words = await _getDueWords(uid: uid, listId: listId);
    return words.take(min(limit, 20)).toList();
  }

  Future<int> countTodayReviewWords({
    required String uid,
    String? listId,
  }) async {
    final words = await _getDueWords(uid: uid, listId: listId);
    return words.length;
  }

  Future<List<VocabularyItem>> _getDueWords({
    required String uid,
    String? listId,
  }) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before reviewing vocabulary.');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(uid)
        .collection('vocabulary');

    final targetListId = listId?.trim();
    if (targetListId != null && targetListId.isNotEmpty) {
      query = query.where('listId', isEqualTo: targetListId);
    }

    final snapshot = await query.get();
    final endOfToday = _endOfToday();
    final words =
        snapshot.docs
            .map(VocabularyItem.fromFirestore)
            .where(_hasLearningContent)
            .where((word) {
              final nextReviewAt = word.nextReviewAt;
              final learned =
                  word.hasSeenFlashcard || word.lastReviewedAt != null;
              return learned &&
                  nextReviewAt != null &&
                  !nextReviewAt.isAfter(endOfToday);
            })
            .toList()
          ..sort(_compareReviewPriority);

    return words;
  }

  bool _hasLearningContent(VocabularyItem item) {
    return item.word.trim().isNotEmpty && item.meaningVi.trim().isNotEmpty;
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  int _compareReviewPriority(VocabularyItem a, VocabularyItem b) {
    final aDue = a.nextReviewAt;
    final bDue = b.nextReviewAt;

    if (aDue == null && bDue != null) return -1;
    if (aDue != null && bDue == null) return 1;
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
    }

    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final levelCompare = _levelWeight(
      b.learningLevel,
    ).compareTo(_levelWeight(a.learningLevel));
    if (levelCompare != 0) return levelCompare;

    return a.word.toLowerCase().compareTo(b.word.toLowerCase());
  }

  int _levelWeight(String level) {
    return switch (level.trim().toLowerCase()) {
      'unknown' => 3,
      'temporary' => 2,
      'mastered' => 1,
      _ => 3,
    };
  }
}
