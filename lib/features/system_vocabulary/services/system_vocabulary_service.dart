import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/system_vocabulary_item.dart';
import '../models/system_vocabulary_progress.dart';
import '../models/system_vocabulary_set.dart';

class SystemVocabularyService {
  SystemVocabularyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SystemVocabularySet>> getSystemSets() async {
    final snapshot =
        await _firestore
            .collection('systemVocabularySets')
            .orderBy('createdAt', descending: false)
            .get();

    return snapshot.docs.map(SystemVocabularySet.fromFirestore).toList();
  }

  Future<List<SystemVocabularyItem>> getWordsBySet(String setId) async {
    final snapshot =
        await _setRef(setId).collection('words').orderBy('no').get();

    return snapshot.docs.map(SystemVocabularyItem.fromFirestore).toList();
  }

  Future<List<SystemVocabularyItem>> getWordsByTopic({
    required String setId,
    required String topic,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) return getWordsBySet(setId);

    final snapshot =
        await _setRef(setId)
            .collection('words')
            .where('topic', isEqualTo: trimmedTopic)
            .orderBy('no')
            .get();

    return snapshot.docs.map(SystemVocabularyItem.fromFirestore).toList();
  }

  Future<List<String>> getTopics(String setId) async {
    final words = await getWordsBySet(setId);
    return words
        .map((word) => word.topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<SystemVocabularyProgress?> getUserProgress({
    required String uid,
    required String setId,
    required String wordId,
  }) async {
    final snapshot = await _progressRef(uid, setId, wordId).get();
    if (!snapshot.exists) return null;
    return SystemVocabularyProgress.fromFirestore(snapshot);
  }

  Future<Map<String, SystemVocabularyProgress>> getUserProgressMap({
    required String uid,
    required String setId,
  }) async {
    final snapshot =
        await _userProgressCollection(
          uid,
        ).where('setId', isEqualTo: setId).get();

    return {
      for (final doc in snapshot.docs)
        SystemVocabularyProgress.fromFirestore(
          doc,
        ).wordId: SystemVocabularyProgress.fromFirestore(doc),
    };
  }

  Future<int> getDueReviewCount({
    required String uid,
    required String setId,
  }) async {
    final progressMap = await getUserProgressMap(uid: uid, setId: setId);
    final endOfToday = _endOfToday();
    return progressMap.values.where((progress) {
      final nextReviewAt = progress.nextReviewAt;
      return nextReviewAt != null && !nextReviewAt.isAfter(endOfToday);
    }).length;
  }

  Future<List<SystemVocabularyItem>> getReviewWords({
    required String uid,
    required String setId,
    int limit = 20,
  }) async {
    final progressMap = await getUserProgressMap(uid: uid, setId: setId);
    final endOfToday = _endOfToday();
    final dueProgress =
        progressMap.values.where((progress) {
            final nextReviewAt = progress.nextReviewAt;
            return nextReviewAt != null && !nextReviewAt.isAfter(endOfToday);
          }).toList()
          ..sort(_compareReviewProgress);

    if (dueProgress.isEmpty) return [];

    final selectedProgress = dueProgress.take(limit.clamp(1, 20)).toList();
    final wordsById = <String, SystemVocabularyItem>{};
    for (final progress in selectedProgress) {
      final doc =
          await _setRef(setId).collection('words').doc(progress.wordId).get();
      if (!doc.exists) continue;
      final word = SystemVocabularyItem.fromFirestore(doc);
      wordsById[word.id] = word;
    }

    return [
      for (final progress in selectedProgress)
        if (wordsById[progress.wordId] != null) wordsById[progress.wordId]!,
    ];
  }

  Future<SystemVocabularyProgress> updateProgress({
    required String uid,
    required String setId,
    required String wordId,
    required bool isCorrect,
    required String learningLevel,
  }) {
    return updatePracticeResult(
      uid: uid,
      setId: setId,
      wordId: wordId,
      isCorrect: isCorrect,
    );
  }

  Future<SystemVocabularyProgress> updatePracticeResult({
    required String uid,
    required String setId,
    required String wordId,
    required bool isCorrect,
  }) async {
    final ref = _progressRef(uid, setId, wordId);
    final snapshot = await ref.get();
    final existing =
        snapshot.exists
            ? SystemVocabularyProgress.fromFirestore(snapshot)
            : null;

    final now = DateTime.now();
    final correctCount = (existing?.correctCount ?? 0) + (isCorrect ? 1 : 0);
    final wrongCount = (existing?.wrongCount ?? 0) + (isCorrect ? 0 : 1);
    final learningLevel =
        isCorrect ? (correctCount >= 3 ? 'mastered' : 'temporary') : 'unknown';
    final nextReviewAt = switch (learningLevel) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };

    final progress = SystemVocabularyProgress(
      id: progressId(setId: setId, wordId: wordId),
      userId: uid,
      setId: setId,
      wordId: wordId,
      learningLevel: learningLevel,
      correctCount: correctCount,
      wrongCount: wrongCount,
      hasSeenFlashcard: true,
      lastReviewedAt: now,
      nextReviewAt: nextReviewAt,
      isFavorite: existing?.isFavorite ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.set(progress.toFirestore(), SetOptions(merge: true));
    return progress;
  }

  Future<SystemVocabularyProgress> updateFlashcardLevel({
    required String uid,
    required String setId,
    required String wordId,
    String? learningLevel,
    String? level,
  }) async {
    final normalizedLevel = _normalizeLearningLevel(learningLevel ?? level);
    final ref = _progressRef(uid, setId, wordId);
    final snapshot = await ref.get();
    final existing =
        snapshot.exists
            ? SystemVocabularyProgress.fromFirestore(snapshot)
            : null;

    final now = DateTime.now();
    final nextReviewAt = switch (normalizedLevel) {
      'mastered' => now.add(const Duration(days: 7)),
      'temporary' => now.add(const Duration(days: 3)),
      _ => now.add(const Duration(days: 1)),
    };

    final progress = SystemVocabularyProgress(
      id: progressId(setId: setId, wordId: wordId),
      userId: uid,
      setId: setId,
      wordId: wordId,
      learningLevel: normalizedLevel,
      correctCount: existing?.correctCount ?? 0,
      wrongCount: existing?.wrongCount ?? 0,
      hasSeenFlashcard: true,
      lastReviewedAt: now,
      nextReviewAt: nextReviewAt,
      isFavorite: existing?.isFavorite ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.set(progress.toFirestore(), SetOptions(merge: true));
    return progress;
  }

  Future<SystemVocabularyProgress> toggleFavorite({
    required String uid,
    required String setId,
    required String wordId,
    required bool isFavorite,
  }) async {
    final ref = _progressRef(uid, setId, wordId);
    final snapshot = await ref.get();
    final existing =
        snapshot.exists
            ? SystemVocabularyProgress.fromFirestore(snapshot)
            : null;
    final now = DateTime.now();
    final progress = SystemVocabularyProgress(
      id: progressId(setId: setId, wordId: wordId),
      userId: uid,
      setId: setId,
      wordId: wordId,
      learningLevel: existing?.learningLevel ?? 'unknown',
      correctCount: existing?.correctCount ?? 0,
      wrongCount: existing?.wrongCount ?? 0,
      hasSeenFlashcard: existing?.hasSeenFlashcard ?? false,
      lastReviewedAt: existing?.lastReviewedAt,
      nextReviewAt: existing?.nextReviewAt,
      isFavorite: isFavorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.set(progress.toFirestore(), SetOptions(merge: true));
    return progress;
  }

  static String progressId({required String setId, required String wordId}) {
    return '${setId}_$wordId';
  }

  DocumentReference<Map<String, dynamic>> _setRef(String setId) {
    return _firestore.collection('systemVocabularySets').doc(setId);
  }

  CollectionReference<Map<String, dynamic>> _userProgressCollection(
    String uid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('systemVocabularyProgress');
  }

  DocumentReference<Map<String, dynamic>> _progressRef(
    String uid,
    String setId,
    String wordId,
  ) {
    return _userProgressCollection(
      uid,
    ).doc(progressId(setId: setId, wordId: wordId));
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  int _compareReviewProgress(
    SystemVocabularyProgress a,
    SystemVocabularyProgress b,
  ) {
    final wrongCompare = b.wrongCount.compareTo(a.wrongCount);
    if (wrongCompare != 0) return wrongCompare;

    final aDue = a.nextReviewAt;
    final bDue = b.nextReviewAt;
    if (aDue != null && bDue != null) {
      final dueCompare = aDue.compareTo(bDue);
      if (dueCompare != 0) return dueCompare;
    }

    final levelCompare = _reviewLevelPriority(
      a.learningLevel,
    ).compareTo(_reviewLevelPriority(b.learningLevel));
    if (levelCompare != 0) return levelCompare;

    return a.wordId.compareTo(b.wordId);
  }

  int _reviewLevelPriority(String learningLevel) {
    return switch (learningLevel.trim().toLowerCase()) {
      'unknown' => 0,
      'temporary' => 1,
      'mastered' => 2,
      _ => 3,
    };
  }

  String _normalizeLearningLevel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'mastered' || normalized == 'temporary') {
      return normalized!;
    }
    return 'unknown';
  }
}
