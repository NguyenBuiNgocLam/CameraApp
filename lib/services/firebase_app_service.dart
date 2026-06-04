import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseAppService {
  const FirebaseAppService._();

  static bool _isReady = false;

  static bool get isReady => _isReady;

  static Future<bool> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      _isReady = true;
      return true;
    }

    try {
      await Firebase.initializeApp();
      _isReady = true;
      return true;
    } catch (_) {
      final options = _optionsFromEnv();
      if (options == null) {
        _isReady = false;
        return false;
      }
      try {
        await Firebase.initializeApp(options: options);
        _isReady = true;
        return true;
      } catch (_) {
        _isReady = false;
        return false;
      }
    }
  }

  static FirebaseOptions? _optionsFromEnv() {
    final apiKey = dotenv.maybeGet('FIREBASE_API_KEY');
    final appId = dotenv.maybeGet('FIREBASE_APP_ID');
    final messagingSenderId = dotenv.maybeGet('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = dotenv.maybeGet('FIREBASE_PROJECT_ID');
    final storageBucket = dotenv.maybeGet('FIREBASE_STORAGE_BUCKET');

    if ([
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].any((value) => value == null || value.isEmpty)) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey!,
      appId: appId!,
      messagingSenderId: messagingSenderId!,
      projectId: projectId!,
      storageBucket: storageBucket,
    );
  }
}
