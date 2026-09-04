import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ghmera_app/features/auth/domain/constants/auth_messages.dart';
import 'package:ghmera_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:ghmera_app/features/auth/presentation/screens/secure_sign_in_screen.dart';

class _InvalidCredentialsAuthProvider extends AuthProvider {
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    throw const AuthException(invalidSignInCredentialsMessage);
  }
}

Future<void> _pumpAuthScreen(
  WidgetTester tester, {
  AuthProvider? authProvider,
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => authProvider ?? AuthProvider(),
      child: const MaterialApp(home: SecureSignInScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows only email and password authentication options', (
    tester,
  ) async {
    await _pumpAuthScreen(tester);

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('phone number'), findsNothing);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Sign Up & Get Code'), findsOneWidget);
    expect(find.textContaining('mail@peatechservice.com'), findsOneWidget);
  });

  testWidgets('forgot password opens the reset-code email dialog', (
    tester,
  ) async {
    await _pumpAuthScreen(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Reset Code'), findsOneWidget);
    expect(find.textContaining('6-digit password reset code'), findsOneWidget);
  });

  testWidgets('invalid sign in offers a create account action', (tester) async {
    await _pumpAuthScreen(
      tester,
      authProvider: _InvalidCredentialsAuthProvider(),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(invalidSignInCredentialsMessage), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Full Name'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Email Address'),
          )
          .controller
          ?.text,
      'new@example.com',
    );
  });
}
