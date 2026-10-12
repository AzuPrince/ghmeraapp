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

  /// Anything other than reading or watching, such as a direct write.
  final List<Symbol> unexpectedCalls = <Symbol>[];

  @override
  Future<Map<String, dynamic>?> loadDatabase() async => savedDatabase;

  @override
  Stream<_RemoteSnapshot> watchDatabase() => remote.stream;

  void push(Map<String, dynamic> database) {
    remote.add((database: database, hasPendingWrites: false));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpectedCalls.add(invocation.memberName);
    return super.noSuchMethod(invocation);
  }
}

typedef _ServerCall = ({
  String operation,
  Map<String, dynamic> payload,
  Map<String, dynamic> database,
});

class _FakeWorkflowApi implements BackendWorkflowApiService {
  _FakeWorkflowApi([this.server]);

  /// Plays the server: answers with its saved database unless [onApply] says
  /// otherwise.
  final _FakeSyncService? server;
  Future<BackendWorkflowApiResult> Function(String operation)? onApply;
  final List<_ServerCall> calls = <_ServerCall>[];

  List<String> get operations => calls.map((call) => call.operation).toList();

  @override
  Future<BackendWorkflowApiResult> applyOperation({
    required String operation,
    required String currentUserId,
    required Map<String, dynamic> database,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    calls.add((operation: operation, payload: payload, database: database));
    final handler = onApply;
    if (handler != null) {
      return handler(operation);
    }
    return Future<BackendWorkflowApiResult>.value(
      BackendWorkflowApiResult(
        database: server!.savedDatabase!,
        result: const <String, dynamic>{},
      ),
    );
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
  Duration profileSyncDelay = Duration.zero,
}) async {
  AppDatabase.instance.hydrateFromMap(database);
  final syncService = sync ?? _FakeSyncService(database);
  final appState = GhmeraAppState(
    firestoreSyncService: syncService,
    workflowApiService: api ?? _FakeWorkflowApi(syncService),
    profileSyncDelay: profileSyncDelay,
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

  test('unverified helpers can offer help on high-risk requests', () async {
    final highRisk = _request('request_risky', category: 'emergencySupport');

    final unverified = await _signIn(
      _database(viewerId: 'user_c', requests: [highRisk]),
    );
    expect(_ids(unverified.requestsNeedingMyHelp), ['request_risky']);
    expect(_ids(unverified.highRiskRequests), ['request_risky']);
    expect(unverified.canCurrentUserOfferHelp('request_risky'), isTrue);
    unverified.dispose();
  });

  Map<String, dynamic> takenDatabase() => _database(
    viewerId: 'user_c',
    requests: [
      _request('request_open', status: 'accepted', acceptedHelperId: 'user_b'),
    ],
  );

  test('own edits go to the server, never straight to Firestore', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi(sync);
    final appState = await _signIn(sync.savedDatabase!, sync: sync, api: api);

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    await pumpEventQueue();

    expect(api.operations, ['sync_my_profile']);
    final call = api.calls.single;
    final sentUser = call.payload['user'] as Map<String, dynamic>;
    expect(sentUser['id'], 'user_c');
    expect(sentUser['helpCategoriesProvided'], contains('errands'));
    expect(
      call.database.keys.where((key) => !key.startsWith('_')),
      ['user_c@example.com'],
    );
    expect(sync.unexpectedCalls, isEmpty);
    appState.dispose();
  });

  test('rapid profile edits are sent as one update', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi(sync);
    final appState = await _signIn(
      sync.savedDatabase!,
      sync: sync,
      api: api,
      profileSyncDelay: const Duration(milliseconds: 40),
    );

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    appState.toggleCurrentUserRequestedCategory(RequestCategory.childcare);
    appState.setAvailability(false);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(api.operations, ['sync_my_profile']);
    final payload = api.calls.single.payload;
    final sentUser = payload['user'] as Map<String, dynamic>;
    expect(sentUser['helpCategoriesProvided'], contains('errands'));
    expect(sentUser['helpCategoriesRequested'], contains('childcare'));
    expect(sentUser['availability'], isFalse);
    expect(
      (payload['addNotifications'] as List).single['title'],
      'Availability is off',
    );
    appState.dispose();
  });

