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

HelpRequestEntity _completed(String id, {String requesterId = 'me'}) =>
    _request(
      id,
      requesterId: requesterId,
      helperId: requesterId == 'me' ? 'neighbour' : 'me',
      status: HelpRequestStatus.completed,
    );

void main() {
  test('a new member starts with five available credits', () {
    final summary = HelpCreditSummary.forUser('new', const []);

    expect(summary.balance, startingHelpCredits);
    expect(summary.available, 5);
    expect(summary.canAffordRequest, isTrue);
    expect(summary.entries.single.kind, HelpCreditEntryKind.starting);
  });

  test('a request costs exactly what a helper earns', () {
    expect(requestCreditCost, 1);
    expect(helpEarnedCredits, requestCreditCost);
    expect(creditCountLabel(1), '1 credit');
    expect(creditCountLabel(17), '17 credits');
  });

  test('each open request holds one credit', () {
    final one = HelpCreditSummary.forUser('me', [
      _request('r0', requesterId: 'me'),
    ]);
    expect(one.held, 1);
    expect(one.available, 4);
    expect(one.canAffordRequest, isTrue);
    expect(one.entries.first.kind, HelpCreditEntryKind.held);
    expect(one.entries.first.amount, -1);

    final allHeld = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 5; index++)
        _request('r$index', requesterId: 'me'),
    ]);
    expect(allHeld.held, 5);
    expect(allHeld.available, 0);
    expect(allHeld.canAffordRequest, isFalse);
    expect(allHeld.creditsNeededToPost, 1);
  });

  test('exactly one available credit is enough to post, zero is not', () {
    final oneLeft = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 4; index++) _completed('done$index'),
    ]);
    expect(oneLeft.available, 1);
    expect(oneLeft.canAffordRequest, isTrue);
    expect(oneLeft.creditsNeededToPost, 0);

    final noneLeft = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 5; index++) _completed('done$index'),
    ]);
    expect(noneLeft.available, 0);
    expect(noneLeft.canAffordRequest, isFalse);
    expect(noneLeft.creditsNeededToPost, 1);
  });

  test('completed help spends one credit in a single history entry', () {
    final summary = HelpCreditSummary.forUser('me', [_completed('done')]);

    expect(summary.spent, 1);
    expect(summary.held, 0);
    expect(summary.available, 4);
    final charges = summary.entries
        .where((entry) => entry.request?.id == 'done')
        .toList();
    expect(charges, hasLength(1));
    expect(charges.single.kind, HelpCreditEntryKind.received);
    expect(charges.single.amount, -1);
    expect(charges.single.title, 'Received help with "Request done"');
  });

  test('a completed exchange balances requester and helper', () {
    final requests = [_completed('done')];
    final mine = HelpCreditSummary.forUser('me', requests);
    final neighbour = HelpCreditSummary.forUser('neighbour', requests);

    expect(mine.available, 4);
    expect(neighbour.available, 6);
    expect(mine.available + neighbour.available, 2 * startingHelpCredits);
  });

  test('a balance below zero shows as zero available and blocks posting', () {
    final summary = HelpCreditSummary.forUser('me', [
      for (var index = 0; index < 6; index++) _completed('done$index'),
    ]);

    expect(summary.balance, -1);
    expect(summary.available, -1);
    expect(summary.spendable, 0);
    expect(summary.shortfall, 1);
    expect(summary.canAffordRequest, isFalse);
    expect(summary.creditsNeededToPost, 2);
  });

  test('earning has no limit: every completed help adds one more credit', () {
    List<HelpRequestEntity> helpsGiven(int count) => [
      for (var index = 0; index < count; index++)
        _completed('given$index', requesterId: 'neighbour$index'),
    ];

    final twelve = HelpCreditSummary.forUser('me', helpsGiven(12));
    expect(twelve.earned, 12);
    expect(twelve.spent, 0);
    expect(twelve.held, 0);
    expect(twelve.balance, 17);
    expect(twelve.available, 17);
    expect(twelve.spendable, 17);

    final many = HelpCreditSummary.forUser('me', helpsGiven(150));
    expect(many.earned, 150);
    expect(many.available, 155);
  });

  test('canceled requests release their credit and emergencies are free', () {
    final requests = [
      _request(
        'canceled',
        requesterId: 'me',
        helperId: 'neighbour',
        status: HelpRequestStatus.canceled,
      ),
      _request(
        'canceled-open',
        requesterId: 'me',
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

    expect(summary.held, 0);
    expect(summary.spent, 0);
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
