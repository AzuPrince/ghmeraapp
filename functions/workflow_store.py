"""Runs workflow operations against the saved shared app state.

The phone's copy of the database is never trusted for other members' data.
Each operation reads ``global_app_state/live`` and the request mirror inside a
Firestore transaction, applies the change and writes both documents back.
"""

from __future__ import annotations

import copy
import logging
import time
from typing import Any

from firebase_admin import firestore
from google.api_core import exceptions as google_exceptions

from workflow_backend import WorkflowError, apply_workflow_operation
from workflow_backend.profile import merge_client_user_record
from workflow_backend.utils import _as_map, _as_map_list, _copy_string_list

logger = logging.getLogger(__name__)

GLOBAL_APP_STATE_COLLECTION = 'global_app_state'
GLOBAL_APP_STATE_DOCUMENT = 'live'
MIRRORED_REQUESTS_COLLECTION = 'Users_requests'
MIRRORED_REQUESTS_DOCUMENT = 'sent request'
SERVER_WRITES_CLIENT_SCHEMA = 2
MAX_TRANSACTION_ATTEMPTS = 5
RETRY_BASE_DELAY_SECONDS = 0.05
BUSY_MESSAGE = 'Ghmera is busy right now. Please try again in a moment.'
PROFILE_NOT_MATCHED_MESSAGE = (
    'The signed-in account could not be matched to the app profile.'
)
SHARED_LIST_KEYS = (
    'matches',
    'threads',
    'messages',
    'reviews',
    'reports',
    'supportCircles',
)
THREAD_MEMBER_FLAG_KEYS = ('blockedByIds', 'mutedByIds', 'contactSharedByIds')


def _normalize_email(value: Any) -> str:
    return str(value or '').strip().lower()


def _iter_user_buckets(database: dict[str, Any]):
    for bucket_key, raw_bucket in database.items():
        if str(bucket_key).startswith('_') or not isinstance(raw_bucket, dict):
            continue
        raw_user = raw_bucket.get('user')
        if isinstance(raw_user, dict):
            yield str(bucket_key), raw_bucket, raw_user


def _empty_database() -> dict[str, Any]:
    return {'_meta': {}, '_shared': {key: [] for key in SHARED_LIST_KEYS}}


def authoritative_database(
    global_document: dict[str, Any] | None,
    mirrored_document: dict[str, Any] | None,
) -> dict[str, Any]:
    """The saved database, with each member's requests taken from the mirror
    the same way the apps read it."""
    raw_database = _as_map((global_document or {}).get('database'))
    if not raw_database:
        return _empty_database()

    mirrored_buckets: dict[str, list[Any]] = {}
    for key, raw_value in (mirrored_document or {}).items():
        if key == 'lastSyncedAt' or not isinstance(raw_value, dict):
            continue
        requests = raw_value.get('requests')
        if isinstance(requests, list) and requests:
            mirrored_buckets[str(key)] = requests

    for _, bucket, user in _iter_user_buckets(raw_database):
        email = _normalize_email(user.get('email'))
        user_id = str(user.get('id') or '').strip()
        mirrored = (mirrored_buckets.get(email) if email else None) or (
            mirrored_buckets.get(user_id) if user_id else None
        )
        if mirrored is not None:
            bucket['requests'] = copy.deepcopy(mirrored)

    shared = _as_map(raw_database.get('_shared'))
    for key in SHARED_LIST_KEYS:
        if not isinstance(shared.get(key), list):
            shared[key] = []
    raw_database['_shared'] = shared
    raw_database['_meta'] = _as_map(raw_database.get('_meta'))
    return raw_database


def resolve_caller_user_id(
    database: dict[str, Any], *, uid: str, email: str
) -> str | None:
    """The signed-in member's profile ID: their canonical ID, or the single
    profile saved under their verified email."""
    canonical_user_id = f'user_{uid}'
    email_matches: list[str] = []
    for _, _, user in _iter_user_buckets(database):
        user_id = str(user.get('id') or '').strip()
        if not user_id or _normalize_email(user.get('email')) != email:
            continue
        if user_id == canonical_user_id:
            return canonical_user_id
        email_matches.append(user_id)

    unique_matches = list(dict.fromkeys(email_matches))
    if len(unique_matches) == 1:
        return unique_matches[0]
    if len(unique_matches) > 1:
        raise WorkflowError(PROFILE_NOT_MATCHED_MESSAGE, status_code=403)
    return None


def _find_bucket(
    database: dict[str, Any], user_id: str
) -> tuple[str, dict[str, Any], dict[str, Any]] | None:
    for bucket_key, bucket, user in _iter_user_buckets(database):
        if str(user.get('id') or '').strip() == user_id:
            return bucket_key, bucket, user
    return None


