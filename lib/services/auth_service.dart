import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import 'firebase_app_service.dart';
import 'firestore_service.dart';

class AuthService {
  AuthService({required FirestoreService firestore}) : _firestore = firestore;

  final FirestoreService _firestore;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Future<AppUser?> currentUser() async {
    if (!FirebaseAppService.isReady) return null;

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    await firebaseUser.reload();
    final reloadedUser = _auth.currentUser;
    if (reloadedUser == null) return null;

    final provider = _providerFor(reloadedUser);
    final verified = provider == 'google' || reloadedUser.emailVerified;
    final firestoreUser = await _firestore.getUser(reloadedUser.uid);
    if (firestoreUser != null) {
      final updated = firestoreUser.copyWith(
        name:
            (reloadedUser.displayName ?? '').trim().isNotEmpty
                ? reloadedUser.displayName
                : firestoreUser.name,
        email:
            (reloadedUser.email ?? '').trim().isNotEmpty
                ? reloadedUser.email
                : firestoreUser.email,
        provider: provider,
        emailVerified: verified,
        photoUrl: reloadedUser.photoURL ?? firestoreUser.photoUrl,
        updatedAt: DateTime.now(),
      );
      await _firestore.saveUser(updated);
      return updated;
    }

    final now = DateTime.now();
    final user = AppUser(
      uid: reloadedUser.uid,
      name: reloadedUser.displayName ?? 'Learner',
      email: reloadedUser.email ?? '',
      provider: provider,
      emailVerified: verified,
      photoUrl: reloadedUser.photoURL ?? '',
      createdAt: now,
      updatedAt: now,
    );
    await _firestore.saveUser(user);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    return loginWithEmail(email: email, password: password);
  }

  Future<AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!FirebaseAppService.isReady) {
      throw Exception(
        'Firebase is not ready. Please configure Firebase first.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Cannot sign in. Please try again.');
      }
      await firebaseUser.reload();
      final reloadedUser = _auth.currentUser ?? firebaseUser;
      final existing = await _firestore.getUser(reloadedUser.uid);
      final now = DateTime.now();
      final user = (existing ?? _userFromFirebase(reloadedUser)).copyWith(
        name:
            (reloadedUser.displayName ?? '').trim().isNotEmpty
                ? reloadedUser.displayName
                : existing?.name ?? 'Learner',
        email: reloadedUser.email ?? email,
        provider: 'password',
        emailVerified: reloadedUser.emailVerified,
        photoUrl: reloadedUser.photoURL ?? existing?.photoUrl ?? '',
        updatedAt: now,
      );
      await _firestore.saveUser(user);
      return user;
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyFirebaseAuthError(error));
    }
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return registerWithEmail(name: name, email: email, password: password);
  }

  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!FirebaseAppService.isReady) {
      throw Exception(
        'Firebase is not ready. Please configure Firebase first.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Cannot create account. Please try again.');
      }
      await firebaseUser.updateDisplayName(name);
      await firebaseUser.sendEmailVerification();
      final now = DateTime.now();
      final user = AppUser(
        uid: firebaseUser.uid,
        name: name,
        email: email,
        provider: 'password',
        emailVerified: false,
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: now,
        updatedAt: now,
      );
      await _firestore.saveUser(user);
      return user;
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyFirebaseAuthError(error));
    }
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please login before verifying your email.');
    }
    await user.reload();
    final reloadedUser = _auth.currentUser ?? user;
    if (reloadedUser.emailVerified) return;
    await reloadedUser.sendEmailVerification();
  }

  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final reloadedUser = _auth.currentUser;
    final isVerified = reloadedUser?.emailVerified ?? false;
    if (reloadedUser != null) {
      final existing = await _firestore.getUser(reloadedUser.uid);
      final updated = (existing ?? _userFromFirebase(reloadedUser)).copyWith(
        emailVerified: isVerified,
        provider: _providerFor(reloadedUser),
        updatedAt: DateTime.now(),
      );
      await _firestore.saveUser(updated);
    }
    return isVerified;
  }

  Future<AppUser> signInWithGoogle() async {
    if (!FirebaseAppService.isReady) {
      throw Exception(
        'Firebase is not ready. Please configure Firebase first.',
      );
    }

    try {
      await _initializeGoogleSignIn();
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email'],
      );
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Cannot sign in with Google. Please try again.');
      }

      final existing = await _firestore.getUser(firebaseUser.uid);
      final now = DateTime.now();
      final user = AppUser(
        uid: firebaseUser.uid,
        name:
            firebaseUser.displayName ??
            googleUser.displayName ??
            existing?.name ??
            'Learner',
        email: firebaseUser.email ?? googleUser.email,
        provider: 'google',
        emailVerified: true,
        photoUrl: firebaseUser.photoURL ?? googleUser.photoUrl ?? '',
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _firestore.saveUser(user);
      return user;
    } on GoogleSignInException catch (error) {
      throw Exception(_friendlyGoogleSignInError(error));
    } on FirebaseAuthException catch (error) {
      throw Exception(_friendlyFirebaseAuthError(error));
    }
  }

  Future<void> logout() async {
    if (FirebaseAppService.isReady) {
      await _auth.signOut();
    }
    await _initializeGoogleSignIn();
    await _googleSignIn.signOut();
  }

  String _friendlyFirebaseAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Email is not valid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found with this email.',
      'wrong-password' => 'Password is incorrect.',
      'email-already-in-use' => 'This email is already registered.',
      'weak-password' => 'Password is too weak.',
      'network-request-failed' => 'Network error. Please try again.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    const dartDefineServerClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
    );
    final envServerClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    final serverClientId =
        dartDefineServerClientId.trim().isNotEmpty
            ? dartDefineServerClientId.trim()
            : envServerClientId.trim();

    if (defaultTargetPlatform == TargetPlatform.android &&
        serverClientId.isEmpty) {
      throw Exception(
        'Google Sign-In needs GOOGLE_WEB_CLIENT_ID on Android. Enable Google provider in Firebase, add SHA-1/SHA-256, download the new google-services.json, then add the Web client ID to .env.',
      );
    }

    await _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleInitialized = true;
  }

  AppUser _userFromFirebase(User firebaseUser) {
    final now = DateTime.now();
    final provider = _providerFor(firebaseUser);
    return AppUser(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? 'Learner',
      email: firebaseUser.email ?? '',
      provider: provider,
      emailVerified: provider == 'google' || firebaseUser.emailVerified,
      photoUrl: firebaseUser.photoURL ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }

  String _providerFor(User user) {
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.contains('google.com')) return 'google';
    return 'password';
  }

  String _friendlyGoogleSignInError(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable on this device.',
      _ =>
        error.description ??
            'Google sign-in failed. Please check Firebase SHA-1/SHA-256 config.',
    };
  }
}
