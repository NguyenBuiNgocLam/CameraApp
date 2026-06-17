class DashboardStats {
  const DashboardStats({
    required this.totalWords,
    required this.favoriteWords,
    required this.masteredWords,
    required this.temporaryWords,
    required this.unknownWords,
    required this.todayReviewCount,
    required this.wordsLearnedToday,
    required this.reviewedWordsToday,
    required this.quizCompleted,
    required this.dictationSessions,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalLearningDays,
  });

  final int totalWords;
  final int favoriteWords;
  final int masteredWords;
  final int temporaryWords;
  final int unknownWords;
  final int todayReviewCount;
  final int wordsLearnedToday;
  final int reviewedWordsToday;
  final int quizCompleted;
  final int dictationSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalLearningDays;

  factory DashboardStats.empty() {
    return const DashboardStats(
      totalWords: 0,
      favoriteWords: 0,
      masteredWords: 0,
      temporaryWords: 0,
      unknownWords: 0,
      todayReviewCount: 0,
      wordsLearnedToday: 0,
      reviewedWordsToday: 0,
      quizCompleted: 0,
      dictationSessions: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalLearningDays: 0,
    );
  }

  DashboardStats copyWith({
    int? totalWords,
    int? favoriteWords,
    int? masteredWords,
    int? temporaryWords,
    int? unknownWords,
    int? todayReviewCount,
    int? wordsLearnedToday,
    int? reviewedWordsToday,
    int? quizCompleted,
    int? dictationSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalLearningDays,
  }) {
    return DashboardStats(
      totalWords: totalWords ?? this.totalWords,
      favoriteWords: favoriteWords ?? this.favoriteWords,
      masteredWords: masteredWords ?? this.masteredWords,
      temporaryWords: temporaryWords ?? this.temporaryWords,
      unknownWords: unknownWords ?? this.unknownWords,
      todayReviewCount: todayReviewCount ?? this.todayReviewCount,
      wordsLearnedToday: wordsLearnedToday ?? this.wordsLearnedToday,
      reviewedWordsToday: reviewedWordsToday ?? this.reviewedWordsToday,
      quizCompleted: quizCompleted ?? this.quizCompleted,
      dictationSessions: dictationSessions ?? this.dictationSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalLearningDays: totalLearningDays ?? this.totalLearningDays,
    );
  }
}
