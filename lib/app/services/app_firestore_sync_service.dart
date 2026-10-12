import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';


class AppFirestoreSyncService {
  AppFirestoreSyncService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String _trackerCollection = 'user_trackers';
  static const String _globalAppStateCollection = 'global_app_state';
  static const String _globalAppStateDocId = 'live';
  static const String _usersRequestsCollection = 'Users_requests';
  static const String _sentRequestsDocId = 'sent request';
  // Shared app state is saved only by the workflow API. This service reads
  // and watches it; it never writes it.
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
      final mirroredRequestBuckets = await _loadMirroredRequestBuckets();
      final globalDatabase = await _loadGlobalDatabase();
      if (globalDatabase != null) {
        return _mergeMirroredRequestsIntoDatabase(
          globalDatabase,
          mirroredRequestBuckets,
        );
      }

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
          return _mergeMirroredRequestsIntoDatabase(
            _normalizeMap(rawDatabase),
            mirroredRequestBuckets,
          );
        }
      }

      final fallbackDatabase = await _loadFallbackDatabase(
        trackerRef: trackerRef,
        authEmail: trackerIdentity.authEmail,
      );
      if (fallbackDatabase == null) {
        return null;
      }

      return _mergeMirroredRequestsIntoDatabase(
        fallbackDatabase,
        mirroredRequestBuckets,
      );
    } catch (error, stackTrace) {
      debugPrint('Firestore app-state load failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Stream<({Map<String, dynamic>? database, bool hasPendingWrites})>
  watchDatabase() async* {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final trackerIdentity = await _resolveTrackerIdentity();
    final trackerRef = trackerIdentity == null
        ? null
        : _trackerRef(trackerIdentity.docId);

    yield* _globalAppStateRef().snapshots().asyncMap((appStateSnapshot) async {
      try {
        final mirroredRequestBuckets = await _loadMirroredRequestBuckets();
        if (appStateSnapshot.exists) {
          final rawDatabase = appStateSnapshot.data()?['database'];
          if (rawDatabase is Map) {
            return (
              database: _mergeMirroredRequestsIntoDatabase(
                _normalizeMap(rawDatabase),
                mirroredRequestBuckets,
              ),
              hasPendingWrites: appStateSnapshot.metadata.hasPendingWrites,
            );
          }
        }

        if (trackerRef == null) {
          return (
            database: null,
            hasPendingWrites: appStateSnapshot.metadata.hasPendingWrites,
          );
        }

        final fallbackDatabase = await _loadFallbackDatabase(
          trackerRef: trackerRef,
          authEmail: trackerIdentity?.authEmail,
        );

        return (
          database: fallbackDatabase == null
              ? null
              : _mergeMirroredRequestsIntoDatabase(
                  fallbackDatabase,
                  mirroredRequestBuckets,
                ),
          hasPendingWrites: appStateSnapshot.metadata.hasPendingWrites,
        );
      } catch (error, stackTrace) {
        debugPrint('Firestore app-state watch failed: $error');
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
        return (
          database: null,
          hasPendingWrites: appStateSnapshot.metadata.hasPendingWrites,
        );
      }
    });
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
      final userRequests = userData['requests'];
      final userNotifications = userData['notifications'];
      final userMoodCheckIns = userData['moodCheckIns'];
      userData.remove('requests');
      userData.remove('notifications');
      userData.remove('moodCheckIns');
      final email = (userData['email'] as String?)?.trim().toLowerCase();
      final bucketKey = email != null && email.isNotEmpty ? email : userDoc.id;
      rawDatabase[bucketKey] = <String, dynamic>{
        'user': userData,
        'requests': userRequests is List ? userRequests : const <Object?>[],
        'notifications': userNotifications is List
            ? userNotifications
            : const <Object?>[],
        'moodCheckIns': userMoodCheckIns is List
            ? userMoodCheckIns
            : const <Object?>[],
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

  DocumentReference<Map<String, dynamic>> _globalAppStateRef() {
    return _firestore
        .collection(_globalAppStateCollection)
        .doc(_globalAppStateDocId);
  }

  DocumentReference<Map<String, dynamic>> _sentRequestsRef() {
    return _firestore
        .collection(_usersRequestsCollection)
        .doc(_sentRequestsDocId);
  }

  Future<Map<String, dynamic>?> _loadGlobalDatabase() async {
    final appStateSnapshot = await _globalAppStateRef().get();
    if (!appStateSnapshot.exists) {
      return null;
    }

    final rawDatabase = appStateSnapshot.data()?['database'];
    if (rawDatabase is Map) {
      return _normalizeMap(rawDatabase);
    }

    return null;
  }

  Future<Map<String, _MirroredRequestBucket>>
  _loadMirroredRequestBuckets() async {
    final requestsSnapshot = await _sentRequestsRef().get();
    final mirroredRequestBuckets = <String, _MirroredRequestBucket>{};

    if (!requestsSnapshot.exists) {
      return mirroredRequestBuckets;
    }

    final mirroredRequestsData = requestsSnapshot.data();
    if (mirroredRequestsData == null) {
      return mirroredRequestBuckets;
    }

    for (final entry in mirroredRequestsData.entries) {
      if (entry.key == 'lastSyncedAt' || entry.value is! Map) {
        continue;
      }

      final requestData = _normalizeMap(entry.value as Map<dynamic, dynamic>);
      final requesterEmail = (requestData['requesterEmail'] as String?)
          ?.trim()
          .toLowerCase();
      final requesterId = (requestData['requesterId'] as String?)?.trim();
      final requests = _serializedList(requestData['requests']);
      if (requests.isEmpty) {
        continue;
      }

      mirroredRequestBuckets[entry.key] = _MirroredRequestBucket(
        requesterEmail: requesterEmail,
        requesterId: requesterId,
        requests: requests,
      );
    }

    return mirroredRequestBuckets;
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

  List<Object?> _serializedList(Object? rawValue) {
    if (rawValue is List) {
      return List<Object?>.from(rawValue);
    }

    return const <Object?>[];
  }

  Map<String, dynamic> _mergeMirroredRequestsIntoDatabase(
    Map<String, dynamic> database,
    Map<String, _MirroredRequestBucket> mirroredRequestBuckets,
  ) {
    if (mirroredRequestBuckets.isEmpty) {
      return database;
    }

    final mergedDatabase = <String, dynamic>{};
    for (final entry in database.entries) {
      if (entry.key.startsWith('_') || entry.value is! Map) {
        mergedDatabase[entry.key] = entry.value;
        continue;
      }

      final bucket = _normalizeMap(entry.value as Map<dynamic, dynamic>);
      final rawUser = bucket['user'];
      if (rawUser is! Map) {
        mergedDatabase[entry.key] = bucket;
        continue;
      }

      final user = _normalizeMap(rawUser);
      final requesterEmail = (user['email'] as String?)?.trim().toLowerCase();
      final requesterId = (user['id'] as String?)?.trim();
      final mirroredBucket =
          (requesterEmail != null && requesterEmail.isNotEmpty)
          ? mirroredRequestBuckets[requesterEmail]
          : null;
      final resolvedMirroredBucket =
          mirroredBucket ??
          ((requesterId != null && requesterId.isNotEmpty)
              ? mirroredRequestBuckets[requesterId]
              : null);

      mergedDatabase[entry.key] = <String, dynamic>{
        ...bucket,
        if (resolvedMirroredBucket != null)
          'requests': resolvedMirroredBucket.requests,
      };
    }

    return mergedDatabase;
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

class _MirroredRequestBucket {
  const _MirroredRequestBucket({
    required this.requesterEmail,
    required this.requesterId,
    required this.requests,
  });

  final String? requesterEmail;
  final String? requesterId;
  final List<Object?> requests;
}
