import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/word_list.dart';

class WordListService {
  WordListService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();
  static const defaultListName = 'My Words';

  Future<List<WordList>> getWordLists(String uid) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before using word lists.');
    }

    var snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('wordLists')
            .orderBy('createdAt', descending: false)
            .get();

    if (snapshot.docs.isEmpty) {
      await getOrCreateDefaultList(uid);
      snapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('wordLists')
              .orderBy('createdAt', descending: false)
              .get();
    }

    return snapshot.docs.map(WordList.fromFirestore).toList();
  }

  Future<WordList> createWordList({
    required String uid,
    required String name,
    String description = '',
  }) async {
    final trimmedName = name.trim();
    if (uid.trim().isEmpty) {
      throw Exception('Please login before creating a word list.');
    }
    if (trimmedName.isEmpty) {
      throw Exception('Please enter a list name.');
    }

    final existing = await getWordLists(uid);
    final duplicate = existing.any(
      (list) => list.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (duplicate) {
      throw Exception('This word list already exists.');
    }

    final now = DateTime.now();
    final list = WordList(
      id: _uuid.v4(),
      userId: uid,
      name: trimmedName,
      description: description.trim(),
      wordCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _listRef(uid, list.id).set(list.toFirestore());
    return list;
  }

  Future<void> updateWordList({
    required String uid,
    required WordList list,
  }) async {
    final trimmedName = list.name.trim();
    if (uid.trim().isEmpty || list.id.trim().isEmpty) {
      throw Exception('Cannot update this word list.');
    }
    if (trimmedName.isEmpty) {
      throw Exception('Please enter a list name.');
    }

    final existing = await getWordLists(uid);
    final duplicate = existing.any(
      (value) =>
          value.id != list.id &&
          value.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (duplicate) {
      throw Exception('This word list already exists.');
    }

    await _listRef(uid, list.id).set(
      list.copyWith(name: trimmedName, updatedAt: DateTime.now()).toFirestore(),
    );
  }

  Future<void> deleteWordList({
    required String uid,
    required String listId,
  }) async {
    if (uid.trim().isEmpty || listId.trim().isEmpty) {
      throw Exception('Cannot delete this word list.');
    }

    final words =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('vocabulary')
            .where('listId', isEqualTo: listId)
            .limit(1)
            .get();
    if (words.docs.isNotEmpty) {
      throw Exception('Cannot delete a list that still has words.');
    }

    await _listRef(uid, listId).delete();
  }

  Future<void> updateWordCount({
    required String uid,
    required String listId,
  }) async {
    if (uid.trim().isEmpty || listId.trim().isEmpty) return;

    final words =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('vocabulary')
            .where('listId', isEqualTo: listId)
            .get();

    await _listRef(uid, listId).set({
      'wordCount': words.docs.length,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<WordList> getOrCreateDefaultList(String uid) async {
    if (uid.trim().isEmpty) {
      throw Exception('Please login before using word lists.');
    }

    final snapshot =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('wordLists')
            .where('name', isEqualTo: defaultListName)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      final list = WordList.fromFirestore(snapshot.docs.first);
      await _assignLegacyWordsToDefault(uid, list.id);
      await updateWordCount(uid: uid, listId: list.id);
      final updatedDoc = await _listRef(uid, list.id).get();
      return updatedDoc.exists ? WordList.fromFirestore(updatedDoc) : list;
    }

    final now = DateTime.now();
    final list = WordList(
      id: 'default',
      userId: uid,
      name: defaultListName,
      description: 'Default vocabulary list',
      wordCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _listRef(
      uid,
      list.id,
    ).set(list.toFirestore(), SetOptions(merge: true));
    await _assignLegacyWordsToDefault(uid, list.id);
    await updateWordCount(uid: uid, listId: list.id);
    final updatedDoc = await _listRef(uid, list.id).get();
    return updatedDoc.exists ? WordList.fromFirestore(updatedDoc) : list;
  }

  Future<void> _assignLegacyWordsToDefault(
    String uid,
    String defaultListId,
  ) async {
    final legacyWords =
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('vocabulary')
            .where('listId', isNull: true)
            .get();

    if (legacyWords.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in legacyWords.docs) {
      batch.update(doc.reference, {
        'listId': defaultListId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> _listRef(String uid, String listId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('wordLists')
        .doc(listId);
  }
}
