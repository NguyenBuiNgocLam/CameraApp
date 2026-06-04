import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/word_list.dart';
import '../services/word_list_service.dart';

class WordListProvider extends ChangeNotifier {
  WordListProvider({required WordListService wordListService})
    : _wordListService = wordListService;

  final WordListService _wordListService;

  bool isLoading = false;
  String? errorMessage;
  List<WordList> wordLists = [];
  WordList? selectedList;

  Future<void> loadWordLists() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uid = _currentUserId();
      wordLists = await _wordListService.getWordLists(uid);
      selectedList ??= wordLists.firstOrNull;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> createList(String name, String description) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uid = _currentUserId();
      final list = await _wordListService.createWordList(
        uid: uid,
        name: name,
        description: description,
      );
      wordLists = [...wordLists, list];
      selectedList = list;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void selectList(WordList list) {
    selectedList = list;
    notifyListeners();
  }

  Future<bool> updateList({
    required WordList list,
    required String name,
    required String description,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final updated = list.copyWith(
        name: name.trim(),
        description: description.trim(),
        updatedAt: DateTime.now(),
      );
      await _wordListService.updateWordList(
        uid: _currentUserId(),
        list: updated,
      );
      wordLists =
          wordLists
              .map((value) => value.id == updated.id ? updated : value)
              .toList();
      if (selectedList?.id == updated.id) {
        selectedList = updated;
      }
      isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(WordList list) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _wordListService.deleteWordList(
        uid: _currentUserId(),
        listId: list.id,
      );
      wordLists = wordLists.where((value) => value.id != list.id).toList();
      if (selectedList?.id == list.id) {
        selectedList = wordLists.firstOrNull;
      }
      isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshWordCount() async {
    try {
      final uid = _currentUserId();
      for (final list in wordLists) {
        await _wordListService.updateWordCount(uid: uid, listId: list.id);
      }
      wordLists = await _wordListService.getWordLists(uid);
      if (selectedList != null && wordLists.isNotEmpty) {
        selectedList = wordLists.firstWhere(
          (list) => list.id == selectedList!.id,
          orElse: () => wordLists.first,
        );
      } else if (wordLists.isEmpty) {
        selectedList = null;
      }
      errorMessage = null;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<WordList?> getOrCreateDefaultList() async {
    try {
      final uid = _currentUserId();
      final list = await _wordListService.getOrCreateDefaultList(uid);
      if (!wordLists.any((value) => value.id == list.id)) {
        wordLists = [list, ...wordLists];
      }
      selectedList ??= list;
      notifyListeners();
      return list;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  String _currentUserId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please login before using word lists.');
    }
    return uid;
  }
}
