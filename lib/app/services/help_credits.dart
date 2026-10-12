import '../models/ghmera_models.dart';

/// Mirrors `functions/workflow_backend/credits.py`, which enforces these rules.
const int startingHelpCredits = 5;

/// What a requester pays for one completed request. It matches what the helper
/// earns, so every exchange balances.
const int requestCreditCost = 1;
const int helpEarnedCredits = 1;
const Set<RequestCategory> creditFreeCategories = <RequestCategory>{
  RequestCategory.emergencySupport,
};

/// "1 credit", "3 credits".
String creditCountLabel(int count) => count == 1 ? '1 credit' : '$count credits';

bool isCreditFreeRequest(HelpRequestEntity request) {
  return creditFreeCategories.contains(request.category);
}

bool _isClosed(HelpRequestEntity request) {
  return request.status == HelpRequestStatus.completed ||
      request.status == HelpRequestStatus.canceled;
}

enum HelpCreditEntryKind { starting, earned, received, held }

class HelpCreditEntry {
  const HelpCreditEntry({
    required this.kind,
    required this.amount,
    required this.title,
    this.request,
    this.at,
  });

  final HelpCreditEntryKind kind;
  final int amount;
  final String title;
  final HelpRequestEntity? request;
  final DateTime? at;
}

class HelpCreditSummary {
  const HelpCreditSummary({
    required this.earned,
    required this.spent,
    required this.held,
    this.entries = const <HelpCreditEntry>[],
  });

  factory HelpCreditSummary.forUser(
    String userId,
    Iterable<HelpRequestEntity> requests,
  ) {
    var earned = 0;
    var spent = 0;
    var held = 0;
    final entries = <HelpCreditEntry>[];

    for (final request in requests) {
      final completedAt = _completedAt(request);
      if (request.acceptedHelperId == userId &&
          request.status == HelpRequestStatus.completed) {
        earned += helpEarnedCredits;
        entries.add(
          HelpCreditEntry(
            kind: HelpCreditEntryKind.earned,
            amount: helpEarnedCredits,
            title: 'Helped with "${request.displayTitle}"',
            request: request,
            at: completedAt,
          ),
        );
      }
      if (request.requesterId != userId || isCreditFreeRequest(request)) {
        continue;
      }
      if (request.status == HelpRequestStatus.completed &&
          request.acceptedHelperId != null) {
        spent += requestCreditCost;
        entries.add(
          HelpCreditEntry(
            kind: HelpCreditEntryKind.received,
            amount: -requestCreditCost,
            title: 'Received help with "${request.displayTitle}"',
            request: request,
            at: completedAt,
          ),
        );
      } else if (!_isClosed(request)) {
        held += requestCreditCost;
        entries.add(
          HelpCreditEntry(
            kind: HelpCreditEntryKind.held,
            amount: -requestCreditCost,
            title: 'On hold for "${request.displayTitle}"',
            request: request,
            at: request.createdAt,
          ),
        );
      }
    }

    entries.sort((first, second) {
      final firstAt = first.at;
      final secondAt = second.at;
      if (firstAt == null || secondAt == null) {
        return 0;
      }
      return secondAt.compareTo(firstAt);
    });
    entries.add(
      const HelpCreditEntry(
        kind: HelpCreditEntryKind.starting,
        amount: startingHelpCredits,
        title: 'Welcome credits',
      ),
    );

    return HelpCreditSummary(
      earned: earned,
      spent: spent,
      held: held,
      entries: List<HelpCreditEntry>.unmodifiable(entries),
    );
  }

  final int earned;
  final int spent;
  final int held;
  final List<HelpCreditEntry> entries;

  int get starting => startingHelpCredits;

  int get balance => startingHelpCredits + earned - spent;

  int get available => balance - held;

  bool get canAffordRequest => available >= requestCreditCost;

  /// How many more credits are needed before another request can be posted.
  int get creditsNeededToPost =>
      canAffordRequest ? 0 : requestCreditCost - available;

  /// Available credits for display; never below zero.
  int get spendable => available < 0 ? 0 : available;

  /// How far below zero the available balance is, e.g. for community supported
  /// accounts that posted without credits.
  int get shortfall => available < 0 ? -available : 0;

  static DateTime? _completedAt(HelpRequestEntity request) {
    if (request.actionLog.isEmpty) {
      return request.createdAt;
    }
    return request.actionLog.last.createdAt;
  }
}

/// Public track record shown to people deciding whether to help a requester.
class UserHelpStats {
  const UserHelpStats({
    required this.helpsGiven,
    required this.helpsReceived,
    required this.requestsPosted,
    required this.averageRating,
    required this.reviewCount,
    required this.trustScore,
  });

  factory UserHelpStats.forUser(
    UserEntity user, {
    required Iterable<HelpRequestEntity> requests,
    required Iterable<ReviewEntity> reviews,
  }) {
    var helpsGiven = 0;
    var helpsReceived = 0;
    var requestsPosted = 0;
    for (final request in requests) {
      final completed =
          request.status == HelpRequestStatus.completed &&
          request.acceptedHelperId != null;
      if (request.requesterId == user.id) {
        requestsPosted += 1;
        if (completed) {
          helpsReceived += 1;
        }
      } else if (completed && request.acceptedHelperId == user.id) {
        helpsGiven += 1;
      }
    }

    var ratingTotal = 0.0;
    var reviewCount = 0;
    for (final review in reviews) {
      if (review.revieweeId != user.id) {
        continue;
      }
      ratingTotal += review.rating;
      reviewCount += 1;
    }

    return UserHelpStats(
      helpsGiven: helpsGiven,
      helpsReceived: helpsReceived,
      requestsPosted: requestsPosted,
      averageRating: reviewCount == 0 ? 0 : ratingTotal / reviewCount,
      reviewCount: reviewCount,
      trustScore: user.trustScore,
    );
  }

  final int helpsGiven;
  final int helpsReceived;
  final int requestsPosted;
  final double averageRating;
  final int reviewCount;
  final double trustScore;

  bool get isNewMember =>
      helpsGiven == 0 && helpsReceived == 0 && reviewCount == 0;

  /// How often this member gives back relative to the help they receive.
  String get giveBackLabel {
    if (helpsReceived == 0) {
      return helpsGiven == 0 ? 'New member' : 'Gives more than receives';
    }
    if (helpsGiven >= helpsReceived) {
      return 'Gives more than receives';
    }
    return 'Received ${helpsReceived - helpsGiven} more than given';
  }
}
