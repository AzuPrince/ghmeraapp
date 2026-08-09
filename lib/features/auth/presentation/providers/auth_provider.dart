import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? firebaseFunctions,
    Connectivity? connectivity,
  }) : _firebaseAuth =
           firebaseAuth ??
           (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null),
       _firebaseFunctions = firebaseFunctions,
       _connectivity = connectivity ?? Connectivity() {
    final auth = _firebaseAuth;
    if (auth == null) return;

    _isSignedIn = auth.currentUser != null;
    _authSubscription = auth.authStateChanges().listen((user) {
      _isSignedIn = user != null;
      notifyListeners();
    });
  }

  static const _functionsRegion = 'us-central1';

  final FirebaseAuth? _firebaseAuth;
  final FirebaseFunctions? _firebaseFunctions;
  final Connectivity _connectivity;
  StreamSubscription<User?>? _authSubscription;

  bool _isLoading = false;
  bool _isSignedIn = false;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;

  User? get firebaseUser => _firebaseAuth?.currentUser;
  String? get photoUrl => firebaseUser?.photoURL;
  String? get email => firebaseUser?.email;

  String get displayName {
    final profileName = firebaseUser?.displayName?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final userEmail = firebaseUser?.email?.trim();
    if (userEmail != null && userEmail.contains('@')) {
      return userEmail.split('@').first;
    }

    return 'Ghmera User';
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _ensureOnline();
    final auth = _requireFirebaseAuth();
    _setLoading();

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (credential.user?.emailVerified != true) {
        await auth.signOut();
        throw const AuthException(
          'Verify your email with the 6-digit sign-up code before signing in.',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('Email sign-in failed: $error');
      throw const AuthException('Sign in failed. Please try again.');
    } finally {
      _clearLoading();
    }
  }

  Future<void> sendRegistrationCode({
    required String email,
    required String displayName,
  }) async {
    await _ensureOnline();
    _setLoading();

    try {
      await _callAuthFunction(
        'send_registration_verification_code',
        <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'displayName': displayName.trim(),
        },
        fallbackMessage: 'Failed to send the verification code.',
      );
    } finally {
      _clearLoading();
    }
  }

  Future<void> completeRegistration({
    required String email,
    required String code,
    required String password,
    required String displayName,
  }) async {
    await _ensureOnline();
    final auth = _requireFirebaseAuth();
    _setLoading();

    try {
      final result = await _callAuthFunction(
        'complete_email_registration',
        <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'password': password,
          'displayName': displayName.trim(),
        },
        fallbackMessage: 'Email verification failed.',
      );

      final customToken = result['customToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        throw const AuthException(
          'The account was verified, but sign in could not be completed. Please try signing in.',
        );
      }
      await auth.signInWithCustomToken(customToken);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } finally {
      _clearLoading();
    }
  }

  Future<void> sendPasswordResetCode(String email) async {
    await _ensureOnline();
    _setLoading();

    try {
      await _callAuthFunction(
        'send_password_reset_code',
        <String, dynamic>{'email': email.trim().toLowerCase()},
        fallbackMessage: 'Failed to send the password reset code.',
      );
    } finally {
      _clearLoading();
    }
  }

  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _ensureOnline();
    _setLoading();

    try {
      await _callAuthFunction('complete_password_reset', <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'password': newPassword,
      }, fallbackMessage: 'Password reset failed.');
    } finally {
      _clearLoading();
    }
  }

  Future<void> signOut() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      _isSignedIn = false;
      notifyListeners();
      return;
    }

    try {
      await auth.signOut();
    } finally {
      _isSignedIn = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _callAuthFunction(
    String name,
    Map<String, dynamic> data, {
    required String fallbackMessage,
  }) async {
    try {
      final callable = _functions.httpsCallable(name);
      final result = await callable.call<Map<String, dynamic>>(data);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(error.message ?? fallbackMessage);
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('Authentication function $name failed: $error');
      throw AuthException(fallbackMessage);
    }
  }

  Future<void> _ensureOnline() async {
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const AuthException(
        'You are offline. Please check your internet connection and try again.',
      );
    }
  }

  FirebaseFunctions get _functions =>
      _firebaseFunctions ??
      FirebaseFunctions.instanceFor(region: _functionsRegion);

  void _setLoading() {
    _isLoading = true;
    notifyListeners();
  }

  void _clearLoading() {
    _isLoading = false;
    notifyListeners();
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Please sign in.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'A network error occurred. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email and password sign in is temporarily unavailable. Please try again later.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  FirebaseAuth _requireFirebaseAuth() {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw const AuthException(
        'Sign in is temporarily unavailable. Please try again later.',
      );
    }
    return auth;
  }
}
