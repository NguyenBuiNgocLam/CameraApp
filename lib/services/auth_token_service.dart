import 'package:firebase_auth/firebase_auth.dart';

class AuthTokenService {
  const AuthTokenService();

  Future<String?> getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  Future<String?> getFreshIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(true);
  }

  Future<String> requireIdToken() async {
    final token = await getIdToken();
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('User is not authenticated');
    }
    if (token == null || token.trim().isEmpty) {
      throw Exception('Unable to get authentication token');
    }
    return token;
  }
}
