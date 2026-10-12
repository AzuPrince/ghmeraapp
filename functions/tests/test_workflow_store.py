import copy
import json
import types
import unittest
from unittest.mock import MagicMock, patch

from google.api_core import exceptions as google_exceptions

import main
import workflow_store
from workflow_backend import WorkflowError, apply_workflow_operation

GLOBAL = ('global_app_state', 'live')
MIRROR = ('Users_requests', 'sent request')
IDENTITY_C = {'uid': 'c', 'email': 'c@example.com'}
DERIVED_FIELDS = (
    'helpGivenCount',
    'helpReceivedCount',
    'completedHelpCount',
    'receivedHelpCount',
    'averageRating',
    'trustScore',
    'trustFlags',
)


def _user(user_id, email, **overrides):
    user = {
        'id': user_id,
        'fullName': user_id.replace('_', ' ').title(),
        'email': email,
        'city': 'Accra',
        'area': 'East Legon',
        'verificationBadges': ['emailVerified'],
        'availability': True,
        'helpCategoriesProvided': ['technicalSupport'],
        'blockedUserIds': [],
        'hiddenRequestIds': [],
        'restrictionStatus': 'clear',
        'isAdmin': False,
    }
    user.update(overrides)
    return user


def _request(**overrides):
    request = {
        'id': 'request_1',
        'requesterId': 'user_a',
        'title': 'Router setup',
        'description': 'Help me set up my router.',
        'category': 'technicalSupport',
        'urgency': 'medium',
        'location': 'East Legon',
        'visibility': 'public',
        'status': 'open',
        'createdAt': '2026-10-12T10:00:00+00:00',
        'acceptedHelperId': None,
        'actionLog': [],
    }
    request.update(overrides)
    return request


def _bucket(user, requests=None, notifications=None):
    return {
        'user': user,
        'requests': requests or [],
        'notifications': notifications or [],
        'moodCheckIns': [],
    }


def _database(request=None, **user_overrides):
    return {
        '_meta': {'currentUserId': 'user_a', 'currentUserEmail': 'a@example.com'},
        '_shared': {
            'matches': [],
            'threads': [],
            'messages': [],
            'reviews': [],
            'reports': [],
            'supportCircles': [],
        },
        'a@example.com': _bucket(
            _user('user_a', 'a@example.com'),
            [request if request is not None else _request()],
        ),
        'b@example.com': _bucket(_user('user_b', 'b@example.com')),
        'c@example.com': _bucket(
            _user('user_c', 'c@example.com', **user_overrides)
        ),
    }


def _mirror(database):
    document = {'lastSyncedAt': 'server-ts'}
    for key, bucket in database.items():
        if key.startswith('_') or not bucket['requests']:
            continue
        document[key] = {
            'requesterEmail': bucket['user']['email'],
            'requesterId': bucket['user']['id'],
            'requests': copy.deepcopy(bucket['requests']),
        }
    return document


class _Snapshot:
    def __init__(self, data):
        self.exists = data is not None
        self._data = copy.deepcopy(data)

    def to_dict(self):
        return copy.deepcopy(self._data)


class _DocumentRef:
    def __init__(self, store, key):
        self._store = store
        self.key = key

    def get(self, transaction=None):
        self._store.reads.append((self.key, transaction))
        return _Snapshot(self._store.docs.get(self.key))


class _Transaction:
    def __init__(self, store, failure):
        self._store = store
        self._failure = failure

    def _write(self, ref, data):
        if self._failure is not None:
            raise self._failure() if callable(self._failure) else self._failure
        self._store.writes.append((ref.key, copy.deepcopy(data)))

    def set(self, ref, data):
        self._write(ref, data)
        self._store.docs[ref.key] = copy.deepcopy(data)

    def update(self, ref, data):
        self._write(ref, data)
        self._store.docs[ref.key] = {**self._store.docs[ref.key], **copy.deepcopy(data)}


