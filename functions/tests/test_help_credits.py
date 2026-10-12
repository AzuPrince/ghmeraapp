import unittest

from workflow_backend import WorkflowError
from workflow_backend.credits import REQUEST_CREDIT_COST, help_credit_summary

from test_workflow_operations import _apply, _database, _user


def _request_payload(title='Laptop setup', category='technicalSupport'):
    return {
        'title': title,
        'description': 'Help me configure my laptop for school.',
        'category': category,
        'urgency': 'medium',
        'location': 'East Legon',
        'preferredTime': 'Today',
        'visibility': 'public',
    }


def _all_requests(database):
    requests = []
    for key, bucket in database.items():
        if key.startswith('_'):
            continue
        requests.extend(bucket.get('requests', []))
    return requests


def _notifications_for(database, email):
    return database[email]['notifications']


def _completed_request(request_id, requester_id='user_requester', helper_id='user_other'):
    return {
        'id': request_id,
        'requesterId': requester_id,
        'acceptedHelperId': helper_id,
        'status': 'completed',
        'category': 'technicalSupport',
        'title': f'Past request {request_id}',
    }


class HelpCreditSummaryTests(unittest.TestCase):
    def test_new_user_starts_with_five_credits(self):
        summary = help_credit_summary('user_new', [])
        self.assertEqual(summary['balance'], 5)
        self.assertEqual(summary['available'], 5)
        self.assertEqual(summary['held'], 0)

    def test_request_costs_one_for_asking_and_one_for_receiving(self):
        self.assertEqual(REQUEST_CREDIT_COST, 2)

    def test_open_request_holds_and_completion_spends_and_earns(self):
        requests = [
            {'id': 'r1', 'requesterId': 'a', 'status': 'matching'},
            {'id': 'r2', 'requesterId': 'a', 'acceptedHelperId': 'b', 'status': 'completed'},
            {'id': 'r3', 'requesterId': 'b', 'acceptedHelperId': 'a', 'status': 'completed'},
            {'id': 'r4', 'requesterId': 'a', 'acceptedHelperId': 'b', 'status': 'canceled'},
            {
                'id': 'r5',
                'requesterId': 'a',
                'status': 'open',
                'category': 'emergencySupport',
            },
        ]
        summary = help_credit_summary('a', requests)
        self.assertEqual(summary['earned'], 1)
        self.assertEqual(summary['spent'], 2)
        self.assertEqual(summary['held'], 2)
        self.assertEqual(summary['balance'], 4)
        self.assertEqual(summary['available'], 2)

        helper_summary = help_credit_summary('b', requests)
        self.assertEqual(helper_summary['earned'], 1)
        self.assertEqual(helper_summary['spent'], 2)
        self.assertEqual(helper_summary['available'], 4)

    def test_history_from_the_old_rule_can_go_negative(self):
        requests = [_completed_request(f'r{i}') for i in range(3)]
        summary = help_credit_summary('user_requester', requests)
        self.assertEqual(summary['spent'], 6)
        self.assertEqual(summary['balance'], -1)
        self.assertEqual(summary['available'], -1)


class HelpCreditWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.requester = _user('user_requester', 'requester@example.com')
        self.helper = _user(
            'user_helper',
            'helper@example.com',
            categories=['technicalSupport'],
        )
        self.database = _database(self.requester, self.helper)

    def _create(self, title='Laptop setup', category='technicalSupport'):
        self.database, result = _apply(
            self.database,
            'user_requester',
            'create_help_request',
            _request_payload(title=title, category=category),
        )
        return result['requestId']

    def _fill_open_requests(self):
        return [self._create(title=f'Request number {index}') for index in range(2)]

    def _seed_requester_history(self, requests):
        self.database['requester@example.com']['requests'].extend(requests)

    def test_requests_are_blocked_once_fewer_than_two_credits_are_free(self):
        self._fill_open_requests()

        with self.assertRaises(WorkflowError) as raised:
            self._create(title='One too many')
        self.assertEqual(raised.exception.status_code, 409)
        self.assertIn('at least 2 help credits', raised.exception.message)

    def test_posting_with_exactly_two_available_succeeds(self):
        self._seed_requester_history([_completed_request('r_old')])
        self.assertTrue(self._create(title='Uses my last two'))
        with self.assertRaises(WorkflowError):
            self._create(title='No credits left')

    def test_one_available_credit_is_not_enough(self):
        self._seed_requester_history(
            [_completed_request('r_old_1'), _completed_request('r_old_2')]
        )
        with self.assertRaises(WorkflowError):
            self._create(title='Only one credit left')

    def test_negative_balance_blocks_posting_but_not_emergencies(self):
        self._seed_requester_history(
            [_completed_request(f'r_old_{i}') for i in range(3)]
        )
        with self.assertRaises(WorkflowError):
            self._create(title='In debt')
        self.assertTrue(self._create(title='Flooded street', category='emergencySupport'))

    def test_emergency_requests_are_free(self):
        self._fill_open_requests()

        request_id = self._create(title='Flooded street', category='emergencySupport')
        self.assertTrue(request_id)

    def test_spoofed_emergency_override_does_not_bypass_credits(self):
        self._fill_open_requests()

        payload = _request_payload(title='Override attempt')
        payload['emergencyOverride'] = True
        with self.assertRaises(WorkflowError):
            _apply(self.database, 'user_requester', 'create_help_request', payload)

    def test_deleting_an_open_request_releases_both_credits(self):
        request_ids = self._fill_open_requests()
        self.database, _ = _apply(
            self.database,
            'user_requester',
            'delete_help_request',
            {'requestId': request_ids[0]},
        )
        summary = help_credit_summary('user_requester', _all_requests(self.database))
        self.assertEqual(summary['held'], 2)
        self.assertEqual(summary['available'], 3)
        self.assertTrue(self._create(title='Fits again now'))

    def test_completed_help_spends_two_and_helper_earns_one(self):
        request_id = self._create()
        self.database, _ = _apply(
            self.database,
            'user_helper',
            'volunteer_for_help_request',
            {'requestId': request_id},
        )
        for actor in ('user_helper', 'user_requester'):
            self.database, _ = _apply(
                self.database,
                actor,
                'confirm_request_completion',
                {'requestId': request_id},
            )

        requests = _all_requests(self.database)
        requester_credits = help_credit_summary('user_requester', requests)
        helper_credits = help_credit_summary('user_helper', requests)
        self.assertEqual(requester_credits['available'], 3)
        self.assertEqual(requester_credits['spent'], 2)
        self.assertEqual(requester_credits['held'], 0)
        self.assertEqual(helper_credits['available'], 6)
        self.assertEqual(helper_credits['earned'], 1)

        helper_titles = [
            notification['title']
            for notification in _notifications_for(self.database, 'helper@example.com')
        ]
        self.assertIn('You earned 1 help credit', helper_titles)
        requester_messages = [
            notification['message']
            for notification in _notifications_for(
                self.database, 'requester@example.com'
            )
        ]
        self.assertTrue(
            any(
                '2 help credits were used: 1 for asking and 1 for receiving help'
                in message
                and 'You have 3 available' in message
                for message in requester_messages
            )
        )

        request = next(item for item in requests if item['id'] == request_id)
        actions = [entry['action'] for entry in request['actionLog']]
        self.assertIn('Requester used 1 help credit for asking', actions)
        self.assertIn('Requester used 1 help credit for receiving help', actions)
        self.assertIn('Helper earned 1 help credit', actions)

    def test_changing_a_free_request_to_paid_needs_two_credits(self):
        self._fill_open_requests()
        emergency_id = self._create(title='Flooded street', category='emergencySupport')

        payload = _request_payload(title='Now a normal request')
        payload['requestId'] = emergency_id
        with self.assertRaises(WorkflowError):
            _apply(self.database, 'user_requester', 'update_help_request', payload)


if __name__ == '__main__':
    unittest.main()
