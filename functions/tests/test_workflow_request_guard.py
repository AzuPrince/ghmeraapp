import copy
import json
import unittest
from unittest.mock import MagicMock, patch

import main
from workflow_backend import WorkflowError, apply_workflow_operation


def _user(user_id, email):
    return {
        'id': user_id,
        'fullName': user_id.replace('_', ' ').title(),
        'email': email,
        'city': 'Accra',
        'area': 'East Legon',
        'verificationBadges': ['emailVerified'],
        'availability': True,
        'helpCategoriesProvided': ['technicalSupport'],
        'blockedUserIds': [],
        'restrictionStatus': 'clear',
    }


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
        'acceptedHelperId': None,
        'actionLog': [],
    }
    request.update(overrides)
    return request


def _database(request):
    return {
        '_meta': {},
        '_shared': {
            'matches': [],
            'threads': [],
            'messages': [],
            'reviews': [],
            'reports': [],
            'supportCircles': [],
        },
        'a@example.com': {
            'user': _user('user_a', 'a@example.com'),
            'requests': [request],
            'notifications': [],
            'moodCheckIns': [],
        },
        'b@example.com': {
            'user': _user('user_b', 'b@example.com'),
            'requests': [],
            'notifications': [],
            'moodCheckIns': [],
        },
        'c@example.com': {
            'user': _user('user_c', 'c@example.com'),
            'requests': [],
            'notifications': [],
            'moodCheckIns': [],
        },
    }


def _snapshot(data):
    snapshot = MagicMock()
    snapshot.exists = data is not None
    snapshot.to_dict.return_value = copy.deepcopy(data)
    return snapshot


def _mock_firestore(client_mock, *, global_request=None, mirrored_request=None):
    """Point firestore.client() at saved copies of request_1."""
    global_document = None
    if global_request is not None:
        global_document = {'database': _database(global_request)}
    mirrored_document = None
    if mirrored_request is not None:
        mirrored_document = {
            'lastSyncedAt': 'server-timestamp',
            'a@example.com': {
                'requesterEmail': 'a@example.com',
                'requesterId': 'user_a',
                'requests': [mirrored_request],
            },
        }

    documents = {
        ('global_app_state', 'live'): _snapshot(global_document),
        ('Users_requests', 'sent request'): _snapshot(mirrored_document),
    }

    def collection(name):
        collection_ref = MagicMock()

        def document(document_id):
            document_ref = MagicMock()
            document_ref.get.return_value = documents[(name, document_id)]
            return document_ref

        collection_ref.document.side_effect = document
        return collection_ref

    client_mock.return_value.collection.side_effect = collection


def _secured_body(operation, database, payload, current_user_id='user_c'):
    secured_database = copy.deepcopy(database)
    secured_database['_meta'] = {'currentUserId': current_user_id}
    return {
        'operation': operation,
        'currentUserId': current_user_id,
        'database': secured_database,
        'payload': payload,
    }


def _stored_request(database):
    return database['a@example.com']['requests'][0]


