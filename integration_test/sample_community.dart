import 'package:ghmera_app/app/services/app_firestore_sync_service.dart';
import 'package:ghmera_app/app/services/backend_workflow_api_service.dart';

// A fictional Accra community for App Store screenshots. Every person and
// request here is made up; none of it is, or is copied from, member data.
// It lives under integration_test/ so it is never part of an app build.

const String sampleViewerId = 'sample_abena';
const String sampleViewerName = 'Abena Owusu';
const String sampleHelperName = 'Selorm Agbeko';
const String sampleSofaRequestTitle = 'Help moving a sofa upstairs';
const String sampleLastChatMessage = 'Thank you so much, Selorm!';

/// Names of real members seen in the demo account's live data. They must
/// never appear in screenshots.
const List<String> realMemberNames = <String>['Prince Azu', 'Isaac Gaius'];

const List<(String, String)> _pastRequests = <(String, String)>[
  ('Carry shopping home from the market', 'errands'),
  ('Fix a slow laptop', 'technicalSupport'),
  ('Homework help for my son', 'studyHelp'),
  ('Move a bed frame across town', 'movingHelp'),
  ('Ride to a job interview', 'transportation'),
  ('Set up a new Wi-Fi router', 'technicalSupport'),
  ('Practise for a driving theory test', 'studyHelp'),
  ('Cook for a family gathering', 'foodSupport'),
  ('Feedback on my CV', 'informationAdvice'),
  ('Assemble a wardrobe', 'movingHelp'),
  ('Talk through a stressful week', 'emotionalSupport'),
  ('Grocery run for the week', 'errands'),
];

const List<String> _feedback = <String>[
  'Kind, on time and really patient. Thank you!',
  'Made a stressful day so much easier.',
  'Friendly and careful. Would happily ask again.',
  'Went above and beyond. Highly recommended.',
];