def _merge_legacy_caller_activity(
    database: dict[str, Any],
    phone_database: dict[str, Any],
    *,
    caller_id: str,
    caller_bucket: dict[str, Any],
) -> None:
    """Older app builds change some of the caller's own data on the phone and
    save it with their own whole-database write, which may not have landed
    yet. Keep those changes, but only where they belong to the caller."""
    phone_bucket = _find_bucket(phone_database, caller_id)
    if phone_bucket is not None:
        _, phone_caller_bucket, _ = phone_bucket

        stored_notifications = _as_map_list(caller_bucket.get('notifications'))
        phone_notifications = {
            str(item.get('id')): item
            for item in _as_map_list(phone_caller_bucket.get('notifications'))
            if item.get('userId') == caller_id and item.get('id')
        }
        for notification in stored_notifications:
            phone_copy = phone_notifications.pop(str(notification.get('id')), None)
            if phone_copy is not None and isinstance(phone_copy.get('isRead'), bool):
                notification['isRead'] = phone_copy['isRead']
        for notification in phone_notifications.values():
            if all(
                isinstance(notification.get(key), str)
                for key in ('id', 'type', 'title', 'message', 'createdAt')
            ):
                stored_notifications.append(notification)
        caller_bucket['notifications'] = stored_notifications

        stored_moods = _as_map_list(caller_bucket.get('moodCheckIns'))
        stored_mood_ids = {str(item.get('id')) for item in stored_moods}
        for mood in _as_map_list(phone_caller_bucket.get('moodCheckIns')):
            if (
                mood.get('userId') == caller_id
                and str(mood.get('id')) not in stored_mood_ids
                and all(
                    isinstance(mood.get(key), str)
                    for key in ('id', 'moodLevel', 'createdAt')
                )
            ):
                stored_moods.append(mood)
        caller_bucket['moodCheckIns'] = stored_moods

    phone_shared = _as_map(phone_database.get('_shared'))
    shared = database['_shared']
    phone_threads = {
        str(thread.get('id')): thread
        for thread in _as_map_list(phone_shared.get('threads'))
    }
    for thread in shared['threads']:
        phone_thread = phone_threads.get(str(thread.get('id')))
        if phone_thread is None or caller_id not in _copy_string_list(
            thread.get('participantIds')
        ):
            continue
        for key in THREAD_MEMBER_FLAG_KEYS:
            members = [
                member
                for member in _copy_string_list(thread.get(key))
                if member != caller_id
            ]
            if caller_id in _copy_string_list(phone_thread.get(key)):
                members.append(caller_id)
            thread[key] = members

    phone_circles = {
        str(circle.get('id')): circle
        for circle in _as_map_list(phone_shared.get('supportCircles'))
    }
    for circle in shared['supportCircles']:
        phone_circle = phone_circles.get(str(circle.get('id')))
        if phone_circle is None:
            continue
        members = [
            member
            for member in _copy_string_list(circle.get('memberIds'))
            if member != caller_id
        ]
        if caller_id in _copy_string_list(phone_circle.get('memberIds')):
            members.append(caller_id)
        circle['memberIds'] = members


def prepare_caller_database(
    authoritative: dict[str, Any],
    body: dict[str, Any],
    *,
    uid: str,
    email: str,
) -> tuple[dict[str, Any], str]:
    """Return the saved database with only the caller's own record merged in
    from the phone, and the caller's profile ID."""
    database = copy.deepcopy(authoritative)
    shared = _as_map(database.get('_shared'))
    for key in SHARED_LIST_KEYS:
        if not isinstance(shared.get(key), list):
            shared[key] = []
    database['_shared'] = shared
    phone_database = _as_map(body.get('database'))
    is_legacy_client = (
        _as_int(body.get('clientSchema')) < SERVER_WRITES_CLIENT_SCHEMA
    )

    caller_id = resolve_caller_user_id(database, uid=uid, email=email)
    if caller_id is None:
        # A brand-new member who isn't saved yet. Only their canonical
        # profile is accepted, so a phone can't claim someone else's ID.
        caller_id = f'user_{uid}'
        phone_bucket = _find_bucket(phone_database, caller_id)
        if phone_bucket is None or _normalize_email(phone_bucket[2].get('email')) != email:
            raise WorkflowError(PROFILE_NOT_MATCHED_MESSAGE, status_code=403)
        database[email] = {
            'user': merge_client_user_record(
                None, phone_bucket[2], user_id=caller_id, email=email
            ),
            'requests': [],
            'notifications': [],
            'moodCheckIns': [],
        }
    elif is_legacy_client:
        stored_bucket = _find_bucket(database, caller_id)
        phone_bucket = _find_bucket(phone_database, caller_id)
        if stored_bucket is not None and phone_bucket is not None:
            _, caller_bucket, stored_user = stored_bucket
            caller_bucket['user'] = merge_client_user_record(
                stored_user,
                phone_bucket[2],
                user_id=caller_id,
                email=_normalize_email(stored_user.get('email')) or email,
            )
            _merge_legacy_caller_activity(
                database,
                phone_database,
                caller_id=caller_id,
                caller_bucket=caller_bucket,
            )

    database['_meta'] = {'currentUserId': caller_id, 'currentUserEmail': email}
    return database, caller_id