class _FakeFirestore:
    def __init__(self, global_database=None, mirror=None):
        self.docs = {}
        if global_database is not None:
            self.docs[GLOBAL] = {'database': copy.deepcopy(global_database)}
            self.docs[MIRROR] = (
                mirror if mirror is not None else _mirror(global_database)
            )
        self.reads = []
        self.writes = []
        self.failures = []
        self.transactions = 0

    def collection(self, name):
        collection = MagicMock()
        collection.document.side_effect = lambda doc_id: _DocumentRef(
            self, (name, doc_id)
        )
        return collection

    def transaction(self, max_attempts=5):
        self.transactions += 1
        failure = self.failures.pop(0) if self.failures else None
        return _Transaction(self, failure)

    @property
    def saved(self):
        return self.docs[GLOBAL]['database']


class StoreTestCase(unittest.TestCase):
    def setUp(self):
        self.store = _FakeFirestore(_database())
        fake_module = types.SimpleNamespace(
            client=lambda: self.store,
            transactional=lambda fn: fn,
            SERVER_TIMESTAMP='server-ts',
        )
        patcher = patch.object(workflow_store, 'firestore', fake_module)
        patcher.start()
        self.addCleanup(patcher.stop)
        sleep_patcher = patch.object(workflow_store.time, 'sleep')
        self.sleep_mock = sleep_patcher.start()
        self.addCleanup(sleep_patcher.stop)

    def _apply(self, operation, payload, *, database=None, identity=IDENTITY_C, schema=None):
        body = {
            'operation': operation,
            'currentUserId': 'spoofed',
            'database': database if database is not None else _database(),
            'payload': payload,
        }
        if schema is not None:
            body['clientSchema'] = schema
        return workflow_store.apply_workflow_request(body, identity)

    def _own_bucket_database(self, user):
        return {'_meta': {}, user['email']: {'user': user}}


