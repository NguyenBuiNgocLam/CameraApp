enum VocabularyFilter {
  all,
  favorite,
  unknown,
  temporary,
  mastered,
  todayReview,
  mostWrong,
  noun,
  verb,
  adjective,
  adverb,
  phrase,
}

enum VocabularySort {
  newest,
  oldest,
  az,
  za,
  mostWrong,
  mostCorrect,
  reviewSoonest,
}

extension VocabularyFilterLabel on VocabularyFilter {
  String get label {
    return switch (this) {
      VocabularyFilter.all => 'All',
      VocabularyFilter.favorite => 'Favorites',
      VocabularyFilter.unknown => 'Unknown',
      VocabularyFilter.temporary => 'Learning',
      VocabularyFilter.mastered => 'Mastered',
      VocabularyFilter.todayReview => 'Review today',
      VocabularyFilter.mostWrong => 'Most wrong',
      VocabularyFilter.noun => 'Noun',
      VocabularyFilter.verb => 'Verb',
      VocabularyFilter.adjective => 'Adjective',
      VocabularyFilter.adverb => 'Adverb',
      VocabularyFilter.phrase => 'Phrase',
    };
  }
}

extension VocabularySortLabel on VocabularySort {
  String get label {
    return switch (this) {
      VocabularySort.newest => 'Newest',
      VocabularySort.oldest => 'Oldest',
      VocabularySort.az => 'A-Z',
      VocabularySort.za => 'Z-A',
      VocabularySort.mostWrong => 'Most Wrong',
      VocabularySort.mostCorrect => 'Most Correct',
      VocabularySort.reviewSoonest => 'Review Soonest',
    };
  }
}
