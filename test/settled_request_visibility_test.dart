import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghmera_app/app/database/database.dart';
import 'package:ghmera_app/app/models/ghmera_models.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';
import 'package:ghmera_app/app/services/app_firestore_sync_service.dart';
import 'package:ghmera_app/app/services/backend_workflow_api_service.dart';
import 'package:ghmera_app/features/help_request/presentation/screens/home_screen.dart';

typedef _RemoteSnapshot = ({
  Map<String, dynamic>? database,
  bool hasPendingWrites,
});

class _FakeSyncService implements AppFirestoreSyncService {
  _FakeSyncService(this.savedDatabase);

  Map<String, dynamic>? savedDatabase;
  final StreamController<_RemoteSnapshot> remote =
      StreamController<_RemoteSnapshot>.broadcast();

  /// When set, the next local writes wait on this until the test completes it.
  Completer<bool>? pendingWrite;
  bool writeResult = true;

  @override
  Future<Map<String, dynamic>?> loadDatabase() async => savedDatabase;

  @override
  Stream<_RemoteSnapshot> watchDatabase() => remote.stream;

  @override
  Future<bool> syncDatabase({
    required Map<String, dynamic> database,
    required List<UserEntity> users,
    required String currentUserId,
  }) {
    return pendingWrite?.future ?? Future<bool>.value(writeResult);
  }

