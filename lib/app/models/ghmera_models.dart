enum AuthMethod { phone, google, apple }

extension AuthMethodLabel on AuthMethod {
  String get label {
    switch (this) {
      case AuthMethod.phone:
        return 'Phone';
      case AuthMethod.google:
        return 'Google';
      case AuthMethod.apple:
        return 'Apple';
    }
  }
}

enum VerificationBadge {
  emailVerified,
  phoneVerified,
  idVerified,
  trustedHelper,
}

extension VerificationBadgeLabel on VerificationBadge {
  String get label {
    switch (this) {
      case VerificationBadge.emailVerified:
        return 'Email verified';
      case VerificationBadge.phoneVerified:
        return 'Phone verified';
      case VerificationBadge.idVerified:
        return 'ID verified';
      case VerificationBadge.trustedHelper:
        return 'Trusted helper';
    }
  }
}

enum RequestCategory {
  errands,
  transportation,
  studyHelp,
  technicalSupport,
  emotionalSupport,
  prayerSupport,
  childcare,
  elderlySupport,
  movingHelp,
  informationAdvice,
  foodSupport,
  emergencySupport,
}

extension RequestCategoryLabel on RequestCategory {
  String get label {
    switch (this) {
      case RequestCategory.errands:
        return 'Errands';
      case RequestCategory.transportation:
        return 'Transportation';
      case RequestCategory.studyHelp:
        return 'Study help';
      case RequestCategory.technicalSupport:
        return 'Technical support';
      case RequestCategory.emotionalSupport:
        return 'Emotional support';
      case RequestCategory.prayerSupport:
        return 'Prayer / spiritual support';
      case RequestCategory.childcare:
        return 'Childcare';
      case RequestCategory.elderlySupport:
        return 'Elderly support';
      case RequestCategory.movingHelp:
        return 'Moving help';
      case RequestCategory.informationAdvice:
        return 'Information / advice';
      case RequestCategory.foodSupport:
        return 'Food support';
      case RequestCategory.emergencySupport:
        return 'Emergency non-medical support';
    }
  }

  bool get isHighRisk {
    switch (this) {
      case RequestCategory.childcare:
      case RequestCategory.elderlySupport:
      case RequestCategory.emergencySupport:
        return true;
      case RequestCategory.errands:
      case RequestCategory.transportation:
      case RequestCategory.studyHelp:
      case RequestCategory.technicalSupport:
      case RequestCategory.emotionalSupport:
      case RequestCategory.prayerSupport:
      case RequestCategory.movingHelp:
      case RequestCategory.informationAdvice:
      case RequestCategory.foodSupport:
        return false;
    }
  }

  bool get supportsLightweightHelp {
    switch (this) {
      case RequestCategory.studyHelp:
      case RequestCategory.technicalSupport:
      case RequestCategory.informationAdvice:
      case RequestCategory.prayerSupport:
      case RequestCategory.emotionalSupport:
        return true;
      case RequestCategory.errands:
      case RequestCategory.transportation:
      case RequestCategory.childcare:
      case RequestCategory.elderlySupport:
      case RequestCategory.movingHelp:
      case RequestCategory.foodSupport:
      case RequestCategory.emergencySupport:
        return false;
    }
  }
}

enum UrgencyLevel { low, medium, high }

extension UrgencyLevelLabel on UrgencyLevel {
  String get label {
    switch (this) {
      case UrgencyLevel.low:
        return 'Low';
      case UrgencyLevel.medium:
        return 'Medium';
      case UrgencyLevel.high:
        return 'High';
    }
  }
}

enum HelpRequestVisibility { public, restricted }

extension HelpRequestVisibilityLabel on HelpRequestVisibility {
  String get label {
    switch (this) {
      case HelpRequestVisibility.public:
        return 'Public';
      case HelpRequestVisibility.restricted:
        return 'Restricted';
    }
  }
}

enum HelpRequestStatus {
  open,
  matching,
  matched,
  accepted,
  inProgress,
  completed,
  canceled,
  reported,
  disputed,
}

