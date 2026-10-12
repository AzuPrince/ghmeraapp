import unittest
from unittest.mock import MagicMock, patch

import account_deletion


class AccountDeletionSanitizerTests(unittest.TestCase):
    def test_removes_account_and_associated_community_data(self):
        database = {
            "_meta": {
                "currentUserId": "user_auth-1",
                "currentUserEmail": "person@example.com",
            },
            "_shared": {
                "matches": [
                    {
                        "id": "match-1",
                        "requesterId": "user_auth-1",
                        "helperId": "user-peer",
                        "requestId": "request-1",
                    },
                    {
                        "id": "match-2",
                        "requesterId": "user-peer",
                        "helperId": "user-other",
                        "requestId": "request-2",
                    },
                ],
                "threads": [
                    {
                        "id": "thread-1",
                        "requestId": "request-1",
                        "participantIds": ["user_auth-1", "user-peer"],
                    },
                    {
                        "id": "thread-2",
                        "requestId": "request-2",
                        "participantIds": ["user-peer", "user-other"],
                    },
                ],
                "messages": [
                    {
                        "id": "message-1",
                        "threadId": "thread-1",
                        "senderId": "user-peer",
                    },
                    {
                        "id": "message-2",
                        "threadId": "thread-2",
                        "senderId": "user-peer",
                    },
                ],
                "reviews": [
                    {
                        "id": "review-1",
                        "matchId": "match-1",
                        "reviewerId": "user-peer",
                        "revieweeId": "user_auth-1",
                    }
                ],
                "reports": [
                    {
                        "id": "report-1",
                        "reporterId": "user-peer",
                        "targetId": "thread-1",
                    }
                ],
                "supportCircles": [
                    {
                        "id": "circle-1",
                        "memberIds": ["user_auth-1", "user-peer"],
                    }
                ],
            },
            "person@example.com": {
                "user": {
                    "id": "user_auth-1",
                    "email": "person@example.com",
                },
                "requests": [
                    {"id": "request-1", "requesterId": "user_auth-1"}
                ],
                "notifications": [],
                "moodCheckIns": [],
            },
            "peer@example.com": {
                "user": {
                    "id": "user-peer",
                    "email": "peer@example.com",
                    "blockedUserIds": ["user_auth-1"],
                    "mutedUserIds": ["user-other"],
                },
                "requests": [
                    {
                        "id": "request-2",
                        "requesterId": "user-peer",
                        "acceptedHelperId": "user_auth-1",
                        "status": "accepted",
                        "suggestedHelperIds": ["user_auth-1", "user-other"],
                        "actionLog": [
                            {"actorId": "user_auth-1", "action": "Accepted"},
                            {"actorId": "user-peer", "action": "Created"},
                        ],
                    }
                ],
                "notifications": [],
                "moodCheckIns": [],
            },
        }

        sanitized, counts = account_deletion.sanitize_database_for_account_deletion(
            database,
            uid="auth-1",
            email="PERSON@example.com",
        )

        self.assertNotIn("person@example.com", sanitized)
        self.assertNotIn("currentUserId", sanitized["_meta"])
        self.assertNotIn("currentUserEmail", sanitized["_meta"])
        self.assertEqual(sanitized["_shared"]["matches"], [database["_shared"]["matches"][1]])
        self.assertEqual(sanitized["_shared"]["threads"], [database["_shared"]["threads"][1]])
        self.assertEqual(sanitized["_shared"]["messages"], [database["_shared"]["messages"][1]])
        self.assertEqual(sanitized["_shared"]["reviews"], [])
        self.assertEqual(sanitized["_shared"]["reports"], [])
        self.assertEqual(
            sanitized["_shared"]["supportCircles"][0]["memberIds"],
            ["user-peer"],
        )

        peer_bucket = sanitized["peer@example.com"]
        self.assertEqual(peer_bucket["user"]["blockedUserIds"], [])
        self.assertEqual(peer_bucket["user"]["mutedUserIds"], ["user-other"])
        peer_request = peer_bucket["requests"][0]
        self.assertNotIn("acceptedHelperId", peer_request)
        self.assertEqual(peer_request["status"], "matching")
        self.assertEqual(peer_request["suggestedHelperIds"], ["user-other"])
        self.assertEqual(peer_request["actionLog"], [{"actorId": "user-peer", "action": "Created"}])
        self.assertEqual(counts["userBuckets"], 1)
        self.assertEqual(counts["requests"], 1)


