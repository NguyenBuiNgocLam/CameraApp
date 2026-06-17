import 'package:flutter/foundation.dart';

import '../features/activity/services/learning_activity_service.dart';
import '../features/vocabulary/models/vocabulary_filter.dart';
import '../models/vocabulary_item.dart';
import '../services/ai_dictionary_service.dart';
import '../services/tts_service.dart';
import '../services/vocabulary_service.dart';

class VocabularyProvider extends ChangeNotifier {
  VocabularyProvider({
    required VocabularyService vocabularyService,
    required AiDictionaryService aiDictionaryService,
    required TtsService ttsService,
    LearningActivityService? activityService,
  }) : _vocabularyService = vocabularyService,
       _aiDictionaryService = aiDictionaryService,
       _ttsService = ttsService,
       _activityService = activityService ?? LearningActivityService();

  final VocabularyService _vocabularyService;
  final AiDictionaryService _aiDictionaryService;
  final TtsService _ttsService;
  final LearningActivityService _activityService;

  List<VocabularyItem> items = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String searchQuery = '';
  VocabularyFilter selectedFilter = VocabularyFilter.all;
  VocabularySort selectedSort = VocabularySort.newest;

  int get totalWords => items.length;
  int get favoriteWords => items.where((item) => item.isFavorite).length;
  List<VocabularyItem> get filteredVocabulary => _applyFilters(items);

  List<VocabularyItem> filteredVocabularyForList(String listId) {
    return _applyFilters(items.where((item) => item.listId == listId).toList());
  }

