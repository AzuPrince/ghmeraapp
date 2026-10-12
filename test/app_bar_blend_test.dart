import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ghmera_app/core/ui/ghmera_theme.dart';
import 'package:ghmera_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:ghmera_app/features/auth/presentation/screens/secure_sign_in_screen.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/home_menu_screen.dart';

Material _appBarMaterial(WidgetTester tester) {
  return tester.widget<Material>(
    find
        .descendant(of: find.byType(AppBar), matching: find.byType(Material))
        .first,
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app bar and status bar stay one clear surface while scrolling', (
    tester,
  ) async {
    await _pump(
      tester,
      MaterialApp(
        theme: buildGhmeraTheme(),
        home: Scaffold(
          appBar: AppBar(title: const Text('Give help')),
          body: ListView(
            children: [
              for (var index = 0; index < 60; index++)
                ListTile(title: Text('Row $index')),
            ],
          ),
        ),
      ),
    );

    expect(_appBarMaterial(tester).color, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    final scrolled = _appBarMaterial(tester);
    expect(scrolled.color, Colors.transparent);
    expect(scrolled.elevation, 0);
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
  });

  testWidgets('menu and legal pages use the shared transparent app bar', (
    tester,
  ) async {
    const pages = <Widget>[
      HomeMenuScreen(),
      AboutGhmeraScreen(),
      TermsOfUseScreen(),
      PrivacyPolicyScreen(),
    ];
    for (final page in pages) {
      await _pump(tester, MaterialApp(theme: buildGhmeraTheme(), home: page));

      expect(
        _appBarMaterial(tester).color,
        Colors.transparent,
        reason: '${page.runtimeType}',
      );
      expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    }
  });

  testWidgets('sign in draws its dark page behind the status bar and app bar', (
    tester,
  ) async {
    await _pump(
      tester,
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: buildGhmeraTheme(),
          home: const SecureSignInScreen(),
        ),
      ),
    );

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBodyBehindAppBar,
      isTrue,
    );
    expect(_appBarMaterial(tester).color, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(
      SystemChrome.latestStyle?.statusBarIconBrightness,
      Brightness.light,
    );
  });
}
