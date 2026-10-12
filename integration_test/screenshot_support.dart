import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared by the screenshot tests. Each test prints a marker at a screen so a
// host script can capture the simulator with `xcrun simctl io screenshot`.

Future<void> wait(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<bool> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await wait(tester, const Duration(milliseconds: 250));
  }
  return false;
}

Future<void> capture(WidgetTester tester, String name) async {
  await wait(tester, const Duration(seconds: 3));
  // ignore: avoid_print
  print('APPSTORE_SCREENSHOT:$name');
  await wait(tester, const Duration(seconds: 4));
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

Map<String, Object?> _position(double latitude, double longitude) =>
    <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
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

void simulateGrantedLocation({
  double latitude = 6.6018,
  double longitude = 3.3515,
}) {
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
        return _position(latitude, longitude);
    }
    return null;
  });
  messenger.setMockStreamHandler(
    _positionUpdates,
    MockStreamHandler.inline(
      onListen: (arguments, sink) =>
          sink.success(_position(latitude, longitude)),
    ),
  );
  messenger.setMockStreamHandler(
    _serviceUpdates,
    MockStreamHandler.inline(onListen: (arguments, sink) => sink.success(1)),
  );
}