  void updateSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void updateFilter(VocabularyFilter filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  void updateSort(VocabularySort sort) {
    selectedSort = sort;
    notifyListeners();
  }

  void clearFilters() {
    searchQuery = '';
    selectedFilter = VocabularyFilter.all;
    selectedSort = VocabularySort.newest;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _vocabularyService.loadVocabulary();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshVocabulary() => load();

  Future<bool> save(VocabularyItem item) async {
    isLoading = true;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final isNewWord =
          !items.any(
            (value) =>
                value.id == item.id ||
                value.word.trim().toLowerCase() ==
                    item.word.trim().toLowerCase(),
          );
      final saved = await _vocabularyService.saveVocabulary(item);
      items = [saved, ...items.where((value) => value.id != saved.id)];
      if (isNewWord) {
        await _recordWordLearned(uid: saved.userId);
      }
      isLoading = false;
      isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<VocabularyItem?> lookupWordWithAI({
    required String word,
    String sourceContext = '',
  }) async {
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      errorMessage = 'Please enter an English word or phrase.';
      notifyListeners();
      return null;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _aiDictionaryService.lookupWord(
        word: trimmedWord,
        sourceContext: sourceContext,
      );
      isLoading = false;
      notifyListeners();
      return result;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkWordExists(String word) async {
    try {
      return await _vocabularyService.checkWordExists(word);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> addManualVocabulary(
    VocabularyItem item, {
    bool allowDuplicate = false,
  }) async {
    final trimmedWord = item.word.trim();
    if (trimmedWord.isEmpty) {
      errorMessage = 'Please enter an English word or phrase.';
      notifyListeners();
      return false;
    }
    if (item.meaningVi.trim().isEmpty) {
      errorMessage = 'Please enter Vietnamese meaning.';
      notifyListeners();
      return false;
    }
    if ((item.imageUrl ?? '').isNotEmpty &&
        !item.imageUrl!.trim().startsWith('https://')) {
      errorMessage = 'Image URL must start with https://';
      notifyListeners();
      return false;
    }
    if (!allowDuplicate &&
        await _vocabularyService.checkWordExists(item.word)) {
      errorMessage = 'This word already exists.';
      notifyListeners();
      return false;
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _vocabularyService.addVocabulary(
        item,
        allowDuplicate: allowDuplicate,
      );
      items = [saved, ...items.where((value) => value.id != saved.id)];
      await _recordWordLearned(uid: saved.userId);
      isSaving = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<int> addManyVocabulary(List<VocabularyItem> vocabularyItems) async {
    if (vocabularyItems.isEmpty) return 0;

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final saved = await _vocabularyService.addManyVocabulary(vocabularyItems);
      items = [
        ...saved,
        ...items.where(
          (item) => !saved.any((savedItem) => savedItem.id == item.id),
        ),
      ];
      if (saved.isNotEmpty) {
        await _recordWordLearned(uid: saved.first.userId, count: saved.length);
      }
      isSaving = false;
      notifyListeners();
      return saved.length;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isSaving = false;
      notifyListeners();
      return 0;
    }
  }

  Future<int> importVocabularyFromCsv(List<VocabularyItem> vocabularyItems) {
    return addManyVocabulary(vocabularyItems);
  }

  Future<void> toggleFavorite(VocabularyItem item) async {
    try {
      final updated = await _vocabularyService.toggleFavorite(item);
      items =
          items
              .map((value) => value.id == updated.id ? updated : value)
              .toList();
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> delete(VocabularyItem item) async {
    try {
      await _vocabularyService.deleteVocabulary(item);
      items = items.where((value) => value.id != item.id).toList();
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> speak(String text) => _ttsService.speak(text);

  List<VocabularyItem> _applyFilters(List<VocabularyItem> source) {
    final query = searchQuery.trim().toLowerCase();
    var result = List<VocabularyItem>.from(source);

    if (query.isNotEmpty) {
      result =
          result.where((item) {
            final searchable =
                [
                  item.word,
                  item.meaningVi,
                  item.phonetic,
                  item.partOfSpeech,
                  item.exampleEn,
                  item.exampleVi,
                  item.sourceContext,
                ].join(' ').toLowerCase();
            return searchable.contains(query);
          }).toList();
    }

    result = result.where(_matchesSelectedFilter).toList();
    result.sort(_compareBySelectedSort);
    return result;
  }

  bool _matchesSelectedFilter(VocabularyItem item) {
    final level = item.learningLevel.trim().toLowerCase();
    final partOfSpeech = item.partOfSpeech.trim().toLowerCase();
    final learned = item.hasSeenFlashcard || item.lastReviewedAt != null;
    final isDueToday =
        learned &&
        item.nextReviewAt != null &&
        !item.nextReviewAt!.isAfter(_endOfToday());

    return switch (selectedFilter) {
      VocabularyFilter.all => true,
      VocabularyFilter.favorite => item.isFavorite,
      VocabularyFilter.unknown => level.isEmpty || level == 'unknown',
      VocabularyFilter.temporary => level == 'temporary',
      VocabularyFilter.mastered => level == 'mastered',
      VocabularyFilter.todayReview => isDueToday,
      VocabularyFilter.mostWrong => item.wrongCount > 0,
      VocabularyFilter.noun => partOfSpeech.contains('noun'),
      VocabularyFilter.verb => partOfSpeech.contains('verb'),
      VocabularyFilter.adjective => partOfSpeech.contains('adjective'),
      VocabularyFilter.adverb => partOfSpeech.contains('adverb'),
      VocabularyFilter.phrase => partOfSpeech.contains('phrase'),
    };
  }

  int _compareBySelectedSort(VocabularyItem a, VocabularyItem b) {
    return switch (selectedSort) {
      VocabularySort.newest => b.createdAt.compareTo(a.createdAt),
      VocabularySort.oldest => a.createdAt.compareTo(b.createdAt),
      VocabularySort.az => a.word.toLowerCase().compareTo(b.word.toLowerCase()),
      VocabularySort.za => b.word.toLowerCase().compareTo(a.word.toLowerCase()),
      VocabularySort.mostWrong => b.wrongCount.compareTo(a.wrongCount),
      VocabularySort.mostCorrect => b.correctCount.compareTo(a.correctCount),
      VocabularySort.reviewSoonest => _compareReviewDate(a, b),
    };
  }

  int _compareReviewDate(VocabularyItem a, VocabularyItem b) {
    final aDate = a.nextReviewAt;
    final bDate = b.nextReviewAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return aDate.compareTo(bDate);
  }

  Future<void> _recordWordLearned({required String uid, int count = 1}) async {
    try {
      await _activityService.recordWordLearned(uid: uid, learnedWords: count);
    } catch (_) {}
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }
}
