import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dictation_segment.dart';
import '../models/dictation_session.dart';

class DictationFirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String userId) {
    return _db.collection('users').doc(userId).collection('dictationSessions');
  }

  CollectionReference<Map<String, dynamic>> _segmentsRef({
    required String userId,
    required String sessionId,
  }) {
    return _sessionsRef(userId).doc(sessionId).collection('segments');
  }

  Future<String> createSession({
    required String userId,
    required String youtubeUrl,
    required String videoTitle,
    required List<DictationSegment> segments,
  }) async {
    if (userId.isEmpty) throw Exception('Please login before saving progress.');
    if (segments.isEmpty) throw Exception('No transcript segments to save.');

    final sessionRef = _sessionsRef(userId).doc();
    final now = DateTime.now();
    final session = DictationSession(
      id: sessionRef.id,
      userId: userId,
      youtubeUrl: youtubeUrl,
      videoTitle: videoTitle,
      totalSegments: segments.length,
      currentSegmentIndex: 0,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(sessionRef, session.toFirestore());

    for (final segment in segments) {
      final segmentRef = _segmentsRef(
        userId: userId,
        sessionId: sessionRef.id,
      ).doc(segment.id);
      batch.set(segmentRef, segment.copyWith(updatedAt: now).toFirestore());
    }

    await batch.commit();
    return sessionRef.id;
  }

  Future<void> updateCurrentSegmentIndex({
    required String userId,
    required String sessionId,
    required int currentSegmentIndex,
  }) async {
    await _sessionsRef(userId).doc(sessionId).update({
      'currentSegmentIndex': currentSegmentIndex,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateSegmentInput({
    required String userId,
    required String sessionId,
    required DictationSegment segment,
  }) async {
    await _segmentsRef(userId: userId, sessionId: sessionId)
        .doc(segment.id)
        .set(
          segment.copyWith(updatedAt: DateTime.now()).toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<List<DictationSession>> getRecentSessions(String userId) async {
    if (userId.isEmpty) return [];
    final snapshot =
        await _sessionsRef(
          userId,
        ).orderBy('updatedAt', descending: true).limit(10).get();
    return snapshot.docs.map(DictationSession.fromFirestore).toList();
  }

  Future<List<DictationSegment>> getSessionSegments({
    required String userId,
    required String sessionId,
  }) async {
    final snapshot =
        await _segmentsRef(
          userId: userId,
          sessionId: sessionId,
        ).orderBy('index').get();
    return snapshot.docs.map(DictationSegment.fromFirestore).toList();
  }

  Future<void> deleteSession({
    required String userId,
    required String sessionId,
  }) async {
    final segmentsSnapshot =
        await _segmentsRef(userId: userId, sessionId: sessionId).get();
    var batch = _db.batch();
    var writes = 0;

    for (final doc in segmentsSnapshot.docs) {
      batch.delete(doc.reference);
      writes++;

      if (writes == 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }

    batch.delete(_sessionsRef(userId).doc(sessionId));
    await batch.commit();
  }
}