extension HelpRequestStatusLabel on HelpRequestStatus {
  String get label {
    switch (this) {
      case HelpRequestStatus.open:
        return 'Open';
      case HelpRequestStatus.matching:
        return 'Matching';
      case HelpRequestStatus.matched:
        return 'Matched';
      case HelpRequestStatus.accepted:
        return 'Accepted';
      case HelpRequestStatus.inProgress:
        return 'In progress';
      case HelpRequestStatus.completed:
        return 'Completed';
      case HelpRequestStatus.canceled:
        return 'Canceled';
      case HelpRequestStatus.reported:
        return 'Reported';
      case HelpRequestStatus.disputed:
        return 'Disputed';
    }
  }
}

enum MatchStatus {
  suggested,
  broadcast,
  accepted,
  declined,
  inProgress,
  completed,
  disputed,
}

extension MatchStatusLabel on MatchStatus {
  String get label {
    switch (this) {
      case MatchStatus.suggested:
        return 'Suggested';
      case MatchStatus.broadcast:
        return 'Broadcast';
      case MatchStatus.accepted:
        return 'Accepted';
      case MatchStatus.declined:
        return 'Declined';
      case MatchStatus.inProgress:
        return 'In progress';
      case MatchStatus.completed:
        return 'Completed';
      case MatchStatus.disputed:
        return 'Disputed';
    }
  }
}

enum NotificationType {
  matchFound,
  newMessage,
  requestAccepted,
  helpCompleted,
  reportUpdate,
  safetyAlert,
  reciprocityWarning,
  emotionalCheckInReminder,
  adminUpdate,
}

extension NotificationTypeLabel on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.matchFound:
        return 'Match found';
      case NotificationType.newMessage:
        return 'New message';
      case NotificationType.requestAccepted:
        return 'Request accepted';
      case NotificationType.helpCompleted:
        return 'Help completed';
      case NotificationType.reportUpdate:
        return 'Report update';
      case NotificationType.safetyAlert:
        return 'Safety alert';
      case NotificationType.reciprocityWarning:
        return 'Reciprocity warning';
      case NotificationType.emotionalCheckInReminder:
        return 'Emotional check-in reminder';
      case NotificationType.adminUpdate:
        return 'Admin update';
    }
  }
}

enum ReportTargetType { user, request, chat }

extension ReportTargetTypeLabel on ReportTargetType {
  String get label {
    switch (this) {
      case ReportTargetType.user:
        return 'User';
      case ReportTargetType.request:
        return 'Request';
      case ReportTargetType.chat:
        return 'Chat';
    }
  }
}

enum ReportStatus { open, investigating, resolved, dismissed }

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.investigating:
        return 'Investigating';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.dismissed:
        return 'Dismissed';
    }
  }
}

enum MoodLevel { good, okay, struggling, notOkay }

extension MoodLevelLabel on MoodLevel {
  String get label {
    switch (this) {
      case MoodLevel.good:
        return 'Good';
      case MoodLevel.okay:
        return 'Okay';
      case MoodLevel.struggling:
        return 'Struggling';
      case MoodLevel.notOkay:
        return 'Not okay';
    }
  }

  bool get needsSupport {
    switch (this) {
      case MoodLevel.good:
      case MoodLevel.okay:
        return false;
      case MoodLevel.struggling:
      case MoodLevel.notOkay:
        return true;
    }
  }
}

enum UserRestrictionStatus {
  clear,
  warning,
  reciprocityHold,
  limited,
  suspended,
  banned,
}

extension UserRestrictionStatusLabel on UserRestrictionStatus {
  String get label {
    switch (this) {
      case UserRestrictionStatus.clear:
        return 'Clear';
      case UserRestrictionStatus.warning:
        return 'Warning';
      case UserRestrictionStatus.reciprocityHold:
        return 'Reciprocity hold';
      case UserRestrictionStatus.limited:
        return 'Limited';
      case UserRestrictionStatus.suspended:
        return 'Suspended';
      case UserRestrictionStatus.banned:
        return 'Banned';
    }
  }
}

