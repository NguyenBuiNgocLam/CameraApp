class VocabularyOverviewStats {
  const VocabularyOverviewStats({
    required this.totalLearned,
    required this.mastered,
    required this.temporary,
    required this.unknown,
    required this.todayReviewCount,
    required this.wordsToday,
    required this.reviewedToday,
    required this.userVocabularyLearned,
    required this.systemVocabularyLearned,
    required this.userDueToday,
    required this.systemDueToday,
    required this.favoriteWords,
  });

  final int totalLearned;
  final int mastered;
  final int temporary;
  final int unknown;
  final int todayReviewCount;
  final int wordsToday;
  final int reviewedToday;
  final int userVocabularyLearned;
  final int systemVocabularyLearned;
  final int userDueToday;
  final int systemDueToday;
  final int favoriteWords;

  factory VocabularyOverviewStats.empty() {
    return const VocabularyOverviewStats(
      totalLearned: 0,
      mastered: 0,
      temporary: 0,
      unknown: 0,
      todayReviewCount: 0,
      wordsToday: 0,
      reviewedToday: 0,
      userVocabularyLearned: 0,
      systemVocabularyLearned: 0,
      userDueToday: 0,
      systemDueToday: 0,
      favoriteWords: 0,
    );
  }
}
