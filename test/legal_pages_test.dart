import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghmera_app/features/help_request/presentation/screens/home_menu_screen.dart';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('about page explains ownership, verification, and safety', (
    tester,
  ) async {
    await _pumpPage(tester, const AboutGhmeraScreen());

    expect(find.text('About Ghmera'), findsOneWidget);
    expect(find.text('Last updated: August 9, 2026'), findsOneWidget);
    expect(find.textContaining('PEATECH SERVICES LLC'), findsWidgets);
    expect(find.textContaining('United States-based company'), findsOneWidget);
    expect(find.text('United States operations'), findsOneWidget);
    expect(find.text('Transparency and accountability'), findsOneWidget);
    expect(find.text('Accounts and verification'), findsOneWidget);
    expect(find.text('Safety and emergencies'), findsOneWidget);
  });

  testWidgets('terms page includes community and emergency rules', (
    tester,
  ) async {
    await _pumpPage(tester, const TermsOfUseScreen());

    expect(find.text('Last updated: August 9, 2026'), findsOneWidget);
    expect(find.textContaining('United States-based company'), findsOneWidget);
    expect(
      find.text('4. No Emergency or Professional Service'),
      findsOneWidget,
    );
    expect(find.text('5. Community Conduct'), findsOneWidget);
    expect(find.text('7. Location and Map Information'), findsOneWidget);
    expect(find.text('14. United States Consumer Rights'), findsOneWidget);
    expect(
      find.text('15. Intellectual Property and Copyright Reports'),
      findsOneWidget,
    );
    expect(
      find.text('17. Applicable Law and General Provisions'),
      findsOneWidget,
    );
    expect(find.textContaining('info@peatechservice.com'), findsWidgets);
  });

  testWidgets('privacy page discloses providers, location, and rights', (
    tester,
  ) async {
    await _pumpPage(tester, const PrivacyPolicyScreen());

    expect(find.text('Last updated: August 9, 2026'), findsOneWidget);
    expect(find.textContaining('United States-based company'), findsOneWidget);
    expect(
      find.text('4. Email Verification and Password Reset'),
      findsOneWidget,
    );
    expect(find.text('5. Location, Geocoding, and Maps'), findsOneWidget);
    expect(find.textContaining('Google Firebase'), findsOneWidget);
    expect(find.text('9. No Sale or Targeted Advertising'), findsOneWidget);
    expect(find.text('12. U.S. State Privacy Rights'), findsOneWidget);
    expect(find.text('13. Exercising Privacy Rights'), findsOneWidget);
    expect(find.text('14. Your Privacy Choices'), findsOneWidget);
  });
}
