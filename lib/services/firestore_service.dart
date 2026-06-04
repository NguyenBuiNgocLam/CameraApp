import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/quiz_models.dart';
import '../models/vocabulary_item.dart';
import 'firebase_app_service.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get isReady => FirebaseAppService.isReady;

  Future<void> saveUser(AppUser user) async {
    if (!isReady) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    if (!isReady) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> saveVocabulary(VocabularyItem item) async {
    if (!isReady || item.userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(item.userId)
        .collection('vocabulary')
        .doc(item.id)
        .set(item.toFirestore());
  }

  Future<List<VocabularyItem>> getVocabulary(String userId) async {
    if (!isReady || userId.isEmpty) return [];
    final snapshot =
        await _db
            .collection('users')
            .doc(userId)
            .collection('vocabulary')
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs.map(VocabularyItem.fromFirestore).toList();
  }

  Future<void> deleteVocabulary(String userId, String vocabularyId) async {
    if (!isReady || userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .collection('vocabulary')
        .doc(vocabularyId)
        .delete();
  }

  Future<void> saveQuizResult(QuizResult result) async {
    if (!isReady || result.userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(result.userId)
        .collection('quizResults')
        .doc(result.id)
        .set(result.toFirestore());
  }

  Future<List<QuizResult>> getQuizResults(String userId) async {
    if (!isReady || userId.isEmpty) return [];
    final snapshot =
        await _db
            .collection('users')
            .doc(userId)
            .collection('quizResults')
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs
        .map((doc) => QuizResult.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }
}