class AuthoritativeStateTests(StoreTestCase):
    def test_operation_applies_to_saved_state_not_phone_copy(self):
        phone = _database()
        phone['b@example.com']['user']['fullName'] = 'Renamed By Phone'
        phone['b@example.com']['requests'] = [
            _request(id='request_fake', requesterId='user_b')
        ]

        updated, result = self._apply(
            'volunteer_for_help_request', {'requestId': 'request_1'}, database=phone
        )

        self.assertTrue(result['matched'])
        for database in (updated, self.store.saved):
            self.assertEqual(database['b@example.com']['user']['fullName'], 'User B')
            self.assertEqual(database['b@example.com']['requests'], [])
            accepted = database['a@example.com']['requests'][0]
            self.assertEqual(accepted['acceptedHelperId'], 'user_c')
        self.assertEqual(updated['_meta']['currentUserId'], 'user_c')
        self.assertNotIn('currentUserId', self.store.saved['_meta'])
        self.assertEqual(
            self.store.docs[MIRROR]['a@example.com']['requests'][0]['acceptedHelperId'],
            'user_c',
        )
        self.assertTrue(all(transaction is not None for _, transaction in self.store.reads))

    def test_stale_phone_cannot_revert_another_helpers_acceptance(self):
        taken = _database(_request(status='accepted', acceptedHelperId='user_b'))
        self.store = _FakeFirestore(taken)
        stale_phone = _database()

        self._apply(
            'update_my_notifications', {'markAllRead': True}, database=stale_phone
        )

        saved_request = self.store.saved['a@example.com']['requests'][0]
        self.assertEqual(saved_request['acceptedHelperId'], 'user_b')
        self.assertEqual(saved_request['status'], 'accepted')
        mirrored = self.store.docs[MIRROR]['a@example.com']['requests'][0]
        self.assertEqual(mirrored['acceptedHelperId'], 'user_b')

    def test_stale_volunteer_gets_conflict_with_saved_state_and_no_write(self):
        self.store = _FakeFirestore(
            _database(_request(status='accepted', acceptedHelperId='user_b'))
        )

        with self.assertRaises(WorkflowError) as raised:
            self._apply('volunteer_for_help_request', {'requestId': 'request_1'})

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(
            raised.exception.message, 'Someone is already helping with this request.'
        )
        returned = raised.exception.database['a@example.com']['requests'][0]
        self.assertEqual(returned['acceptedHelperId'], 'user_b')
        self.assertEqual(self.store.writes, [])

    def test_mirror_wins_like_the_apps_read_it(self):
        saved = _database()
        mirror = _mirror(_database(_request(status='accepted', acceptedHelperId='user_b')))
        self.store = _FakeFirestore(saved, mirror=mirror)

        with self.assertRaises(WorkflowError) as raised:
            self._apply('volunteer_for_help_request', {'requestId': 'request_1'})

        self.assertEqual(raised.exception.status_code, 409)

    def test_stale_phone_cannot_overwrite_another_members_profile(self):
        phone = _database()
        phone['b@example.com']['user'].update(
            {'fullName': 'Hacked', 'isAdmin': True, 'city': 'Elsewhere'}
        )

        self._apply(
            'sync_my_profile',
            {'user': phone['c@example.com']['user']},
            database=phone,
        )

        saved_b = self.store.saved['b@example.com']['user']
        self.assertEqual(saved_b['fullName'], 'User B')
        self.assertFalse(saved_b['isAdmin'])
        self.assertEqual(saved_b['city'], 'Accra')

    def test_sync_my_profile_only_changes_the_callers_own_fields(self):
        self.store = _FakeFirestore(_database(restrictionStatus='restricted'))
        before = copy.deepcopy(self.store.saved)
        edited = _user(
            'user_c',
            'c@example.com',
            fullName='Cee Updated',
            city='Kumasi',
            availability=False,
            helpCategoriesProvided=['errands'],
            isAdmin=True,
            restrictionStatus='clear',
            verificationBadges=['emailVerified', 'phoneVerified', 'idVerified', 'trustedHelper'],
            trustScore=99,
        )
        edited['email'] = 'someone-else@example.com'

        self._apply('sync_my_profile', {'user': edited}, schema=2,
                    database=self._own_bucket_database(edited))

        saved_c = self.store.saved['c@example.com']['user']
        self.assertEqual(saved_c['fullName'], 'Cee Updated')
        self.assertEqual(saved_c['city'], 'Kumasi')
        self.assertFalse(saved_c['availability'])
        self.assertEqual(saved_c['helpCategoriesProvided'], ['errands'])
        self.assertFalse(saved_c['isAdmin'])
        self.assertEqual(saved_c['restrictionStatus'], 'restricted')
        self.assertEqual(saved_c['email'], 'c@example.com')
        self.assertEqual(saved_c['trustScore'], 0)
        self.assertEqual(
            sorted(saved_c['verificationBadges']), ['emailVerified', 'phoneVerified']
        )
        self.assertEqual(self.store.saved['_shared'], before['_shared'])
        for key in ('a@example.com', 'b@example.com'):
            saved_bucket = copy.deepcopy(self.store.saved[key])
            for field in DERIVED_FIELDS:
                saved_bucket['user'].pop(field, None)
            self.assertEqual(saved_bucket, before[key])

    def test_sync_my_profile_ignores_fields_with_the_wrong_type(self):
        edited = _user('user_c', 'c@example.com', fullName=42, city=['x'], sessions='bad')

        self._apply('sync_my_profile', {'user': edited}, schema=2,
                    database=self._own_bucket_database(edited))

        saved_c = self.store.saved['c@example.com']['user']
        self.assertEqual(saved_c['fullName'], 'User C')
        self.assertEqual(saved_c['city'], 'Accra')
        self.assertNotIn('sessions', saved_c)

    def test_new_client_profile_in_other_ops_does_not_overwrite_saved_record(self):
        stale = _user('user_c', 'c@example.com', fullName='Old Name')

        self._apply('update_my_notifications', {'markAllRead': True}, schema=2,
                    database=self._own_bucket_database(stale))

        self.assertEqual(self.store.saved['c@example.com']['user']['fullName'], 'User C')

    def test_spoofed_current_user_id_is_ignored(self):
        updated, _ = self._apply('update_my_notifications', {})
        self.assertEqual(updated['_meta']['currentUserId'], 'user_c')

        with self.assertRaises(WorkflowError) as raised:
            self._apply(
                'sync_my_profile',
                {'user': _user('user_a', 'a@example.com', fullName='Not Me')},
            )

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(self.store.saved['a@example.com']['user']['fullName'], 'User A')
        self.assertEqual(self.store.saved['c@example.com']['user']['fullName'], 'User C')


