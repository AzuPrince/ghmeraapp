import unittest
from unittest.mock import MagicMock, patch

import main
from workflow_backend import WorkflowError


class WorkflowAuthenticationTests(unittest.TestCase):
    def test_workflow_identity_requires_bearer_token(self):
        request = MagicMock()
        request.headers = {}

        with self.assertRaises(WorkflowError) as raised:
            main._require_workflow_identity(request)

        self.assertEqual(raised.exception.status_code, 401)

    @patch('main.admin_auth.verify_id_token')
    def test_workflow_identity_verifies_token_and_normalizes_email(
        self,
        verify_id_token_mock,
    ):
        verify_id_token_mock.return_value = {
            'uid': 'firebase-uid',
            'email': ' Person@Example.COM ',
            'email_verified': True,
        }
        request = MagicMock()
        request.headers = {'Authorization': 'Bearer valid-token'}

        identity = main._require_workflow_identity(request)

        verify_id_token_mock.assert_called_once_with(
            'valid-token',
            check_revoked=True,
        )
        self.assertEqual(
            identity,
            {'uid': 'firebase-uid', 'email': 'person@example.com'},
        )

    @patch('main.admin_auth.verify_id_token')
    def test_workflow_identity_rejects_invalid_token(
        self,
        verify_id_token_mock,
    ):
        verify_id_token_mock.side_effect = ValueError('invalid token detail')
        request = MagicMock()
        request.headers = {'Authorization': 'Bearer invalid-token'}

        with self.assertRaises(WorkflowError) as raised:
            main._require_workflow_identity(request)

        self.assertEqual(raised.exception.status_code, 401)
        self.assertNotIn('invalid token detail', raised.exception.message)

    @patch('main.admin_auth.verify_id_token')
    def test_workflow_identity_rejects_unverified_email(
        self,
        verify_id_token_mock,
    ):
        verify_id_token_mock.return_value = {
            'uid': 'firebase-uid',
            'email': 'person@example.com',
            'email_verified': False,
        }
        request = MagicMock()
        request.headers = {'Authorization': 'Bearer valid-token'}

        with self.assertRaises(WorkflowError) as raised:
            main._require_workflow_identity(request)

        self.assertEqual(raised.exception.status_code, 403)

    def test_secure_workflow_body_overrides_spoofed_user_id(self):
        body = {
            'operation': 'send_message',
            'currentUserId': 'user_victim',
            'database': {
                '_meta': {
                    'currentUserId': 'user_victim',
                    'currentUserEmail': 'victim@example.com',
                },
                'person@example.com': {
                    'user': {
                        'id': 'legacy_person_id',
                        'email': 'person@example.com',
                    }
                },
                'victim@example.com': {
                    'user': {
                        'id': 'user_victim',
                        'email': 'victim@example.com',
                    }
                },
            },
            'payload': {'threadId': 'thread_1', 'content': 'Hello'},
        }

        secured = main._secure_workflow_body(
            body,
            {'uid': 'firebase-uid', 'email': 'person@example.com'},
        )

        self.assertEqual(secured['currentUserId'], 'legacy_person_id')
        self.assertEqual(
            secured['database']['_meta']['currentUserId'],
            'legacy_person_id',
        )
        self.assertEqual(
            secured['database']['_meta']['currentUserEmail'],
            'person@example.com',
        )
        self.assertEqual(body['currentUserId'], 'user_victim')

    def test_secure_workflow_body_prefers_canonical_uid_profile(self):
        database = {
            'legacy': {
                'user': {'id': 'legacy_id', 'email': 'person@example.com'}
            },
            'canonical': {
                'user': {
                    'id': 'user_firebase-uid',
                    'email': 'person@example.com',
                }
            },
        }

        secured = main._secure_workflow_body(
            {'operation': 'create_help_request', 'database': database},
            {'uid': 'firebase-uid', 'email': 'person@example.com'},
        )

        self.assertEqual(secured['currentUserId'], 'user_firebase-uid')

    def test_secure_workflow_body_rejects_unmatched_account(self):
        body = {
            'operation': 'create_help_request',
            'database': {
                'someone-else': {
                    'user': {
                        'id': 'user_someone_else',
                        'email': 'someone.else@example.com',
                    }
                }
            },
        }

        with self.assertRaises(WorkflowError) as raised:
            main._secure_workflow_body(
                body,
                {'uid': 'firebase-uid', 'email': 'person@example.com'},
            )

        self.assertEqual(raised.exception.status_code, 403)


if __name__ == '__main__':
    unittest.main()