class SessionDevice {
  const SessionDevice({
    required this.id,
    required this.label,
    required this.lastActive,
    required this.isCurrent,
  });

  final String id;
  final String label;
  final DateTime lastActive;
  final bool isCurrent;

  SessionDevice copyWith({
    String? id,
    String? label,
    DateTime? lastActive,
    bool? isCurrent,
  }) {
    return SessionDevice(
      id: id ?? this.id,
      label: label ?? this.label,
      lastActive: lastActive ?? this.lastActive,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

class PrivacySettings {
  const PrivacySettings({
    this.showApproximateLocation = true,
    this.sharePhoneAfterAcceptance = false,
    this.shareEmailAfterAcceptance = false,
    this.allowSupportCircleInvites = true,
    this.allowMessageRequests = true,
  });

  final bool showApproximateLocation;
  final bool sharePhoneAfterAcceptance;
  final bool shareEmailAfterAcceptance;
  final bool allowSupportCircleInvites;
  final bool allowMessageRequests;

  PrivacySettings copyWith({
    bool? showApproximateLocation,
    bool? sharePhoneAfterAcceptance,
    bool? shareEmailAfterAcceptance,
    bool? allowSupportCircleInvites,
    bool? allowMessageRequests,
  }) {
    return PrivacySettings(
      showApproximateLocation:
          showApproximateLocation ?? this.showApproximateLocation,
      sharePhoneAfterAcceptance:
          sharePhoneAfterAcceptance ?? this.sharePhoneAfterAcceptance,
      shareEmailAfterAcceptance:
          shareEmailAfterAcceptance ?? this.shareEmailAfterAcceptance,
      allowSupportCircleInvites:
          allowSupportCircleInvites ?? this.allowSupportCircleInvites,
      allowMessageRequests: allowMessageRequests ?? this.allowMessageRequests,
    );
  }
}

class UserEntity {
  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePhoto,
    this.shortBio = '',
    this.city = '',
    this.area = '',
    this.verificationBadges = const <VerificationBadge>{},
    this.trustScore = 50,
    this.availability = true,
    this.helpCategoriesProvided = const <RequestCategory>[],
    this.helpCategoriesRequested = const <RequestCategory>[],
    this.serviceRadiusKm = 10,
    this.helpGivenCount = 0,
    this.helpReceivedCount = 0,
    this.restrictionStatus = UserRestrictionStatus.clear,
    this.averageRating = 0,
    this.completedHelpCount = 0,
    this.receivedHelpCount = 0,
    this.blockedUserIds = const <String>[],
    this.mutedUserIds = const <String>[],
    this.privacySettings = const PrivacySettings(),
    this.twoFactorEnabled = false,
    this.isAdmin = false,
    this.vulnerableUser = false,
    this.hasDisability = false,
    this.adminOverrideReciprocity = false,
    this.sessions = const <SessionDevice>[],
    this.trustFlags = const <String>[],
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePhoto;
  final String shortBio;
  final String city;
  final String area;
  final Set<VerificationBadge> verificationBadges;
  final double trustScore;
  final bool availability;
  final List<RequestCategory> helpCategoriesProvided;
  final List<RequestCategory> helpCategoriesRequested;
  final double serviceRadiusKm;
  final int helpGivenCount;
  final int helpReceivedCount;
  final UserRestrictionStatus restrictionStatus;
  final double averageRating;
  final int completedHelpCount;
  final int receivedHelpCount;
  final List<String> blockedUserIds;
  final List<String> mutedUserIds;
  final PrivacySettings privacySettings;
  final bool twoFactorEnabled;
  final bool isAdmin;
  final bool vulnerableUser;
  final bool hasDisability;
  final bool adminOverrideReciprocity;
  final List<SessionDevice> sessions;
  final List<String> trustFlags;

  int get helpBalance => helpGivenCount - helpReceivedCount;

  bool get canBypassReciprocity {
    return vulnerableUser || hasDisability || adminOverrideReciprocity;
  }

  bool get phoneVerified =>
      verificationBadges.contains(VerificationBadge.phoneVerified);

  bool get emailVerified =>
      verificationBadges.contains(VerificationBadge.emailVerified);

  bool get idVerified =>
      verificationBadges.contains(VerificationBadge.idVerified);

  bool get trustedHelper =>
      verificationBadges.contains(VerificationBadge.trustedHelper);

  UserEntity copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? profilePhoto,
    String? shortBio,
    String? city,
    String? area,
    Set<VerificationBadge>? verificationBadges,
    double? trustScore,
    bool? availability,
    List<RequestCategory>? helpCategoriesProvided,
    List<RequestCategory>? helpCategoriesRequested,
    double? serviceRadiusKm,
    int? helpGivenCount,
    int? helpReceivedCount,
    UserRestrictionStatus? restrictionStatus,
    double? averageRating,
    int? completedHelpCount,
    int? receivedHelpCount,
    List<String>? blockedUserIds,
    List<String>? mutedUserIds,
    PrivacySettings? privacySettings,
    bool? twoFactorEnabled,
    bool? isAdmin,
    bool? vulnerableUser,
    bool? hasDisability,
    bool? adminOverrideReciprocity,
    List<SessionDevice>? sessions,
    List<String>? trustFlags,
  }) {
    return UserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      shortBio: shortBio ?? this.shortBio,
      city: city ?? this.city,
      area: area ?? this.area,
      verificationBadges: verificationBadges ?? this.verificationBadges,
      trustScore: trustScore ?? this.trustScore,
      availability: availability ?? this.availability,
      helpCategoriesProvided:
          helpCategoriesProvided ?? this.helpCategoriesProvided,
      helpCategoriesRequested:
          helpCategoriesRequested ?? this.helpCategoriesRequested,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      helpGivenCount: helpGivenCount ?? this.helpGivenCount,
      helpReceivedCount: helpReceivedCount ?? this.helpReceivedCount,
      restrictionStatus: restrictionStatus ?? this.restrictionStatus,
      averageRating: averageRating ?? this.averageRating,
      completedHelpCount: completedHelpCount ?? this.completedHelpCount,
      receivedHelpCount: receivedHelpCount ?? this.receivedHelpCount,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      mutedUserIds: mutedUserIds ?? this.mutedUserIds,
      privacySettings: privacySettings ?? this.privacySettings,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      isAdmin: isAdmin ?? this.isAdmin,
      vulnerableUser: vulnerableUser ?? this.vulnerableUser,
      hasDisability: hasDisability ?? this.hasDisability,
      adminOverrideReciprocity:
          adminOverrideReciprocity ?? this.adminOverrideReciprocity,
      sessions: sessions ?? this.sessions,
      trustFlags: trustFlags ?? this.trustFlags,
    );
  }
}