def _as_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return 0


def stored_database(
    database: dict[str, Any], stored_meta: dict[str, Any]
) -> dict[str, Any]:
    """The shared copy to save: no caller-specific metadata."""
    saved = copy.deepcopy(database)
    saved['_meta'] = {
        key: value
        for key, value in stored_meta.items()
        if key not in {'currentUserId', 'currentUserEmail'}
    }
    return saved


def mirrored_requests_document(database: dict[str, Any]) -> dict[str, Any]:
    document: dict[str, Any] = {'lastSyncedAt': firestore.SERVER_TIMESTAMP}
    for _, bucket, user in _iter_user_buckets(database):
        requests = _as_map_list(bucket.get('requests'))
        if not requests:
            continue
        email = _normalize_email(user.get('email'))
        user_id = str(user.get('id') or '').strip()
        document_key = email or user_id
        if not document_key:
            continue
        document[document_key] = {
            'requesterEmail': email or None,
            'requesterId': user_id or None,
            'requests': requests,
        }
    return document


def _apply_in_transaction(
    transaction,
    *,
    global_ref,
    mirrored_ref,
    body: dict[str, Any],
    uid: str,
    email: str,
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    global_snapshot = global_ref.get(transaction=transaction)
    mirrored_snapshot = mirrored_ref.get(transaction=transaction)
    global_document = global_snapshot.to_dict() if global_snapshot.exists else None
    mirrored_document = (
        mirrored_snapshot.to_dict() if mirrored_snapshot.exists else None
    )

    authoritative = authoritative_database(global_document, mirrored_document)
    database, caller_id = prepare_caller_database(
        authoritative, body, uid=uid, email=email
    )

    operation_body = {
        'operation': body.get('operation'),
        'currentUserId': caller_id,
        'database': database,
        'payload': body.get('payload'),
    }
    try:
        updated_database, result = apply_workflow_operation(operation_body)
    except WorkflowError as error:
        if error.database is None and error.status_code in {403, 404, 409}:
            error.database = database
        raise

    saved = stored_database(updated_database, authoritative['_meta'])
    global_update = {
        'database': saved,
        'schemaVersion': 1,
        'lastSyncedAt': firestore.SERVER_TIMESTAMP,
    }
    if global_snapshot.exists:
        transaction.update(global_ref, global_update)
    else:
        transaction.set(global_ref, global_update)
    transaction.set(mirrored_ref, mirrored_requests_document(saved))
    return updated_database, result


def apply_workflow_request(
    body: dict[str, Any], identity: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Apply a workflow request for the signed-in member and save the result.

    Accepts both request formats: older builds send their whole database,
    newer builds (``clientSchema`` 2) send only their own profile.
    """
    if not isinstance(body.get('database'), dict):
        raise WorkflowError('Missing app-state database payload.')
    uid = str(identity.get('uid') or '').strip()
    email = _normalize_email(identity.get('email'))

    db = firestore.client()
    global_ref = db.collection(GLOBAL_APP_STATE_COLLECTION).document(
        GLOBAL_APP_STATE_DOCUMENT
    )
    mirrored_ref = db.collection(MIRRORED_REQUESTS_COLLECTION).document(
        MIRRORED_REQUESTS_DOCUMENT
    )

    def run(transaction):
        return _apply_in_transaction(
            transaction,
            global_ref=global_ref,
            mirrored_ref=mirrored_ref,
            body=body,
            uid=uid,
            email=email,
        )

    for attempt in range(MAX_TRANSACTION_ATTEMPTS):
        transaction = db.transaction(max_attempts=MAX_TRANSACTION_ATTEMPTS)
        try:
            return firestore.transactional(run)(transaction)
        except google_exceptions.Aborted:
            logger.info(
                'Workflow transaction contention on attempt %s; retrying.',
                attempt + 1,
            )
            time.sleep(RETRY_BASE_DELAY_SECONDS * (2**attempt))
        except ValueError as error:
            # The Firestore client gives up with a ValueError once its own
            # commit retries are exhausted.
            if 'transaction' not in str(error).lower():
                raise
            logger.warning('Workflow transaction kept conflicting: %s', error)
            break
    raise WorkflowError(BUSY_MESSAGE, status_code=503)