  test('notifications, moods and blocks call server operations', () async {
    final database = _database(viewerId: 'user_c', requests: [open]);
    (database['user_c@example.com'] as Map<String, dynamic>)['notifications'] =
        <Object?>[
          <String, dynamic>{
            'id': 'notification_1',
            'userId': 'user_c',
            'type': 'adminUpdate',
            'title': 'Hello',
            'message': 'World',
            'createdAt': '2026-10-12T10:00:00.000Z',
            'isRead': false,
          },
        ];
    final sync = _FakeSyncService(database);
    final api = _FakeWorkflowApi(sync);
    final appState = await _signIn(database, sync: sync, api: api);

    appState.markNotificationRead('notification_1');
    appState.recordMood(MoodLevel.good);
    appState.blockUserAccount('user_b', requestId: 'request_open');
    await pumpEventQueue();

    expect(api.operations, [
      'update_my_notifications',
      'record_mood',
      'block_user',
    ]);
    expect(api.calls[0].payload['readIds'], ['notification_1']);
    expect(api.calls[2].payload, {'userId': 'user_b', 'requestId': 'request_open'});
    expect(sync.unexpectedCalls, isEmpty);
    appState.dispose();
  });

  test('the live listener applies other members\' changes', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final appState = await _signIn(sync.savedDatabase!, sync: sync);
    expect(_ids(appState.requestsNeedingMyHelp), ['request_open']);

    sync.push(takenDatabase());
    await pumpEventQueue();

    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  test('live updates during a server call are fetched once it lands', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final response = Completer<BackendWorkflowApiResult>();
    final api = _FakeWorkflowApi(sync)..onApply = (_) => response.future;
    final appState = await _signIn(sync.savedDatabase!, sync: sync, api: api);

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    await pumpEventQueue();
    expect(api.operations, ['sync_my_profile']);

    sync.push(takenDatabase());
    await pumpEventQueue();
    expect(_ids(appState.requestsNeedingMyHelp), ['request_open']);

    final staleResponse = _database(viewerId: 'user_c', requests: [open]);
    sync.savedDatabase = takenDatabase();
    response.complete(BackendWorkflowApiResult(database: staleResponse));
    await pumpEventQueue();

    expect(appState.requestsNeedingMyHelp, isEmpty);
    appState.dispose();
  });

  test('pull to refresh applies saved data even during a server call', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi(sync)
      ..onApply = (_) => Completer<BackendWorkflowApiResult>().future;
    final appState = await _signIn(sync.savedDatabase!, sync: sync, api: api);
    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    await pumpEventQueue();

    sync.savedDatabase = takenDatabase();
    await appState.refreshHelpRequests();

    expect(appState.requestsNeedingMyHelp, isEmpty);
  });

  test('unsent profile edits survive a live update', () async {
    final sync = _FakeSyncService(
      _database(viewerId: 'user_c', requests: [open]),
    );
    final api = _FakeWorkflowApi(sync);
    final appState = await _signIn(
      sync.savedDatabase!,
      sync: sync,
      api: api,
      profileSyncDelay: const Duration(milliseconds: 40),
    );

    appState.toggleCurrentUserProvidedCategory(RequestCategory.errands);
    sync.push(takenDatabase());
    await pumpEventQueue();

    expect(appState.requestsNeedingMyHelp, isEmpty);
    expect(
      appState.currentUser.helpCategoriesProvided,
      contains(RequestCategory.errands),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(api.operations, ['sync_my_profile']);
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
    final api = _FakeWorkflowApi(sync)
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
    final api = _FakeWorkflowApi(sync);
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

  testWidgets('high-risk details show a safety reminder beside I can help', (
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
      _database(
        viewerId: 'user_c',
        requests: [
          _request(
            'request_risky',
            title: 'Evening pickup',
            requiresHomeVisit: true,
          ),
        ],
      ),
    );
    late GhmeraAppState appState;
    await tester.runAsync(() async {
      appState = await _signIn(sync.savedDatabase!, sync: sync);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<GhmeraAppState>.value(
        value: appState,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening pickup'));
    await tester.pumpAndSettle();

    expect(find.text('I can help'), findsOneWidget);
    expect(
      find.text(
        'This request has extra safety checks. Meet in public where possible '
        'and keep chats in Ghmera.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ID-verified'), findsNothing);
  });
}
