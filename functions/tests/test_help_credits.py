import unittest

from workflow_backend import WorkflowError
from workflow_backend.credits import REQUEST_CREDIT_COST, help_credit_summary
from workflow_backend.constants import HELP_EARNED_CREDITS, STARTING_HELP_CREDITS

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

    def test_a_request_costs_what_a_helper_earns(self):
        self.assertEqual(STARTING_HELP_CREDITS, 5)
        self.assertEqual(REQUEST_CREDIT_COST, 1)
        self.assertEqual(HELP_EARNED_CREDITS, REQUEST_CREDIT_COST)

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
        self.assertEqual(summary['spent'], 1)
        self.assertEqual(summary['held'], 1)
        self.assertEqual(summary['balance'], 5)
        self.assertEqual(summary['available'], 4)

        helper_summary = help_credit_summary('b', requests)
        self.assertEqual(helper_summary['earned'], 1)
        self.assertEqual(helper_summary['spent'], 1)
        self.assertEqual(helper_summary['available'], 5)

    def test_completed_exchange_balances(self):
        requests = [_completed_request('r1', requester_id='a', helper_id='b')]
        requester = help_credit_summary('a', requests)
        helper = help_credit_summary('b', requests)
        self.assertEqual(requester['available'] + helper['available'], 10)
        self.assertEqual(requester['available'], 4)
        self.assertEqual(helper['available'], 6)

    def test_earning_has_no_limit(self):
        def helps_given(count):
            return [
                _completed_request(
                    f'given_{i}', requester_id=f'neighbour_{i}', helper_id='me'
                )
                for i in range(count)
            ]

        summary = help_credit_summary('me', helps_given(12))
        self.assertEqual(summary['earned'], 12)
        self.assertEqual(summary['spent'], 0)
        self.assertEqual(summary['held'], 0)
        self.assertEqual(summary['balance'], 17)
        self.assertEqual(summary['available'], 17)

        self.assertEqual(help_credit_summary('me', helps_given(150))['available'], 155)

    def test_balance_can_go_below_zero(self):
        requests = [_completed_request(f'r{i}') for i in range(6)]
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
        return [
            self._create(title=f'Request number {index}')
            for index in range(STARTING_HELP_CREDITS)
        ]

    def _seed_requester_history(self, requests):
        self.database['requester@example.com']['requests'].extend(requests)

    def _requester_credits(self):
        return help_credit_summary('user_requester', _all_requests(self.database))

    def _volunteer(self, request_id):
        self.database, _ = _apply(
            self.database,
            'user_helper',
            'volunteer_for_help_request',
            {'requestId': request_id},
        )

    def _complete(self, request_id):
        self._volunteer(request_id)
        for actor in ('user_helper', 'user_requester'):
            self.database, _ = _apply(
                self.database,
                actor,
                'confirm_request_completion',
                {'requestId': request_id},
            )

    def test_each_open_request_holds_one_credit(self):
        self._create()
        credits = self._requester_credits()
        self.assertEqual(credits['held'], 1)
        self.assertEqual(credits['available'], 4)

    def test_requests_are_blocked_once_no_credit_is_free(self):
        self._fill_open_requests()
        self.assertEqual(self._requester_credits()['available'], 0)

        with self.assertRaises(WorkflowError) as raised:
            self._create(title='One too many')
        self.assertEqual(raised.exception.status_code, 409)
        self.assertIn('at least 1 help credit available', raised.exception.message)

    def test_posting_with_exactly_one_available_succeeds(self):
        self._seed_requester_history(
            [_completed_request(f'r_old_{i}') for i in range(4)]
        )
        self.assertEqual(self._requester_credits()['available'], 1)
        self.assertTrue(self._create(title='Uses my last one'))
        with self.assertRaises(WorkflowError):
            self._create(title='No credits left')

    def test_zero_available_is_blocked(self):
        self._seed_requester_history(
            [_completed_request(f'r_old_{i}') for i in range(5)]
        )
        self.assertEqual(self._requester_credits()['available'], 0)
        with self.assertRaises(WorkflowError):
            self._create(title='Nothing left')

    def test_negative_balance_blocks_posting_but_not_emergencies(self):
        self._seed_requester_history(
            [_completed_request(f'r_old_{i}') for i in range(6)]
        )
        with self.assertRaises(WorkflowError):
            self._create(title='In debt')
        self.assertTrue(self._create(title='Flooded street', category='emergencySupport'))

    def test_emergency_requests_are_free(self):
        self._fill_open_requests()

        request_id = self._create(title='Flooded street', category='emergencySupport')
        self.assertTrue(request_id)
        self.assertEqual(self._requester_credits()['held'], STARTING_HELP_CREDITS)

    def test_spoofed_emergency_override_does_not_bypass_credits(self):
        self._fill_open_requests()

        payload = _request_payload(title='Override attempt')
        payload['emergencyOverride'] = True
        with self.assertRaises(WorkflowError):
            _apply(self.database, 'user_requester', 'create_help_request', payload)

    def test_deleting_an_open_request_releases_its_credit(self):
        request_ids = self._fill_open_requests()
        self.database, _ = _apply(
            self.database,
            'user_requester',
            'delete_help_request',
            {'requestId': request_ids[0]},
        )
        credits = self._requester_credits()
        self.assertEqual(credits['held'], 4)
        self.assertEqual(credits['available'], 1)
        self.assertTrue(self._create(title='Fits again now'))

    def test_canceling_a_matched_request_releases_its_credit(self):
        request_id = self._create()
        self._volunteer(request_id)
        self.assertEqual(self._requester_credits()['available'], 4)

        self.database, _ = _apply(
            self.database,
            'user_requester',
            'cancel_accepted_request',
            {'requestId': request_id},
        )
        credits = self._requester_credits()
        self.assertEqual(credits['held'], 0)
        self.assertEqual(credits['spent'], 0)
        self.assertEqual(credits['available'], 5)
        helper_credits = help_credit_summary('user_helper', _all_requests(self.database))
        self.assertEqual(helper_credits['earned'], 0)

    def test_completed_help_spends_one_and_helper_earns_one(self):
        request_id = self._create()
        self._complete(request_id)

        requests = _all_requests(self.database)
        requester_credits = help_credit_summary('user_requester', requests)
        helper_credits = help_credit_summary('user_helper', requests)
        self.assertEqual(requester_credits['available'], 4)
        self.assertEqual(requester_credits['spent'], 1)
        self.assertEqual(requester_credits['held'], 0)
        self.assertEqual(helper_credits['available'], 6)
        self.assertEqual(helper_credits['earned'], 1)

        helper_notifications = _notifications_for(self.database, 'helper@example.com')
        self.assertIn(
            'You earned 1 help credit',
            [notification['title'] for notification in helper_notifications],
        )
        self.assertTrue(
            any(
                'You now have 6 help credits' in notification['message']
                for notification in helper_notifications
            )
        )
        requester_messages = [
            notification['message']
            for notification in _notifications_for(
                self.database, 'requester@example.com'
            )
        ]
        self.assertTrue(
            any(
                '1 help credit was used. You have 4 available.' in message
                for message in requester_messages
            )
        )
        self.assertFalse(any('for asking' in message for message in requester_messages))

        request = next(item for item in requests if item['id'] == request_id)
        credit_actions = [
            entry['action']
            for entry in request['actionLog']
            if 'help credit' in entry['action']
        ]
        self.assertEqual(
            credit_actions,
            ['Helper earned 1 help credit', 'Requester used 1 help credit'],
        )

    def test_helper_keeps_earning_past_the_starting_balance(self):
        neighbour = _user('user_neighbour', 'neighbour@example.com')
        self.database['neighbour@example.com'] = _database(neighbour)[
            'neighbour@example.com'
        ]
        self.database['neighbour@example.com']['requests'].extend(
            _completed_request(
                f'given_{i}', requester_id='user_neighbour', helper_id='user_helper'
            )
            for i in range(12)
        )
        self.assertEqual(
            help_credit_summary('user_helper', _all_requests(self.database))['available'],
            17,
        )

        self._complete(self._create())

        helper_credits = help_credit_summary('user_helper', _all_requests(self.database))
        self.assertEqual(helper_credits['earned'], 13)
        self.assertEqual(helper_credits['available'], 18)
        helper_messages = [
            notification['message']
            for notification in _notifications_for(self.database, 'helper@example.com')
        ]
        self.assertTrue(
            any('You now have 18 help credits' in message for message in helper_messages)
        )

    def test_changing_a_free_request_to_paid_needs_a_credit(self):
        self._fill_open_requests()
        emergency_id = self._create(title='Flooded street', category='emergencySupport')

        payload = _request_payload(title='Now a normal request')
        payload['requestId'] = emergency_id
        with self.assertRaises(WorkflowError):
            _apply(self.database, 'user_requester', 'update_help_request', payload)


if __name__ == '__main__':
    unittest.main()