  void push(Map<String, dynamic> database) {
    remote.add((database: database, hasPendingWrites: false));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorkflowApi implements BackendWorkflowApiService {
  Future<BackendWorkflowApiResult> Function(String operation)? onApply;
  final List<String> operations = <String>[];

  @override
  Future<BackendWorkflowApiResult> applyOperation({
    required String operation,
    required String currentUserId,
    required Map<String, dynamic> database,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    operations.add(operation);
    return onApply!(operation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _user(String id, {List<String> badges = const []}) {
  return <String, dynamic>{
    'id': id,
    'fullName': '${id.substring(5).toUpperCase()} Person',
    'email': '$id@example.com',
    'city': 'Accra',
    'area': 'East Legon',
    'verificationBadges': <String>['emailVerified', ...badges],
    'usesDeviceLocation': false,
    'helpCategoriesProvided': <String>['technicalSupport'],
  };
}

Map<String, dynamic> _request(
  String id, {
  String title = 'Router setup',
  String status = 'open',
  String? acceptedHelperId,
  String category = 'technicalSupport',
  bool requiresHomeVisit = false,
}) {
  return <String, dynamic>{
    'id': id,
    'requesterId': 'user_a',
    'title': title,
    'description': 'Please help me with this today.',
    'category': category,
    'urgency': 'medium',
    'location': 'East Legon',
    'preferredTime': 'Today',
    'visibility': 'public',
    'status': status,
    'createdAt': '2026-10-12T10:00:00.000Z',
    'acceptedHelperId': acceptedHelperId,
    'requiresHomeVisit': requiresHomeVisit,
  };
}

Map<String, dynamic> _database({
  required String viewerId,
  required List<Map<String, dynamic>> requests,
  List<String> viewerBadges = const [],
}) {
  Map<String, dynamic> bucket(Map<String, dynamic> user, [List? requests]) {
    return <String, dynamic>{
      'user': user,
      'requests': requests ?? <Object?>[],
      'notifications': <Object?>[],
      'moodCheckIns': <Object?>[],
    };
  }

  return <String, dynamic>{
    '_meta': <String, dynamic>{'currentUserId': viewerId},
    '_shared': <String, dynamic>{
      'matches': <Object?>[],
      'threads': <Object?>[],
      'messages': <Object?>[],
      'reviews': <Object?>[],
      'reports': <Object?>[],
      'supportCircles': <Object?>[],
    },
    'user_a@example.com': bucket(_user('user_a'), requests),
    'user_b@example.com': bucket(_user('user_b')),
    'user_c@example.com': bucket(
      _user(
        'user_c',
        badges: viewerId == 'user_c' ? viewerBadges : const <String>[],
      ),
    ),
  };
}

Future<GhmeraAppState> _signIn(
  Map<String, dynamic> database, {
  _FakeSyncService? sync,
  _FakeWorkflowApi? api,
}) async {
  AppDatabase.instance.hydrateFromMap(database);
  final appState = GhmeraAppState(
    firestoreSyncService: sync ?? _FakeSyncService(database),
    workflowApiService: api ?? _FakeWorkflowApi(),
  );
  await pumpEventQueue();
  return appState;
}

List<String> _ids(Iterable<HelpRequestEntity> requests) =>
    requests.map((request) => request.id).toList();

void main() {
  final takenByB = _request(
    'request_taken',
    status: 'inProgress',
    acceptedHelperId: 'user_b',
    requiresHomeVisit: true,
  );
  final open = _request('request_open', title: 'Printer help');

  tearDown(AppDatabase.instance.clear);

  test('a request taken by B is hidden from C but shown to B', () async {
    final requests = [
      takenByB,
      open,
      _request('request_done', status: 'completed'),
      _request('request_canceled', status: 'canceled'),
      _request('request_disputed', status: 'disputed'),
    ];

    final viewerC = await _signIn(
      _database(viewerId: 'user_c', requests: requests),
    );
    expect(_ids(viewerC.requestsNeedingMyHelp), ['request_open']);
    expect(_ids(viewerC.communityRequests), ['request_open']);
    expect(_ids(viewerC.highRiskRequests), isEmpty);
    expect(viewerC.canCurrentUserOfferHelp('request_taken'), isFalse);
    expect(viewerC.canCurrentUserOfferHelp('request_open'), isTrue);
    viewerC.dispose();

    final viewerB = await _signIn(
      _database(viewerId: 'user_b', requests: requests),
    );
    final helping = viewerB.requestsNeedingMyHelp
        .where((request) => request.acceptedHelperId == 'user_b')
        .toList();
    expect(_ids(helping), ['request_taken']);
    expect(_ids(viewerB.highRiskRequests), ['request_taken']);
    viewerB.dispose();
  });

  test('high-risk requests need a verified helper to offer help', () async {
    final highRisk = _request('request_risky', category: 'emergencySupport');

    final unverified = await _signIn(
      _database(viewerId: 'user_c', requests: [highRisk]),
    );
    expect(_ids(unverified.requestsNeedingMyHelp), ['request_risky']);
    expect(unverified.canCurrentUserOfferHelp('request_risky'), isFalse);
    unverified.dispose();

    final verified = await _signIn(
      _database(
        viewerId: 'user_c',
        requests: [highRisk],
        viewerBadges: ['idVerified'],
      ),
    );
    expect(verified.canCurrentUserOfferHelp('request_risky'), isTrue);
    verified.dispose();
  });

  test('a failed local write does not block later remote updates', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    )..writeResult = false;
    final appState = await _signIn(sync.savedDatabase!, sync: sync);

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    await pumpEventQueue();
    sync.push(
      _database(
        viewerId: 'user_c',
        requests: [
          _request(
            'request_open',
            status: 'accepted',
            acceptedHelperId: 'user_b',
          ),
        ],
      ),
    );
    await pumpEventQueue();

    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  test('remote updates held back during a write apply once it lands', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final appState = await _signIn(sync.savedDatabase!, sync: sync);
    final write = sync.pendingWrite = Completer<bool>();

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    sync.push(
      _database(
        viewerId: 'user_c',
        requests: [
          _request(
            'request_open',
            status: 'accepted',
            acceptedHelperId: 'user_b',
          ),
        ],
      ),
    );
    await pumpEventQueue();
    expect(_ids(appState.requestsNeedingMyHelp), ['request_open']);

    write.complete(true);
    await pumpEventQueue();
    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  test('pull to refresh applies saved data even during a write', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final appState = await _signIn(sync.savedDatabase!, sync: sync);
    sync.pendingWrite = Completer<bool>();
    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);

    sync.savedDatabase = _database(
      viewerId: 'user_c',
      requests: [
        _request('request_open', status: 'accepted', acceptedHelperId: 'user_b'),
      ],
    );
    await appState.refreshHelpRequests();

    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  test('a rejected volunteer shows the server state and refreshes', () async {
    final takenDatabase = _database(
      viewerId: 'user_c',
      requests: [
        _request('request_open', status: 'accepted', acceptedHelperId: 'user_b'),
      ],
    );
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi()
      ..onApply = (_) async => throw BackendWorkflowApiException(
        'Someone is already helping with this request.',
        statusCode: 409,
        database: takenDatabase,
      );
    final appState = await _signIn(sync.savedDatabase!, sync: sync, api: api);
    sync.savedDatabase = takenDatabase;

    final matched = await appState.volunteerForHelpRequest('request_open');
    await pumpEventQueue();

    expect(matched, isFalse);
    expect(
      appState.lastWorkflowError,
      'Someone is already helping with this request.',
    );
    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  testWidgets('details for a request someone else took offer no help action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ghmera_credits_intro_seen_user_c': true,
    });
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi();
    late GhmeraAppState appState;
    await tester.runAsync(() async {
      appState = await _signIn(sync.savedDatabase!, sync: sync, api: api);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<GhmeraAppState>.value(
        value: appState,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Printer help'));
    await tester.pumpAndSettle();
    expect(find.text('I can help'), findsOneWidget);

    await tester.runAsync(() async {
      sync.push(
        _database(
          viewerId: 'user_c',
          requests: [
            _request(
              'request_open',
              title: 'Printer help',
              status: 'accepted',
              acceptedHelperId: 'user_b',
            ),
          ],
        ),
      );
      await pumpEventQueue();
    });
    await tester.pumpAndSettle();

    expect(find.text('I can help'), findsNothing);
    expect(
      find.text('Someone is already helping with this request.'),
      findsOneWidget,
    );
    expect(find.textContaining('Chat'), findsNothing);
    expect(api.operations, isEmpty);
  });
}
