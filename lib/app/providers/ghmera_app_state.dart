import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../database/database.dart';
import '../models/ghmera_models.dart';
import '../services/app_firestore_sync_service.dart';
import '../services/backend_workflow_api_service.dart';
import '../services/request_matching_engine.dart';

class GhmeraAppState extends ChangeNotifier {
  GhmeraAppState() : _currentUserId = AppDatabase.instance.currentUserId {
    if (_currentUserId.trim().isEmpty) {
      _currentUserId = _defaultCurrentUserId;
    }

    _isHydratingRemoteState = true;
    _ensureCurrentUserContext();
    _syncDerivedUserMetrics();

    try {
      final auth = FirebaseAuth.instance;
      _authStateSubscription = auth.authStateChanges().listen((user) {
        _handleAuthStateChange(user);
      });
      _handleAuthStateChange(auth.currentUser, notifyListenersAfter: false);
    } catch (_) {
      _authStateSubscription = null;
    }

    unawaited(_restoreAppStateFromFirestore());
  }

  static const String _defaultCurrentUserId = 'user_current';
  static const int _matchSuggestionLimit = 3;
  static const int reciprocityFloor = -5;
  static const Set<String> _legacyDemoUserIds = <String>{
    _defaultCurrentUserId,
    'user_ama',
    'user_daniel',
    'user_kofi',
    'user_nana',
    'user_zainab',
  };
  static const Set<HelpRequestStatus> _reciprocityTrackedRequestStatuses =
      <HelpRequestStatus>{
        HelpRequestStatus.accepted,
        HelpRequestStatus.inProgress,
        HelpRequestStatus.completed,
      };

  final AppDatabase _database = AppDatabase.instance;
  final AppFirestoreSyncService _appFirestoreSyncService =
      AppFirestoreSyncService();
  final BackendWorkflowApiService _backendWorkflowApiService =
      BackendWorkflowApiService();
  final RequestMatchingEngine _requestMatchingEngine =
      const RequestMatchingEngine();
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<({Map<String, dynamic>? database, bool hasPendingWrites})>?
  _remoteDatabaseSubscription;
  StreamSubscription<Position>? _locationPositionSubscription;
  String _currentUserId;
  bool _isHydratingRemoteState = false;
  Map<String, dynamic>? _pendingLocalDatabase;

  List<UserEntity> get _users => _database.users;
  List<HelpRequestEntity> get _requests => _database.requests;
  List<HelpMatchEntity> get _matches => _database.matches;
  List<MessageThreadEntity> get _threads => _database.threads;
  List<MessageEntity> get _messages => _database.messages;
  List<ReviewEntity> get _reviews => _database.reviews;
  List<ReportEntity> get _reports => _database.reports;
  List<MoodCheckInEntity> get _moodCheckIns => _database.moodCheckIns;
  List<NotificationEntity> get _notifications => _database.notifications;
  List<SupportCircleEntity> get _supportCircles => _database.supportCircles;

  String get currentUserId => _currentUserId;

  UserEntity get currentUser => userById(_currentUserId);

  List<UserEntity> get users => List<UserEntity>.unmodifiable(_users);

  bool isUserAvailableForMatching(UserEntity user, {DateTime? at}) {
    return user.isAvailableAt(at ?? DateTime.now());
  }

  bool get isCurrentUserAvailableForMatching {
    return isUserAvailableForMatching(currentUser);
  }

  bool _isRequestHiddenForCurrentUser(String requestId) {
    return currentUser.hiddenRequestIds.contains(requestId);
  }

  bool _shouldShowCommunityRequest(HelpRequestEntity request) {
    if (request.requesterId == _currentUserId) {
      return false;
    }
    if (_isRequestHiddenForCurrentUser(request.id)) {
      return false;
    }
    if (currentUser.blockedUserIds.contains(request.requesterId)) {
      return false;
    }
    // Once another user has accepted this request, hide it from everyone
    // except the accepted helper themselves.
    if (request.acceptedHelperId != null &&
        request.acceptedHelperId != _currentUserId) {
      return false;
    }
    return true;
  }

