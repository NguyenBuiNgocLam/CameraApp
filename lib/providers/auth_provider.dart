import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService);

  final AuthService _authService;

  AppUser? user;
  bool isLoading = false;
  String? errorMessage;
  bool isEmailVerificationSent = false;
  bool isEmailVerified = false;
  bool isResetPasswordLoading = false;
  String? resetPasswordMessage;
  String? resetPasswordError;

  bool get isAuthenticated => user != null;
  bool get canEnterApp =>
      user != null && (user!.provider == 'google' || user!.emailVerified);

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    user = await _authService.currentUser();
    isEmailVerified = user?.emailVerified ?? false;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    return loginWithEmail(email: email, password: password);
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuth(
      () => _authService.loginWithEmail(email: email, password: password),
    );
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return registerWithEmail(name: name, email: email, password: password);
  }

  Future<bool> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    return _runAuth(
      () => _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
      ),
      emailVerificationSent: true,
    );
  }

  Future<bool> signInWithGoogle() async {
    return _runAuth(() => _authService.signInWithGoogle());
  }

  Future<bool> resendVerificationEmail() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.resendEmailVerification();
      isEmailVerificationSent = true;
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

  Future<bool> checkEmailVerification() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final verified = await _authService.checkEmailVerified();
      if (verified) {
        user = await _authService.currentUser();
      }
      isEmailVerified = verified;
      isLoading = false;
      notifyListeners();
      return verified;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    isResetPasswordLoading = true;
    resetPasswordMessage = null;
    resetPasswordError = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      resetPasswordMessage =
          'Email đặt lại mật khẩu đã được gửi. Vui lòng kiểm tra Gmail.';
      isResetPasswordLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      resetPasswordError = error.toString().replaceFirst('Exception: ', '');
      isResetPasswordLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearResetPasswordState() {
    isResetPasswordLoading = false;
    resetPasswordMessage = null;
    resetPasswordError = null;
    notifyListeners();
  }

  Future<void> logout() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    await _authService.logout();
    user = null;
    isEmailVerificationSent = false;
    isEmailVerified = false;
    isLoading = false;
    notifyListeners();
  }

  Future<bool> _runAuth(
    Future<AppUser> Function() action, {
    bool emailVerificationSent = false,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await action();
      isEmailVerificationSent = emailVerificationSent;
      isEmailVerified = user?.emailVerified ?? false;
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
}
