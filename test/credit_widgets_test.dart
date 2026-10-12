import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/services/help_credits.dart';
import 'package:ghmera_app/core/ui/ghmera_components.dart';
import 'package:ghmera_app/core/ui/ghmera_theme.dart';
import 'package:ghmera_app/features/credits/presentation/widgets/credit_wallet_card.dart';

Future<void> _pumpOnSmallPhone(WidgetTester tester, Widget child) =>
    _pumpAt(tester, const Size(320, 900), child);

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
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

HelpCreditSummary _summaryWithAvailable(int credits) {
  return HelpCreditSummary(
    earned: credits > startingHelpCredits ? credits - startingHelpCredits : 0,
    spent: credits < startingHelpCredits ? startingHelpCredits - credits : 0,
    held: 0,
  );
}

Iterable<GhCoin> _dimmedCoins(WidgetTester tester) =>
    tester.widgetList<GhCoin>(find.byType(GhCoin)).where((coin) => coin.dimmed);

void main() {
  testWidgets('wallet shows available credits and holds on a small phone', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [_request('r1')]);

    await _pumpOnSmallPhone(
      tester,
      CreditWalletCard(
        summary: summary,
        message: 'You have 4 credits ready to use.',
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('credits available'), findsOneWidget);
    expect(find.text('On hold'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text('Each request uses 1 credit'),
      findsOneWidget,
    );
    expect(find.byType(GhCoin), findsNWidgets(4));
    expect(_dimmedCoins(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet coin row never implies a maximum balance', (
    tester,
  ) async {
    const screens = <String, Size>{
      'small phone': Size(320, 900),
      'phone': Size(375, 812),
      'iPad': Size(1024, 1366),
    };
    for (final MapEntry(key: screen, value: size) in screens.entries) {
      for (final credits in const [0, 1, 3, 5, 12, 150]) {
        final reason = '$credits credits on $screen';
        await _pumpAt(
          tester,
          size,
          CreditWalletCard(
            summary: _summaryWithAvailable(credits),
            message: 'Keep helping to earn more.',
          ),
        );

        expect(tester.takeException(), isNull, reason: reason);
        expect(find.text('$credits'), findsWidgets, reason: reason);
        expect(
          find.text(credits == 1 ? 'credit available' : 'credits available'),
          findsOneWidget,
          reason: reason,
        );
        expect(
          find.text('No limit · +1 for every help you give'),
          findsOneWidget,
          reason: reason,
        );
        expect(
          find.byType(GhCoin),
          findsNWidgets(credits < 5 ? credits : 5),
          reason: reason,
        );
        expect(_dimmedCoins(tester), isEmpty, reason: reason);
        expect(
          find.descendant(
            of: find.byType(GhCoinStack),
            matching: credits > 5
                ? find.text('+${credits - 5}')
                : find.textContaining('+'),
          ),
          credits > 5 ? findsOneWidget : findsNothing,
          reason: reason,
        );
      }
    }
  });

  testWidgets('credit chip shows large balances without overflow or slots', (
    tester,
  ) async {
    await _pumpOnSmallPhone(
      tester,
      Container(
        color: GhColors.brand,
        padding: const EdgeInsets.all(12),
        child: const Row(
          children: [
            Expanded(child: Text('150 people need a hand')),
            SizedBox(width: 12),
            GhCreditChip(credits: 150, onDark: true),
          ],
        ),
      ),
    );

    expect(find.text('150 credits'), findsOneWidget);
    expect(find.byType(GhCoin), findsOneWidget);
    expect(_dimmedCoins(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coin stack caps the drawn coins, not the balance', (
    tester,
  ) async {
    await _pumpOnSmallPhone(tester, const GhCoinStack(credits: 150));
    expect(find.byType(GhCoin), findsNWidgets(5));
    expect(find.text('+145'), findsOneWidget);
    expect(find.bySemanticsLabel('150 credits'), findsOneWidget);

    await _pumpOnSmallPhone(tester, const GhCoinStack(credits: 0));
    expect(find.byType(GhCoin), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet explains how many more credits are needed to post', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 5; index++) _request('r$index'),
    ]);

    await _pumpOnSmallPhone(
      tester,
      CreditWalletCard(summary: summary, message: 'Help someone to post.'),
    );

    expect(find.text('credits available'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(GhCoin), findsNothing);
    expect(
      find.text('Need 1 more to post · requests need 1 credit'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet never shows a negative balance as available', (
    tester,
  ) async {
    final summary = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 6; index++)
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
