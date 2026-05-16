import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../app/models/ghmera_models.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? firebaseAuth})
    : _firebaseAuth =
          firebaseAuth ??
          (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null) {
    final auth = _firebaseAuth;
    if (auth == null) {
      return;
    }

    _isSignedIn = auth.currentUser != null;
    _authSubscription = auth.authStateChanges().listen((user) {
      _isSignedIn = user != null;
      if (user == null) {
        _verificationId = null;
        _pendingPhoneNumber = null;
      }
      notifyListeners();
    });
  }

  final FirebaseAuth? _firebaseAuth;
  StreamSubscription<User?>? _authSubscription;

  bool _isLoading = false;
  bool _isSignedIn = false;
  bool _isGoogleInitialized = false;
  AuthMethod? _activeMethod;
  String? _verificationId;
  String? _pendingPhoneNumber;

  bool get isLoading => _isLoading;
  bool get isSignedIn => _isSignedIn;
  AuthMethod? get activeMethod => _activeMethod;

  User? get firebaseUser => _firebaseAuth?.currentUser;
  String? get photoUrl => firebaseUser?.photoURL;
  String? get email => firebaseUser?.email;
  bool get hasPendingPhoneVerification => _verificationId != null;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

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

  bool isBusy(AuthMethod method) => _isLoading && _activeMethod == method;

  Future<void> signIn(AuthMethod method) {
    switch (method) {
      case AuthMethod.google:
        return signInWithGoogle();
      case AuthMethod.apple:
        return signInWithApple();
      case AuthMethod.phone:
        throw const AuthException('Use phone number verification to continue.');
    }
  }

  Future<void> signInWithGoogle() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const AuthException(
        'You are offline. Please check your internet connection and try again.',
      );
    }

    final auth = _requireFirebaseAuth();
    _setLoading(AuthMethod.google);

    try {
      if (!_isGoogleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '439222343527-kksj2d02c3ell375is31s36795a0p5s7.apps.googleusercontent.com',
        );
        _isGoogleInitialized = true;
      }
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } on GoogleSignInException catch (error) {
      throw AuthException('Google sign-in failed: ${error.description}');
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Google sign-in could not be completed. Please try again.',
      );
    } finally {
      _clearLoading();
    }
  }

  Future<void> signInWithApple() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const AuthException(
        'You are offline. Please check your internet connection and try again.',
      );
    }

    final auth = _requireFirebaseAuth();
    _setLoading(AuthMethod.apple);

    try {
      if (!(Platform.isIOS || Platform.isMacOS)) {
        throw const AuthException(
          'Apple sign-in is only available on iOS and macOS.',
        );
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw const AuthException(
          'Apple sign-in returned no identity token. Please try again.',
        );
      }

      final credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: idToken, rawNonce: rawNonce);

      await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } on SignInWithAppleAuthorizationException catch (error) {
      throw AuthException('Apple sign-in failed: ${error.message}.');
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Apple sign-in could not be completed. Please try again.',
      );
    } finally {
      _clearLoading();
    }
  }

  Future<void> startPhoneNumberSignIn(String phoneNumber) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const AuthException(
        'You are offline. Please check your internet connection and try again.',
      );
    }

    final auth = _requireFirebaseAuth();
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty) {
      throw const AuthException('Enter a valid phone number.');
    }

    _setLoading(AuthMethod.phone);
    _verificationId = null;
    _pendingPhoneNumber = null;
    notifyListeners();

    final completer = Completer<void>();

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            await auth.signInWithCredential(credential);
            _verificationId = null;
            _pendingPhoneNumber = null;
            if (!completer.isCompleted) {
              completer.complete();
            }
          } on FirebaseAuthException catch (error) {
            if (!completer.isCompleted) {
              completer.completeError(
                AuthException(_firebaseErrorMessage(error)),
              );
            }
          }
        },
        verificationFailed: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              AuthException(_firebaseErrorMessage(error)),
            );
          }
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _pendingPhoneNumber = normalizedPhone;
          notifyListeners();

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          _pendingPhoneNumber = normalizedPhone;
          notifyListeners();

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          throw const AuthException(
            'Verification is taking longer than expected. Please check your network and request the code again.',
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Phone verification could not be started. Please try again.',
      );
    } finally {
      _clearLoading();
    }
  }

  Future<void> confirmPhoneCode(String smsCode) async {
    final auth = _requireFirebaseAuth();
    final code = smsCode.trim();
    if (code.isEmpty) {
      throw const AuthException('Enter the verification code.');
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      throw const AuthException(
        'No phone verification is in progress. Request a new code.',
      );
    }

    _setLoading(AuthMethod.phone);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );

      await auth.signInWithCredential(credential);
      _verificationId = null;
      _pendingPhoneNumber = null;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseErrorMessage(error));
    } finally {
      _clearLoading();
    }
  }

  void clearPhoneVerification() {
    _verificationId = null;
    _pendingPhoneNumber = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      _isSignedIn = false;
      _activeMethod = null;
      _verificationId = null;
      _pendingPhoneNumber = null;
      notifyListeners();
      return;
    }

    try {
      await auth.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore Google cleanup errors after Firebase sign-out.
      }
    } finally {
      _isSignedIn = false;
      _activeMethod = null;
      _verificationId = null;
      _pendingPhoneNumber = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setLoading(AuthMethod method) {
    _isLoading = true;
    _activeMethod = method;
    notifyListeners();
  }

  void _clearLoading() {
    _isLoading = false;
    _activeMethod = null;
    notifyListeners();
  }

  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'invalid-verification-id':
        return 'The verification session expired. Request a new code.';
      case 'session-expired':
        return 'The verification code expired. Request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid credentials. Try again.';
      case 'missing-phone-number':
        return 'Enter a phone number.';
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Authentication.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  FirebaseAuth _requireFirebaseAuth() {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw const AuthException(
        'Firebase is not configured yet. Run flutterfire configure and add platform config files.',
      );
    }
    return auth;
  }
}
