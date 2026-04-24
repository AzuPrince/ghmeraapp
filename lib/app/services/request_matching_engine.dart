import '../models/ghmera_models.dart';

class HelperMatchCandidate {
  const HelperMatchCandidate({
    required this.helper,
    required this.score,
    required this.reasons,
    required this.isFallbackCandidate,
  });

  final UserEntity helper;
  final double score;
  final List<String> reasons;
  final bool isFallbackCandidate;
}

class RequestMatchingEngine {
  const RequestMatchingEngine();

  static const Map<RequestCategory, Set<RequestCategory>> _relatedCategories =
      <RequestCategory, Set<RequestCategory>>{
        RequestCategory.errands: <RequestCategory>{
          RequestCategory.transportation,
          RequestCategory.foodSupport,
          RequestCategory.movingHelp,
        },
        RequestCategory.transportation: <RequestCategory>{
          RequestCategory.errands,
          RequestCategory.elderlySupport,
          RequestCategory.foodSupport,
        },
        RequestCategory.studyHelp: <RequestCategory>{
          RequestCategory.technicalSupport,
          RequestCategory.informationAdvice,
        },
        RequestCategory.technicalSupport: <RequestCategory>{
          RequestCategory.studyHelp,
          RequestCategory.informationAdvice,
        },
        RequestCategory.emotionalSupport: <RequestCategory>{
          RequestCategory.prayerSupport,
          RequestCategory.informationAdvice,
        },
        RequestCategory.prayerSupport: <RequestCategory>{
          RequestCategory.emotionalSupport,
        },
        RequestCategory.childcare: <RequestCategory>{
          RequestCategory.emotionalSupport,
          RequestCategory.foodSupport,
        },
        RequestCategory.elderlySupport: <RequestCategory>{
          RequestCategory.transportation,
          RequestCategory.errands,
          RequestCategory.emotionalSupport,
        },
        RequestCategory.movingHelp: <RequestCategory>{
          RequestCategory.errands,
          RequestCategory.transportation,
        },
        RequestCategory.informationAdvice: <RequestCategory>{
          RequestCategory.studyHelp,
          RequestCategory.technicalSupport,
          RequestCategory.emotionalSupport,
        },
        RequestCategory.foodSupport: <RequestCategory>{
          RequestCategory.errands,
          RequestCategory.transportation,
        },
        RequestCategory.emergencySupport: <RequestCategory>{
          RequestCategory.transportation,
          RequestCategory.elderlySupport,
          RequestCategory.errands,
        },
      };

  List<HelperMatchCandidate> rankHelpers({
    required HelpRequestEntity request,
    required UserEntity requester,
    required Iterable<UserEntity> users,
    int limit = 3,
  }) {
    final strictCandidates = _rankCandidates(
      request: request,
      requester: requester,
      users: users,
      allowUrgencyFallback: false,
    );
    if (strictCandidates.isNotEmpty || !_allowsUrgencyFallback(request)) {
      return strictCandidates.take(limit).toList();
    }

    final relaxedCandidates = _rankCandidates(
      request: request,
      requester: requester,
      users: users,
      allowUrgencyFallback: true,
    );
    return relaxedCandidates.take(limit).toList();
  }

