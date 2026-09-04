const String invalidSignInCredentialsMessage =
    'No matching account or incorrect password. '
    'Check your details or create an account.';

const String signInTemporarilyUnavailableMessage =
    "We couldn't sign you in right now. Please try again.";

String cleanAuthenticationErrorMessage(
  String? message, {
  required String fallbackMessage,
}) {
  final cleaned = (message ?? '').replaceFirst('Exception: ', '').trim();
  final normalized = cleaned.toLowerCase();
  final isInternalError =
      normalized.isEmpty ||
      normalized == 'internal' ||
      normalized == 'internal error' ||
      normalized == 'an internal error has occurred.' ||
      normalized.contains('[firebase_auth/internal-error]') ||
      normalized.contains('[firebase_functions/internal]') ||
      normalized.contains('[cloud_firestore/internal]');

  return isInternalError ? fallbackMessage : cleaned;
}

String firebaseAuthenticationErrorMessage({
  required String code,
  String? message,
}) {
  switch (code) {
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'invalid-credential':
    case 'invalid-login-credential':
    case 'invalid-login-credentials':
    case 'user-not-found':
    case 'wrong-password':
      return invalidSignInCredentialsMessage;
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
    case 'internal-error':
    case 'internal':
      if ((message ?? '').toUpperCase().contains('INVALID_LOGIN_CREDENTIALS')) {
        return invalidSignInCredentialsMessage;
      }
      return signInTemporarilyUnavailableMessage;
    default:
      return cleanAuthenticationErrorMessage(
        message,
        fallbackMessage: 'Authentication failed. Please try again.',
      );
  }
}