class CompatibilityTests(StoreTestCase):
    def test_old_full_database_requests_still_work(self):
        phone = _database()
        phone['c@example.com']['user']['city'] = 'Tema'
        phone['c@example.com']['notifications'] = [
            {
                'id': 'notification_local',
                'userId': 'user_c',
                'type': 'adminUpdate',
                'title': 'Availability is on',
                'message': 'Local notice',
                'createdAt': '2026-10-12T10:00:00Z',
                'isRead': False,
            }
        ]

        updated, result = self._apply(
            'volunteer_for_help_request', {'requestId': 'request_1'}, database=phone
        )

        self.assertTrue(result['matched'])
        saved_c = self.store.saved['c@example.com']
        self.assertEqual(saved_c['user']['city'], 'Tema')
        self.assertIn(
            'notification_local',
            [notification['id'] for notification in saved_c['notifications']],
        )
        self.assertEqual(updated['a@example.com']['requests'][0]['status'], 'accepted')

    def test_old_builds_keep_their_own_block_on_a_shared_thread(self):
        saved = _database()
        thread = {
            'id': 'thread_1',
            'requestId': 'request_1',
            'participantIds': ['user_a', 'user_c'],
            'blockedByIds': ['user_a'],
            'mutedByIds': [],
            'contactSharedByIds': [],
        }
        saved['_shared']['threads'] = [copy.deepcopy(thread)]
        self.store = _FakeFirestore(saved)
        phone = copy.deepcopy(saved)
        phone['_shared']['threads'][0]['blockedByIds'] = ['user_c']

        self._apply('update_my_notifications', {}, database=phone)

        self.assertEqual(
            sorted(self.store.saved['_shared']['threads'][0]['blockedByIds']),
            ['user_a', 'user_c'],
        )

    def test_new_member_not_yet_saved_is_created(self):
        newcomer = _user('user_d', 'd@example.com', fullName='Dee New', isAdmin=True)
        identity = {'uid': 'd', 'email': 'd@example.com'}

        updated, _ = self._apply(
            'sync_my_profile',
            {'user': newcomer},
            database=self._own_bucket_database(newcomer),
            identity=identity,
            schema=2,
        )

        saved_d = self.store.saved['d@example.com']
        self.assertEqual(saved_d['user']['id'], 'user_d')
        self.assertEqual(saved_d['user']['fullName'], 'Dee New')
        self.assertFalse(saved_d['user']['isAdmin'])
        self.assertEqual(saved_d['requests'], [])
        self.assertEqual(updated['_meta']['currentUserId'], 'user_d')
        self.assertIn('a@example.com', self.store.saved)

    def test_new_member_must_use_their_canonical_id(self):
        impostor = _user('user_b', 'd@example.com')

        with self.assertRaises(WorkflowError) as raised:
            self._apply(
                'sync_my_profile',
                {'user': impostor},
                database=self._own_bucket_database(impostor),
                identity={'uid': 'd', 'email': 'd@example.com'},
            )

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(self.store.writes, [])

    def test_existing_profile_found_by_verified_email(self):
        updated, _ = self._apply(
            'update_my_notifications',
            {},
            identity={'uid': 'other-uid', 'email': 'C@Example.com'},
        )

        self.assertEqual(updated['_meta']['currentUserId'], 'user_c')

    def test_missing_saved_document_starts_empty_instead_of_trusting_phone(self):
        self.store = _FakeFirestore()
        newcomer = _user('user_c', 'c@example.com')

        self._apply('sync_my_profile', {'user': newcomer}, database=_database())

        self.assertEqual(
            sorted(key for key in self.store.saved if not key.startswith('_')),
            ['c@example.com'],
        )


