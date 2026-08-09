import unittest

from workflow_backend import WorkflowError, apply_workflow_operation


def _user(user_id, email, *, categories=None, blocked_user_ids=None):
    return {
        'id': user_id,
        'fullName': user_id.replace('_', ' ').title(),
        'email': email,
        'city': 'Accra',
        'area': 'East Legon',
        'verificationBadges': ['emailVerified', 'phoneVerified'],
        'trustScore': 90,
        'availability': True,
        'helpCategoriesProvided': categories or [],
        'helpCategoriesRequested': [],
        'serviceRadiusKm': 10,
        'helpGivenCount': 0,
        'helpReceivedCount': 0,
        'restrictionStatus': 'clear',
        'averageRating': 4.8,
        'completedHelpCount': 4,
        'receivedHelpCount': 1,
        'blockedUserIds': blocked_user_ids or [],
        'mutedUserIds': [],
        'hiddenRequestIds': [],
    }


def _database(*users):
    database = {
        '_meta': {},
        '_shared': {
            'matches': [],
            'threads': [],
            'messages': [],
            'reviews': [],
            'reports': [],
            'supportCircles': [],
        },
    }
    for user in users:
        database[user['email']] = {
            'user': user,
            'requests': [],
            'notifications': [],
            'moodCheckIns': [],
        }
    return database


def _apply(database, current_user_id, operation, payload=None):
    return apply_workflow_operation(
        {
            'database': database,
            'currentUserId': current_user_id,
            'operation': operation,
            'payload': payload or {},
        }
    )


class WorkflowOperationTests(unittest.TestCase):
    def test_request_match_completion_and_review_lifecycle(self):
        requester = _user('user_requester', 'requester@example.com')
        helper = _user(
            'user_helper',
            'helper@example.com',
            categories=['technicalSupport'],
        )
        database = _database(requester, helper)

        database, create_result = _apply(
            database,
            'user_requester',
            'create_help_request',
            {
                'title': 'Laptop setup',
                'description': 'Help me configure my laptop.',
                'category': 'technicalSupport',
                'urgency': 'medium',
                'location': 'East Legon',
                'preferredTime': 'Today',
                'visibility': 'public',
            },
        )
        request_id = create_result['requestId']
        created_request = database['requester@example.com']['requests'][0]
        self.assertEqual(created_request['id'], request_id)
        self.assertIn('user_helper', created_request['suggestedHelperIds'])

        database, match_result = _apply(
            database,
            'user_helper',
            'volunteer_for_help_request',
            {'requestId': request_id},
        )
        self.assertTrue(match_result['matched'])
        matched_request = database['requester@example.com']['requests'][0]
        self.assertEqual(matched_request['status'], 'accepted')
        self.assertEqual(matched_request['acceptedHelperId'], 'user_helper')
        self.assertEqual(len(database['_shared']['threads']), 1)

        database, start_result = _apply(
            database,
            'user_helper',
            'start_request_work',
            {'requestId': request_id},
        )
        self.assertTrue(start_result['started'])

        database, _ = _apply(
            database,
            'user_helper',
            'confirm_request_completion',
            {'requestId': request_id},
        )
        database, completion_result = _apply(
            database,
            'user_requester',
            'confirm_request_completion',
            {'requestId': request_id},
        )
        self.assertTrue(completion_result['confirmed'])
        completed_request = database['requester@example.com']['requests'][0]
        self.assertEqual(completed_request['status'], 'completed')

        database, review_result = _apply(
            database,
            'user_requester',
            'submit_review_for_request',
            {
                'requestId': request_id,
                'helpfulness': 5,
                'respectfulness': 5,
                'safety': 5,
                'reliability': 5,
                'accuracy': 5,
                'feedback': 'Great help.',
            },
        )
        self.assertTrue(review_result['reviewId'])
        self.assertEqual(
            database['_shared']['reviews'][0]['revieweeId'],
            'user_helper',
        )

    def test_blocked_accounts_cannot_send_messages(self):
        sender = _user(
            'user_sender',
            'sender@example.com',
            blocked_user_ids=['user_peer'],
        )
        peer = _user('user_peer', 'peer@example.com')
        database = _database(sender, peer)
        database['_shared']['threads'] = [
            {
                'id': 'thread_1',
                'requestId': 'request_1',
                'participantIds': ['user_sender', 'user_peer'],
                'blockedByIds': [],
            }
        ]

        with self.assertRaises(WorkflowError) as raised:
            _apply(
                database,
                'user_sender',
                'send_message',
                {'threadId': 'thread_1', 'content': 'Should not send'},
            )

        self.assertEqual(raised.exception.status_code, 403)

    def test_unrelated_user_cannot_file_participant_safety_report(self):
        requester = _user('user_requester', 'requester@example.com')
        helper = _user('user_helper', 'helper@example.com')
        outsider = _user('user_outsider', 'outsider@example.com')
        database = _database(requester, helper, outsider)
        database['requester@example.com']['requests'] = [
            {
                'id': 'request_1',
                'requesterId': 'user_requester',
                'acceptedHelperId': 'user_helper',
                'title': 'Private request',
                'status': 'accepted',
            }
        ]

        with self.assertRaises(WorkflowError) as raised:
            _apply(
                database,
                'user_outsider',
                'submit_participant_safety_report',
                {
                    'requestId': 'request_1',
                    'reason': 'Not a participant',
                },
            )

        self.assertEqual(raised.exception.status_code, 409)


if __name__ == '__main__':
    unittest.main()