class StoredRequestGuardTests(unittest.TestCase):
    @patch('main.firestore.client')
    def test_volunteer_rejected_when_saved_request_has_another_helper(
        self,
        client_mock,
    ):
        _mock_firestore(
            client_mock,
            global_request=_request(status='inProgress', acceptedHelperId='user_b'),
            mirrored_request=_request(status='inProgress', acceptedHelperId='user_b'),
        )
        stale_body = _secured_body(
            'volunteer_for_help_request',
            _database(_request()),
            {'requestId': 'request_1'},
        )

        with self.assertRaises(WorkflowError) as raised:
            main._apply_stored_request_state(stale_body)

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(
            raised.exception.message,
            'Someone is already helping with this request.',
        )
        returned_request = _stored_request(raised.exception.database)
        self.assertEqual(returned_request['acceptedHelperId'], 'user_b')
        self.assertEqual(returned_request['status'], 'inProgress')
        self.assertIsNone(_stored_request(stale_body['database'])['acceptedHelperId'])

    @patch('main.firestore.client')
    def test_volunteer_rejected_when_only_the_mirror_shows_a_helper(
        self,
        client_mock,
    ):
        _mock_firestore(
            client_mock,
            global_request=_request(),
            mirrored_request=_request(status='accepted', acceptedHelperId='user_b'),
        )

        with self.assertRaises(WorkflowError) as raised:
            main._apply_stored_request_state(
                _secured_body(
                    'volunteer_for_help_request',
                    _database(_request()),
                    {'requestId': 'request_1'},
                )
            )

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(
            raised.exception.message,
            main.REQUEST_ALREADY_TAKEN_MESSAGE,
        )

    @patch('main.firestore.client')
    def test_volunteer_rejected_when_saved_request_is_closed(self, client_mock):
        _mock_firestore(client_mock, global_request=_request(status='canceled'))

        with self.assertRaises(WorkflowError) as raised:
            main._apply_stored_request_state(
                _secured_body(
                    'volunteer_for_help_request',
                    _database(_request()),
                    {'requestId': 'request_1'},
                )
            )

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(
            raised.exception.message,
            main.REQUEST_CLOSED_MESSAGE,
        )
        self.assertEqual(
            _stored_request(raised.exception.database)['status'],
            'canceled',
        )

    @patch('main.firestore.client')
    def test_missing_saved_copy_falls_back_to_caller_copy(self, client_mock):
        _mock_firestore(client_mock)
        body = _secured_body(
            'volunteer_for_help_request',
            _database(_request()),
            {'requestId': 'request_1'},
        )

        self.assertIs(main._apply_stored_request_state(body), body)

    @patch('main.firestore.client')
    def test_saved_request_is_added_when_caller_copy_is_missing_it(
        self,
        client_mock,
    ):
        _mock_firestore(client_mock, global_request=_request())
        stale_database = _database(_request())
        stale_database['a@example.com']['requests'] = []

        guarded = main._apply_stored_request_state(
            _secured_body(
                'volunteer_for_help_request',
                stale_database,
                {'requestId': 'request_1'},
            )
        )

        self.assertEqual(_stored_request(guarded['database'])['id'], 'request_1')

    @patch('main.firestore.client')
    def test_volunteer_runs_on_saved_request_when_it_is_still_open(
        self,
        client_mock,
    ):
        saved = _request(description='Updated: router and printer.')
        _mock_firestore(client_mock, global_request=saved, mirrored_request=saved)

        guarded = main._apply_stored_request_state(
            _secured_body(
                'volunteer_for_help_request',
                _database(_request()),
                {'requestId': 'request_1'},
            )
        )

        self.assertEqual(
            _stored_request(guarded['database'])['description'],
            'Updated: router and printer.',
        )

    @patch('main.firestore.client')
    def test_assigned_helper_can_repeat_volunteering(self, client_mock):
        _mock_firestore(
            client_mock,
            global_request=_request(status='accepted', acceptedHelperId='user_c'),
        )

        guarded = main._apply_stored_request_state(
            _secured_body(
                'volunteer_for_help_request',
                _database(_request()),
                {'requestId': 'request_1'},
            )
        )

        self.assertEqual(
            _stored_request(guarded['database'])['acceptedHelperId'],
            'user_c',
        )

    @patch('main.firestore.client')
    def test_requester_cannot_pick_a_second_helper(self, client_mock):
        _mock_firestore(
            client_mock,
            global_request=_request(status='accepted', acceptedHelperId='user_b'),
        )

        with self.assertRaises(WorkflowError) as raised:
            main._apply_stored_request_state(
                _secured_body(
                    'request_helper_for_my_request',
                    _database(_request()),
                    {'requestId': 'request_1', 'helperId': 'user_c'},
                    current_user_id='user_a',
                )
            )

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(
            raised.exception.message,
            main.REQUEST_ALREADY_TAKEN_MESSAGE,
        )

    @patch('main.firestore.client')
    def test_requester_can_pick_helper_for_request_still_syncing(
        self,
        client_mock,
    ):
        _mock_firestore(client_mock)
        body = _secured_body(
            'request_helper_for_my_request',
            _database(_request()),
            {'requestId': 'request_1', 'helperId': 'user_c'},
            current_user_id='user_a',
        )

        self.assertIs(main._apply_stored_request_state(body), body)

    @patch('main.firestore.client')
    def test_firestore_read_failure_keeps_caller_copy(self, client_mock):
        client_mock.side_effect = RuntimeError('firestore unavailable')
        body = _secured_body(
            'volunteer_for_help_request',
            _database(_request()),
            {'requestId': 'request_1'},
        )

        with self.assertLogs('main', level='WARNING'):
            self.assertIs(main._apply_stored_request_state(body), body)

    @patch('main.firestore.client')
    def test_other_operations_do_not_read_firestore(self, client_mock):
        body = _secured_body(
            'send_message',
            _database(_request()),
            {'threadId': 'thread_1', 'content': 'Hi'},
        )

        self.assertIs(main._apply_stored_request_state(body), body)
        client_mock.assert_not_called()