class HelpActionLogEntry {
  const HelpActionLogEntry({
    required this.actorId,
    required this.action,
    required this.createdAt,
  });

  final String actorId;
  final String action;
  final DateTime createdAt;
}

class HelpRequestEntity {
  const HelpRequestEntity({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.category,
    required this.urgency,
    required this.location,
    required this.preferredTime,
    required this.visibility,
    this.attachmentLabel,
    required this.status,
    required this.createdAt,
    this.acceptedHelperId,
    this.emotionalSupportMode = false,
    this.requiresHomeVisit = false,
    this.lateNightSupport = false,
    this.moneyRelated = false,
    this.emergencyOverride = false,
    this.requesterCompletionConfirmed = false,
    this.helperCompletionConfirmed = false,
    this.contactConsentFromRequester = false,
    this.contactConsentFromHelper = false,
    this.safetyCheckInRequired = false,
    this.suggestedHelperIds = const <String>[],
    this.actionLog = const <HelpActionLogEntry>[],
  });

  final String id;
  final String requesterId;
  final String title;
  final String description;
  final RequestCategory category;
  final UrgencyLevel urgency;
  final String location;
  final String preferredTime;
  final HelpRequestVisibility visibility;
  final String? attachmentLabel;
  final HelpRequestStatus status;
  final DateTime createdAt;
  final String? acceptedHelperId;
  final bool emotionalSupportMode;
  final bool requiresHomeVisit;
  final bool lateNightSupport;
  final bool moneyRelated;
  final bool emergencyOverride;
  final bool requesterCompletionConfirmed;
  final bool helperCompletionConfirmed;
  final bool contactConsentFromRequester;
  final bool contactConsentFromHelper;
  final bool safetyCheckInRequired;
  final List<String> suggestedHelperIds;
  final List<HelpActionLogEntry> actionLog;