/// The fictional community in the shape [AppDatabase.hydrateFromMap] reads.
/// Times are relative to [now] so the screens show recent activity.
Map<String, dynamic> buildSampleCommunity({DateTime? now}) {
  final clock = now ?? DateTime.now();
  String ago(Duration age) => clock.subtract(age).toUtc().toIso8601String();

  final users = <String, Map<String, dynamic>>{};
  final requests = <Map<String, dynamic>>[];
  final matches = <Map<String, dynamic>>[];
  final reviews = <Map<String, dynamic>>[];

  void person(
    String id,
    String name,
    String area, {
    List<String> badges = const <String>['emailVerified', 'phoneVerified'],
    List<String> offers = const <String>[],
    String bio = '',
  }) {
    users[id] = <String, dynamic>{
      'id': id,
      'fullName': name,
      'email': '$id@example.com',
      'shortBio': bio,
      'city': 'Accra',
      'area': area,
      'verificationBadges': badges,
      'availability': true,
      'helpCategoriesProvided': offers,
      'usesDeviceLocation': false,
    };
  }

  Map<String, dynamic> request({
    required String id,
    required String requesterId,
    required String title,
    required String category,
    required String description,
    required Duration age,
    String urgency = 'medium',
    String status = 'open',
    String? helperId,
    String preferredTime = '',
    String? location,
  }) {
    final completed = status == 'completed';
    final entry = <String, dynamic>{
      'id': id,
      'requesterId': requesterId,
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'location': location ?? '${users[requesterId]!['area']}, Accra',
      'preferredTime': preferredTime,
      'visibility': 'public',
      'status': status,
      'createdAt': ago(age),
      'acceptedHelperId': helperId,
      'requesterCompletionConfirmed': completed,
      'helperCompletionConfirmed': completed,
      'actionLog': <Map<String, dynamic>>[
        <String, dynamic>{
          'actorId': requesterId,
          'action': 'Request created',
          'createdAt': ago(age),
        },
        if (helperId != null)
          <String, dynamic>{
            'actorId': helperId,
            'action': 'Helper accepted',
            'createdAt': ago(age - const Duration(minutes: 20)),
          },
        if (completed)
          <String, dynamic>{
            'actorId': requesterId,
            'action': 'Help completed',
            'createdAt': ago(age - const Duration(hours: 3)),
          },
      ],
    };
    requests.add(entry);
    return entry;
  }

  void completed(
    String requesterId,
    String helperId, {
    required int daysAgo,
    List<int>? rating,
    String? title,
    String? category,
  }) {
    final index = requests.length;
    final (pastTitle, pastCategory) = _pastRequests[index % _pastRequests.length];
    final id = 'sample_done_$index';
    final age = Duration(days: daysAgo, hours: 4);
    request(
      id: id,
      requesterId: requesterId,
      title: title ?? pastTitle,
      category: category ?? pastCategory,
      description: 'Thanks to everyone who offered.',
      age: age,
      status: 'completed',
      helperId: helperId,
    );
    matches.add(<String, dynamic>{
      'id': 'match_$id',
      'requesterId': requesterId,
      'helperId': helperId,
      'requestId': id,
      'status': 'completed',
      'score': 0.9,
      'reasons': <String>[],
      'acceptedAt': ago(age - const Duration(minutes: 20)),
      'completedAt': ago(age - const Duration(hours: 3)),
    });
    if (rating != null) {
      reviews.add(<String, dynamic>{
        'id': 'review_$id',
        'matchId': 'match_$id',
        'reviewerId': requesterId,
        'revieweeId': helperId,
        'helpfulness': rating[0],
        'respectfulness': rating[1],
        'safety': rating[2],
        'reliability': rating[3],
        'accuracy': rating[4],
        'feedback': _feedback[index % _feedback.length],
        'createdAt': ago(age - const Duration(hours: 4)),
      });
    }
  }

  const great = <int>[5, 5, 5, 5, 5];
  const good = <int>[5, 5, 5, 4, 4];

  person(
    sampleViewerId,
    sampleViewerName,
    'East Legon',
    offers: const <String>[
      'errands',
      'movingHelp',
      'studyHelp',
      'technicalSupport',
    ],
    bio:
        'Primary school teacher. Happy to run errands, carry boxes or help '
        'with homework at weekends.',
  );
  person(
    'sample_ama',
    'Ama Mensah',
    'Osu',
    badges: const <String>['emailVerified', 'phoneVerified', 'idVerified'],
  );
  person('sample_esi', 'Esi Darko', 'Labone');
  person('sample_kwesi', 'Kwesi Appiah', 'Airport Residential');
  person('sample_yaw', 'Yaw Boateng', 'Cantonments', badges: const <String>[
    'emailVerified',
  ]);
  person(
    'sample_selorm',
    sampleHelperName,
    'East Legon',
    badges: const <String>['emailVerified', 'phoneVerified', 'idVerified'],
    offers: const <String>['technicalSupport', 'studyHelp'],
  );
  const pool = <String>[
    'sample_kofi',
    'sample_akosua',
    'sample_naa',
    'sample_fiifi',
    'sample_adwoa',
  ];
  person('sample_kofi', 'Kofi Larbi', 'Tema');
  person('sample_akosua', 'Akosua Frimpong', 'Dzorwulu');
  person('sample_naa', 'Naa Lamptey', 'Teshie');
  person('sample_fiifi', 'Fiifi Quansah', 'Spintex');
  person('sample_adwoa', 'Adwoa Asare', 'Madina');

  // Track records shown next to each request: helps given, help received,
  // and how many of the helps were rated.
  void history(
    String userId, {
    required int given,
    required int received,
    required int rated,
  }) {
    for (var i = 0; i < given; i++) {
      completed(
        pool[i % pool.length],
        userId,
        daysAgo: 8 + i * 5,
        rating: i < rated ? (i == 1 ? good : great) : null,
      );
    }
    for (var i = 0; i < received; i++) {
      completed(userId, pool[(i + 2) % pool.length], daysAgo: 11 + i * 9);
    }
  }

  history('sample_ama', given: 7, received: 2, rated: 5);
  history('sample_esi', given: 5, received: 2, rated: 4);
  history('sample_kwesi', given: 3, received: 2, rated: 3);
  history('sample_selorm', given: 12, received: 3, rated: 9);

  // The viewer helped four people and was helped twice.
  completed(
    'sample_naa',
    sampleViewerId,
    daysAgo: 4,
    rating: great,
    title: 'Grocery run for the week',
    category: 'errands',
  );
  completed(
    'sample_fiifi',
    sampleViewerId,
    daysAgo: 9,
    rating: great,
    title: 'Fix a slow laptop',
    category: 'technicalSupport',
  );
  completed(
    'sample_adwoa',
    sampleViewerId,
    daysAgo: 15,
    rating: good,
    title: 'Homework help for my son',
    category: 'studyHelp',
  );
  completed(
    'sample_esi',
    sampleViewerId,
    daysAgo: 24,
    rating: great,
    title: 'Carry a fridge up two floors',
    category: 'movingHelp',
  );
  completed(
    sampleViewerId,
    'sample_kofi',
    daysAgo: 12,
    title: 'Carry boxes to my new flat',
    category: 'movingHelp',
  );
  completed(
    sampleViewerId,
    'sample_akosua',
    daysAgo: 20,
    title: 'Proofread my cover letter',
    category: 'studyHelp',
  );

  // Open requests on Give Help.
  request(
    id: 'sample_sofa',
    requesterId: 'sample_ama',
    title: sampleSofaRequestTitle,
    category: 'movingHelp',
    description:
        'My new two-seater will not fit up the stairs on my own. It needs '
        'two people and about 30 minutes.',
    urgency: 'high',
    preferredTime: 'Today, 5:00 PM',
    age: const Duration(minutes: 18),
  );
  request(
    id: 'sample_prescription',
    requesterId: 'sample_esi',
    title: "Collect my grandmother's prescription",
    category: 'errands',
    description:
        'It is ready at the pharmacy near Labone. I am at work until 7 and '
        'she needs it this evening.',
    preferredTime: 'Today, before 7:00 PM',
    age: const Duration(minutes: 42),
  );
  request(
    id: 'sample_phone',
    requesterId: 'sample_kwesi',
    title: "Set up my mum's new smartphone",
    category: 'technicalSupport',
    description:
        'She wants WhatsApp and video calls working so she can see the '
        'grandchildren. Should take under an hour.',
    preferredTime: 'Saturday morning',
    age: const Duration(hours: 2, minutes: 10),
  );
  request(
    id: 'sample_maths',
    requesterId: 'sample_yaw',
    title: "Maths revision before Friday's exam",
    category: 'studyHelp',
    description:
        'Looking for someone patient to go through algebra and graphs with '
        'me for an hour or two.',
    urgency: 'low',
    preferredTime: 'Thursday, 4:00 PM',
    age: const Duration(hours: 5),
  );

  // The viewer's own requests on Receive Help.
  request(
    id: 'sample_laptop',
    requesterId: sampleViewerId,
    title: 'Help choosing a laptop',
    category: 'technicalSupport',
    description:
        'Buying my first laptop for lesson planning. I would love someone '
        'who knows the specs to come along and compare options.',
    urgency: 'low',
    status: 'inProgress',
    helperId: 'sample_selorm',
    preferredTime: 'Saturday, 10:00 AM',
    age: const Duration(hours: 3),
  );
  matches.add(<String, dynamic>{
    'id': 'match_sample_laptop',
    'requesterId': sampleViewerId,
    'helperId': 'sample_selorm',
    'requestId': 'sample_laptop',
    'status': 'inProgress',
    'score': 0.94,
    'reasons': <String>['Lives nearby', 'Offers technical support'],
    'acceptedAt': ago(const Duration(hours: 2, minutes: 40)),
  });
  request(
    id: 'sample_plants',
    requesterId: sampleViewerId,
    title: 'Water my plants this weekend',
    category: 'errands',
    description:
        'I am away Friday to Sunday. Two quick visits to water the balcony '
        'plants.',
    urgency: 'low',
    preferredTime: 'Saturday and Sunday',
    age: const Duration(days: 1, hours: 2),
  );

  const threadId = 'sample_thread_laptop';
  final chat = <(String, String, Duration)>[
    (
      'sample_selorm',
      'Hi Abena! Happy to help you choose a laptop. Are you free on '
          'Saturday morning?',
      const Duration(hours: 2, minutes: 38),
    ),
    (
      sampleViewerId,
      "Saturday works! It's mostly for lesson planning and video calls.",
      const Duration(hours: 2, minutes: 31),
    ),
    (
      'sample_selorm',
      "Then you won't need anything fancy. Shall we meet at the Accra Mall "
          'entrance at 10?',
      const Duration(hours: 2, minutes: 12),
    ),
    (
      sampleViewerId,
      'Perfect, a public place suits me too.',
      const Duration(hours: 1, minutes: 58),
    ),
    (
      'sample_selorm',
      "Great. I'll bring a short list of good options. See you Saturday!",
      const Duration(minutes: 6),
    ),
    (sampleViewerId, sampleLastChatMessage, const Duration(minutes: 4)),
  ];

  Map<String, dynamic> bucket(String userId) => <String, dynamic>{
    'user': users[userId],
    'requests': requests
        .where((request) => request['requesterId'] == userId)
        .toList(),
    'notifications': userId == sampleViewerId
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'sample_notification_message',
              'userId': sampleViewerId,
              'type': 'newMessage',
              'title': 'New message from Selorm',
              'message': "Great. I'll bring a short list of good options.",
              'createdAt': ago(const Duration(minutes: 6)),
              'isRead': false,
            },
            <String, dynamic>{
              'id': 'sample_notification_accepted',
              'userId': sampleViewerId,
              'type': 'requestAccepted',
              'title': 'Selorm is helping you',
              'message': 'Selorm Agbeko offered to help choose your laptop.',
              'createdAt': ago(const Duration(hours: 2, minutes: 40)),
              'isRead': false,
            },
          ]
        : <Map<String, dynamic>>[],
    'moodCheckIns': <Map<String, dynamic>>[],
  };

  return <String, dynamic>{
    '_meta': <String, dynamic>{'currentUserId': sampleViewerId},
    '_shared': <String, dynamic>{
      'matches': matches,
      'threads': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': threadId,
          'requestId': 'sample_laptop',
          'participantIds': <String>[sampleViewerId, 'sample_selorm'],
          'createdAt': ago(const Duration(hours: 2, minutes: 40)),
          'lastMessageAt': ago(const Duration(minutes: 4)),
          'messageRequestPending': false,
        },
      ],
      'messages': <Map<String, dynamic>>[
        for (var i = 0; i < chat.length; i++)
          <String, dynamic>{
            'id': 'sample_message_$i',
            'threadId': threadId,
            'senderId': chat[i].$1,
            'content': chat[i].$2,
            'createdAt': ago(chat[i].$3),
          },
      ],
      'reviews': reviews,
      'reports': <Map<String, dynamic>>[],
      'supportCircles': <Map<String, dynamic>>[],
    },
    for (final userId in users.keys) '$userId@example.com': bucket(userId),
  };
}

/// Serves the sample community in place of Firestore. Any other call fails,
/// so a screenshot run can never read or write live data.
class SampleCommunitySyncService implements AppFirestoreSyncService {
  SampleCommunitySyncService(this._database);

  final Map<String, dynamic> _database;

  @override
  Future<Map<String, dynamic>?> loadDatabase() async => _database;

  @override
  Stream<({Map<String, dynamic>? database, bool hasPendingWrites})>
  watchDatabase() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Sample data is read-only.');
}

/// Stands in for the workflow API without touching the network. It records
/// what the app tried to save and answers with the unchanged sample data.
class SampleCommunityWorkflowApi implements BackendWorkflowApiService {
  SampleCommunityWorkflowApi(this._database);

  final Map<String, dynamic> _database;
  final List<String> operations = <String>[];

  @override
  Future<BackendWorkflowApiResult> applyOperation({
    required String operation,
    required String currentUserId,
    required Map<String, dynamic> database,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    operations.add(operation);
    return BackendWorkflowApiResult(database: _database);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Sample data is read-only.');
}
