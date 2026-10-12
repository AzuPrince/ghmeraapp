import 'package:flutter_test/flutter_test.dart';
import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/services/help_credits.dart';

HelpRequestEntity _request(
  String id, {
  required String requesterId,
  String? helperId,
  HelpRequestStatus status = HelpRequestStatus.open,
  RequestCategory category = RequestCategory.errands,
}) {
  return HelpRequestEntity(
    id: id,
    requesterId: requesterId,
    title: 'Request $id',
    description: 'Description for request $id',
    category: category,
    urgency: UrgencyLevel.medium,
    location: 'Ikeja',
    preferredTime: 'Today',
    visibility: HelpRequestVisibility.public,
    status: status,
    createdAt: DateTime(2026, 10, 1),
    acceptedHelperId: helperId,
  );
}

void main() {
  test('a new member starts with five available credits', () {
    final summary = HelpCreditSummary.forUser('new', const []);

    expect(summary.balance, startingHelpCredits);
    expect(summary.available, 5);
    expect(summary.canAffordRequest, isTrue);
    expect(summary.entries.single.kind, HelpCreditEntryKind.starting);
  });

  test('a request costs one credit to ask and one to receive', () {
    expect(askCreditCost, 1);
    expect(receiveCreditCost, 1);
    expect(requestCreditCost, 2);
    expect(helpEarnedCredits, 1);
  });

  test('each open request holds two credits and posting needs two', () {
    final one = HelpCreditSummary.forUser('me', [
      _request('r0', requesterId: 'me'),
    ]);
    expect(one.held, 2);
    expect(one.available, 3);
    expect(one.canAffordRequest, isTrue);
    expect(one.entries.first.kind, HelpCreditEntryKind.held);
    expect(one.entries.first.amount, -2);

    final two = HelpCreditSummary.forUser('me', [
      _request('r0', requesterId: 'me'),
      _request('r1', requesterId: 'me'),
    ]);
    expect(two.held, 4);
    expect(two.available, 1);
    expect(two.canAffordRequest, isFalse);
    expect(two.creditsNeededToPost, 1);
  });

  test(
    'completed help is recorded as separate asking and receiving charges',
    () {
      final summary = HelpCreditSummary.forUser('me', [
        _request(
          'done',
          requesterId: 'me',
          helperId: 'neighbour',
          status: HelpRequestStatus.completed,
        ),
      ]);

      expect(summary.spent, 2);
      expect(summary.held, 0);
      expect(summary.available, 3);
      final charges = summary.entries
          .where((entry) => entry.request?.id == 'done')
          .toList();
      expect(
        charges.map((entry) => entry.kind),
        unorderedEquals([
          HelpCreditEntryKind.received,
          HelpCreditEntryKind.asked,
        ]),
      );
      expect(charges.map((entry) => entry.amount), [-1, -1]);
      expect(
        charges.map((entry) => entry.title),
        unorderedEquals([
          'Received help with "Request done"',
          'Asked for help with "Request done"',
        ]),
      );
    },
  );

  test('recomputed history can go below zero and blocks posting', () {
    final summary = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 3; index++)
        _request(
          'done$index',
          requesterId: 'me',
          helperId: 'neighbour',
          status: HelpRequestStatus.completed,
        ),
    ]);

    expect(summary.balance, -1);
    expect(summary.available, -1);
    expect(summary.spendable, 0);
    expect(summary.shortfall, 1);
    expect(summary.canAffordRequest, isFalse);
    expect(summary.creditsNeededToPost, 3);
  });

  test('exactly two available credits is enough to post', () {
    final summary = HelpCreditSummary.forUser('me', [
      _request(
        'done',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.completed,
      ),
      _request('open', requesterId: 'me'),
    ]);

    expect(summary.available, 1);
    expect(summary.canAffordRequest, isFalse);

    final afterHelping = HelpCreditSummary.forUser('me', [
      _request(
        'done',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.completed,
      ),
      _request('open', requesterId: 'me'),
      _request(
        'given',
        requesterId: 'neighbour',
        helperId: 'me',
        status: HelpRequestStatus.completed,
      ),
    ]);
    expect(afterHelping.available, 2);
    expect(afterHelping.canAffordRequest, isTrue);
    expect(afterHelping.creditsNeededToPost, 0);
  });

  test('receiving help spends two credits and giving help earns one', () {
    final requests = [
      _request(
        'received',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.completed,
      ),
      _request(
        'given',
        requesterId: 'neighbour',
        helperId: 'me',
        status: HelpRequestStatus.completed,
      ),
      _request(
        'given-again',
        requesterId: 'friend',
        helperId: 'me',
        status: HelpRequestStatus.completed,
      ),
    ];

    final mine = HelpCreditSummary.forUser('me', requests);
    final neighbour = HelpCreditSummary.forUser('neighbour', requests);

    expect(mine.spent, 2);
    expect(mine.earned, 2);
    expect(mine.available, 5);
    expect(neighbour.available, 4);
  });

  test('canceled and emergency requests do not cost credits', () {
    final requests = [
      _request(
        'canceled',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.canceled,
      ),
      _request(
        'emergency',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.completed,
        category: RequestCategory.emergencySupport,
      ),
      _request(
        'emergency-open',
        requesterId: 'me',
        category: RequestCategory.emergencySupport,
      ),
    ];

    final summary = HelpCreditSummary.forUser('me', requests);

    expect(summary.available, startingHelpCredits);
    expect(HelpCreditSummary.forUser('neighbour', requests).earned, 1);
  });

  test('help stats expose a requester track record to helpers', () {
    const requester = UserEntity(
      id: 'me',
      fullName: 'Ada Lovelace',
      email: 'ada@example.com',
    );
    final requests = [
      _request(
        'received',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.completed,
      ),
      _request(
        'given',
        requesterId: 'neighbour',
        helperId: 'me',
        status: HelpRequestStatus.completed,
      ),
      _request('open', requesterId: 'me'),
    ];
    final reviews = [
      ReviewEntity(
        id: 'review',
        matchId: 'match',
        reviewerId: 'neighbour',
        revieweeId: 'me',
        helpfulness: 5,
        respectfulness: 5,
        safety: 5,
        reliability: 4,
        accuracy: 4,
        feedback: 'Great',
        createdAt: DateTime(2026, 10, 2),
      ),
    ];

    final stats = UserHelpStats.forUser(
      requester,
      requests: requests,
      reviews: reviews,
    );

    expect(stats.helpsGiven, 1);
    expect(stats.helpsReceived, 1);
    expect(stats.requestsPosted, 2);
    expect(stats.reviewCount, 1);
    expect(stats.averageRating, closeTo(4.6, 0.01));
    expect(stats.giveBackLabel, 'Gives more than receives');
  });
}
