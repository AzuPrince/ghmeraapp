import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ghmera_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:ghmera_app/features/auth/presentation/screens/secure_sign_in_screen.dart';

Future<void> _pumpAuthScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
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
}