  List<HelpRequestEntity> get myRequests {
    final requests =
        _requests
            .where(
              (request) =>
                  request.requesterId == _currentUserId &&
                  !_isRequestHiddenForCurrentUser(request.id),
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return requests;
  }

  List<HelpRequestEntity> get hiddenMyRequests {
    final requests =
        _requests
            .where(
              (request) =>
                  request.requesterId == _currentUserId &&
                  _isRequestHiddenForCurrentUser(request.id),
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return requests;
  }

  List<HelpRequestEntity> get communityRequests {
    final requests = _requests.where(_shouldShowCommunityRequest).toList()
      ..sort(_compareRequests);
    return requests;
  }

  List<HelpRequestEntity> get requestsNeedingMyHelp {
    final visibleRequestsById = <String, HelpRequestEntity>{
      for (final request in _requests)
        if (_shouldShowCommunityRequest(request) &&
            request.status != HelpRequestStatus.completed &&
            request.status != HelpRequestStatus.canceled)
          request.id: request,
    };

    final rankedMatches =
        _matches
            .where(
              (match) =>
                  match.helperId == _currentUserId &&
                  match.status != MatchStatus.declined &&
                  match.status != MatchStatus.disputed,
            )
            .map((match) {
              final request = visibleRequestsById[match.requestId];
              if (request == null) {
                return null;
              }

              return (request: request, match: match);
            })
            .whereType<({HelpRequestEntity request, HelpMatchEntity match})>()
            .toList()
          ..sort((first, second) {
            final scoreComparison = second.match.score.compareTo(
              first.match.score,
            );
            if (scoreComparison != 0) {
              return scoreComparison;
            }

            return _compareRequests(first.request, second.request);
          });

    final requests = <HelpRequestEntity>[];
    final seenRequestIds = <String>{};

    for (final entry in rankedMatches) {
      if (seenRequestIds.add(entry.request.id)) {
        requests.add(entry.request);
      }
    }

    for (final request in visibleRequestsById.values) {
      if (request.acceptedHelperId == _currentUserId &&
          seenRequestIds.add(request.id)) {
        requests.add(request);
      }
    }

    final publicUnmatchedRequests =
        visibleRequestsById.values
            .where(
              (request) =>
                  request.visibility == HelpRequestVisibility.public &&
                  request.acceptedHelperId == null,
            )
            .toList()
          ..sort(_compareRequests);
    for (final request in publicUnmatchedRequests) {
      if (seenRequestIds.add(request.id)) {
        requests.add(request);
      }
    }

    return requests;
  }

  List<HelpMatchEntity> get matchesForMyRequests {
    final matches =
        _matches.where((match) => match.requesterId == _currentUserId).toList()
          ..sort(
            (first, second) =>
                (second.acceptedAt ?? requestById(second.requestId).createdAt)
                    .compareTo(
                      first.acceptedAt ??
                          requestById(first.requestId).createdAt,
                    ),
          );
    return matches;
  }

  List<HelpMatchEntity> get helpingMatches {
    final matches =
        _matches.where((match) => match.helperId == _currentUserId).toList()
          ..sort(
            (first, second) =>
                (second.acceptedAt ?? requestById(second.requestId).createdAt)
                    .compareTo(
                      first.acceptedAt ??
                          requestById(first.requestId).createdAt,
                    ),
          );
    return matches;
  }

  List<MessageThreadEntity> get messageThreads {
    final threads =
        _threads
            .where((thread) => thread.participantIds.contains(_currentUserId))
            .toList()
          ..sort(
            (first, second) =>
                second.lastMessageAt.compareTo(first.lastMessageAt),
          );
    return threads;
  }

  List<MessageEntity> messagesForThread(String threadId) {
    final threadMessages =
        _messages.where((message) => message.threadId == threadId).toList()
          ..sort(
            (first, second) => first.createdAt.compareTo(second.createdAt),
          );
    return threadMessages;
  }

  MessageThreadEntity? threadForRequest(String requestId) {
    for (final thread in _threads) {
      if (thread.requestId == requestId &&
          thread.participantIds.contains(_currentUserId)) {
        return thread;
      }
    }

    return null;
  }

  List<ReviewEntity> get reviewsAboutCurrentUser {
    final reviews =
        _reviews.where((review) => review.revieweeId == _currentUserId).toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return reviews;
  }

  List<NotificationEntity> get currentNotifications {
    final notifications =
        _notifications
            .where((notification) => notification.userId == _currentUserId)
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return notifications;
  }

  List<ReportEntity> get moderationQueue {
    final reports =
        _reports
            .where(
              (report) =>
                  report.status == ReportStatus.open ||
                  report.status == ReportStatus.investigating,
            )
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return reports;
  }

  List<MoodCheckInEntity> get moodHistory {
    final moods =
        _moodCheckIns
            .where((checkIn) => checkIn.userId == _currentUserId)
            .toList()
          ..sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
    return moods;
  }

  List<SupportCircleEntity> get supportCircles =>
      List<SupportCircleEntity>.unmodifiable(_supportCircles);

  List<HelpRequestEntity> get highRiskRequests {
    final requests = _requests.where((request) => request.isHighRisk).toList()
      ..sort(_compareRequests);
    return requests;
  }

  MoodCheckInEntity? get latestMoodCheckIn {
    if (moodHistory.isEmpty) {
      return null;
    }

    return moodHistory.first;
  }

  int get unreadNotificationsCount =>
      currentNotifications.where((notification) => !notification.isRead).length;

  int get hiddenMyRequestsCount => hiddenMyRequests.length;

  List<ReportEntity> get reportsAboutCurrentUser {
    final reports =
        _reports.where((report) {
          return report.targetType == ReportTargetType.user &&
              report.targetId == _currentUserId;
        }).toList()..sort(
          (first, second) => second.createdAt.compareTo(first.createdAt),
        );
    return reports;
  }

  int get activeSafetyReportsAboutCurrentUser =>
      _activeSafetyReportCountForUser(_currentUserId);

  int get suspiciousReviewsAboutCurrentUser =>
      _suspiciousReviewCountForUser(_currentUserId);

  List<String> get currentUserTrustFlags =>
      List<String>.unmodifiable(currentUser.trustFlags);

  bool get hasReciprocityActivity {
    return currentUser.helpGivenCount > 0 ||
        currentUser.helpReceivedCount > 0 ||
        currentUser.completedHelpCount > 0 ||
        currentUser.receivedHelpCount > 0;
  }

  bool get canCreateRequest {
    return currentUser.canBypassReciprocity ||
        currentUser.helpBalance >= reciprocityFloor;
  }

  String get reciprocityMessage {
    if (currentUser.canBypassReciprocity) {
      return 'Your account is exempt from reciprocity holds. You can keep requesting support while the team monitors safety.';
    }

    if (!hasReciprocityActivity) {
      return 'Reciprocity tracking starts after your first matched help exchange.';
    }

    if (currentUser.helpBalance >= 2) {
      return 'Your help balance is healthy. You are contributing back into the community.';
    }

    if (canCreateRequest) {
      return 'You are approaching the reciprocity floor. Offer help soon so you stay above -5.';
    }

    return 'You have received support from the community. Please help someone else before creating another request.';
  }

  double get reciprocityProgress {
    if (!hasReciprocityActivity) {
      return 0;
    }

    final progress = (currentUser.helpBalance - reciprocityFloor) / 10;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  int get reciprocityPercent => (reciprocityProgress * 100).round();

  double get currentUserAverageReview {
    return currentUser.averageRating;
  }

  int get totalUsers => _users.length;

  int get dailyActiveUsers => _users
      .where(
        (user) => isUserAvailableForMatching(user) || user.helpGivenCount > 0,
      )
      .length;

  int get helpRequestsCreated => _requests.length;

  int get helpRequestsCompleted => _requests
      .where((request) => request.status == HelpRequestStatus.completed)
      .length;

  int get reportsCount => _reports.length;

  int get highRiskInteractionCount => highRiskRequests.length;

  int get emotionalSupportUsageCount => _requests
      .where(
        (request) =>
            request.category == RequestCategory.emotionalSupport ||
            request.emotionalSupportMode,
      )
      .length;

  double get currentUserHelpRatio {
    if (currentUser.helpReceivedCount == 0) {
      return currentUser.helpGivenCount.toDouble();
    }

    return currentUser.helpGivenCount / currentUser.helpReceivedCount;
  }

  UserEntity userById(String id) {
    return _users.firstWhere((user) => user.id == id);
  }

  HelpRequestEntity requestById(String id) {
    return _requests.firstWhere((request) => request.id == id);
  }

  UserEntity? helperForRequest(HelpRequestEntity request) {
    final helperId = request.acceptedHelperId;
    if (helperId == null) {
      return null;
    }

    return userById(helperId);
  }

  UserEntity? peerForThread(MessageThreadEntity thread) {
    final otherId = thread.participantIds.firstWhere(
      (participantId) => participantId != _currentUserId,
      orElse: () => _currentUserId,
    );

    if (otherId == _currentUserId) {
      return null;
    }

    return userById(otherId);
  }

  List<UserEntity> helperCandidatesForRequest(HelpRequestEntity request) {
    if (request.acceptedHelperId case final acceptedHelperId?) {
      final acceptedHelper = _findUserById(acceptedHelperId);
      if (acceptedHelper != null) {
        return <UserEntity>[acceptedHelper];
      }
    }

    final requester = _findUserById(request.requesterId);
    if (requester != null) {
      final rankedHelpers = _rankedHelperCandidatesForRequest(
        request,
        requester: requester,
      );
      if (rankedHelpers.isNotEmpty) {
        return rankedHelpers.map((candidate) => candidate.helper).toList();
      }
    }

    final candidateIds = request.suggestedHelperIds;
    if (candidateIds.isNotEmpty) {
      return candidateIds.map(_findUserById).whereType<UserEntity>().toList();
    }

    return const <UserEntity>[];
  }

  List<UserEntity> get potentialHelpers {
    final requestedCategories = currentUser.helpCategoriesRequested.toSet();
    final helpers =
        _users
            .where(
              (user) =>
                  user.id != _currentUserId &&
                  isUserAvailableForMatching(user) &&
                  (requestedCategories.isEmpty ||
                      user.helpCategoriesProvided.any(
                        requestedCategories.contains,
                      )),
            )
            .toList()
          ..sort(
            (first, second) => (second.trustScore + second.averageRating * 10)
                .compareTo(first.trustScore + first.averageRating * 10),
          );
    return helpers;
  }

  List<HelpRequestEntity> get myOpenRequests {
    final requests =
        myRequests
            .where(
              (request) =>
                  request.status != HelpRequestStatus.completed &&
                  request.status != HelpRequestStatus.canceled,
            )
            .toList()
          ..sort(_compareRequests);
    return requests;
  }

  HelpMatchEntity? matchForRequestAndHelper({
    required String requestId,
    required String helperId,
  }) {
    for (final match in _matches) {
      if (match.requestId == requestId && match.helperId == helperId) {
        return match;
      }
    }

    return null;
  }

  HelpMatchEntity? acceptedMatchForRequest(HelpRequestEntity request) {
    final helperId = request.acceptedHelperId;
    if (helperId == null) {
      return null;
    }

    return matchForRequestAndHelper(requestId: request.id, helperId: helperId);
  }

  UserEntity? otherParticipantForRequest(HelpRequestEntity request) {
    if (request.requesterId == _currentUserId) {
      final helperId = request.acceptedHelperId;
      if (helperId == null) {
        return null;
      }

      return _findUserById(helperId);
    }

    return _findUserById(request.requesterId);
  }

  bool isCurrentUserParticipantForRequest(HelpRequestEntity request) {
    return request.requesterId == _currentUserId ||
        request.acceptedHelperId == _currentUserId;
  }

  bool hasCurrentUserConfirmedRequestCompletion(HelpRequestEntity request) {
    if (request.requesterId == _currentUserId) {
      return request.requesterCompletionConfirmed;
    }
    if (request.acceptedHelperId == _currentUserId) {
      return request.helperCompletionConfirmed;
    }

    return false;
  }

  bool canCurrentUserStartRequest(HelpRequestEntity request) {
    return isCurrentUserParticipantForRequest(request) &&
        request.acceptedHelperId != null &&
        request.status == HelpRequestStatus.accepted;
  }

  bool canCurrentUserConfirmRequestCompletion(HelpRequestEntity request) {
    return isCurrentUserParticipantForRequest(request) &&
        request.acceptedHelperId != null &&
        (request.status == HelpRequestStatus.accepted ||
            request.status == HelpRequestStatus.inProgress) &&
        !hasCurrentUserConfirmedRequestCompletion(request);
  }

  bool hasCurrentUserSubmittedReviewForRequest(HelpRequestEntity request) {
    final acceptedMatch = acceptedMatchForRequest(request);
    if (acceptedMatch == null) {
      return false;
    }

    return _reviews.any(
      (review) =>
          review.matchId == acceptedMatch.id &&
          review.reviewerId == _currentUserId,
    );
  }

  bool canCurrentUserSubmitReviewForRequest(HelpRequestEntity request) {
    final requesterCanRateAcceptedHelper =
        request.requesterId == _currentUserId &&
        request.requesterCompletionConfirmed;

    return isCurrentUserParticipantForRequest(request) &&
        request.acceptedHelperId != null &&
        (request.status == HelpRequestStatus.completed ||
            requesterCanRateAcceptedHelper) &&
        !hasCurrentUserSubmittedReviewForRequest(request);
  }

  void setAvailability(bool value) {
    _replaceUser(currentUser.copyWith(availability: value));
    _notifications.insert(
      0,
      NotificationEntity(
        id: 'notification_${_notifications.length + 1}',
        userId: _currentUserId,
        type: NotificationType.adminUpdate,
        title: value ? 'Availability is on' : 'Availability is off',
        message: value
            ? 'You will now appear in helper matching for your selected categories.'
            : 'You will not receive new broadcasts until you turn availability back on.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void toggleAvailability() {
    setAvailability(!currentUser.availability);
  }

  void updateCurrentUserProfile({
    required String fullName,
    required String shortBio,
    required String city,
    required String area,
    String? phone,
    String? profilePhoto,
    bool? usesDeviceLocation,
    int? availabilityStartMinuteOfDay,
    int? availabilityEndMinuteOfDay,
  }) {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final trimmedPhone = phone?.trim();
    final trimmedPhoto = profilePhoto?.trim();
    final normalizedCity = city.trim();
    final normalizedArea = area.trim();
    final resolvedUsesDeviceLocation =
        usesDeviceLocation ?? currentUser.usesDeviceLocation;
    final shouldClearExactLocation =
        !resolvedUsesDeviceLocation ||
        normalizedCity != currentUser.city ||
        normalizedArea != currentUser.area;
    final badges = <VerificationBadge>{...currentUser.verificationBadges};
    if (currentUser.email.trim().isNotEmpty) {
      badges.add(VerificationBadge.emailVerified);
    }
    if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
      badges.add(VerificationBadge.phoneVerified);
    }

    final updatedUser = currentUser.copyWith(
      fullName: trimmedName,
      shortBio: shortBio.trim(),
      city: normalizedCity,
      area: normalizedArea,
      phone: trimmedPhone != null && trimmedPhone.isNotEmpty
          ? trimmedPhone
          : currentUser.phone,
      profilePhoto: trimmedPhoto != null && trimmedPhoto.isNotEmpty
          ? trimmedPhoto
          : currentUser.profilePhoto,
      usesDeviceLocation: resolvedUsesDeviceLocation,
      exactLatitude: shouldClearExactLocation
          ? null
          : currentUser.exactLatitude,
      exactLongitude: shouldClearExactLocation
          ? null
          : currentUser.exactLongitude,
      availabilityStartMinuteOfDay:
          availabilityStartMinuteOfDay ??
          currentUser.availabilityStartMinuteOfDay,
      availabilityEndMinuteOfDay:
          availabilityEndMinuteOfDay ?? currentUser.availabilityEndMinuteOfDay,
      verificationBadges: badges,
    );

    _replaceUser(updatedUser);
    _syncCurrentUserToAuthProfile(updatedUser);
    unawaited(
      _syncLocationTrackingState(
        requestPermissionIfNeeded: updatedUser.usesDeviceLocation,
      ),
    );
    notifyListeners();
  }

  Future<({String city, String area})?> refreshCurrentUserLocationFromDevice({
    bool enableAutoUpdate = true,
    bool requestPermissionIfNeeded = true,
  }) async {
    if (_findUserById(_currentUserId) == null) {
      return null;
    }

    final hasLocationAccess = await _ensureLocationAccess(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
    if (!hasLocationAccess) {
      if (!enableAutoUpdate) {
        await _stopLocationTracking();
      }
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final resolvedLocation = await _resolveLocationFromPosition(position);
      if (resolvedLocation == null) {
        return null;
      }

      _applyCurrentUserDeviceLocation(
        city: resolvedLocation.city,
        area: resolvedLocation.area,
        exactLatitude: resolvedLocation.exactLatitude,
        exactLongitude: resolvedLocation.exactLongitude,
        enableAutoUpdate: enableAutoUpdate,
      );

      if (enableAutoUpdate) {
        await _ensureLocationTracking(requestPermissionIfNeeded: false);
      } else {
        await _stopLocationTracking();
      }

      return (city: resolvedLocation.city, area: resolvedLocation.area);
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshHelpRequests() async {
    final rawDatabase = await _appFirestoreSyncService.loadDatabase();
    if (rawDatabase == null) {
      return;
    }

    _applyRemoteDatabase(rawDatabase, hasPendingWrites: false);
  }

  void toggleCurrentUserProvidedCategory(RequestCategory category) {
    final categories = List<RequestCategory>.from(
      currentUser.helpCategoriesProvided,
    );
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }

    _replaceUser(currentUser.copyWith(helpCategoriesProvided: categories));
    notifyListeners();
  }

  void toggleCurrentUserRequestedCategory(RequestCategory category) {
    final categories = List<RequestCategory>.from(
      currentUser.helpCategoriesRequested,
    );
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }

    _replaceUser(currentUser.copyWith(helpCategoriesRequested: categories));
    notifyListeners();
  }

  bool hideRequestFromCurrentUser(String requestId) {
    if (_isRequestHiddenForCurrentUser(requestId) ||
        !_requests.any((request) => request.id == requestId)) {
      return false;
    }

    final hiddenRequestIds = List<String>.from(currentUser.hiddenRequestIds)
      ..add(requestId);
    _replaceUser(currentUser.copyWith(hiddenRequestIds: hiddenRequestIds));
    notifyListeners();
    return true;
  }

  bool unhideRequestForCurrentUser(String requestId) {
    if (!_isRequestHiddenForCurrentUser(requestId)) {
      return false;
    }

    final hiddenRequestIds = List<String>.from(currentUser.hiddenRequestIds)
      ..remove(requestId);
    _replaceUser(currentUser.copyWith(hiddenRequestIds: hiddenRequestIds));
    notifyListeners();
    return true;
  }

  bool blockUserAccount(String userId, {String? requestId}) {
    if (userId == _currentUserId) {
      return false;
    }

    final blockedUser = _findUserById(userId);
    if (blockedUser == null) {
      return false;
    }

    final blockedUserIds = List<String>.from(currentUser.blockedUserIds);
    final hiddenRequestIds = List<String>.from(currentUser.hiddenRequestIds);
    var didChange = false;

    if (!blockedUserIds.contains(userId)) {
      blockedUserIds.add(userId);
      didChange = true;
    }

    if (requestId != null &&
        requestId.isNotEmpty &&
        !hiddenRequestIds.contains(requestId)) {
      hiddenRequestIds.add(requestId);
      didChange = true;
    }

    if (!didChange) {
      return false;
    }

    _replaceUser(
      currentUser.copyWith(
        blockedUserIds: blockedUserIds,
        hiddenRequestIds: hiddenRequestIds,
      ),
    );
    _notifications.insert(
      0,
      NotificationEntity(
        id: 'notification_${_notifications.length + 1}',
        userId: _currentUserId,
        type: NotificationType.safetyAlert,
        title: 'Account blocked',
        message:
            'You blocked ${blockedUser.fullName}. Their requests will no longer appear to you.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  void toggleCurrentUserSupportCircleMembership(String circleId) {
    final index = _supportCircles.indexWhere((circle) => circle.id == circleId);
    if (index == -1) {
      return;
    }

    final circle = _supportCircles[index];
    final memberIds = List<String>.from(circle.memberIds);
    if (memberIds.contains(_currentUserId)) {
      memberIds.remove(_currentUserId);
    } else {
      memberIds.add(_currentUserId);
    }

    _supportCircles[index] = circle.copyWith(memberIds: memberIds);
    notifyListeners();
  }

  void updateCurrentUserPrivacySettings(PrivacySettings settings) {
    _replaceUser(currentUser.copyWith(privacySettings: settings));
    notifyListeners();
  }

  void setCurrentSessionDevice(String sessionId) {
    final sessions = currentUser.sessions;
    if (sessions.isEmpty ||
        !sessions.any((session) => session.id == sessionId)) {
      return;
    }

    final now = DateTime.now();
    final updatedSessions = sessions
        .map(
          (session) => session.copyWith(
            isCurrent: session.id == sessionId,
            lastActive: session.id == sessionId ? now : session.lastActive,
          ),
        )
        .toList();

    _replaceUser(currentUser.copyWith(sessions: updatedSessions));
    notifyListeners();
  }

  void removeSessionDevice(String sessionId) {
    final sessions = List<SessionDevice>.from(currentUser.sessions);
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index == -1 || sessions.length <= 1) {
      return;
    }

    final removedWasCurrent = sessions[index].isCurrent;
    sessions.removeAt(index);

    if (removedWasCurrent && sessions.isNotEmpty) {
      sessions[0] = sessions[0].copyWith(
        isCurrent: true,
        lastActive: DateTime.now(),
      );
    }

    var currentMarked = false;
    final normalizedSessions = sessions.map((session) {
      if (!session.isCurrent) {
        return session;
      }
      if (currentMarked) {
        return session.copyWith(isCurrent: false);
      }
      currentMarked = true;
      return session;
    }).toList();

    if (!currentMarked && normalizedSessions.isNotEmpty) {
      normalizedSessions[0] = normalizedSessions[0].copyWith(isCurrent: true);
    }

    _replaceUser(currentUser.copyWith(sessions: normalizedSessions));
    notifyListeners();
  }

  void recordMood(MoodLevel mood) {
    final now = DateTime.now();
    _moodCheckIns.insert(
      0,
      MoodCheckInEntity(
        id: 'mood_${_moodCheckIns.length + 1}',
        userId: _currentUserId,
        moodLevel: mood,
        createdAt: now,
        note: mood.needsSupport
            ? 'Support options surfaced automatically.'
            : 'Community wellness check-in completed.',
      ),
    );

    if (mood.needsSupport) {
      _notifications.insert(
        0,
        NotificationEntity(
          id: 'notification_${_notifications.length + 1}',
          userId: _currentUserId,
          type: NotificationType.emotionalCheckInReminder,
          title: 'Support options are ready',
          message:
              'You marked yourself as ${mood.label.toLowerCase()}. Emotional support requests and support circles are now highlighted.',
          createdAt: now,
        ),
      );
    }

    notifyListeners();
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );
    if (index == -1) {
      return;
    }

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();
  }

  void markCurrentNotificationsRead() {
    var didChange = false;

    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];
      if (notification.userId != _currentUserId || notification.isRead) {
        continue;
      }

      _notifications[index] = notification.copyWith(isRead: true);
      didChange = true;
    }

    if (didChange) {
      notifyListeners();
    }
  }

  Future<void> acceptHelpingOpportunity(String matchId) async {
    final matchIndex = _matches.indexWhere((match) => match.id == matchId);
    if (matchIndex == -1) {
      return;
    }

    final match = _matches[matchIndex];
    if (match.helperId != _currentUserId) {
      return;
    }

    await volunteerForHelpRequest(match.requestId);
  }

  Future<bool> volunteerForHelpRequest(String requestId) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'volunteer_for_help_request',
      payload: <String, dynamic>{'requestId': requestId},
    );
    return response?.result?['matched'] == true;
  }

  Future<bool> requestHelperForMyRequest({
    required String requestId,
    required String helperId,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'request_helper_for_my_request',
      payload: <String, dynamic>{'requestId': requestId, 'helperId': helperId},
    );
    return response?.result?['matched'] == true;
  }

  Future<bool> startCurrentUserRequestWork(String requestId) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'start_request_work',
      payload: <String, dynamic>{'requestId': requestId},
    );
    return response?.result?['started'] == true;
  }

  Future<bool> confirmCurrentUserRequestCompletion(String requestId) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'confirm_request_completion',
      payload: <String, dynamic>{'requestId': requestId},
    );
    return response?.result?['confirmed'] == true;
  }

  Future<ReviewEntity?> submitReviewForRequest({
    required String requestId,
    required int helpfulness,
    required int respectfulness,
    required int safety,
    required int reliability,
    required int accuracy,
    required String feedback,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'submit_review_for_request',
      payload: <String, dynamic>{
        'requestId': requestId,
        'helpfulness': helpfulness,
        'respectfulness': respectfulness,
        'safety': safety,
        'reliability': reliability,
        'accuracy': accuracy,
        'feedback': feedback,
      },
    );
    final reviewId = response?.result?['reviewId']?.toString();
    if (reviewId == null || reviewId.isEmpty) {
      return null;
    }

    for (final review in _reviews) {
      if (review.id == reviewId) {
        return review;
      }
    }
    return null;
  }

  Future<ReportEntity?> submitParticipantSafetyReportForRequest({
    required String requestId,
    required String reason,
    required String details,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'submit_participant_safety_report',
      payload: <String, dynamic>{
        'requestId': requestId,
        'reason': reason,
        'details': details,
      },
    );
    final reportId = response?.result?['reportId']?.toString();
    if (reportId == null || reportId.isEmpty) {
      return null;
    }

    for (final report in _reports) {
      if (report.id == reportId) {
        return report;
      }
    }
    return null;
  }

  Future<bool> sendMessage({
    required String threadId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return false;
    }

    final response = await _applyBackendWorkflowOperation(
      operation: 'send_message',
      payload: <String, dynamic>{
        'threadId': threadId,
        'content': trimmedContent,
      },
    );
    return response?.result?['messageId'] != null;
  }

  Future<HelpRequestEntity?> createHelpRequest({
    required String title,
    required String description,
    required RequestCategory category,
    required UrgencyLevel urgency,
    required String location,
    required String preferredTime,
    required HelpRequestVisibility visibility,
    required String attachmentLabel,
    required bool emotionalSupportMode,
    required bool requiresHomeVisit,
    required bool lateNightSupport,
    required bool moneyRelated,
    required bool emergencyOverride,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'create_help_request',
      payload: <String, dynamic>{
        'title': title,
        'description': description,
        'category': category.name,
        'urgency': urgency.name,
        'location': location,
        'preferredTime': preferredTime,
        'visibility': visibility.name,
        'attachmentLabel': attachmentLabel,
        'emotionalSupportMode': emotionalSupportMode,
        'requiresHomeVisit': requiresHomeVisit,
        'lateNightSupport': lateNightSupport,
        'moneyRelated': moneyRelated,
        'emergencyOverride': emergencyOverride,
      },
    );
    final requestId = response?.result?['requestId']?.toString();
    if (requestId == null || requestId.isEmpty) {
      return null;
    }

    for (final request in _requests) {
      if (request.id == requestId) {
        return request;
      }
    }
    return null;
  }

  Future<HelpRequestEntity?> updateMyHelpRequest({
    required String requestId,
    required String title,
    required String description,
    required RequestCategory category,
    required UrgencyLevel urgency,
    required String location,
    required String preferredTime,
    required HelpRequestVisibility visibility,
    required String attachmentLabel,
    required bool emotionalSupportMode,
    required bool requiresHomeVisit,
    required bool lateNightSupport,
    required bool moneyRelated,
    required bool emergencyOverride,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'update_help_request',
      payload: <String, dynamic>{
        'requestId': requestId,
        'title': title,
        'description': description,
        'category': category.name,
        'urgency': urgency.name,
        'location': location,
        'preferredTime': preferredTime,
        'visibility': visibility.name,
        'attachmentLabel': attachmentLabel,
        'emotionalSupportMode': emotionalSupportMode,
        'requiresHomeVisit': requiresHomeVisit,
        'lateNightSupport': lateNightSupport,
        'moneyRelated': moneyRelated,
        'emergencyOverride': emergencyOverride,
      },
    );
    final updatedRequestId = response?.result?['requestId']?.toString();
    if (updatedRequestId == null || updatedRequestId.isEmpty) {
      return null;
    }

    for (final request in _requests) {
      if (request.id == updatedRequestId) {
        return request;
      }
    }
    return null;
  }

  Future<bool> deleteMyHelpRequest(String requestId) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'delete_help_request',
      payload: <String, dynamic>{'requestId': requestId},
    );
    return response?.result?['deleted'] == true;
  }

  Future<bool> cancelMyAcceptedRequest(String requestId) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'cancel_accepted_request',
      payload: <String, dynamic>{'requestId': requestId},
    );
    return response?.result?['canceled'] == true;
  }

  Future<ReportEntity?> reportUserAccount({
    required String userId,
    required String reason,
    required String details,
    String? requestId,
  }) async {
    final response = await _applyBackendWorkflowOperation(
      operation: 'report_user_account',
      payload: <String, dynamic>{
        'userId': userId,
        'reason': reason,
        'details': details,
        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
      },
    );
    final reportId = response?.result?['reportId']?.toString();
    if (reportId == null || reportId.isEmpty) {
      return null;
    }

    for (final report in _reports) {
      if (report.id == reportId) {
        return report;
      }
    }
    return null;
  }

  List<HelperMatchCandidate> _rankedHelperCandidatesForRequest(
    HelpRequestEntity request, {
    required UserEntity requester,
  }) {
    return _requestMatchingEngine.rankHelpers(
      request: request,
      requester: requester,
      users: _users,
      limit: _matchSuggestionLimit,
    );
  }

  int _compareRequests(HelpRequestEntity first, HelpRequestEntity second) {
    final urgencyScore = <UrgencyLevel, int>{
      UrgencyLevel.high: 3,
      UrgencyLevel.medium: 2,
      UrgencyLevel.low: 1,
    };

    final urgencyComparison = urgencyScore[second.urgency]!.compareTo(
      urgencyScore[first.urgency]!,
    );
    if (urgencyComparison != 0) {
      return urgencyComparison;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  void _replaceUser(UserEntity updatedUser) {
    _database.replaceUser(updatedUser);
  }

  Future<BackendWorkflowApiResult?> _applyBackendWorkflowOperation({
    required String operation,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (_isHydratingRemoteState) {
      return null;
    }

    final localDatabase = _database.toMap(
      currentUserEmail: _resolvedCurrentUserEmail,
    );

    try {
      final response = await _backendWorkflowApiService.applyOperation(
        operation: operation,
        currentUserId: _currentUserId,
        database: localDatabase,
        payload: payload,
      );

      _isHydratingRemoteState = true;
      try {
        _database.hydrateFromMap(response.database);
        _currentUserId = _database.currentUserId;
      } finally {
        _isHydratingRemoteState = false;
      }

      notifyListeners();
      return response;
    } catch (error, stackTrace) {
      debugPrint('Workflow API operation "$operation" failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  void _persistAppState() {
    if (_isHydratingRemoteState) {
      return;
    }

    final localDatabase = _database.toMap(
      currentUserEmail: _resolvedCurrentUserEmail,
    );
    _pendingLocalDatabase = localDatabase;

    unawaited(
      _appFirestoreSyncService.syncDatabase(
        database: localDatabase,
        users: _users,
        currentUserId: _currentUserId,
      ),
    );
  }

  void _startFirestoreLiveSync() {
    unawaited(_remoteDatabaseSubscription?.cancel());
    _remoteDatabaseSubscription = _appFirestoreSyncService
        .watchDatabase()
        .listen(
          (remoteDatabase) {
            final rawDatabase = remoteDatabase.database;
            if (rawDatabase == null) {
              return;
            }

            _applyRemoteDatabase(
              rawDatabase,
              hasPendingWrites: remoteDatabase.hasPendingWrites,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Failed to watch Firestore app state: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _applyRemoteDatabase(
    Map<String, dynamic> rawDatabase, {
    required bool hasPendingWrites,
  }) {
    final localDatabase = _database.toMap(
      currentUserEmail: _resolvedCurrentUserEmail,
    );
    if (_deepEquals(localDatabase, rawDatabase)) {
      if (_pendingLocalDatabase != null &&
          _deepEquals(_pendingLocalDatabase, rawDatabase) &&
          !hasPendingWrites) {
        _pendingLocalDatabase = null;
      }
      return;
    }

    if (_pendingLocalDatabase != null) {
      if (_deepEquals(_pendingLocalDatabase, rawDatabase)) {
        if (!hasPendingWrites) {
          _pendingLocalDatabase = null;
        }
      }
      return;
    }

    if (hasPendingWrites) {
      return;
    }

    _isHydratingRemoteState = true;
    try {
      _database.hydrateFromMap(rawDatabase);
      _currentUserId = _database.currentUserId;

      final authUser = Firebase.apps.isNotEmpty
          ? FirebaseAuth.instance.currentUser
          : null;
      if (authUser != null) {
        final syncedUser = _upsertCurrentUserFromAuth(authUser);
        _currentUserId = syncedUser.id;
        _removeLegacyDemoData();
        _database.currentUserId = _currentUserId;
      } else {
        _ensureCurrentUserContext();
      }

      _syncDerivedUserMetrics();
      super.notifyListeners();
      unawaited(_syncLocationTrackingState(requestPermissionIfNeeded: false));
    } catch (error, stackTrace) {
      debugPrint('Failed to apply remote Firestore app state: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isHydratingRemoteState = false;
    }
  }

  Future<void> _restoreAppStateFromFirestore() async {
    try {
      final rawDatabase = await _appFirestoreSyncService.loadDatabase();
      if (rawDatabase != null) {
        _database.hydrateFromMap(rawDatabase);
        _currentUserId = _database.currentUserId;
      }

      final authUser = Firebase.apps.isNotEmpty
          ? FirebaseAuth.instance.currentUser
          : null;
      if (authUser != null) {
        final syncedUser = _upsertCurrentUserFromAuth(authUser);
        _currentUserId = syncedUser.id;
        _removeLegacyDemoData();
        _database.currentUserId = _currentUserId;
      } else {
        _ensureCurrentUserContext();
      }

      _startFirestoreLiveSync();
      await _syncLocationTrackingState();
    } catch (error, stackTrace) {
      debugPrint('Failed to restore Firestore app state: $error');
      debugPrintStack(stackTrace: stackTrace);
      _ensureCurrentUserContext();
    } finally {
      _isHydratingRemoteState = false;
    }

    notifyListeners();
  }

  void _handleAuthStateChange(
    User? authUser, {
    bool notifyListenersAfter = true,
  }) {
    var didChange = false;

    if (authUser != null) {
      final syncedUser = _upsertCurrentUserFromAuth(authUser);
      didChange = true;
      if (_currentUserId != syncedUser.id) {
        _currentUserId = syncedUser.id;
        didChange = true;
      }
      _removeLegacyDemoData();
      _database.currentUserId = _currentUserId;
    } else {
      final previousId = _currentUserId;
      _ensureCurrentUserContext();
      didChange = didChange || previousId != _currentUserId;
    }

    if (!didChange) {
      return;
    }

    unawaited(_syncLocationTrackingState());
    _startFirestoreLiveSync();
    _syncDerivedUserMetrics();

    if (notifyListenersAfter) {
      notifyListeners();
    } else {
      _persistAppState();
    }
  }

  String? get _resolvedCurrentUserEmail {
    if (Firebase.apps.isNotEmpty) {
      final authEmail = FirebaseAuth.instance.currentUser?.email
          ?.trim()
          .toLowerCase();
      if (authEmail != null && authEmail.isNotEmpty) {
        return authEmail;
      }
    }

    for (final user in _users) {
      if (user.id != _currentUserId) {
        continue;
      }

      final email = user.email.trim().toLowerCase();
      if (email.isNotEmpty) {
        return email;
      }
      break;
    }

    return null;
  }

  @override
  void notifyListeners() {
    _syncDerivedUserMetrics();
    _persistAppState();
    super.notifyListeners();
  }

  void _syncDerivedUserMetrics() {
    for (var index = 0; index < _users.length; index++) {
      final user = _users[index];
      final helpGivenCount = _requests.where((request) {
        return _requestCountsTowardReciprocity(request) &&
            request.acceptedHelperId == user.id;
      }).length;
      final helpReceivedCount = _requests.where((request) {
        return _requestCountsTowardReciprocity(request) &&
            request.requesterId == user.id;
      }).length;
      final completedHelpCount = _requests.where((request) {
        return _requestCountsTowardCompletedSupport(request) &&
            request.acceptedHelperId == user.id;
      }).length;
      final receivedHelpCount = _requests.where((request) {
        return _requestCountsTowardCompletedSupport(request) &&
            request.requesterId == user.id;
      }).length;
      final reviewsAboutUser = _reviews.where(
        (review) => review.revieweeId == user.id,
      );
      final averageRating = _averageRatingForReviews(reviewsAboutUser);
      final trustFlags = _buildTrustFlags(
        user: user,
        averageRating: averageRating,
        completedHelpCount: completedHelpCount,
      );
      final trustScore = _calculateTrustScore(
        user: user,
        averageRating: averageRating,
        completedHelpCount: completedHelpCount,
      );

      if (user.helpGivenCount == helpGivenCount &&
          user.helpReceivedCount == helpReceivedCount &&
          user.completedHelpCount == completedHelpCount &&
          user.receivedHelpCount == receivedHelpCount &&
          user.averageRating == averageRating &&
          user.trustScore == trustScore &&
          _listEquals(user.trustFlags, trustFlags)) {
        continue;
      }

      _users[index] = user.copyWith(
        helpGivenCount: helpGivenCount,
        helpReceivedCount: helpReceivedCount,
        completedHelpCount: completedHelpCount,
        receivedHelpCount: receivedHelpCount,
        averageRating: averageRating,
        trustScore: trustScore,
        trustFlags: trustFlags,
      );
    }
  }

  double _averageRatingForReviews(Iterable<ReviewEntity> reviews) {
    var total = 0.0;
    var count = 0;
    for (final review in reviews) {
      total += review.rating;
      count += 1;
    }

    if (count == 0) {
      return 0;
    }

    return total / count;
  }

  List<String> _buildTrustFlags({
    required UserEntity user,
    required double averageRating,
    required int completedHelpCount,
  }) {
    final activeSafetyReports = _activeSafetyReportCountForUser(user.id);
    final suspiciousReviews = _suspiciousReviewCountForUser(user.id);
    final flags = <String>[
      if (user.trustedHelper) 'Trusted helper badge',
      if (user.idVerified) 'ID verified',
      if (user.phoneVerified) 'Phone verified',
      if (completedHelpCount >= 5) '$completedHelpCount completed help records',
      if (averageRating >= 4)
        '${averageRating.toStringAsFixed(1)} average review',
      if (activeSafetyReports > 0)
        '$activeSafetyReports active safety report${activeSafetyReports == 1 ? '' : 's'}',
      if (suspiciousReviews > 0)
        '$suspiciousReviews suspicious review flag${suspiciousReviews == 1 ? '' : 's'}',
      if (user.blockedUserIds.isNotEmpty)
        '${user.blockedUserIds.length} blocked account safeguard${user.blockedUserIds.length == 1 ? '' : 's'}',
      if (user.mutedUserIds.isNotEmpty)
        '${user.mutedUserIds.length} muted conversation safeguard${user.mutedUserIds.length == 1 ? '' : 's'}',
    ];
    return flags;
  }

  double _calculateTrustScore({
    required UserEntity user,
    required double averageRating,
    required int completedHelpCount,
  }) {
    final activeSafetyReports = _activeSafetyReportCountForUser(user.id);
    final suspiciousReviews = _suspiciousReviewCountForUser(user.id);

    final hasReputationActivity =
        averageRating > 0 ||
        completedHelpCount > 0 ||
        user.helpGivenCount > 0 ||
        user.helpReceivedCount > 0 ||
        activeSafetyReports > 0 ||
        suspiciousReviews > 0;
    if (!hasReputationActivity) {
      return 0;
    }

    var score = 0.0;
    if (averageRating > 0) {
      score += (averageRating / 5) * 55;
    }
    score += completedHelpCount.clamp(0, 20) * 1.5;
    if (user.helpGivenCount > 0 || user.helpReceivedCount > 0) {
      score += user.helpBalance.clamp(-5, 10) * 1.2;
    }
    if (user.emailVerified) {
      score += 6;
    }
    if (user.phoneVerified) {
      score += 8;
    }
    if (user.idVerified) {
      score += 10;
    }
    if (user.trustedHelper) {
      score += 10;
    }
    score -= activeSafetyReports * 12;
    score -= suspiciousReviews * 8;
    score -= user.blockedUserIds.length * 1.5;
    score -= user.mutedUserIds.length * 0.5;

    return score.clamp(0, 99).toDouble();
  }

  bool _listEquals(List<String> first, List<String> second) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  bool _deepEquals(Object? first, Object? second) {
    if (identical(first, second)) {
      return true;
    }
    if (first is num && second is num) {
      return first.toDouble() == second.toDouble();
    }
    if (first is List && second is List) {
      if (first.length != second.length) {
        return false;
      }

      for (var index = 0; index < first.length; index++) {
        if (!_deepEquals(first[index], second[index])) {
          return false;
        }
      }

      return true;
    }
    if (first is Map && second is Map) {
      if (first.length != second.length) {
        return false;
      }

      for (final key in first.keys) {
        if (!second.containsKey(key) || !_deepEquals(first[key], second[key])) {
          return false;
        }
      }

      return true;
    }

    return first == second;
  }

  int _activeSafetyReportCountForUser(String userId) {
    return _reports.where((report) {
      return report.targetType == ReportTargetType.user &&
          report.targetId == userId &&
          (report.status == ReportStatus.open ||
              report.status == ReportStatus.investigating);
    }).length;
  }

  int _suspiciousReviewCountForUser(String userId) {
    return _reviews
        .where(
          (review) => review.revieweeId == userId && review.flaggedSuspicious,
        )
        .length;
  }

  bool _requestCountsTowardReciprocity(HelpRequestEntity request) {
    return request.acceptedHelperId != null &&
        _reciprocityTrackedRequestStatuses.contains(request.status);
  }

  bool _requestCountsTowardCompletedSupport(HelpRequestEntity request) {
    return request.acceptedHelperId != null &&
        request.status == HelpRequestStatus.completed;
  }

  UserEntity? _findUserById(String id) {
    final index = _users.indexWhere((user) => user.id == id);
    if (index == -1) {
      return null;
    }

    return _users[index];
  }

  void _removeLegacyDemoData() {
    final demoUserIds = _users
        .map((user) => user.id)
        .where(_legacyDemoUserIds.contains)
        .toSet();
    if (demoUserIds.isEmpty) {
      return;
    }

    final removedRequestIds = <String>{};
    final sanitizedRequests = <HelpRequestEntity>[];
    for (final request in _requests) {
      if (demoUserIds.contains(request.requesterId)) {
        removedRequestIds.add(request.id);
        continue;
      }

      final filteredSuggestedHelperIds = request.suggestedHelperIds
          .where((helperId) => !demoUserIds.contains(helperId))
          .toList();
      final acceptedHelperWasDemo =
          request.acceptedHelperId != null &&
          demoUserIds.contains(request.acceptedHelperId);
      final filteredActionLog = request.actionLog
          .where((entry) => !demoUserIds.contains(entry.actorId))
          .toList();
      final shouldResetToOpen =
          request.acceptedHelperId == null &&
          request.status == HelpRequestStatus.matching &&
          filteredSuggestedHelperIds.isEmpty;
      final normalizedStatus = (acceptedHelperWasDemo || shouldResetToOpen)
          ? (filteredSuggestedHelperIds.isNotEmpty
                ? HelpRequestStatus.matching
                : HelpRequestStatus.open)
          : request.status;

      sanitizedRequests.add(
        request.copyWith(
          clearAcceptedHelper: acceptedHelperWasDemo,
          status: normalizedStatus,
          requesterCompletionConfirmed: acceptedHelperWasDemo
              ? false
              : request.requesterCompletionConfirmed,
          helperCompletionConfirmed: acceptedHelperWasDemo
              ? false
              : request.helperCompletionConfirmed,
          contactConsentFromRequester: acceptedHelperWasDemo
              ? false
              : request.contactConsentFromRequester,
          contactConsentFromHelper: acceptedHelperWasDemo
              ? false
              : request.contactConsentFromHelper,
          suggestedHelperIds: filteredSuggestedHelperIds,
          actionLog: filteredActionLog,
        ),
      );
    }
    _requests
      ..clear()
      ..addAll(sanitizedRequests);

    final removedMatchIds = _matches
        .where(
          (match) =>
              removedRequestIds.contains(match.requestId) ||
              demoUserIds.contains(match.requesterId) ||
              demoUserIds.contains(match.helperId),
        )
        .map((match) => match.id)
        .toSet();
    _matches.removeWhere((match) => removedMatchIds.contains(match.id));

    final removedThreadIds = _threads
        .where(
          (thread) =>
              removedRequestIds.contains(thread.requestId) ||
              thread.participantIds.any(demoUserIds.contains),
        )
        .map((thread) => thread.id)
        .toSet();
    _threads.removeWhere((thread) => removedThreadIds.contains(thread.id));

    _messages.removeWhere(
      (message) =>
          removedThreadIds.contains(message.threadId) ||
          demoUserIds.contains(message.senderId),
    );
    _reviews.removeWhere(
      (review) =>
          removedMatchIds.contains(review.matchId) ||
          demoUserIds.contains(review.reviewerId) ||
          demoUserIds.contains(review.revieweeId),
    );
    _reports.removeWhere(
      (report) =>
          demoUserIds.contains(report.reporterId) ||
          (report.targetType == ReportTargetType.user &&
              demoUserIds.contains(report.targetId)) ||
          (report.targetType == ReportTargetType.request &&
              removedRequestIds.contains(report.targetId)) ||
          (report.targetType == ReportTargetType.chat &&
              removedThreadIds.contains(report.targetId)),
    );
    _moodCheckIns.removeWhere(
      (checkIn) => demoUserIds.contains(checkIn.userId),
    );
    _notifications.removeWhere(
      (notification) => demoUserIds.contains(notification.userId),
    );

    final sanitizedSupportCircles = <SupportCircleEntity>[];
    for (final circle in _supportCircles) {
      final filteredMemberIds = circle.memberIds
          .where((memberId) => !demoUserIds.contains(memberId))
          .toList();
      if (filteredMemberIds.isEmpty) {
        continue;
      }

      sanitizedSupportCircles.add(
        circle.copyWith(memberIds: filteredMemberIds),
      );
    }
    _supportCircles
      ..clear()
      ..addAll(sanitizedSupportCircles);

    final sanitizedUsers = <UserEntity>[];
    for (final user in _users) {
      if (demoUserIds.contains(user.id)) {
        continue;
      }

      sanitizedUsers.add(
        user.copyWith(
          blockedUserIds: user.blockedUserIds
              .where((userId) => !demoUserIds.contains(userId))
              .toList(),
          mutedUserIds: user.mutedUserIds
              .where((userId) => !demoUserIds.contains(userId))
              .toList(),
          hiddenRequestIds: user.hiddenRequestIds
              .where((requestId) => !removedRequestIds.contains(requestId))
              .toList(),
        ),
      );
    }
    _users
      ..clear()
      ..addAll(sanitizedUsers);

    _ensureCurrentUserContext();
  }

  Future<void> _syncLocationTrackingState({
    bool requestPermissionIfNeeded = true,
  }) async {
    final user = _findUserById(_currentUserId);
    if (user == null) {
      await _stopLocationTracking();
      return;
    }

    if (!user.usesDeviceLocation) {
      await _stopLocationTracking();
      return;
    }

    await refreshCurrentUserLocationFromDevice(
      enableAutoUpdate: true,
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
  }

  Future<bool> _ensureLocationAccess({
    bool requestPermissionIfNeeded = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied &&
          requestPermissionIfNeeded) {
        permission = await Geolocator.requestPermission();
      }

      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureLocationTracking({
    bool requestPermissionIfNeeded = true,
  }) async {
    if (_locationPositionSubscription != null) {
      return;
    }

    final hasLocationAccess = await _ensureLocationAccess(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
    if (!hasLocationAccess) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _locationPositionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            unawaited(_handleLocationPositionUpdate(position));
          },
        );
  }

  Future<void> _stopLocationTracking() async {
    await _locationPositionSubscription?.cancel();
    _locationPositionSubscription = null;
  }

  Future<void> _handleLocationPositionUpdate(Position position) async {
    final user = _findUserById(_currentUserId);
    if (user == null || !user.usesDeviceLocation) {
      return;
    }

    final resolvedLocation = await _resolveLocationFromPosition(position);
    if (resolvedLocation == null) {
      return;
    }

    _applyCurrentUserDeviceLocation(
      city: resolvedLocation.city,
      area: resolvedLocation.area,
      exactLatitude: resolvedLocation.exactLatitude,
      exactLongitude: resolvedLocation.exactLongitude,
      enableAutoUpdate: true,
    );
  }

  Future<
    ({String city, String area, double exactLatitude, double exactLongitude})?
  >
  _resolveLocationFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final city = _joinDistinctLocationParts([
        placemark?.locality,
        placemark?.subAdministrativeArea,
        placemark?.administrativeArea,
        placemark?.country,
      ]);
      final area = _firstNonEmptyLocationPart([
        placemark?.thoroughfare,
        placemark?.street,
        placemark?.name,
      ]);

      if (city.isEmpty && area.isEmpty) {
        return null;
      }

      return (
        city: city,
        area: area,
        exactLatitude: position.latitude,
        exactLongitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  String _firstNonEmptyLocationPart(Iterable<String?> values) {
    for (final value in values) {
      final trimmedValue = value?.trim() ?? '';
      if (trimmedValue.isNotEmpty) {
        return trimmedValue;
      }
    }

    return '';
  }

  String _joinDistinctLocationParts(Iterable<String?> values) {
    final parts = <String>[];
    final seenValues = <String>{};

    for (final value in values) {
      final trimmedValue = value?.trim() ?? '';
      if (trimmedValue.isEmpty) {
        continue;
      }

      final normalizedValue = trimmedValue.toLowerCase();
      if (!seenValues.add(normalizedValue)) {
        continue;
      }

      parts.add(trimmedValue);
    }

    return parts.join(', ');
  }

  void _applyCurrentUserDeviceLocation({
    required String city,
    required String area,
    required double exactLatitude,
    required double exactLongitude,
    required bool enableAutoUpdate,
  }) {
    final user = _findUserById(_currentUserId);
    if (user == null) {
      return;
    }

    final normalizedCity = city.trim();
    final normalizedArea = area.trim();
    final resolvedCity = normalizedCity.isNotEmpty ? normalizedCity : user.city;
    if (user.city == resolvedCity &&
        user.area == normalizedArea &&
        user.usesDeviceLocation == enableAutoUpdate &&
        user.exactLatitude == exactLatitude &&
        user.exactLongitude == exactLongitude) {
      return;
    }

    _replaceUser(
      user.copyWith(
        city: resolvedCity,
        area: normalizedArea,
        exactLatitude: exactLatitude,
        exactLongitude: exactLongitude,
        usesDeviceLocation: enableAutoUpdate,
      ),
    );
    notifyListeners();
  }

  UserEntity _upsertCurrentUserFromAuth(User authUser) {
    final canonicalId = _canonicalUserIdFromUid(authUser.uid);
    final normalizedEmail = authUser.email?.trim().toLowerCase();
    final normalizedPhone = authUser.phoneNumber?.trim();
    final normalizedPhoto = authUser.photoURL?.trim();
    final resolvedName = _resolveAuthDisplayName(authUser);

    var index = _users.indexWhere((user) => user.id == canonicalId);
    if (index == -1 && normalizedEmail != null && normalizedEmail.isNotEmpty) {
      index = _users.indexWhere(
        (user) => user.email.trim().toLowerCase() == normalizedEmail,
      );
    }

    final badges = <VerificationBadge>{
      if (normalizedEmail != null && normalizedEmail.isNotEmpty)
        VerificationBadge.emailVerified,
      if (normalizedPhone != null && normalizedPhone.isNotEmpty)
        VerificationBadge.phoneVerified,
    };

    if (index == -1) {
      final createdUser = UserEntity(
        id: canonicalId,
        fullName: resolvedName,
        email: normalizedEmail?.isNotEmpty == true
            ? normalizedEmail!
            : '$canonicalId@ghmera.app',
        phone: normalizedPhone,
        profilePhoto: normalizedPhoto?.isNotEmpty == true
            ? normalizedPhoto
            : null,
        shortBio: 'New community member.',
        verificationBadges: badges,
      );
      _users.insert(0, createdUser);
      return createdUser;
    }

    final existing = _users[index];
    final mergedBadges = <VerificationBadge>{
      ...existing.verificationBadges,
      ...badges,
    };
    final updated = existing.copyWith(
      fullName: resolvedName,
      email: normalizedEmail?.isNotEmpty == true
          ? normalizedEmail
          : existing.email,
      phone: normalizedPhone?.isNotEmpty == true
          ? normalizedPhone
          : existing.phone,
      profilePhoto: normalizedPhoto?.isNotEmpty == true
          ? normalizedPhoto
          : existing.profilePhoto,
      verificationBadges: mergedBadges,
    );

    _database.replaceUser(updated);
    return updated;
  }

  String _resolveAuthDisplayName(User authUser) {
    final directDisplayName = authUser.displayName?.trim();
    if (directDisplayName != null && directDisplayName.isNotEmpty) {
      return directDisplayName;
    }

    final email = authUser.email?.trim();
    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        final words = localPart
            .split(RegExp(r'[._-]+'))
            .where((word) => word.isNotEmpty)
            .map(
              (word) =>
                  '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .toList();
        if (words.isNotEmpty) {
          return words.join(' ');
        }
      }
    }

    return 'Ghmera User';
  }

  String _canonicalUserIdFromUid(String uid) {
    return 'user_$uid';
  }

  void _ensureCurrentUserContext() {
    if (_users.isEmpty) {
      _currentUserId = _defaultCurrentUserId;
      _database.currentUserId = _currentUserId;
      return;
    }

    final hasCurrentUser = _users.any((user) => user.id == _currentUserId);
    if (!hasCurrentUser) {
      final storedId = _database.currentUserId;
      final storedUserExists = _users.any((user) => user.id == storedId);
      _currentUserId = storedUserExists ? storedId : _users.first.id;
      _database.currentUserId = _currentUserId;
    }
  }

  void _syncCurrentUserToAuthProfile(UserEntity user) {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        return;
      }

      final trimmedName = user.fullName.trim();
      final trimmedPhoto = user.profilePhoto?.trim();
      unawaited(authUser.updateDisplayName(trimmedName));
      if (trimmedPhoto != null && trimmedPhoto.isNotEmpty) {
        unawaited(authUser.updatePhotoURL(trimmedPhoto));
      }
    } catch (_) {
      // Ignore auth profile sync failures to keep local profile updates responsive.
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _remoteDatabaseSubscription?.cancel();
    unawaited(_stopLocationTracking());
    super.dispose();
  }

  // ignore: unused_element
  void _seedDemoData() {
    final now = DateTime.now();

    _users.addAll(<UserEntity>[
      UserEntity(
        id: _currentUserId,
        fullName: 'Amara Nwosu',
        email: 'amara@ghmera.app',
        phone: '+233 20 555 0147',
        shortBio:
            'Hybrid user focused on emotional support, errands, and community recovery requests.',
        city: 'Accra',
        area: 'East Legon',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
        },
        trustScore: 88,
        availability: true,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.emotionalSupport,
          RequestCategory.errands,
          RequestCategory.studyHelp,
          RequestCategory.foodSupport,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.technicalSupport,
          RequestCategory.transportation,
        ],
        serviceRadiusKm: 7,
        helpGivenCount: 6,
        helpReceivedCount: 10,
        restrictionStatus: UserRestrictionStatus.warning,
        averageRating: 4.7,
        completedHelpCount: 9,
        receivedHelpCount: 10,
        blockedUserIds: const <String>['user_spam'],
        mutedUserIds: const <String>['user_muted'],
        privacySettings: const PrivacySettings(
          showApproximateLocation: true,
          sharePhoneAfterAcceptance: false,
          shareEmailAfterAcceptance: false,
          allowSupportCircleInvites: true,
          allowMessageRequests: true,
        ),
        twoFactorEnabled: true,
        sessions: <SessionDevice>[
          SessionDevice(
            id: 'session_1',
            label: 'Pixel 8 Pro',
            lastActive: now.subtract(const Duration(minutes: 8)),
            isCurrent: true,
          ),
          SessionDevice(
            id: 'session_2',
            label: 'Chrome on Windows',
            lastActive: now.subtract(const Duration(hours: 6)),
            isCurrent: false,
          ),
        ],
      ),
      UserEntity(
        id: 'user_daniel',
        fullName: 'Daniel Owusu',
        email: 'daniel@ghmera.app',
        phone: '+233 24 310 5521',
        shortBio: 'Device setup, software fixes, and digital literacy support.',
        city: 'Accra',
        area: 'Dzorwulu',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
          VerificationBadge.idVerified,
          VerificationBadge.trustedHelper,
        },
        trustScore: 95,
        availability: true,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.technicalSupport,
          RequestCategory.informationAdvice,
          RequestCategory.studyHelp,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.transportation,
        ],
        serviceRadiusKm: 12,
        helpGivenCount: 21,
        helpReceivedCount: 3,
        restrictionStatus: UserRestrictionStatus.clear,
        averageRating: 4.9,
        completedHelpCount: 24,
        receivedHelpCount: 3,
      ),
      UserEntity(
        id: 'user_kofi',
        fullName: 'Kofi Mensah',
        email: 'kofi@ghmera.app',
        phone: '+233 27 988 1200',
        shortBio: 'Reliable transport, errands, and elder accompaniment.',
        city: 'Accra',
        area: 'Osu',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
          VerificationBadge.idVerified,
          VerificationBadge.trustedHelper,
        },
        trustScore: 91,
        availability: true,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.transportation,
          RequestCategory.errands,
          RequestCategory.elderlySupport,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.foodSupport,
        ],
        serviceRadiusKm: 15,
        helpGivenCount: 18,
        helpReceivedCount: 4,
        restrictionStatus: UserRestrictionStatus.clear,
        averageRating: 4.8,
        completedHelpCount: 22,
        receivedHelpCount: 4,
      ),
      UserEntity(
        id: 'user_zainab',
        fullName: 'Zainab Bello',
        email: 'zainab@ghmera.app',
        phone: '+233 54 881 0043',
        shortBio:
            'Peer listener, prayer support, and study accountability partner.',
        city: 'Accra',
        area: 'Madina',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
          VerificationBadge.trustedHelper,
        },
        trustScore: 90,
        availability: true,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.emotionalSupport,
          RequestCategory.prayerSupport,
          RequestCategory.studyHelp,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.informationAdvice,
        ],
        serviceRadiusKm: 10,
        helpGivenCount: 16,
        helpReceivedCount: 5,
        restrictionStatus: UserRestrictionStatus.clear,
        averageRating: 4.8,
        completedHelpCount: 18,
        receivedHelpCount: 5,
      ),
      UserEntity(
        id: 'user_ama',
        fullName: 'Ama Boateng',
        email: 'ama@ghmera.app',
        phone: '+233 55 190 6630',
        shortBio: 'Single parent asking for flexible neighborhood support.',
        city: 'Accra',
        area: 'Labone',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
        },
        trustScore: 82,
        availability: false,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.foodSupport,
          RequestCategory.childcare,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.emotionalSupport,
          RequestCategory.foodSupport,
        ],
        serviceRadiusKm: 5,
        helpGivenCount: 3,
        helpReceivedCount: 8,
        restrictionStatus: UserRestrictionStatus.warning,
        averageRating: 4.4,
        completedHelpCount: 5,
        receivedHelpCount: 8,
      ),
      UserEntity(
        id: 'user_nana',
        fullName: 'Nana Badu',
        email: 'nana@ghmera.app',
        phone: '+233 24 773 4412',
        shortBio: 'Trusted elder care volunteer with daytime availability.',
        city: 'Accra',
        area: 'Airport Residential',
        verificationBadges: const <VerificationBadge>{
          VerificationBadge.emailVerified,
          VerificationBadge.phoneVerified,
          VerificationBadge.idVerified,
        },
        trustScore: 86,
        availability: false,
        helpCategoriesProvided: const <RequestCategory>[
          RequestCategory.elderlySupport,
          RequestCategory.transportation,
          RequestCategory.errands,
        ],
        helpCategoriesRequested: const <RequestCategory>[
          RequestCategory.prayerSupport,
        ],
        serviceRadiusKm: 11,
        helpGivenCount: 12,
        helpReceivedCount: 2,
        restrictionStatus: UserRestrictionStatus.clear,
        averageRating: 4.6,
        completedHelpCount: 15,
        receivedHelpCount: 2,
      ),
    ]);

    _requests.addAll(<HelpRequestEntity>[
      HelpRequestEntity(
        id: 'request_1',
        requesterId: _currentUserId,
        title: 'Need help setting up my laptop for remote classes',
        description:
            'I need someone to help install Zoom, connect my printer, and back up class notes before tomorrow morning.',
        category: RequestCategory.technicalSupport,
        urgency: UrgencyLevel.medium,
        location: 'East Legon',
        preferredTime: 'Today, 6:00 PM',
        visibility: HelpRequestVisibility.restricted,
        attachmentLabel: 'Setup checklist screenshot',
        status: HelpRequestStatus.matching,
        createdAt: now.subtract(const Duration(hours: 3)),
        suggestedHelperIds: const <String>['user_daniel', 'user_zainab'],
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: _currentUserId,
            action: 'Request created',
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
          HelpActionLogEntry(
            actorId: _currentUserId,
            action: 'Matching engine started ranking helpers',
            createdAt: now.subtract(const Duration(hours: 2, minutes: 45)),
          ),
        ],
      ),
      HelpRequestEntity(
        id: 'request_2',
        requesterId: _currentUserId,
        title: 'Need a safe ride to a clinic follow-up',
        description:
            'I have an early morning appointment and would prefer a trusted helper who can stay until check-in is done.',
        category: RequestCategory.transportation,
        urgency: UrgencyLevel.high,
        location: 'Osu',
        preferredTime: 'Tomorrow, 8:00 AM',
        visibility: HelpRequestVisibility.restricted,
        status: HelpRequestStatus.accepted,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        acceptedHelperId: 'user_kofi',
        safetyCheckInRequired: true,
        contactConsentFromRequester: true,
        contactConsentFromHelper: true,
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: _currentUserId,
            action: 'Request created',
            createdAt: now.subtract(const Duration(days: 1, hours: 2)),
          ),
          HelpActionLogEntry(
            actorId: 'user_kofi',
            action: 'Helper accepted request',
            createdAt: now.subtract(
              const Duration(days: 1, hours: 1, minutes: 20),
            ),
          ),
        ],
      ),
      HelpRequestEntity(
        id: 'request_3',
        requesterId: 'user_ama',
        title: 'I need someone to talk to tonight',
        description:
            'I am overwhelmed and would like a calm peer supporter to check in with me by chat for the next hour.',
        category: RequestCategory.emotionalSupport,
        urgency: UrgencyLevel.high,
        location: 'Labone',
        preferredTime: 'Tonight, 9:00 PM',
        visibility: HelpRequestVisibility.restricted,
        status: HelpRequestStatus.inProgress,
        createdAt: now.subtract(const Duration(hours: 5)),
        acceptedHelperId: _currentUserId,
        emotionalSupportMode: true,
        requesterCompletionConfirmed: false,
        helperCompletionConfirmed: false,
        suggestedHelperIds: <String>[_currentUserId, 'user_zainab'],
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: 'user_ama',
            action: 'Emotional support request created',
            createdAt: now.subtract(const Duration(hours: 5)),
          ),
          HelpActionLogEntry(
            actorId: _currentUserId,
            action: 'Peer supporter accepted',
            createdAt: now.subtract(const Duration(hours: 4, minutes: 20)),
          ),
        ],
      ),
      HelpRequestEntity(
        id: 'request_4',
        requesterId: 'user_ama',
        title: 'Need groceries for two days until payday',
        description:
            'Food staples or supermarket pickup would help. I can receive in a public location.',
        category: RequestCategory.foodSupport,
        urgency: UrgencyLevel.high,
        location: 'Labone',
        preferredTime: 'This evening',
        visibility: HelpRequestVisibility.public,
        status: HelpRequestStatus.matching,
        createdAt: now.subtract(const Duration(hours: 10)),
        suggestedHelperIds: <String>[_currentUserId],
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: 'user_ama',
            action: 'Request created',
            createdAt: now.subtract(const Duration(hours: 10)),
          ),
        ],
      ),
      HelpRequestEntity(
        id: 'request_5',
        requesterId: 'user_nana',
        title: 'Escort needed for an elderly home visit',
        description:
            'Need a verified helper to accompany an older adult for a short home visit and return trip.',
        category: RequestCategory.elderlySupport,
        urgency: UrgencyLevel.medium,
        location: 'Airport Residential',
        preferredTime: 'Saturday, 2:00 PM',
        visibility: HelpRequestVisibility.restricted,
        status: HelpRequestStatus.open,
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        requiresHomeVisit: true,
        safetyCheckInRequired: true,
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: 'user_nana',
            action: 'High-risk request created with home visit flag',
            createdAt: now.subtract(const Duration(days: 1, hours: 5)),
          ),
        ],
      ),
      HelpRequestEntity(
        id: 'request_6',
        requesterId: 'user_zainab',
        title: 'Prayer and encouragement circle this weekend',
        description:
            'Looking for a few people who can join a small support circle for prayer, encouragement, and follow-up.',
        category: RequestCategory.prayerSupport,
        urgency: UrgencyLevel.low,
        location: 'Madina',
        preferredTime: 'Sunday, 4:00 PM',
        visibility: HelpRequestVisibility.public,
        status: HelpRequestStatus.open,
        createdAt: now.subtract(const Duration(days: 2)),
        emotionalSupportMode: true,
        actionLog: <HelpActionLogEntry>[
          HelpActionLogEntry(
            actorId: 'user_zainab',
            action: 'Support circle request created',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
        ],
      ),
    ]);

    _matches.addAll(<HelpMatchEntity>[
      HelpMatchEntity(
        id: 'match_1',
        requesterId: _currentUserId,
        helperId: 'user_daniel',
        requestId: 'request_1',
        status: MatchStatus.suggested,
        score: 96,
        reasons: const <String>[
          'Supports technical support',
          'Currently available within 12 km',
          '95 trust score',
          'Trusted helper badge',
        ],
      ),
      HelpMatchEntity(
        id: 'match_2',
        requesterId: _currentUserId,
        helperId: 'user_zainab',
        requestId: 'request_1',
        status: MatchStatus.broadcast,
        score: 82,
        reasons: const <String>[
          'Strong peer listener reputation',
          'Available for lightweight support',
          '90 trust score',
        ],
      ),
      HelpMatchEntity(
        id: 'match_3',
        requesterId: 'user_ama',
        helperId: _currentUserId,
        requestId: 'request_3',
        status: MatchStatus.accepted,
        score: 89,
        reasons: const <String>[
          'Emotional support category fit',
          'Available tonight',
          'Strong review history for respect and safety',
        ],
        acceptedAt: now.subtract(const Duration(hours: 4, minutes: 20)),
      ),
      HelpMatchEntity(
        id: 'match_4',
        requesterId: 'user_ama',
        helperId: _currentUserId,
        requestId: 'request_4',
        status: MatchStatus.suggested,
        score: 78,
        reasons: const <String>[
          'Food support is one of your help categories',
          'You are active in the same city',
          'Requester is approaching reciprocity support needs',
        ],
      ),
      HelpMatchEntity(
        id: 'match_5',
        requesterId: _currentUserId,
        helperId: 'user_kofi',
        requestId: 'request_2',
        status: MatchStatus.accepted,
        score: 94,
        reasons: const <String>[
          'Transportation category fit',
          'Trusted helper badge',
          'ID verified for higher-trust travel support',
        ],
        acceptedAt: now.subtract(
          const Duration(days: 1, hours: 1, minutes: 20),
        ),
      ),
    ]);

    _threads.addAll(<MessageThreadEntity>[
      MessageThreadEntity(
        id: 'thread_1',
        requestId: 'request_1',
        participantIds: <String>[_currentUserId, 'user_daniel'],
        createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        lastMessageAt: now.subtract(const Duration(minutes: 20)),
        messageRequestPending: false,
        contactSharedByIds: <String>[_currentUserId],
      ),
      MessageThreadEntity(
        id: 'thread_2',
        requestId: 'request_3',
        participantIds: <String>[_currentUserId, 'user_ama'],
        createdAt: now.subtract(const Duration(hours: 4)),
        lastMessageAt: now.subtract(const Duration(minutes: 12)),
        messageRequestPending: false,
      ),
      MessageThreadEntity(
        id: 'thread_3',
        requestId: 'request_4',
        participantIds: <String>[_currentUserId, 'user_ama'],
        createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
        lastMessageAt: now.subtract(const Duration(hours: 1, minutes: 5)),
        messageRequestPending: true,
      ),
    ]);

    _messages.addAll(<MessageEntity>[
      MessageEntity(
        id: 'message_1',
        threadId: 'thread_1',
        senderId: 'user_daniel',
        content:
            'I can handle the laptop setup tonight. Can you send the printer model first?',
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      MessageEntity(
        id: 'message_2',
        threadId: 'thread_1',
        senderId: _currentUserId,
        content:
            'Yes, and thank you. I have only shared my phone after acceptance for now.',
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      MessageEntity(
        id: 'message_3',
        threadId: 'thread_2',
        senderId: 'user_ama',
        content:
            'Thank you for staying online. I am calmer now than I was an hour ago.',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      MessageEntity(
        id: 'message_4',
        threadId: 'thread_2',
        senderId: _currentUserId,
        content:
            'I am here with you. If you want more support after this, I can help you request a follow-up check-in.',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      MessageEntity(
        id: 'message_5',
        threadId: 'thread_3',
        senderId: 'user_ama',
        content:
            'Message request: I can pick up at a public location near Labone Junction.',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 5)),
      ),
    ]);

    _reviews.addAll(<ReviewEntity>[
      ReviewEntity(
        id: 'review_1',
        matchId: 'match_5',
        reviewerId: _currentUserId,
        revieweeId: 'user_kofi',
        helpfulness: 5,
        respectfulness: 5,
        safety: 5,
        reliability: 5,
        accuracy: 4,
        feedback: 'Clear communication, safe transport, and punctual arrival.',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ReviewEntity(
        id: 'review_2',
        matchId: 'match_3',
        reviewerId: 'user_ama',
        revieweeId: _currentUserId,
        helpfulness: 5,
        respectfulness: 5,
        safety: 5,
        reliability: 4,
        accuracy: 5,
        feedback:
            'Very calm, respectful, and stayed within the platform safety prompts.',
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
      ReviewEntity(
        id: 'review_3',
        matchId: 'match_6',
        reviewerId: 'user_daniel',
        revieweeId: _currentUserId,
        helpfulness: 4,
        respectfulness: 5,
        safety: 5,
        reliability: 4,
        accuracy: 4,
        feedback:
            'Shared details carefully and stayed inside the protected workflow.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);

    _reports.addAll(<ReportEntity>[
      ReportEntity(
        id: 'report_1',
        reporterId: _currentUserId,
        targetType: ReportTargetType.chat,
        targetId: 'thread_9',
        reason: 'Inappropriate language',
        details:
            'Automated moderation flagged repeated pressure to move off-platform.',
        status: ReportStatus.investigating,
        createdAt: now.subtract(const Duration(hours: 8)),
        assignedModeratorId: 'mod_1',
      ),
      ReportEntity(
        id: 'report_2',
        reporterId: 'user_zainab',
        targetType: ReportTargetType.request,
        targetId: 'request_10',
        reason: 'Conflicting request details',
        details:
            'Requester posted duplicate emergency support requests with conflicting details.',
        status: ReportStatus.open,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 10)),
      ),
    ]);

    _moodCheckIns.addAll(<MoodCheckInEntity>[
      MoodCheckInEntity(
        id: 'mood_1',
        userId: _currentUserId,
        moodLevel: MoodLevel.struggling,
        createdAt: now.subtract(const Duration(hours: 2)),
        note: 'Surface emotional support request and support circles.',
      ),
      MoodCheckInEntity(
        id: 'mood_2',
        userId: _currentUserId,
        moodLevel: MoodLevel.okay,
        createdAt: now.subtract(const Duration(days: 1)),
        note: 'Completed a small helping task yesterday.',
      ),
      MoodCheckInEntity(
        id: 'mood_3',
        userId: _currentUserId,
        moodLevel: MoodLevel.good,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ]);

    _notifications.addAll(<NotificationEntity>[
      NotificationEntity(
        id: 'notification_1',
        userId: _currentUserId,
        type: NotificationType.matchFound,
        title: 'Two helpers fit your tech request',
        message: 'Daniel and Zainab were ranked for your laptop setup request.',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      NotificationEntity(
        id: 'notification_2',
        userId: _currentUserId,
        type: NotificationType.newMessage,
        title: 'Daniel sent a new message',
        message:
            'He is asking for the printer model before the session starts.',
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      NotificationEntity(
        id: 'notification_3',
        userId: _currentUserId,
        type: NotificationType.safetyAlert,
        title: 'Safety check-in scheduled',
        message:
            'Your clinic ride request will trigger a check-in before and after the trip.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      NotificationEntity(
        id: 'notification_4',
        userId: _currentUserId,
        type: NotificationType.reciprocityWarning,
        title: 'You are close to the reciprocity floor',
        message:
            'Offer one more help interaction soon to stay comfortably above -5.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      NotificationEntity(
        id: 'notification_5',
        userId: _currentUserId,
        type: NotificationType.emotionalCheckInReminder,
        title: 'Daily wellbeing check-in',
        message:
            'If you are struggling, the app can route you into a listener match or support circle.',
        createdAt: now.subtract(const Duration(hours: 7)),
      ),
      NotificationEntity(
        id: 'notification_6',
        userId: _currentUserId,
        type: NotificationType.reportUpdate,
        title: 'Your report is being reviewed',
        message: 'Moderation moved your chat safety report into investigation.',
        createdAt: now.subtract(const Duration(hours: 8)),
        isRead: true,
      ),
    ]);

    _supportCircles.addAll(<SupportCircleEntity>[
      SupportCircleEntity(
        id: 'circle_1',
        name: 'New Immigrant Circle',
        description:
            'Weekly support for new arrivals navigating housing, jobs, and local systems.',
        tags: <String>['belonging', 'orientation', 'peer support'],
        memberIds: <String>['user_zainab', 'user_ama'],
      ),
      SupportCircleEntity(
        id: 'circle_2',
        name: 'Single Parent Circle',
        description:
            'Low-pressure check-ins, food support coordination, and shared childcare tips.',
        tags: <String>['care', 'practical help', 'family'],
        memberIds: <String>['user_ama'],
      ),
      SupportCircleEntity(
        id: 'circle_3',
        name: 'Young Professional Support Circle',
        description:
            'Study, work, and burnout recovery support for early-career adults.',
        tags: <String>['career', 'stress', 'accountability'],
        memberIds: <String>['user_daniel', _currentUserId],
      ),
      SupportCircleEntity(
        id: 'circle_4',
        name: 'Prayer and Encouragement Circle',
        description:
            'Faith-based peer support with gentle moderation and follow-up prompts.',
        tags: <String>['prayer', 'encouragement', 'check-ins'],
        memberIds: <String>['user_zainab', _currentUserId],
      ),
    ]);
  }
}