  bool get isHighRisk {
    return category.isHighRisk ||
        requiresHomeVisit ||
        lateNightSupport ||
        moneyRelated;
  }

  bool get isEmergencyOrExempt {
    return emergencyOverride || category == RequestCategory.emergencySupport;
  }

  HelpRequestEntity copyWith({
    String? id,
    String? requesterId,
    String? title,
    String? description,
    RequestCategory? category,
    UrgencyLevel? urgency,
    String? location,
    String? preferredTime,
    HelpRequestVisibility? visibility,
    String? attachmentLabel,
    bool clearAttachment = false,
    HelpRequestStatus? status,
    DateTime? createdAt,
    String? acceptedHelperId,
    bool clearAcceptedHelper = false,
    bool? emotionalSupportMode,
    bool? requiresHomeVisit,
    bool? lateNightSupport,
    bool? moneyRelated,
    bool? emergencyOverride,
    bool? requesterCompletionConfirmed,
    bool? helperCompletionConfirmed,
    bool? contactConsentFromRequester,
    bool? contactConsentFromHelper,
    bool? safetyCheckInRequired,
    List<String>? suggestedHelperIds,
    List<HelpActionLogEntry>? actionLog,
  }) {
    return HelpRequestEntity(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      location: location ?? this.location,
      preferredTime: preferredTime ?? this.preferredTime,
      visibility: visibility ?? this.visibility,
      attachmentLabel: clearAttachment
          ? null
          : attachmentLabel ?? this.attachmentLabel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedHelperId: clearAcceptedHelper
          ? null
          : acceptedHelperId ?? this.acceptedHelperId,
      emotionalSupportMode: emotionalSupportMode ?? this.emotionalSupportMode,
      requiresHomeVisit: requiresHomeVisit ?? this.requiresHomeVisit,
      lateNightSupport: lateNightSupport ?? this.lateNightSupport,
      moneyRelated: moneyRelated ?? this.moneyRelated,
      emergencyOverride: emergencyOverride ?? this.emergencyOverride,
      requesterCompletionConfirmed:
          requesterCompletionConfirmed ?? this.requesterCompletionConfirmed,
      helperCompletionConfirmed:
          helperCompletionConfirmed ?? this.helperCompletionConfirmed,
      contactConsentFromRequester:
          contactConsentFromRequester ?? this.contactConsentFromRequester,
      contactConsentFromHelper:
          contactConsentFromHelper ?? this.contactConsentFromHelper,
      safetyCheckInRequired:
          safetyCheckInRequired ?? this.safetyCheckInRequired,
      suggestedHelperIds: suggestedHelperIds ?? this.suggestedHelperIds,
      actionLog: actionLog ?? this.actionLog,
    );
  }
}

class HelpMatchEntity {
  const HelpMatchEntity({
    required this.id,
    required this.requesterId,
    required this.helperId,
    required this.requestId,
    required this.status,
    required this.score,
    required this.reasons,
    this.acceptedAt,
    this.completedAt,
  });

