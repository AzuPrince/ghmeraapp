import 'package:flutter_test/flutter_test.dart';

import 'package:ghmera_app/features/auth/domain/constants/auth_messages.dart';

void main() {
  test('raw internal sign-in errors are replaced with a useful message', () {
    expect(
      firebaseAuthenticationErrorMessage(
        code: 'internal-error',
        message: 'INTERNAL',
      ),
      signInTemporarilyUnavailableMessage,
    );
    expect(
      firebaseAuthenticationErrorMessage(
        code: 'unknown',
        message: '[firebase_auth/internal-error] INTERNAL',
      ),
      'Authentication failed. Please try again.',
    );
  });

  test('invalid credential variants use the create-account message', () {
    for (final code in <String>[
      'invalid-credential',
      'invalid-login-credential',
      'invalid-login-credentials',
      'user-not-found',
      'wrong-password',
    ]) {
      expect(
        firebaseAuthenticationErrorMessage(code: code),
        invalidSignInCredentialsMessage,
      );
    }

    expect(
      firebaseAuthenticationErrorMessage(
        code: 'internal',
        message: 'INVALID_LOGIN_CREDENTIALS',
      ),
      invalidSignInCredentialsMessage,
    );
  });

  test('callable-function errors keep actionable backend messages', () {
    const actionableMessage =
        'Your account was created, but automatic sign in could not be completed.';

    expect(
      cleanAuthenticationErrorMessage(
        actionableMessage,
        fallbackMessage: 'Registration failed.',
      ),
      actionableMessage,
    );
    expect(
      cleanAuthenticationErrorMessage(
        'INTERNAL',
        fallbackMessage: 'Registration failed.',
      ),
      'Registration failed.',
    );
  });
}
