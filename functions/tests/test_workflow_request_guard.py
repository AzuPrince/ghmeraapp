import unittest

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


def _stored_request(database):
    return database['a@example.com']['requests'][0]


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

    def test_unverified_helper_can_take_high_risk_requests_with_safety_flags(self):
        high_risk_requests = {
            'childcare': _request(category='childcare'),
            'elderlySupport': _request(category='elderlySupport'),
            'emergencySupport': _request(category='emergencySupport'),
            'homeVisit': _request(requiresHomeVisit=True),
            'lateNight': _request(lateNightSupport=True),
            'money': _request(moneyRelated=True),
        }
        for label, request in high_risk_requests.items():
            with self.subTest(label):
                updated, result = self._volunteer(_database(request))

                self.assertTrue(result['matched'])
                accepted = _stored_request(updated)
                self.assertEqual(accepted['acceptedHelperId'], 'user_c')
                self.assertTrue(accepted['safetyCheckInRequired'])
                thread = updated['_shared']['threads'][0]
                self.assertTrue(thread['flaggedSafetyConcern'])

    def test_requester_can_pick_unverified_helper_for_high_risk_request(self):
        database = _database(_request(category='childcare'))

        updated, result = apply_workflow_operation(
            {
                'database': database,
                'currentUserId': 'user_a',
                'operation': 'request_helper_for_my_request',
                'payload': {'requestId': 'request_1', 'helperId': 'user_c'},
            }
        )

        self.assertTrue(result['matched'])
        accepted = _stored_request(updated)
        self.assertEqual(accepted['acceptedHelperId'], 'user_c')
        self.assertTrue(accepted['safetyCheckInRequired'])

    def test_unverified_helpers_are_suggested_for_high_risk_requests(self):
        database = _database(_request())
        database['b@example.com']['user']['helpCategoriesProvided'] = ['childcare']

        updated, _ = apply_workflow_operation(
            {
                'database': database,
                'currentUserId': 'user_a',
                'operation': 'create_help_request',
                'payload': {
                    'title': 'School pickup',
                    'description': 'Please pick my son up from school today.',
                    'category': 'childcare',
                    'urgency': 'medium',
                    'location': 'East Legon',
                    'preferredTime': 'Today',
                    'visibility': 'public',
                },
            }
        )

        created = next(
            request
            for request in updated['a@example.com']['requests']
            if request['category'] == 'childcare'
        )
        self.assertTrue(created['safetyCheckInRequired'])
        self.assertIn('user_b', created['suggestedHelperIds'])


if __name__ == '__main__':
    unittest.main()
