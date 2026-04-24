import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ghmera_models.dart';

class AppFirestoreSyncService {
  AppFirestoreSyncService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String _trackerCollection = 'user_trackers';
  static const String _usersSubcollection = 'users';
  static const String _appStateSubcollection = 'app_state';
  static const String _appStateDocId = 'live';
  static const String _deviceUuidPrefsKey = 'ghmera_device_uuid';
  static const Uuid _uuid = Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>?> loadDatabase() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    try {
      final trackerIdentity = await _resolveTrackerIdentity();
      if (trackerIdentity == null) {
        return null;
      }

      final trackerRef = _trackerRef(trackerIdentity.docId);
      final appStateSnapshot = await trackerRef
          .collection(_appStateSubcollection)
          .doc(_appStateDocId)
          .get();

      if (appStateSnapshot.exists) {
        final rawDatabase = appStateSnapshot.data()?['database'];
        if (rawDatabase is Map) {
          return _normalizeMap(rawDatabase);
        }
      }

      return _loadFallbackDatabase(
        trackerRef: trackerRef,
        authEmail: trackerIdentity.authEmail,
      );
    } catch (error, stackTrace) {
      debugPrint('Firestore app-state load failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Future<void> syncDatabase({
    required Map<String, dynamic> database,
    required List<UserEntity> users,
    required String currentUserId,
  }) async {
    if (users.isEmpty || Firebase.apps.isEmpty) {
      return;
    }

    try {
      final trackerIdentity = await _resolveTrackerIdentity();
      if (trackerIdentity == null) {
        return;
      }

      final trackerRef = _trackerRef(trackerIdentity.docId);
      final batch = _firestore.batch();

      batch.set(trackerRef, <String, dynamic>{
        'trackerType': trackerIdentity.type,
        'trackerId': trackerIdentity.id,
        'authEmail': trackerIdentity.authEmail,
        'deviceUuid': trackerIdentity.deviceUuid,
        'currentUserId': currentUserId,
        'userCount': users.length,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(
        trackerRef.collection(_appStateSubcollection).doc(_appStateDocId),
        <String, dynamic>{
          'database': database,
          'currentUserId': currentUserId,
          'schemaVersion': 1,
          'lastSyncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final user in users) {
        batch.set(
          trackerRef.collection(_usersSubcollection).doc(user.id),
          <String, dynamic>{
            ..._serializeUser(user),
            'trackedBy': <String, dynamic>{
              'type': trackerIdentity.type,
              'id': trackerIdentity.id,
            },
            'lastSyncedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (error, stackTrace) {
      debugPrint('Firestore app-state sync failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<Map<String, dynamic>?> _loadFallbackDatabase({
    required DocumentReference<Map<String, dynamic>> trackerRef,
    required String? authEmail,
  }) async {
    final trackerSnapshot = await trackerRef.get();
    final usersSnapshot = await trackerRef
        .collection(_usersSubcollection)
        .get();
    if (usersSnapshot.docs.isEmpty) {
      return null;
    }

    final trackerData = trackerSnapshot.data();
    final currentUserId = trackerData?['currentUserId'] as String?;
    final rawDatabase = <String, dynamic>{
      '_meta': <String, dynamic>{
        if (currentUserId != null && currentUserId.isNotEmpty)
          'currentUserId': currentUserId,
        if (authEmail != null && authEmail.isNotEmpty)
          'currentUserEmail': authEmail,
      },
      '_shared': _emptySharedBucket(),
    };

    for (final userDoc in usersSnapshot.docs) {
      final userData = _normalizeMap(userDoc.data());
      final email = (userData['email'] as String?)?.trim().toLowerCase();
      final bucketKey = email != null && email.isNotEmpty ? email : userDoc.id;
      rawDatabase[bucketKey] = <String, dynamic>{
        'user': userData,
        'requests': const <Object?>[],
        'notifications': const <Object?>[],
        'moodCheckIns': const <Object?>[],
      };
    }

    return rawDatabase;
  }

  Future<_TrackerIdentity?> _resolveTrackerIdentity() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    final deviceUuid = await _getOrCreateDeviceUuid();
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    final isAuthenticated = email != null && email.isNotEmpty;
    final trackerType = isAuthenticated ? 'email' : 'device_uuid';
    final trackerId = isAuthenticated ? email : deviceUuid;
    if (trackerId.isEmpty) {
      return null;
    }

    return _TrackerIdentity(
      type: trackerType,
      id: trackerId,
      docId: '${trackerType}_$trackerId',
      authEmail: isAuthenticated ? email : null,
      deviceUuid: deviceUuid,
    );
  }

  DocumentReference<Map<String, dynamic>> _trackerRef(String docId) {
    return _firestore.collection(_trackerCollection).doc(docId);
  }

  Future<String> _getOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceUuidPrefsKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _uuid.v4();
    await prefs.setString(_deviceUuidPrefsKey, generated);
    return generated;
  }

  Map<String, dynamic> _emptySharedBucket() {
    return <String, dynamic>{
      'matches': const <Object?>[],
      'threads': const <Object?>[],
      'messages': const <Object?>[],
      'reviews': const <Object?>[],
      'reports': const <Object?>[],
      'supportCircles': const <Object?>[],
    };
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> rawValue) {
    return rawValue.map((key, value) => MapEntry(key.toString(), value));
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
}

class _TrackerIdentity {
  const _TrackerIdentity({
    required this.type,
    required this.id,
    required this.docId,
    required this.authEmail,
    required this.deviceUuid,
  });

  final String type;
  final String id;
  final String docId;
  final String? authEmail;
  final String deviceUuid;
}