  final String id;
  final String requesterId;
  final String helperId;
  final String requestId;
  final MatchStatus status;
  final double score;
  final List<String> reasons;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  HelpMatchEntity copyWith({
    String? id,
    String? requesterId,
    String? helperId,
    String? requestId,
    MatchStatus? status,
    double? score,
    List<String>? reasons,
    DateTime? acceptedAt,
    bool clearAcceptedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return HelpMatchEntity(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      helperId: helperId ?? this.helperId,
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      score: score ?? this.score,
      reasons: reasons ?? this.reasons,
      acceptedAt: clearAcceptedAt ? null : acceptedAt ?? this.acceptedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

class MessageThreadEntity {
  const MessageThreadEntity({
    required this.id,
    required this.requestId,
    required this.participantIds,
    required this.createdAt,
    required this.lastMessageAt,
    this.messageRequestPending = true,
    this.blockedByIds = const <String>[],
    this.mutedByIds = const <String>[],
    this.contactSharedByIds = const <String>[],
    this.flaggedSafetyConcern = false,
  });

  final String id;
  final String requestId;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final bool messageRequestPending;
  final List<String> blockedByIds;
  final List<String> mutedByIds;
  final List<String> contactSharedByIds;
  final bool flaggedSafetyConcern;

  MessageThreadEntity copyWith({
    String? id,
    String? requestId,
    List<String>? participantIds,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    bool? messageRequestPending,
    List<String>? blockedByIds,
    List<String>? mutedByIds,
    List<String>? contactSharedByIds,
    bool? flaggedSafetyConcern,
  }) {
    return MessageThreadEntity(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageRequestPending:
          messageRequestPending ?? this.messageRequestPending,
      blockedByIds: blockedByIds ?? this.blockedByIds,
      mutedByIds: mutedByIds ?? this.mutedByIds,
      contactSharedByIds: contactSharedByIds ?? this.contactSharedByIds,
      flaggedSafetyConcern: flaggedSafetyConcern ?? this.flaggedSafetyConcern,
    );
  }
}

class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.flaggedSafetyConcern = false,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool flaggedSafetyConcern;
}

class ReviewEntity {
  const ReviewEntity({
    required this.id,
    required this.matchId,
    required this.reviewerId,
    required this.revieweeId,
    required this.helpfulness,
    required this.respectfulness,
    required this.safety,
    required this.reliability,
    required this.accuracy,
    required this.feedback,
    required this.createdAt,
    this.flaggedSuspicious = false,
  });

  final String id;
  final String matchId;
  final String reviewerId;
  final String revieweeId;
  final int helpfulness;
  final int respectfulness;
  final int safety;
  final int reliability;
  final int accuracy;
  final String feedback;
  final DateTime createdAt;
  final bool flaggedSuspicious;

  double get rating {
    return (helpfulness + respectfulness + safety + reliability + accuracy) / 5;
  }
}

class ReportEntity {
  const ReportEntity({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    this.assignedModeratorId,
  });

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final String details;
  final ReportStatus status;
  final DateTime createdAt;
  final String? assignedModeratorId;

  ReportEntity copyWith({
    String? id,
    String? reporterId,
    ReportTargetType? targetType,
    String? targetId,
    String? reason,
    String? details,
    ReportStatus? status,
    DateTime? createdAt,
    String? assignedModeratorId,
    bool clearAssignedModerator = false,
  }) {
    return ReportEntity(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      assignedModeratorId: clearAssignedModerator
          ? null
          : assignedModeratorId ?? this.assignedModeratorId,
    );
  }
}

class MoodCheckInEntity {
  const MoodCheckInEntity({
    required this.id,
    required this.userId,
    required this.moodLevel,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String userId;
  final MoodLevel moodLevel;
  final DateTime createdAt;
  final String note;
}

class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  NotificationEntity copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class SupportCircleEntity {
  const SupportCircleEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    this.memberIds = const <String>[],
  });

  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final List<String> memberIds;

  SupportCircleEntity copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? tags,
    List<String>? memberIds,
  }) {
    return SupportCircleEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}