class WorkflowApiStoredRequestTests(unittest.TestCase):
    def _post(self, body):
        request = MagicMock()
        request.method = 'POST'
        request.headers = {'Authorization': 'Bearer valid-token'}
        request.get_json.return_value = body
        response = main.workflow_api(request)
        return response.status_code, json.loads(response.get_data(as_text=True))

    @patch('main.firestore.client')
    @patch('main.admin_auth.verify_id_token')
    def test_stale_volunteer_gets_409_and_saved_request(
        self,
        verify_id_token_mock,
        client_mock,
    ):
        verify_id_token_mock.return_value = {
            'uid': 'c',
            'email': 'c@example.com',
            'email_verified': True,
        }
        _mock_firestore(
            client_mock,
            global_request=_request(status='inProgress', acceptedHelperId='user_b'),
            mirrored_request=_request(status='inProgress', acceptedHelperId='user_b'),
        )

        status, body = self._post(
            {
                'operation': 'volunteer_for_help_request',
                'database': _database(_request()),
                'payload': {'requestId': 'request_1'},
            }
        )

        self.assertEqual(status, 409)
        self.assertEqual(body['error'], 'Someone is already helping with this request.')
        self.assertEqual(_stored_request(body['database'])['acceptedHelperId'], 'user_b')
        self.assertEqual(body['database']['_shared']['matches'], [])

    @patch('main.firestore.client')
    @patch('main.admin_auth.verify_id_token')
    def test_volunteer_on_open_saved_request_is_matched(
        self,
        verify_id_token_mock,
        client_mock,
    ):
        verify_id_token_mock.return_value = {
            'uid': 'c',
            'email': 'c@example.com',
            'email_verified': True,
        }
        _mock_firestore(client_mock, global_request=_request())

        status, body = self._post(
            {
                'operation': 'volunteer_for_help_request',
                'database': _database(_request()),
                'payload': {'requestId': 'request_1'},
            }
        )

        self.assertEqual(status, 200)
        self.assertTrue(body['result']['matched'])
        matched_request = _stored_request(body['database'])
        self.assertEqual(matched_request['acceptedHelperId'], 'user_c')
        self.assertEqual(matched_request['status'], 'accepted')


class VolunteerOperationTests(unittest.TestCase):
    def _volunteer(self, database, current_user_id='user_c'):
        return apply_workflow_operation(
            {
                'database': database,
                'currentUserId': current_user_id,
                'operation': 'volunteer_for_help_request',
                'payload': {'requestId': 'request_1'},
            }
        )

    def _assert_rejected(self, database, message):
        with self.assertRaises(WorkflowError) as raised:
            self._volunteer(database)
        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(raised.exception.message, message)

    def test_fresh_restricted_request_shared_with_helper_succeeds(self):
        database = _database(_request(visibility='restricted', status='matching'))
        helper = database['c@example.com']['user']
        helper['helpCategoriesProvided'] = []
        helper['availability'] = False
        database['_shared']['matches'].append(
            {
                'id': 'match_1',
                'requesterId': 'user_a',
                'helperId': 'user_c',
                'requestId': 'request_1',
                'status': 'broadcast',
                'score': 8,
                'reasons': [],
            }
        )

        updated, result = self._volunteer(database)

        self.assertTrue(result['matched'])
        self.assertEqual(_stored_request(updated)['acceptedHelperId'], 'user_c')

    def test_restricted_request_not_shared_with_helper_is_rejected(self):
        database = _database(_request(visibility='restricted'))
        database['c@example.com']['user']['helpCategoriesProvided'] = []

        self._assert_rejected(
            database,
            'This request was only shared with selected helpers.',
        )

    def test_fresh_public_request_succeeds_for_unavailable_helper(self):
        database = _database(_request())
        helper = database['c@example.com']['user']
        helper['helpCategoriesProvided'] = []
        helper['availability'] = False

        updated, result = self._volunteer(database)

        self.assertTrue(result['matched'])
        self.assertEqual(_stored_request(updated)['status'], 'accepted')

    def test_taken_request_says_someone_is_already_helping(self):
        self._assert_rejected(
            _database(_request(status='accepted', acceptedHelperId='user_b')),
            'Someone is already helping with this request.',
        )

    def test_closed_request_is_rejected(self):
        self._assert_rejected(
            _database(_request(status='canceled')),
            'This request is no longer open for help.',
        )

    def test_high_risk_request_explains_verification_requirement(self):
        self._assert_rejected(
            _database(_request(category='emergencySupport')),
            'This request needs extra safety checks, so only ID-verified or '
            'trusted helpers can take it.',
        )

    def test_verified_helper_can_take_high_risk_request(self):
        database = _database(_request(moneyRelated=True, lateNightSupport=True))
        database['c@example.com']['user']['verificationBadges'].append('idVerified')

        _, result = self._volunteer(database)

        self.assertTrue(result['matched'])


if __name__ == '__main__':
    unittest.main()
