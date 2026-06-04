import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_app_service.dart';

class StorageService {
  FirebaseStorage get _storage => FirebaseStorage.instance;

  Future<String?> uploadVocabularyImage({
    required String userId,
    required String vocabularyId,
    required String imagePath,
  }) async {
    if (!FirebaseAppService.isReady || imagePath.isEmpty) return null;
    final file = File(imagePath);
    if (!file.existsSync()) return null;

    final ref = _storage.ref('users/$userId/vocabulary/$vocabularyId.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
