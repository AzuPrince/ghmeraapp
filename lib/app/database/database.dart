import '../models/ghmera_models.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  String currentUserId = 'user_current';

  final List<UserEntity> users = <UserEntity>[];
  final List<HelpRequestEntity> requests = <HelpRequestEntity>[];
  final List<HelpMatchEntity> matches = <HelpMatchEntity>[];
  final List<MessageThreadEntity> threads = <MessageThreadEntity>[];
  final List<MessageEntity> messages = <MessageEntity>[];
  final List<ReviewEntity> reviews = <ReviewEntity>[];
  final List<ReportEntity> reports = <ReportEntity>[];
  final List<MoodCheckInEntity> moodCheckIns = <MoodCheckInEntity>[];
  final List<NotificationEntity> notifications = <NotificationEntity>[];
  final List<SupportCircleEntity> supportCircles = <SupportCircleEntity>[];

  Future<void> load() async {}

  void hydrateFromMap(Map<String, dynamic> rawDatabase) {
    _hydrate(rawDatabase);
  }

  Map<String, dynamic> toMap({String? currentUserEmail}) {
    var resolvedCurrentUserEmail = currentUserEmail?.trim().toLowerCase();
    if (resolvedCurrentUserEmail == null || resolvedCurrentUserEmail.isEmpty) {
      for (final user in users) {
        if (user.id != currentUserId) {
          continue;
        }

        final email = user.email.trim().toLowerCase();
        if (email.isNotEmpty) {
          resolvedCurrentUserEmail = email;
        }
        break;
      }
    }

    final rawDatabase = <String, dynamic>{
      '_meta': <String, dynamic>{
        'currentUserId': currentUserId,
        if (resolvedCurrentUserEmail != null &&
            resolvedCurrentUserEmail.isNotEmpty)
          'currentUserEmail': resolvedCurrentUserEmail,
      },
      '_shared': <String, dynamic>{
        'matches': matches.map(_serializeHelpMatch).toList(),
        'threads': threads.map(_serializeMessageThread).toList(),
        'messages': messages.map(_serializeMessage).toList(),
        'reviews': reviews.map(_serializeReview).toList(),
        'reports': reports.map(_serializeReport).toList(),
        'supportCircles': supportCircles.map(_serializeSupportCircle).toList(),
      },
    };

    for (final user in users) {
      final email = user.email.trim().toLowerCase();
      final bucketKey = email.isNotEmpty ? email : user.id;
      rawDatabase[bucketKey] = <String, dynamic>{
        'user': _serializeUser(user),
        'requests': requests
            .where((request) => request.requesterId == user.id)
            .map(_serializeHelpRequest)
            .toList(),
        'notifications': notifications
            .where((notification) => notification.userId == user.id)
            .map(_serializeNotification)
            .toList(),
        'moodCheckIns': moodCheckIns
            .where((checkIn) => checkIn.userId == user.id)
            .map(_serializeMoodCheckIn)
            .toList(),
      };
    }

    return rawDatabase;
  }

  void clear() {
    currentUserId = 'user_current';
    users.clear();
    requests.clear();
    matches.clear();
    threads.clear();
    messages.clear();
    reviews.clear();
    reports.clear();
    moodCheckIns.clear();
    notifications.clear();
    supportCircles.clear();
  }

  void replaceUser(UserEntity updatedUser) {
    final index = users.indexWhere((user) => user.id == updatedUser.id);
    if (index == -1) {
      return;
    }

    users[index] = updatedUser;
  }

  void replaceRequest(HelpRequestEntity updatedRequest) {
    final index = requests.indexWhere(
      (request) => request.id == updatedRequest.id,
    );
    if (index == -1) {
      return;
    }

    requests[index] = updatedRequest;
  }

  void _hydrate(Map<String, dynamic> rawDatabase) {
    clear();

    final meta = _asMap(rawDatabase['_meta']);
    final shared = _asMap(rawDatabase['_shared']);
    final currentUserIdFromMeta = meta['currentUserId'] as String?;
    final currentUserEmail = meta['currentUserEmail'] as String?;

    for (final entry in rawDatabase.entries) {
      if (entry.key.startsWith('_')) {
        continue;
      }

      final userBucket = _asMap(entry.value);
      final user = _parseUser(_asMap(userBucket['user']), entry.key);
      users.add(user);
      requests.addAll(_parseHelpRequests(userBucket['requests']));
      notifications.addAll(_parseNotifications(userBucket['notifications']));
      moodCheckIns.addAll(_parseMoodCheckIns(userBucket['moodCheckIns']));
    }

    matches.addAll(_parseHelpMatches(shared['matches']));
    threads.addAll(_parseMessageThreads(shared['threads']));
    messages.addAll(_parseMessages(shared['messages']));
    reviews.addAll(_parseReviews(shared['reviews']));
    reports.addAll(_parseReports(shared['reports']));
    supportCircles.addAll(_parseSupportCircles(shared['supportCircles']));

    if (currentUserIdFromMeta != null) {
      for (final user in users) {
        if (user.id == currentUserIdFromMeta) {
          currentUserId = user.id;
          return;
        }
      }
    }

    if (currentUserEmail != null) {
      for (final user in users) {
        if (user.email.trim().toLowerCase() ==
            currentUserEmail.trim().toLowerCase()) {
          currentUserId = user.id;
          break;
        }
      }
    }
  }

  Map<String, dynamic> _serializeUser(UserEntity user) {
    return <String, dynamic>{
      'id': user.id,
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'profilePhoto': user.profilePhoto,
      'shortBio': user.shortBio,
      'city': user.city,
      'area': user.area,
      'verificationBadges': user.verificationBadges
          .map((badge) => badge.name)
          .toList(),
      'trustScore': user.trustScore,
      'availability': user.availability,
      'helpCategoriesProvided': user.helpCategoriesProvided
          .map((category) => category.name)
          .toList(),
      'helpCategoriesRequested': user.helpCategoriesRequested
          .map((category) => category.name)
          .toList(),
      'serviceRadiusKm': user.serviceRadiusKm,
      'helpGivenCount': user.helpGivenCount,
      'helpReceivedCount': user.helpReceivedCount,
      'restrictionStatus': user.restrictionStatus.name,
      'averageRating': user.averageRating,
      'completedHelpCount': user.completedHelpCount,
      'receivedHelpCount': user.receivedHelpCount,
      'blockedUserIds': List<String>.from(user.blockedUserIds),
      'mutedUserIds': List<String>.from(user.mutedUserIds),
      'privacySettings': _serializePrivacySettings(user.privacySettings),
      'twoFactorEnabled': user.twoFactorEnabled,
      'isAdmin': user.isAdmin,
      'vulnerableUser': user.vulnerableUser,
      'hasDisability': user.hasDisability,
      'adminOverrideReciprocity': user.adminOverrideReciprocity,
      'sessions': user.sessions.map(_serializeSessionDevice).toList(),
      'trustFlags': List<String>.from(user.trustFlags),
    };
  }

  Map<String, dynamic> _serializePrivacySettings(PrivacySettings settings) {
    return <String, dynamic>{
      'showApproximateLocation': settings.showApproximateLocation,
      'sharePhoneAfterAcceptance': settings.sharePhoneAfterAcceptance,
      'shareEmailAfterAcceptance': settings.shareEmailAfterAcceptance,
      'allowSupportCircleInvites': settings.allowSupportCircleInvites,
      'allowMessageRequests': settings.allowMessageRequests,
    };
  }

  Map<String, dynamic> _serializeSessionDevice(SessionDevice session) {
    return <String, dynamic>{
      'id': session.id,
      'label': session.label,
      'lastActive': session.lastActive.toIso8601String(),
      'isCurrent': session.isCurrent,
    };
  }

  Map<String, dynamic> _serializeHelpRequest(HelpRequestEntity request) {
    return <String, dynamic>{
      'id': request.id,
      'requesterId': request.requesterId,
      'title': request.title,
      'description': request.description,
      'category': request.category.name,
      'urgency': request.urgency.name,
      'location': request.location,
      'preferredTime': request.preferredTime,
      'visibility': request.visibility.name,
      'attachmentLabel': request.attachmentLabel,
      'status': request.status.name,
      'createdAt': request.createdAt.toIso8601String(),
      'acceptedHelperId': request.acceptedHelperId,
      'emotionalSupportMode': request.emotionalSupportMode,
      'requiresHomeVisit': request.requiresHomeVisit,
      'lateNightSupport': request.lateNightSupport,
      'moneyRelated': request.moneyRelated,
      'emergencyOverride': request.emergencyOverride,
      'requesterCompletionConfirmed': request.requesterCompletionConfirmed,
      'helperCompletionConfirmed': request.helperCompletionConfirmed,
      'contactConsentFromRequester': request.contactConsentFromRequester,
      'contactConsentFromHelper': request.contactConsentFromHelper,
      'safetyCheckInRequired': request.safetyCheckInRequired,
      'suggestedHelperIds': List<String>.from(request.suggestedHelperIds),
      'actionLog': request.actionLog.map(_serializeHelpActionLog).toList(),
    };
  }

  Map<String, dynamic> _serializeHelpActionLog(HelpActionLogEntry entry) {
    return <String, dynamic>{
      'actorId': entry.actorId,
      'action': entry.action,
      'createdAt': entry.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _serializeHelpMatch(HelpMatchEntity match) {
    return <String, dynamic>{
      'id': match.id,
      'requesterId': match.requesterId,
      'helperId': match.helperId,
      'requestId': match.requestId,
      'status': match.status.name,
      'score': match.score,
      'reasons': List<String>.from(match.reasons),
      'acceptedAt': match.acceptedAt?.toIso8601String(),
      'completedAt': match.completedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _serializeMessageThread(MessageThreadEntity thread) {
    return <String, dynamic>{
      'id': thread.id,
      'requestId': thread.requestId,
      'participantIds': List<String>.from(thread.participantIds),
      'createdAt': thread.createdAt.toIso8601String(),
      'lastMessageAt': thread.lastMessageAt.toIso8601String(),
      'messageRequestPending': thread.messageRequestPending,
      'blockedByIds': List<String>.from(thread.blockedByIds),
      'mutedByIds': List<String>.from(thread.mutedByIds),
      'contactSharedByIds': List<String>.from(thread.contactSharedByIds),
      'flaggedSafetyConcern': thread.flaggedSafetyConcern,
    };
  }

  Map<String, dynamic> _serializeMessage(MessageEntity message) {
    return <String, dynamic>{
      'id': message.id,
      'threadId': message.threadId,
      'senderId': message.senderId,
      'content': message.content,
      'createdAt': message.createdAt.toIso8601String(),
      'flaggedSafetyConcern': message.flaggedSafetyConcern,
    };
  }

  Map<String, dynamic> _serializeReview(ReviewEntity review) {
    return <String, dynamic>{
      'id': review.id,
      'matchId': review.matchId,
      'reviewerId': review.reviewerId,
      'revieweeId': review.revieweeId,
      'helpfulness': review.helpfulness,
      'respectfulness': review.respectfulness,
      'safety': review.safety,
      'reliability': review.reliability,
      'accuracy': review.accuracy,
      'feedback': review.feedback,
      'createdAt': review.createdAt.toIso8601String(),
      'flaggedSuspicious': review.flaggedSuspicious,
    };
  }

  Map<String, dynamic> _serializeReport(ReportEntity report) {
    return <String, dynamic>{
      'id': report.id,
      'reporterId': report.reporterId,
      'targetType': report.targetType.name,
      'targetId': report.targetId,
      'reason': report.reason,
      'details': report.details,
      'status': report.status.name,
      'createdAt': report.createdAt.toIso8601String(),
      'assignedModeratorId': report.assignedModeratorId,
    };
  }

  Map<String, dynamic> _serializeMoodCheckIn(MoodCheckInEntity checkIn) {
    return <String, dynamic>{
      'id': checkIn.id,
      'userId': checkIn.userId,
      'moodLevel': checkIn.moodLevel.name,
      'createdAt': checkIn.createdAt.toIso8601String(),
      'note': checkIn.note,
    };
  }

  Map<String, dynamic> _serializeNotification(NotificationEntity notification) {
    return <String, dynamic>{
      'id': notification.id,
      'userId': notification.userId,
      'type': notification.type.name,
      'title': notification.title,
      'message': notification.message,
      'createdAt': notification.createdAt.toIso8601String(),
      'isRead': notification.isRead,
    };
  }

  Map<String, dynamic> _serializeSupportCircle(SupportCircleEntity circle) {
    return <String, dynamic>{
      'id': circle.id,
      'name': circle.name,
      'description': circle.description,
      'tags': List<String>.from(circle.tags),
      'memberIds': List<String>.from(circle.memberIds),
    };
  }

  UserEntity _parseUser(Map<String, dynamic> json, String emailKey) {
    return UserEntity(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: (json['email'] as String?) ?? emailKey,
      phone: json['phone'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      shortBio: json['shortBio'] as String? ?? '',
      city: json['city'] as String? ?? '',
      area: json['area'] as String? ?? '',
      verificationBadges: _parseEnumList(
        VerificationBadge.values,
        json['verificationBadges'],
      ).toSet(),
      trustScore: _readDouble(json['trustScore'], 50),
      availability: json['availability'] as bool? ?? true,
      helpCategoriesProvided: _parseEnumList(
        RequestCategory.values,
        json['helpCategoriesProvided'],
      ),
      helpCategoriesRequested: _parseEnumList(
        RequestCategory.values,
        json['helpCategoriesRequested'],
      ),
      serviceRadiusKm: _readDouble(json['serviceRadiusKm'], 10),
      helpGivenCount: _readInt(json['helpGivenCount']),
      helpReceivedCount: _readInt(json['helpReceivedCount']),
      restrictionStatus: _parseEnum(
        UserRestrictionStatus.values,
        json['restrictionStatus'],
        UserRestrictionStatus.clear,
      ),
      averageRating: _readDouble(json['averageRating'], 0),
      completedHelpCount: _readInt(json['completedHelpCount']),
      receivedHelpCount: _readInt(json['receivedHelpCount']),
      blockedUserIds: _readStringList(json['blockedUserIds']),
      mutedUserIds: _readStringList(json['mutedUserIds']),
      privacySettings: _parsePrivacySettings(json['privacySettings']),
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      vulnerableUser: json['vulnerableUser'] as bool? ?? false,
      hasDisability: json['hasDisability'] as bool? ?? false,
      adminOverrideReciprocity:
          json['adminOverrideReciprocity'] as bool? ?? false,
      sessions: _parseSessions(json['sessions']),
      trustFlags: _readStringList(json['trustFlags']),
    );
  }

  PrivacySettings _parsePrivacySettings(Object? rawValue) {
    final json = _asMap(rawValue);
    return PrivacySettings(
      showApproximateLocation: json['showApproximateLocation'] as bool? ?? true,
      sharePhoneAfterAcceptance:
          json['sharePhoneAfterAcceptance'] as bool? ?? false,
      shareEmailAfterAcceptance:
          json['shareEmailAfterAcceptance'] as bool? ?? false,
      allowSupportCircleInvites:
          json['allowSupportCircleInvites'] as bool? ?? true,
      allowMessageRequests: json['allowMessageRequests'] as bool? ?? true,
    );
  }

  List<SessionDevice> _parseSessions(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => SessionDevice(
            id: json['id'] as String,
            label: json['label'] as String,
            lastActive: _parseDateTime(json['lastActive']),
            isCurrent: json['isCurrent'] as bool? ?? false,
          ),
        )
        .toList();
  }

  List<HelpRequestEntity> _parseHelpRequests(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => HelpRequestEntity(
            id: json['id'] as String,
            requesterId: json['requesterId'] as String,
            title: json['title'] as String,
            description: json['description'] as String,
            category: _parseEnum(
              RequestCategory.values,
              json['category'],
              RequestCategory.errands,
            ),
            urgency: _parseEnum(
              UrgencyLevel.values,
              json['urgency'],
              UrgencyLevel.medium,
            ),
            location: json['location'] as String,
            preferredTime: json['preferredTime'] as String,
            visibility: _parseEnum(
              HelpRequestVisibility.values,
              json['visibility'],
              HelpRequestVisibility.restricted,
            ),
            attachmentLabel: json['attachmentLabel'] as String?,
            status: _parseEnum(
              HelpRequestStatus.values,
              json['status'],
              HelpRequestStatus.open,
            ),
            createdAt: _parseDateTime(json['createdAt']),
            acceptedHelperId: json['acceptedHelperId'] as String?,
            emotionalSupportMode:
                json['emotionalSupportMode'] as bool? ?? false,
            requiresHomeVisit: json['requiresHomeVisit'] as bool? ?? false,
            lateNightSupport: json['lateNightSupport'] as bool? ?? false,
            moneyRelated: json['moneyRelated'] as bool? ?? false,
            emergencyOverride: json['emergencyOverride'] as bool? ?? false,
            requesterCompletionConfirmed:
                json['requesterCompletionConfirmed'] as bool? ?? false,
            helperCompletionConfirmed:
                json['helperCompletionConfirmed'] as bool? ?? false,
            contactConsentFromRequester:
                json['contactConsentFromRequester'] as bool? ?? false,
            contactConsentFromHelper:
                json['contactConsentFromHelper'] as bool? ?? false,
            safetyCheckInRequired:
                json['safetyCheckInRequired'] as bool? ?? false,
            suggestedHelperIds: _readStringList(json['suggestedHelperIds']),
            actionLog: _parseHelpActionLog(json['actionLog']),
          ),
        )
        .toList();
  }

  List<HelpActionLogEntry> _parseHelpActionLog(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => HelpActionLogEntry(
            actorId: json['actorId'] as String,
            action: json['action'] as String,
            createdAt: _parseDateTime(json['createdAt']),
          ),
        )
        .toList();
  }

  List<HelpMatchEntity> _parseHelpMatches(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => HelpMatchEntity(
            id: json['id'] as String,
            requesterId: json['requesterId'] as String,
            helperId: json['helperId'] as String,
            requestId: json['requestId'] as String,
            status: _parseEnum(
              MatchStatus.values,
              json['status'],
              MatchStatus.suggested,
            ),
            score: _readDouble(json['score'], 0),
            reasons: _readStringList(json['reasons']),
            acceptedAt: _parseOptionalDateTime(json['acceptedAt']),
            completedAt: _parseOptionalDateTime(json['completedAt']),
          ),
        )
        .toList();
  }

  List<MessageThreadEntity> _parseMessageThreads(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => MessageThreadEntity(
            id: json['id'] as String,
            requestId: json['requestId'] as String,
            participantIds: _readStringList(json['participantIds']),
            createdAt: _parseDateTime(json['createdAt']),
            lastMessageAt: _parseDateTime(json['lastMessageAt']),
            messageRequestPending:
                json['messageRequestPending'] as bool? ?? true,
            blockedByIds: _readStringList(json['blockedByIds']),
            mutedByIds: _readStringList(json['mutedByIds']),
            contactSharedByIds: _readStringList(json['contactSharedByIds']),
            flaggedSafetyConcern:
                json['flaggedSafetyConcern'] as bool? ?? false,
          ),
        )
        .toList();
  }

  List<MessageEntity> _parseMessages(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => MessageEntity(
            id: json['id'] as String,
            threadId: json['threadId'] as String,
            senderId: json['senderId'] as String,
            content: json['content'] as String,
            createdAt: _parseDateTime(json['createdAt']),
            flaggedSafetyConcern:
                json['flaggedSafetyConcern'] as bool? ?? false,
          ),
        )
        .toList();
  }

  List<ReviewEntity> _parseReviews(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => ReviewEntity(
            id: json['id'] as String,
            matchId: json['matchId'] as String,
            reviewerId: json['reviewerId'] as String,
            revieweeId: json['revieweeId'] as String,
            helpfulness: _readInt(json['helpfulness']),
            respectfulness: _readInt(json['respectfulness']),
            safety: _readInt(json['safety']),
            reliability: _readInt(json['reliability']),
            accuracy: _readInt(json['accuracy']),
            feedback: json['feedback'] as String,
            createdAt: _parseDateTime(json['createdAt']),
            flaggedSuspicious: json['flaggedSuspicious'] as bool? ?? false,
          ),
        )
        .toList();
  }

  List<ReportEntity> _parseReports(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => ReportEntity(
            id: json['id'] as String,
            reporterId: json['reporterId'] as String,
            targetType: _parseEnum(
              ReportTargetType.values,
              json['targetType'],
              ReportTargetType.user,
            ),
            targetId: json['targetId'] as String,
            reason: json['reason'] as String,
            details: json['details'] as String,
            status: _parseEnum(
              ReportStatus.values,
              json['status'],
              ReportStatus.open,
            ),
            createdAt: _parseDateTime(json['createdAt']),
            assignedModeratorId: json['assignedModeratorId'] as String?,
          ),
        )
        .toList();
  }

  List<MoodCheckInEntity> _parseMoodCheckIns(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => MoodCheckInEntity(
            id: json['id'] as String,
            userId: json['userId'] as String,
            moodLevel: _parseEnum(
              MoodLevel.values,
              json['moodLevel'],
              MoodLevel.okay,
            ),
            createdAt: _parseDateTime(json['createdAt']),
            note: json['note'] as String? ?? '',
          ),
        )
        .toList();
  }

  List<NotificationEntity> _parseNotifications(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => NotificationEntity(
            id: json['id'] as String,
            userId: json['userId'] as String,
            type: _parseEnum(
              NotificationType.values,
              json['type'],
              NotificationType.adminUpdate,
            ),
            title: json['title'] as String,
            message: json['message'] as String,
            createdAt: _parseDateTime(json['createdAt']),
            isRead: json['isRead'] as bool? ?? false,
          ),
        )
        .toList();
  }

  List<SupportCircleEntity> _parseSupportCircles(Object? rawValue) {
    return _asMapList(rawValue)
        .map(
          (json) => SupportCircleEntity(
            id: json['id'] as String,
            name: json['name'] as String,
            description: json['description'] as String,
            tags: _readStringList(json['tags']),
            memberIds: _readStringList(json['memberIds']),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _asMap(Object? rawValue) {
    if (rawValue is Map<String, dynamic>) {
      return rawValue;
    }

    if (rawValue is Map) {
      return rawValue.map((key, value) => MapEntry(key.toString(), value));
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(Object? rawValue) {
    if (rawValue is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawValue.map(_asMap).toList();
  }

  List<String> _readStringList(Object? rawValue) {
    if (rawValue is! List) {
      return const <String>[];
    }

    return rawValue.map((item) => item.toString()).toList();
  }

  int _readInt(Object? rawValue) {
    if (rawValue is int) {
      return rawValue;
    }

    if (rawValue is num) {
      return rawValue.toInt();
    }

    return 0;
  }

  double _readDouble(Object? rawValue, double fallback) {
    if (rawValue is double) {
      return rawValue;
    }

    if (rawValue is num) {
      return rawValue.toDouble();
    }

    return fallback;
  }

  DateTime _parseDateTime(Object? rawValue) {
    if (rawValue is String) {
      return DateTime.parse(rawValue);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parseOptionalDateTime(Object? rawValue) {
    if (rawValue is String) {
      return DateTime.parse(rawValue);
    }

    return null;
  }

  T _parseEnum<T extends Enum>(List<T> values, Object? rawValue, T fallback) {
    if (rawValue is String) {
      for (final value in values) {
        if (value.name == rawValue) {
          return value;
        }
      }
    }

    return fallback;
  }

  List<T> _parseEnumList<T extends Enum>(List<T> values, Object? rawValue) {
    if (rawValue is! List) {
      return <T>[];
    }

    final parsedValues = <T>[];
    for (final item in rawValue) {
      if (item is! String) {
        continue;
      }

      for (final candidate in values) {
        if (candidate.name == item) {
          parsedValues.add(candidate);
          break;
        }
      }
    }

    return parsedValues;
  }
}
