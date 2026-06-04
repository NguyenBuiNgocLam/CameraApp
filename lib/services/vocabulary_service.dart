import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/vocabulary_item.dart';
import '../features/vocabulary/services/word_list_service.dart';
import 'firebase_app_service.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class VocabularyService {
  VocabularyService({
    required FirestoreService firestore,
    required StorageService storage,
    WordListService? wordListService,
  }) : _firestore = firestore,
       _storage = storage,
       _wordListService = wordListService;

  final FirestoreService _firestore;
  final StorageService _storage;
  final WordListService? _wordListService;
  static const _uuid = Uuid();

  WordListService get _lists => _wordListService ?? WordListService();

  String _currentUserId() {
    if (!FirebaseAppService.isReady) {
      throw Exception(
        'Firebase is not ready. Please configure Firebase first.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Please login before using vocabulary.');
    }
    return uid;
  }

  Future<List<VocabularyItem>> loadVocabulary() async {
    final userId = _currentUserId();
    return _firestore.getVocabulary(userId);
  }

  Future<List<VocabularyItem>> getVocabularyList() => loadVocabulary();

  Future<bool> checkWordExists(String word) async {
    final normalized = word.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final userId = _currentUserId();
    final vocabulary = await _firestore.getVocabulary(userId);
    return vocabulary.any(
      (item) => item.word.trim().toLowerCase() == normalized,
    );
  }

  Future<VocabularyItem> addVocabulary(
    VocabularyItem item, {
    bool allowDuplicate = false,
  }) async {
    if (!allowDuplicate) {
      return saveVocabulary(item);
    }

    final userId = _currentUserId();
    final now = DateTime.now();
    var itemToSave = item.copyWith(
      id: item.id.isEmpty ? _uuid.v4() : item.id,
      userId: userId,
      listId: await _resolveListId(userId, item.listId),
      createdAt: item.createdAt,
      updatedAt: now,
    );

    var imageUrl = itemToSave.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      try {
        imageUrl = await _storage.uploadVocabularyImage(
          userId: itemToSave.userId,
          vocabularyId: itemToSave.id,
          imagePath: itemToSave.imagePath ?? '',
        );
      } catch (_) {
        imageUrl = null;
      }
    }

    itemToSave = itemToSave.copyWith(imageUrl: imageUrl);
    await _firestore.saveVocabulary(itemToSave);
    await _lists.updateWordCount(uid: userId, listId: itemToSave.listId);
    return itemToSave;
  }

  Future<List<VocabularyItem>> addManyVocabulary(
    List<VocabularyItem> items,
  ) async {
    if (items.isEmpty) return [];

    final userId = _currentUserId();
    final defaultList = await _lists.getOrCreateDefaultList(userId);
    final existingWords =
        (await _firestore.getVocabulary(
          userId,
        )).map((item) => item.word.trim().toLowerCase()).toSet();
    final savedItems = <VocabularyItem>[];
    final now = DateTime.now();

    for (final item in items) {
      final normalized = item.word.trim().toLowerCase();
      if (normalized.isEmpty || existingWords.contains(normalized)) {
        continue;
      }

      final itemToSave = item.copyWith(
        id: item.id.isEmpty ? _uuid.v4() : item.id,
        userId: userId,
        listId:
            item.listId.trim().isEmpty || item.listId == 'default'
                ? defaultList.id
                : item.listId,
        createdAt: item.createdAt,
        updatedAt: now,
      );
      await _firestore.saveVocabulary(itemToSave);
      savedItems.add(itemToSave);
      existingWords.add(normalized);
    }

    final changedListIds = savedItems.map((item) => item.listId).toSet();
    for (final listId in changedListIds) {
      await _lists.updateWordCount(uid: userId, listId: listId);
    }

    return savedItems;
  }

  Future<VocabularyItem> saveVocabulary(VocabularyItem item) async {
    final userId = _currentUserId();
    final listId = await _resolveListId(userId, item.listId);

    VocabularyItem? existing;
    for (final value in await _firestore.getVocabulary(userId)) {
      if (value.word.toLowerCase() == item.word.toLowerCase()) {
        existing = value;
        break;
      }
    }

    final now = DateTime.now();
    var itemToSave = (existing ?? item).copyWith(
      id: existing?.id ?? (item.id.isEmpty ? _uuid.v4() : item.id),
      userId: userId,
      listId: existing?.listId ?? listId,
      isFavorite: existing?.isFavorite ?? item.isFavorite,
      updatedAt: now,
      createdAt: existing?.createdAt ?? item.createdAt,
    );

    var imageUrl = itemToSave.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      try {
        imageUrl = await _storage.uploadVocabularyImage(
          userId: itemToSave.userId,
          vocabularyId: itemToSave.id,
          imagePath: itemToSave.imagePath ?? '',
        );
      } catch (_) {
        imageUrl = null;
      }
    }

    itemToSave = itemToSave.copyWith(imageUrl: imageUrl);
    await _firestore.saveVocabulary(itemToSave);
    await _lists.updateWordCount(uid: userId, listId: itemToSave.listId);
    return itemToSave;
  }

  Future<VocabularyItem> toggleFavorite(VocabularyItem item) async {
    final userId = _currentUserId();
    final updated = item.copyWith(
      userId: userId,
      isFavorite: !item.isFavorite,
      updatedAt: DateTime.now(),
    );
    await _firestore.saveVocabulary(updated);
    return updated;
  }

  Future<void> deleteVocabulary(VocabularyItem item) async {
    final userId = _currentUserId();
    await _firestore.deleteVocabulary(userId, item.id);
    await _lists.updateWordCount(uid: userId, listId: item.listId);
  }

  Future<String> _resolveListId(String userId, String listId) async {
    if (listId.trim().isNotEmpty && listId != 'default') return listId;
    final defaultList = await _lists.getOrCreateDefaultList(userId);
    return defaultList.id;
  }
}
