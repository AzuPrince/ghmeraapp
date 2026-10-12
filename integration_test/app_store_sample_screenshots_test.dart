import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghmera_app/app/database/database.dart';
import 'package:ghmera_app/app/providers/app_theme_provider.dart';
import 'package:ghmera_app/app/providers/connectivity_provider.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';
import 'package:ghmera_app/core/ui/ghmera_theme.dart';
import 'package:ghmera_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/home_screen.dart';
import 'package:ghmera_app/main.dart' show ConnectivityListener;

import 'sample_community.dart';
import 'screenshot_support.dart';

// Captures the App Store screenshots from the real screens filled with the
// fictional community in sample_community.dart, so no member's name, photo or
// data appears. Firebase is never initialised and the backend services are
// replaced, so nothing is read from or written to live data.

/// The same providers and app shell as GhmeraApp in lib/main.dart, with the
/// app state supplied instead of created.
class _SampleApp extends StatelessWidget {
  const _SampleApp({required this.appState, required this.home});

  final GhmeraAppState appState;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<GhmeraAppState>.value(value: appState),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: 'Ghmera',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: buildGhmeraTheme(),
        builder: (context, child) {
          return ConnectivityListener(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: ghCanvasGradient),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: home,
      ),
    );
  }
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back').first);
  await wait(tester, const Duration(seconds: 2));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('capture App Store screenshots with sample data', (tester) async {
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

    await tester.pumpWidget(
      _SampleApp(appState: appState, home: const HomeScreen()),
    );
    expect(await waitFor(tester, find.text(sampleSofaRequestTitle)), isTrue);
    expect(appState.currentUserId, sampleViewerId);
    await capture(tester, '01_give_help');

    await tester.tap(find.text(sampleSofaRequestTitle));
    expect(await waitFor(tester, find.text('I can help')), isTrue);
    await capture(tester, '02_request_details');
    await _back(tester);

    await tester.tap(find.text('Receive Help').last);
    expect(await waitFor(tester, find.text('Matched with a helper')), isTrue);

    await tester.tap(find.text('New request'));
    expect(await waitFor(tester, find.text('Ask for help')), isTrue);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Short title'),
      'Ride to the airport on Sunday',
    );
    await tester.tap(find.text('Transportation'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Details'),
      'Flight at 11 AM, ready by 7:30.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, const Duration(seconds: 1));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 2000),
    );
    await capture(tester, '03_ask_for_help');
    await _back(tester);

    await capture(tester, '04_receive_help');

    await tester.tap(find.text('How it works').first);
    expect(await waitFor(tester, find.text('How credits work')), isTrue);
    await capture(tester, '05_credits_sheet');
    await tester.tapAt(const Offset(20, 60));
    await wait(tester, const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Messages'));
    // The thread preview, unlike the helper's name, is only on Messages.
    final threadPreview = find.textContaining(sampleLastChatMessage);
    expect(await waitFor(tester, threadPreview), isTrue);
    await wait(tester, const Duration(seconds: 1));
    await tester.tap(threadPreview.first);
    expect(await waitFor(tester, find.text(sampleLastChatMessage)), isTrue);
    await capture(tester, '06_chat');
    await _back(tester);
    await _back(tester);

    await tester.tap(find.text('Account').last);
    expect(await waitFor(tester, find.text(sampleViewerName)), isTrue);
    await capture(tester, '07_account');

    for (final name in realMemberNames) {
      expect(find.textContaining(name), findsNothing);
    }
    expect(workflowApi.operations, isEmpty);
  });
}
