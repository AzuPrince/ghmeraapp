import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/services/help_credits.dart';
import 'package:ghmera_app/core/ui/ghmera_components.dart';
import 'package:ghmera_app/core/ui/ghmera_theme.dart';
import 'package:ghmera_app/features/credits/presentation/widgets/credit_wallet_card.dart';

Future<void> _pumpOnSmallPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildGhmeraTheme(),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [child]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

HelpRequestEntity _request(
  String id, {
  HelpRequestStatus status = HelpRequestStatus.matching,
  String? helperId,
}) {
  return HelpRequestEntity(
    id: id,
    requesterId: 'me',
    title: 'Groceries $id',
    description: 'Pick up groceries from the market',
    category: RequestCategory.errands,
    urgency: UrgencyLevel.low,
    location: 'Ikeja',
    preferredTime: 'Today',
    visibility: HelpRequestVisibility.public,
    status: status,
    createdAt: DateTime(2026, 10, 1),
    acceptedHelperId: helperId,
  );
}

void main() {
  testWidgets('wallet shows available credits and holds on a small phone', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [_request('r1')]);

    await _pumpOnSmallPhone(
      tester,
      CreditWalletCard(
        summary: summary,
        message: 'You have 3 credits ready to use.',
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('credits available'), findsOneWidget);
    expect(find.text('On hold'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('Each request uses 2: 1 to ask, 1 to receive'),
      findsOneWidget,
    );
    expect(find.byType(GhCoin), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet explains how many more credits are needed to post', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [
      _request('r1'),
      _request('r2'),
    ]);

    await _pumpOnSmallPhone(
      tester,
      CreditWalletCard(summary: summary, message: 'Help someone to post.'),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('credit available'), findsOneWidget);
    expect(find.text('Need 1 more to post · requests need 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet never shows a negative balance as available', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 3; index++)
        _request(
          'done$index',
          status: HelpRequestStatus.completed,
          helperId: 'neighbour',
        ),
    ]);
    expect(summary.available, -1);

    await _pumpOnSmallPhone(
      tester,
      CreditWalletCard(summary: summary, message: 'Below zero.'),
    );

    expect(find.text('0'), findsWidgets);
    expect(find.text('-1'), findsNothing);
    expect(find.text('credits available'), findsOneWidget);
    expect(
      find.text('1 below zero · help someone to get back on track'),
      findsOneWidget,
    );
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('credit chip clamps negative balances to zero', (tester) async {
    await _pumpOnSmallPhone(tester, const GhCreditChip(credits: -3));
    expect(find.text('0 credits'), findsOneWidget);
  });

  testWidgets('requester stats strip summarises their track record', (
    tester,
  ) async {
    const stats = UserHelpStats(
      helpsGiven: 3,
      helpsReceived: 1,
      requestsPosted: 2,
      averageRating: 4.5,
      reviewCount: 2,
      trustScore: 60,
    );

    await _pumpOnSmallPhone(tester, const GhHelpStatsStrip(stats: stats));
    expect(find.text('Helped 3'), findsOneWidget);
    expect(find.text('Received 1'), findsOneWidget);
    expect(find.text('4.5 (2)'), findsOneWidget);

    await _pumpOnSmallPhone(
      tester,
      const GhHelpStatsStrip(stats: stats, compact: false),
    );
    expect(find.text('Helped others'), findsOneWidget);
    expect(find.text('2 ratings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