  HelperMatchCandidate? scoreHelper({
    required HelpRequestEntity request,
    required UserEntity requester,
    required UserEntity helper,
    bool allowUrgencyFallback = false,
  }) {
    final isAssignedHelper = request.acceptedHelperId == helper.id;

    if (_isClosedRequest(request) || helper.id == requester.id) {
      return null;
    }

    if (request.acceptedHelperId != null && !isAssignedHelper) {
      return null;
    }

    if (!_canUsersInteract(requester: requester, helper: helper)) {
      return null;
    }

    if (!isAssignedHelper && !_isActiveHelper(helper)) {
      return null;
    }

    if (!isAssignedHelper &&
        request.isHighRisk &&
        !_isHighRiskQualified(helper)) {
      return null;
    }

    final directCategoryMatch = helper.helpCategoriesProvided.contains(
      request.category,
    );
    final relatedCategory = _firstRelatedCategoryMatch(
      helper,
      request.category,
    );
    final emotionalSupportFit =
        request.emotionalSupportMode && _supportsEmotionalSupport(helper);
    final fallbackUrgencyFit =
        !directCategoryMatch &&
        relatedCategory == null &&
        !emotionalSupportFit &&
        allowUrgencyFallback &&
        _allowsUrgencyFallback(request);

    if (!isAssignedHelper &&
        !directCategoryMatch &&
        relatedCategory == null &&
        !emotionalSupportFit &&
        !fallbackUrgencyFit) {
      return null;
    }

    var score = 0.0;
    final reasons = <String>[];

    if (isAssignedHelper) {
      score += 30;
      reasons.add('Already accepted as the active helper for this request');
    }

    if (directCategoryMatch) {
      score += 38;
      reasons.add('Direct ${request.category.label.toLowerCase()} match');
    } else if (relatedCategory != null) {
      score += 20;
      reasons.add(
        'Related experience in ${relatedCategory.label.toLowerCase()}',
      );
    }

    if (emotionalSupportFit) {
      score += 18;
      reasons.add('Profile is set up for emotional or prayer support');
    }

    if (fallbackUrgencyFit) {
      score += 12;
      reasons.add('Available for urgent community support');
    }

    final sameCity =
        _matchesLocation(helper.city, requester.city) ||
        _matchesLocation(helper.city, request.location);
    final sameArea =
        _matchesLocation(helper.area, requester.area) ||
        _matchesLocation(helper.area, request.location);

    if (sameCity) {
      score += 12;
      if (helper.city.trim().isNotEmpty) {
        reasons.add('Based in ${helper.city.trim()}');
      }
    }

    if (sameArea) {
      score += 8;
      if (helper.area.trim().isNotEmpty) {
        reasons.add('Near ${helper.area.trim()}');
      }
    }

    score += helper.serviceRadiusKm.clamp(0, 25) / 2;
    if (helper.serviceRadiusKm >= 10) {
      reasons.add(
        'Covers ${helper.serviceRadiusKm.toStringAsFixed(0)} km service radius',
      );
    }

    score += helper.trustScore * 0.32;
    if (helper.trustScore >= 85) {
      reasons.add('${helper.trustScore.toStringAsFixed(0)} trust score');
    }

    score += helper.averageRating * 5;
    if (helper.averageRating >= 4) {
      reasons.add('${helper.averageRating.toStringAsFixed(1)} average rating');
    }

    score += helper.completedHelpCount.clamp(0, 20) * 0.6;
    if (helper.completedHelpCount >= 5) {
      reasons.add('${helper.completedHelpCount} completed help requests');
    }

    if (helper.trustedHelper) {
      score += 10;
      reasons.add('Trusted helper badge');
    } else if (helper.idVerified) {
      score += 6;
      reasons.add('ID verified');
    }

    if (helper.phoneVerified) {
      score += 2;
    }
    if (helper.emailVerified) {
      score += 1;
    }

    if (request.requiresHomeVisit && helper.idVerified) {
      score += 8;
      reasons.add('Verified for home-visit safety');
    }

    if (request.lateNightSupport &&
        (helper.trustedHelper || helper.idVerified)) {
      score += 6;
      reasons.add('Better suited for late-night coordination');
    }

    if (request.moneyRelated && helper.idVerified) {
      score += 8;
      reasons.add('Verified for money-related support');
    }

    if (helper.helpGivenCount > helper.helpReceivedCount) {
      score += 4;
      reasons.add('Usually gives more support than they request');
    }

    final normalizedScore = score.clamp(0, 99).toDouble();
    return HelperMatchCandidate(
      helper: helper,
      score: normalizedScore,
      reasons: _dedupeReasons(reasons),
      isFallbackCandidate: fallbackUrgencyFit,
    );
  }

  List<HelperMatchCandidate> _rankCandidates({
    required HelpRequestEntity request,
    required UserEntity requester,
    required Iterable<UserEntity> users,
    required bool allowUrgencyFallback,
  }) {
    final candidates = <HelperMatchCandidate>[];
    for (final helper in users) {
      final candidate = scoreHelper(
        request: request,
        requester: requester,
        helper: helper,
        allowUrgencyFallback: allowUrgencyFallback,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    candidates.sort((first, second) {
      final scoreComparison = second.score.compareTo(first.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      final trustComparison = second.helper.trustScore.compareTo(
        first.helper.trustScore,
      );
      if (trustComparison != 0) {
        return trustComparison;
      }

      return second.helper.completedHelpCount.compareTo(
        first.helper.completedHelpCount,
      );
    });

    return candidates;
  }

  bool _isClosedRequest(HelpRequestEntity request) {
    return request.status == HelpRequestStatus.completed ||
        request.status == HelpRequestStatus.canceled;
  }

  bool _canUsersInteract({
    required UserEntity requester,
    required UserEntity helper,
  }) {
    if (requester.blockedUserIds.contains(helper.id) ||
        helper.blockedUserIds.contains(requester.id)) {
      return false;
    }

    const blockedStatuses = <UserRestrictionStatus>{
      UserRestrictionStatus.suspended,
      UserRestrictionStatus.banned,
    };
    return !blockedStatuses.contains(helper.restrictionStatus) &&
        !blockedStatuses.contains(requester.restrictionStatus);
  }

  bool _isActiveHelper(UserEntity helper) {
    return helper.availability;
  }

  bool _isHighRiskQualified(UserEntity helper) {
    return helper.idVerified || helper.trustedHelper;
  }

  bool _supportsEmotionalSupport(UserEntity helper) {
    return helper.helpCategoriesProvided.contains(
          RequestCategory.emotionalSupport,
        ) ||
        helper.helpCategoriesProvided.contains(RequestCategory.prayerSupport);
  }

  RequestCategory? _firstRelatedCategoryMatch(
    UserEntity helper,
    RequestCategory category,
  ) {
    final relatedCategories = _relatedCategories[category];
    if (relatedCategories == null) {
      return null;
    }

    for (final candidate in helper.helpCategoriesProvided) {
      if (relatedCategories.contains(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  bool _allowsUrgencyFallback(HelpRequestEntity request) {
    return request.urgency == UrgencyLevel.high ||
        request.category == RequestCategory.emergencySupport;
  }

  bool _matchesLocation(String left, String right) {
    final normalizedLeft = _normalize(left);
    final normalizedRight = _normalize(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }

    return normalizedLeft == normalizedRight ||
        normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  List<String> _dedupeReasons(List<String> reasons) {
    final seen = <String>{};
    final uniqueReasons = <String>[];
    for (final reason in reasons) {
      if (reason.trim().isEmpty || !seen.add(reason)) {
        continue;
      }

      uniqueReasons.add(reason);
      if (uniqueReasons.length == 5) {
        break;
      }
    }

    return uniqueReasons;
  }
}
