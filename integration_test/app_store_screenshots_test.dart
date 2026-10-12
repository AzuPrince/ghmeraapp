import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ghmera_app/main.dart' as app;

// Drives the app through its main screens and prints a marker at each one so
// a host script can capture the simulator with `xcrun simctl io screenshot`.
const String _email = String.fromEnvironment('SCREENSHOT_EMAIL');
const String _password = String.fromEnvironment('SCREENSHOT_PASSWORD');
// Also captures detail screens for design review; these can show other
// members, so they are not meant for the public store listing.
const bool _fullTour = bool.fromEnvironment('SCREENSHOT_TOUR');

Future<void> _wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await _wait(tester, const Duration(milliseconds: 250));
  }
  return false;
}

Future<void> _capture(WidgetTester tester, String name) async {
  await _wait(tester, const Duration(seconds: 3));
  // ignore: avoid_print
  print('APPSTORE_SCREENSHOT:$name');
  await _wait(tester, const Duration(seconds: 4));
}

// Answers the location plugin from Dart so the iOS permission alert, which
// the test cannot dismiss, never covers the screenshots.
const MethodChannel _geolocator = MethodChannel(
  'flutter.baseflow.com/geolocator_apple',
);
const EventChannel _positionUpdates = EventChannel(
  'flutter.baseflow.com/geolocator_updates_apple',
);
const EventChannel _serviceUpdates = EventChannel(
  'flutter.baseflow.com/geolocator_service_updates_apple',
);

Map<String, Object?> _lagosPosition() => <String, Object?>{
  'latitude': 6.6018,
  'longitude': 3.3515,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'accuracy': 5.0,
  'altitude': 40.0,
  'altitude_accuracy': 3.0,
  'heading': 0.0,
  'heading_accuracy': 0.0,
  'speed': 0.0,
  'speed_accuracy': 0.0,
  'is_mocked': false,
};

void _simulateGrantedLocation() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_geolocator, (call) async {
    switch (call.method) {
      case 'checkPermission':
      case 'requestPermission':
        return 2;
      case 'isLocationServiceEnabled':
        return true;
      case 'getLocationAccuracy':
        return 1;
      case 'getCurrentPosition':
      case 'getLastKnownPosition':
        return _lagosPosition();
    }
    return null;
  });
  messenger.setMockStreamHandler(
    _positionUpdates,
    MockStreamHandler.inline(
      onListen: (arguments, sink) => sink.success(_lagosPosition()),
    ),
  );
  messenger.setMockStreamHandler(
    _serviceUpdates,
    MockStreamHandler.inline(onListen: (arguments, sink) => sink.success(1)),
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture App Store screenshots', (tester) async {
    _simulateGrantedLocation();
    app.main();
    await _wait(tester, const Duration(seconds: 4));

    final acceptTerms = find.textContaining('Accept Terms of Use');
    if (await _waitFor(
      tester,
      acceptTerms,
      timeout: const Duration(seconds: 20),
    )) {
      await _capture(tester, '01_welcome');
      await tester.tap(acceptTerms.first);
    }

    final emailField = _field('Email Address');
    if (await _waitFor(
      tester,
      emailField,
      timeout: const Duration(seconds: 15),
    )) {
      expect(_email, isNotEmpty, reason: 'Pass SCREENSHOT_EMAIL.');
      await tester.enterText(emailField.first, _email);
      await tester.enterText(_field('Password').first, _password);
      FocusManager.instance.primaryFocus?.unfocus();
      await _wait(tester, const Duration(seconds: 1));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    }

    expect(
      await _waitFor(tester, find.text('Give Help')),
      isTrue,
      reason: 'Home screen did not appear after sign in.',
    );
    final creditsIntro = find.text('Got it');
    if (await _waitFor(
      tester,
      creditsIntro,
      timeout: const Duration(seconds: 8),
    )) {
      if (_fullTour) {
        await _capture(tester, '00_credits_intro');
      }
      await tester.tap(creditsIntro);
      await _wait(tester, const Duration(seconds: 1));
    }
    await _capture(tester, '02_give_help');

    if (_fullTour) {
      final requestCard = find.text('+1 credit');
      if (requestCard.evaluate().isNotEmpty) {
        await tester.tap(requestCard.first);
        await _capture(tester, '06_request_details');
        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await _capture(tester, '07_request_details_more');
        await tester.tap(find.byTooltip('Back').first);
        await _wait(tester, const Duration(seconds: 2));
      }
    }

    await tester.tap(find.text('Receive Help').last);
    await _capture(tester, '03_receive_help');

    if (_fullTour) {
      await tester.tap(find.text('How it works').first);
      await _capture(tester, '08_credits_sheet');
      await tester.tapAt(const Offset(20, 60));
      await _wait(tester, const Duration(seconds: 2));

      await tester.tap(find.text('New request'));
      await _capture(tester, '09_create_request');
      await tester.tap(find.byTooltip('Back').first);
      await _wait(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.text('Account').last);
    await _capture(tester, '04_account');

    if (_fullTour) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await _capture(tester, '10_account_more');
      await tester.tap(find.byTooltip('Notifications'));
      await _capture(tester, '11_notifications');
      await tester.tap(find.byTooltip('Back').first);
      await _wait(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.text('Give Help').last);
    await _wait(tester, const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Messages'));
    await _capture(tester, '05_messages');

    if (_fullTour) {
      final firstThread = find.textContaining('You:');
      final anyThread = firstThread.evaluate().isNotEmpty
          ? firstThread
          : find.textContaining('Say hello');
      if (anyThread.evaluate().isNotEmpty) {
        await tester.tap(anyThread.first);
        await _capture(tester, '12_thread');
      }
    }
  });
}