class ContentionTests(StoreTestCase):
    def test_retries_after_transaction_contention(self):
        self.store.failures = [google_exceptions.Aborted('contention')]

        _, result = self._apply('volunteer_for_help_request', {'requestId': 'request_1'})

        self.assertTrue(result['matched'])
        self.assertEqual(self.store.transactions, 2)
        self.assertEqual(self.sleep_mock.call_count, 1)
        self.assertEqual(
            self.store.saved['a@example.com']['requests'][0]['acceptedHelperId'],
            'user_c',
        )

    def test_retry_rereads_saved_state(self):
        def take_request_then_abort():
            self.store.docs[GLOBAL]['database'] = _database(
                _request(status='accepted', acceptedHelperId='user_b')
            )
            self.store.docs[MIRROR] = _mirror(self.store.docs[GLOBAL]['database'])
            return google_exceptions.Aborted('contention')

        self.store.failures = [take_request_then_abort]

        with self.assertRaises(WorkflowError) as raised:
            self._apply('volunteer_for_help_request', {'requestId': 'request_1'})

        self.assertEqual(raised.exception.status_code, 409)

    def test_gives_up_with_busy_message(self):
        self.store.failures = [
            google_exceptions.Aborted('contention')
        ] * workflow_store.MAX_TRANSACTION_ATTEMPTS

        with self.assertRaises(WorkflowError) as raised:
            self._apply('volunteer_for_help_request', {'requestId': 'request_1'})

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(self.store.writes, [])


class WorkflowApiTests(StoreTestCase):
    def _post(self, body):
        request = MagicMock()
        request.method = 'POST'
        request.headers = {'Authorization': 'Bearer token'}
        request.get_json.return_value = body
        response = main.workflow_api(request)
        return response.status_code, json.loads(response.get_data(as_text=True))

    @patch('main.admin_auth.verify_id_token')
    def test_volunteer_is_saved_by_the_server(self, verify_mock):
        verify_mock.return_value = {
            'uid': 'c', 'email': 'c@example.com', 'email_verified': True,
        }

        status, body = self._post(
            {
                'operation': 'volunteer_for_help_request',
                'clientSchema': 2,
                'database': self._own_bucket_database(_user('user_c', 'c@example.com')),
                'payload': {'requestId': 'request_1'},
            }
        )

        self.assertEqual(status, 200)
        self.assertTrue(body['result']['matched'])
        self.assertIn('b@example.com', body['database'])
        self.assertEqual(
            self.store.saved['a@example.com']['requests'][0]['acceptedHelperId'],
            'user_c',
        )

    @patch('main.admin_auth.verify_id_token')
    def test_conflict_returns_saved_state(self, verify_mock):
        verify_mock.return_value = {
            'uid': 'c', 'email': 'c@example.com', 'email_verified': True,
        }
        self.store = _FakeFirestore(
            _database(_request(status='accepted', acceptedHelperId='user_b'))
        )

        status, body = self._post(
            {
                'operation': 'volunteer_for_help_request',
                'database': _database(),
                'payload': {'requestId': 'request_1'},
            }
        )

        self.assertEqual(status, 409)
        self.assertEqual(body['error'], 'Someone is already helping with this request.')
        self.assertEqual(
            body['database']['a@example.com']['requests'][0]['acceptedHelperId'],
            'user_b',
        )


