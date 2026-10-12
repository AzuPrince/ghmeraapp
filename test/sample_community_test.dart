import 'package:flutter_test/flutter_test.dart';

import 'package:ghmera_app/app/database/database.dart';
import 'package:ghmera_app/app/providers/ghmera_app_state.dart';

import '../integration_test/sample_community.dart';

void main() {
  tearDown(AppDatabase.instance.clear);

  test('the screenshot community is fictional and loads offline', () async {
    final database = buildSampleCommunity(now: DateTime.utc(2026, 10, 12, 9));
    AppDatabase.instance.hydrateFromMap(database);
    final api = SampleCommunityWorkflowApi(database);
    final appState = GhmeraAppState(
      firestoreSyncService: SampleCommunitySyncService(database),
      workflowApiService: api,
    );
    await pumpEventQueue();

    expect(appState.currentUser.fullName, sampleViewerName);
    expect(
      appState.requestsNeedingMyHelp.map((request) => request.title),
      hasLength(4),
    );
    expect(appState.requestsNeedingMyHelp.first.title, sampleSofaRequestTitle);

    final credits = appState.currentUserCredits;
    expect(
      (credits.available, credits.earned, credits.spent, credits.held),
      (5, 4, 2, 2),
    );
    final requester = appState.helpStatsForUser('sample_ama');
    expect(
      (requester.helpsGiven, requester.helpsReceived, requester.reviewCount),
      (7, 2, 5),
    );
    expect(appState.messageThreads, hasLength(1));

    for (final user in appState.users) {
      expect(realMemberNames, isNot(contains(user.fullName)));
      expect(user.profilePhoto, isNull);
      expect(user.email, endsWith('@example.com'));
    }
    expect(api.operations, isEmpty);
    appState.dispose();
  });
}
