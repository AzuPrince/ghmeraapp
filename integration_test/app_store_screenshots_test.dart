import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ghmera_app/main.dart' as app;

import 'screenshot_support.dart';

// Drives the app through its main screens with the App Review demo account.
// Its live data shows other members, so these captures are for design review;
// store screenshots come from app_store_sample_screenshots_test.dart.
const String _email = String.fromEnvironment('SCREENSHOT_EMAIL');
const String _password = String.fromEnvironment('SCREENSHOT_PASSWORD');
// Also captures detail screens for design review; these can show other
// members, so they are not meant for the public store listing.
const bool _fullTour = bool.fromEnvironment('SCREENSHOT_TOUR');

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture App Store screenshots', (tester) async {
    simulateGrantedLocation();
    app.main();
    await wait(tester, const Duration(seconds: 4));

    final acceptTerms = find.textContaining('Accept Terms of Use');
    if (await waitFor(
      tester,
      acceptTerms,
      timeout: const Duration(seconds: 20),
    )) {
      await capture(tester, '01_welcome');
      await tester.tap(acceptTerms.first);
    }

    final emailField = _field('Email Address');
    if (await waitFor(
      tester,
      emailField,
      timeout: const Duration(seconds: 15),
    )) {
      expect(_email, isNotEmpty, reason: 'Pass SCREENSHOT_EMAIL.');
      await tester.enterText(emailField.first, _email);
      await tester.enterText(_field('Password').first, _password);
      FocusManager.instance.primaryFocus?.unfocus();
      await wait(tester, const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    }

    expect(
      await waitFor(tester, find.text('Give Help')),
      isTrue,
      reason: 'Home screen did not appear after sign in.',
    );
    final creditsIntro = find.text('Got it');
    if (await waitFor(
      tester,
      creditsIntro,
      timeout: const Duration(seconds: 8),
    )) {
      if (_fullTour) {
        await capture(tester, '00_credits_intro');
      }
      await tester.tap(creditsIntro);
      await wait(tester, const Duration(seconds: 1));
    }
    await capture(tester, '02_give_help');

    if (_fullTour) {
      final requestCard = find.text('+1 credit');
      if (requestCard.evaluate().isNotEmpty) {
        await tester.tap(requestCard.first);
        await capture(tester, '06_request_details');
        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await capture(tester, '07_request_details_more');
        await tester.tap(find.byTooltip('Back').first);
        await wait(tester, const Duration(seconds: 2));
      }
    }

    await tester.tap(find.text('Receive Help').last);
    await capture(tester, '03_receive_help');

    if (_fullTour) {
      await tester.tap(find.text('How it works').first);
      await capture(tester, '08_credits_sheet');
      await tester.tapAt(const Offset(20, 60));
      await wait(tester, const Duration(seconds: 2));

      await tester.tap(find.text('New request'));
      await capture(tester, '09_create_request');
      await tester.tap(find.byTooltip('Back').first);
      await wait(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.text('Account').last);
    await capture(tester, '04_account');

    if (_fullTour) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await capture(tester, '10_account_more');
      await tester.tap(find.byTooltip('Notifications'));
      await capture(tester, '11_notifications');
      await tester.tap(find.byTooltip('Back').first);
      await wait(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.text('Give Help').last);
    await wait(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Messages'));
    await capture(tester, '05_messages');

    if (_fullTour) {
      final firstThread = find.textContaining('You:');
      final anyThread = firstThread.evaluate().isNotEmpty
          ? firstThread
          : find.textContaining('Say hello');
      if (anyThread.evaluate().isNotEmpty) {
        await tester.tap(anyThread.first);
        await capture(tester, '12_thread');
      }
    }
  });
}