class OwnDataOperationTests(unittest.TestCase):
    def _apply(self, operation, payload, database=None, current_user_id='user_c'):
        return apply_workflow_operation(
            {
                'operation': operation,
                'currentUserId': current_user_id,
                'database': database if database is not None else _database(),
                'payload': payload,
            }
        )

    def _notification(self, notification_id, user_id, is_read=False):
        return {
            'id': notification_id,
            'userId': user_id,
            'type': 'adminUpdate',
            'title': 'Hello',
            'message': 'World',
            'createdAt': '2026-10-12T10:00:00Z',
            'isRead': is_read,
        }

    def test_notifications_update_only_touches_own_notifications(self):
        database = _database()
        database['c@example.com']['notifications'] = [
            self._notification('notification_1', 'user_c'),
            self._notification('notification_2', 'user_c'),
        ]
        database['b@example.com']['notifications'] = [
            self._notification('notification_3', 'user_b'),
        ]

        updated, _ = self._apply(
            'update_my_notifications',
            {'readIds': ['notification_1', 'notification_3'], 'deleteIds': ['notification_2']},
            database,
        )

        own = updated['c@example.com']['notifications']
        self.assertEqual([item['id'] for item in own], ['notification_1'])
        self.assertTrue(own[0]['isRead'])
        self.assertFalse(updated['b@example.com']['notifications'][0]['isRead'])

    def test_block_user_updates_profile_and_shared_threads(self):
        database = _database()
        database['_shared']['threads'] = [
            {'id': 'thread_1', 'participantIds': ['user_b', 'user_c'], 'blockedByIds': []},
            {'id': 'thread_2', 'participantIds': ['user_a', 'user_b'], 'blockedByIds': []},
        ]

        updated, result = self._apply(
            'block_user', {'userId': 'user_b', 'requestId': 'request_9'}, database
        )

        self.assertTrue(result['changed'])
        user_c = updated['c@example.com']['user']
        self.assertEqual(user_c['blockedUserIds'], ['user_b'])
        self.assertEqual(user_c['hiddenRequestIds'], ['request_9'])
        threads = updated['_shared']['threads']
        self.assertEqual(threads[0]['blockedByIds'], ['user_c'])
        self.assertEqual(threads[1]['blockedByIds'], [])
        self.assertEqual(
            updated['c@example.com']['notifications'][0]['title'], 'Account blocked'
        )

        unblocked, _ = self._apply('unblock_user', {'userId': 'user_b'}, updated)
        self.assertEqual(unblocked['c@example.com']['user']['blockedUserIds'], [])
        self.assertEqual(unblocked['_shared']['threads'][0]['blockedByIds'], [])

    def test_members_can_only_delete_their_own_messages(self):
        database = _database()
        database['_shared']['messages'] = [
            {'id': 'message_1', 'threadId': 'thread_1', 'senderId': 'user_c'},
            {'id': 'message_2', 'threadId': 'thread_1', 'senderId': 'user_a'},
        ]

        updated, result = self._apply(
            'delete_message', {'threadId': 'thread_1', 'messageId': 'message_1'}, database
        )
        self.assertTrue(result['deleted'])
        self.assertEqual(
            [message['id'] for message in updated['_shared']['messages']], ['message_2']
        )

        with self.assertRaises(WorkflowError) as raised:
            self._apply(
                'delete_message', {'threadId': 'thread_1', 'messageId': 'message_2'}, database
            )
        self.assertEqual(raised.exception.status_code, 403)

    def test_record_mood_adds_support_notification_when_struggling(self):
        updated, result = self._apply('record_mood', {'moodLevel': 'struggling'})

        bucket = updated['c@example.com']
        self.assertEqual(bucket['moodCheckIns'][0]['id'], result['moodCheckInId'])
        self.assertEqual(
            bucket['notifications'][0]['type'], 'emotionalCheckInReminder'
        )

    def test_support_circle_membership_changes_only_the_caller(self):
        database = _database()
        database['_shared']['supportCircles'] = [
            {'id': 'circle_1', 'name': 'Parents', 'memberIds': ['user_a']}
        ]

        joined, _ = self._apply(
            'set_support_circle_membership', {'circleId': 'circle_1', 'member': True}, database
        )
        self.assertEqual(
            joined['_shared']['supportCircles'][0]['memberIds'], ['user_a', 'user_c']
        )
        left, _ = self._apply(
            'set_support_circle_membership', {'circleId': 'circle_1', 'member': False}, joined
        )
        self.assertEqual(left['_shared']['supportCircles'][0]['memberIds'], ['user_a'])

    def test_profile_sync_adds_own_notifications_with_server_ids(self):
        updated, result = self._apply(
            'sync_my_profile',
            {
                'user': _user('user_c', 'c@example.com', availability=False),
                'addNotifications': [
                    {'type': 'adminUpdate', 'title': 'Availability is off', 'message': 'Off'},
                    {'type': 'notAType', 'title': 'Ignored', 'message': 'x'},
                ],
            },
        )

        notifications = updated['c@example.com']['notifications']
        self.assertEqual(len(notifications), 1)
        self.assertEqual(notifications[0]['id'], result['notificationIds'][0])
        self.assertEqual(notifications[0]['userId'], 'user_c')

    def test_server_derives_reputation_figures(self):
        database = _database(
            _request(status='completed', acceptedHelperId='user_c')
        )
        database['c@example.com']['user']['completedHelpCount'] = 40

        updated, _ = self._apply('update_my_notifications', {}, database)

        helper = updated['c@example.com']['user']
        self.assertEqual(helper['completedHelpCount'], 1)
        self.assertEqual(helper['helpGivenCount'], 1)
        self.assertEqual(updated['a@example.com']['user']['receivedHelpCount'], 1)
        self.assertGreater(helper['trustScore'], 0)


if __name__ == '__main__':
    unittest.main()
