import 'package:cloud_firestore/cloud_firestore.dart';

class LearningActivityService {
  LearningActivityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> recordVocabularyReview({
    required String uid,
    int reviewedWords = 1,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) {
    return _incrementTodayActivity(
      uid: uid,
      increments: {
        'reviewedWords': reviewedWords,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
      },
    );
  }

  Future<void> recordWordLearned({required String uid, int learnedWords = 1}) {
    return _incrementTodayActivity(
      uid: uid,
      increments: {'learnedWords': learnedWords},
    );
  }

  Future<void> recordQuizCompleted({required String uid}) {
    return _incrementTodayActivity(uid: uid, increments: {'quizCompleted': 1});
  }

  Future<void> recordDictationCompleted({required String uid}) {
    return _incrementTodayActivity(
      uid: uid,
      increments: {'dictationCompleted': 1},
    );
  }

  Future<int> calculateCurrentStreak(String uid) async {
    final dates = await _activityDates(uid);
    if (dates.isEmpty) return 0;

    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime cursor;

    if (dates.contains(today)) {
      cursor = today;
    } else if (dates.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    var streak = 0;
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> calculateLongestStreak(String uid) async {
    final sortedDates = (await _activityDates(uid)).toList()..sort();
    if (sortedDates.isEmpty) return 0;

    var longest = 1;
    var current = 1;
    for (var index = 1; index < sortedDates.length; index++) {
      final previous = sortedDates[index - 1];
      final currentDate = sortedDates[index];
      final expected = previous.add(const Duration(days: 1));

      if (_isSameDate(currentDate, expected)) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
    }
    return longest;
  }

  Future<int> countLearningDays(String uid) async {
    if (uid.trim().isEmpty) return 0;
    final snapshot = await _activityRef(uid).get();
    return snapshot.docs.length;
  }

  Future<Map<String, dynamic>> getActivityForDate({
    required String uid,
    DateTime? date,
  }) async {
    if (uid.trim().isEmpty) return const {};
    final dateId = formatDateId(date ?? DateTime.now());
    final doc = await _activityRef(uid).doc(dateId).get();
    return doc.data() ?? const {};
  }

  Future<void> _incrementTodayActivity({
    required String uid,
    required Map<String, int> increments,
  }) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before recording learning activity.');
    }

    final now = DateTime.now();
    final dateId = formatDateId(now);
    final docRef = _activityRef(uid).doc(dateId);
    final existing = await docRef.get();
    final data = <String, dynamic>{
      'id': dateId,
      'userId': uid,
      'date': dateId,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (!existing.exists) {
      data.addAll({
        'learnedWords': 0,
        'reviewedWords': 0,
        'quizCompleted': 0,
        'dictationCompleted': 0,
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'createdAt': Timestamp.fromDate(now),
      });
    }

    for (final entry in increments.entries) {
      if (entry.value == 0) continue;
      data[entry.key] = FieldValue.increment(entry.value);
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<Set<DateTime>> _activityDates(String uid) async {
    if (uid.trim().isEmpty) return const {};
    final snapshot = await _activityRef(uid).get();
    return snapshot.docs
        .map((doc) => _parseDateId(doc.data()['date'] as String? ?? doc.id))
        .whereType<DateTime>()
        .map(_dateOnly)
        .toSet();
  }

  CollectionReference<Map<String, dynamic>> _activityRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learningActivity');
  }

  static String formatDateId(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime? _parseDateId(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
