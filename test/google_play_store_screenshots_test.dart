import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghmera_app/app/database/database.dart';
import 'package:ghmera_app/app/providers/app_theme_provider.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';
import 'package:ghmera_app/core/ui/ghmera_theme.dart';
import 'package:ghmera_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/home_screen.dart';

import '../integration_test/sample_community.dart';
import '../integration_test/screenshot_support.dart';

const _outputDirectory = 'store_assets/google_play/phone';
const _flutterMaterialFonts =
    r'C:\src\flutter\bin\cache\artifacts\material_fonts';

Future<ByteData> _readFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> _loadProductionFonts() async {
  final roboto = FontLoader('Roboto')
    ..addFont(_readFont('$_flutterMaterialFonts\\roboto-regular.ttf'));
  // Widget tests assign Ahem directly to some component text styles. Loading
  // Roboto into that family prevents button labels from becoming block glyphs.
  final testFallback = FontLoader('Ahem')
    ..addFont(_readFont('$_flutterMaterialFonts\\roboto-regular.ttf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(
      _readFont('$_flutterMaterialFonts\\materialicons-regular.otf'),
    );
  await Future.wait([
    roboto.load(),
    testFallback.load(),
    materialIcons.load(),
  ]);
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final ticks = duration.inMilliseconds ~/ 100;
  for (var index = 0; index < ticks; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final ticks = timeout.inMilliseconds ~/ 100;
  for (var index = 0; index < ticks; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

class _StoreScreenshotApp extends StatelessWidget {
  const _StoreScreenshotApp({
    required this.appState,
    required this.boundaryKey,
  });

  final GhmeraAppState appState;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    final baseTheme = buildGhmeraTheme();
    final screenshotTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: 'Roboto'),
    );
    return RepaintBoundary(
      key: boundaryKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider<GhmeraAppState>.value(value: appState),
        ],
        child: MaterialApp(
          title: 'Ghmera',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.light,
          theme: screenshotTheme,
          builder: (context, child) {
            return DecoratedBox(
              decoration: const BoxDecoration(gradient: ghCanvasGradient),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String filename,
) async {
  await _pumpFor(tester, const Duration(seconds: 1));
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('$_outputDirectory/$filename');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back').first);
  await _pumpFor(tester, const Duration(seconds: 1));
}

void main() {
  testWidgets('render privacy-safe Google Play phone screenshots', (
    tester,
  ) async {
    await tester.runAsync(_loadProductionFonts);
    tester.view.physicalSize = const Size(414, 736);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    simulateGrantedLocation(latitude: 5.6037, longitude: -0.1870);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ghmera_credits_intro_seen_$sampleViewerId': true,
    });
    final database = buildSampleCommunity();
    AppDatabase.instance.hydrateFromMap(database);
    final workflowApi = SampleCommunityWorkflowApi(database);
    final appState = GhmeraAppState(
      firestoreSyncService: SampleCommunitySyncService(database),
      workflowApiService: workflowApi,
    );
    final boundaryKey = GlobalKey();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });

    await tester.pumpWidget(
      _StoreScreenshotApp(appState: appState, boundaryKey: boundaryKey),
    );

    // The welcome sheet can appear if its post-frame callback races the
    // sample-state hydration. It is useful in the app but must not obscure the
    // privacy-safe store screenshots.
    await _pumpFor(tester, const Duration(seconds: 1));
    final welcomeDismissal = find.text('Got it');
    if (welcomeDismissal.evaluate().isNotEmpty) {
      await tester.tap(welcomeDismissal);
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    // The first request card sits below the Give Help hero on a 9:16 phone.
    // Scroll it into view before locating and capturing it.
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pump();
    final foundHome = await _pumpUntil(
      tester,
      find.text(sampleSofaRequestTitle),
    );
    expect(foundHome, isTrue);
    await _capture(tester, boundaryKey, '01_give_help.png');

    await tester.tap(find.text(sampleSofaRequestTitle));
    expect(await _pumpUntil(tester, find.text('I can help')), isTrue);
    await _capture(tester, boundaryKey, '02_request_details.png');
    await _back(tester);

    await tester.tap(find.text('Receive Help').last);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -260),
    );
    await tester.pump();
    expect(await _pumpUntil(tester, find.text('Matched with a helper')), isTrue);
    await _capture(tester, boundaryKey, '03_receive_help.png');

    await tester.tap(find.byTooltip('Messages'));
    final threadPreview = find.textContaining(sampleLastChatMessage);
    expect(await _pumpUntil(tester, threadPreview), isTrue);
    await tester.tap(threadPreview.first);
    expect(await _pumpUntil(tester, find.text(sampleLastChatMessage)), isTrue);
    await _capture(tester, boundaryKey, '04_chat.png');

    expect(workflowApi.operations, isEmpty);
  });
}