class AccountDeletionFirestoreTests(unittest.TestCase):
    @patch("account_deletion.firestore.client")
    def test_deletes_tracker_recursively_and_is_idempotent_by_path(self, client_mock):
        db = client_mock.return_value
        global_collection = MagicMock()
        mirrored_collection = MagicMock()
        tracker_collection = MagicMock()
        db.collection.side_effect = lambda name: {
            "global_app_state": global_collection,
            "Users_requests": mirrored_collection,
            "user_trackers": tracker_collection,
        }[name]

        global_ref = MagicMock()
        global_ref.get.return_value.exists = False
        global_collection.document.return_value = global_ref

        mirrored_ref = MagicMock()
        mirrored_ref.get.return_value.exists = False
        mirrored_collection.document.return_value = mirrored_ref

        explicit_tracker_ref = MagicMock()
        explicit_tracker_ref.path = "user_trackers/email_person@example.com"
        tracker_collection.document.return_value = explicit_tracker_ref
        duplicate_tracker_ref = MagicMock()
        duplicate_tracker_ref.path = explicit_tracker_ref.path
        duplicate_snapshot = MagicMock()
        duplicate_snapshot.reference = duplicate_tracker_ref
        tracker_collection.where.return_value.stream.return_value = [
            duplicate_snapshot
        ]

        result = account_deletion.delete_user_data(
            "auth-1",
            "Person@Example.com",
        )

        db.recursive_delete.assert_called_once()
        self.assertEqual(result["trackerDocuments"], 1)
        tracker_collection.where.assert_called_once_with(
            "authEmail",
            "==",
            "person@example.com",
        )

    @patch("account_deletion.firestore.client")
    def test_replaces_global_database_instead_of_merging(self, client_mock):
        db = client_mock.return_value
        global_collection = MagicMock()
        mirrored_collection = MagicMock()
        tracker_collection = MagicMock()
        db.collection.side_effect = lambda name: {
            "global_app_state": global_collection,
            "Users_requests": mirrored_collection,
            "user_trackers": tracker_collection,
        }[name]

        global_ref = MagicMock()
        global_ref.get.return_value.exists = True
        global_ref.get.return_value.to_dict.return_value = {
            "currentUserId": "user_auth-1",
            "database": {
                "_meta": {"currentUserId": "user_auth-1"},
                "person@example.com": {
                    "user": {"id": "user_auth-1", "email": "person@example.com"},
                    "requests": [],
                },
                "peer@example.com": {
                    "user": {"id": "user-peer", "email": "peer@example.com"},
                    "requests": [],
                },
            },
        }
        global_collection.document.return_value = global_ref

        mirrored_ref = MagicMock()
        mirrored_ref.get.return_value.exists = False
        mirrored_collection.document.return_value = mirrored_ref
        tracker_collection.document.return_value.path = (
            "user_trackers/email_person@example.com"
        )
        tracker_collection.where.return_value.stream.return_value = []

        account_deletion.delete_user_data("auth-1", "person@example.com")

        global_ref.set.assert_not_called()
        global_ref.update.assert_called_once()
        written = global_ref.update.call_args.args[0]
        self.assertNotIn("person@example.com", written["database"])
        self.assertIn("peer@example.com", written["database"])
        self.assertNotIn("currentUserId", written["database"]["_meta"])
        self.assertIs(
            written["currentUserId"],
            account_deletion.firestore.DELETE_FIELD,
        )

    def test_requires_a_user_id(self):
        with self.assertRaisesRegex(ValueError, "user ID"):
            account_deletion.delete_user_data("", "person@example.com")


if __name__ == "__main__":
    unittest.main()
