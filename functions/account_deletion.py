"""Privacy-safe deletion of Ghmera account data stored in Firestore."""

from __future__ import annotations

import copy
from typing import Any

from firebase_admin import firestore


_TRACKER_COLLECTION = "user_trackers"
_GLOBAL_APP_STATE_COLLECTION = "global_app_state"
_GLOBAL_APP_STATE_DOCUMENT = "live"
_MIRRORED_REQUESTS_COLLECTION = "Users_requests"
_MIRRORED_REQUESTS_DOCUMENT = "sent request"


def _normalize_email(value: Any) -> str:
    return str(value or "").strip().lower()


def _map_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [dict(item) for item in value if isinstance(item, dict)]


def _string_list_without(value: Any, removed_values: set[str]) -> list[str]:
    if not isinstance(value, list):
        return []
    return [
        str(item)
        for item in value
        if str(item).strip() and str(item).strip() not in removed_values
    ]


def _target_identity(
    raw_database: dict[str, Any],
    *,
    uid: str,
    email: str,
) -> tuple[set[str], set[str]]:
    normalized_email = _normalize_email(email)
    target_user_ids = {uid, f"user_{uid}"}
    target_bucket_keys: set[str] = set()

    for bucket_key, raw_bucket in raw_database.items():
        if str(bucket_key).startswith("_") or not isinstance(raw_bucket, dict):
            continue
        raw_user = raw_bucket.get("user")
        if not isinstance(raw_user, dict):
            continue

        user_id = str(raw_user.get("id") or "").strip()
        user_email = _normalize_email(raw_user.get("email"))
        bucket_email = _normalize_email(bucket_key)
        if (
            user_id in target_user_ids
            or (normalized_email and user_email == normalized_email)
            or (normalized_email and bucket_email == normalized_email)
        ):
            target_bucket_keys.add(str(bucket_key))
            if user_id:
                target_user_ids.add(user_id)

    return target_user_ids, target_bucket_keys


def sanitize_database_for_account_deletion(
    raw_database: dict[str, Any],
    *,
    uid: str,
    email: str,
) -> tuple[dict[str, Any], dict[str, int]]:
    """Remove one account and all of its direct community data references."""
    updated = copy.deepcopy(raw_database)
    target_user_ids, target_bucket_keys = _target_identity(
        updated,
        uid=uid,
        email=email,
    )

    deleted_request_ids: set[str] = set()
    for bucket_key, raw_bucket in updated.items():
        if str(bucket_key).startswith("_") or not isinstance(raw_bucket, dict):
            continue
        for request in _map_list(raw_bucket.get("requests")):
            if str(request.get("requesterId") or "").strip() in target_user_ids:
                request_id = str(request.get("id") or "").strip()
                if request_id:
                    deleted_request_ids.add(request_id)

    for bucket_key in target_bucket_keys:
        updated.pop(bucket_key, None)

    for bucket_key, raw_bucket in list(updated.items()):
        if str(bucket_key).startswith("_") or not isinstance(raw_bucket, dict):
            continue

        bucket = dict(raw_bucket)
        raw_user = bucket.get("user")
        if isinstance(raw_user, dict):
            user = dict(raw_user)
            for field in ("blockedUserIds", "mutedUserIds"):
                user[field] = _string_list_without(user.get(field), target_user_ids)
            bucket["user"] = user

        surviving_requests: list[dict[str, Any]] = []
        for raw_request in _map_list(bucket.get("requests")):
            request = dict(raw_request)
            requester_id = str(request.get("requesterId") or "").strip()
            request_id = str(request.get("id") or "").strip()
            if requester_id in target_user_ids or request_id in deleted_request_ids:
                continue

            request["suggestedHelperIds"] = _string_list_without(
                request.get("suggestedHelperIds"),
                target_user_ids,
            )
            request["actionLog"] = [
                entry
                for entry in _map_list(request.get("actionLog"))
                if str(entry.get("actorId") or "").strip() not in target_user_ids
            ]
            if str(request.get("acceptedHelperId") or "").strip() in target_user_ids:
                request.pop("acceptedHelperId", None)
                request.pop("contactConsentFromHelper", None)
                request.pop("contactConsentFromRequester", None)
                if request.get("status") in {"accepted", "inProgress"}:
                    request["status"] = "matching"
            surviving_requests.append(request)
        bucket["requests"] = surviving_requests
        updated[str(bucket_key)] = bucket

    raw_shared = updated.get("_shared")
    shared = dict(raw_shared) if isinstance(raw_shared, dict) else {}

    matches = _map_list(shared.get("matches"))
    deleted_match_ids = {
        str(item.get("id") or "").strip()
        for item in matches
        if (
            str(item.get("requesterId") or "").strip() in target_user_ids
            or str(item.get("helperId") or "").strip() in target_user_ids
            or str(item.get("requestId") or "").strip() in deleted_request_ids
        )
    }
    shared["matches"] = [
        item
        for item in matches
        if str(item.get("id") or "").strip() not in deleted_match_ids
    ]

    threads = _map_list(shared.get("threads"))
    deleted_thread_ids = {
        str(item.get("id") or "").strip()
        for item in threads
        if (
            any(
                participant_id in target_user_ids
                for participant_id in _string_list_without(
                    item.get("participantIds"),
                    set(),
                )
            )
            or str(item.get("requestId") or "").strip() in deleted_request_ids
        )
    }
    shared["threads"] = [
        item
        for item in threads
        if str(item.get("id") or "").strip() not in deleted_thread_ids
    ]
    shared["messages"] = [
        item
        for item in _map_list(shared.get("messages"))
        if (
            str(item.get("senderId") or "").strip() not in target_user_ids
            and str(item.get("threadId") or "").strip() not in deleted_thread_ids
        )
    ]
    shared["reviews"] = [
        item
        for item in _map_list(shared.get("reviews"))
        if (
            str(item.get("reviewerId") or "").strip() not in target_user_ids
            and str(item.get("revieweeId") or "").strip() not in target_user_ids
            and str(item.get("matchId") or "").strip() not in deleted_match_ids
        )
    ]

    deleted_target_ids = (
        target_user_ids
        | deleted_request_ids
        | deleted_match_ids
        | deleted_thread_ids
    )
    shared["reports"] = [
        item
        for item in _map_list(shared.get("reports"))
        if (
            str(item.get("reporterId") or "").strip() not in target_user_ids
            and str(item.get("targetId") or "").strip() not in deleted_target_ids
        )
    ]

    surviving_circles: list[dict[str, Any]] = []
    for raw_circle in _map_list(shared.get("supportCircles")):
        circle = dict(raw_circle)
        if any(
            str(circle.get(field) or "").strip() in target_user_ids
            for field in ("ownerId", "creatorId")
        ):
            continue
        circle["memberIds"] = _string_list_without(
            circle.get("memberIds"),
            target_user_ids,
        )
        surviving_circles.append(circle)
    shared["supportCircles"] = surviving_circles
    updated["_shared"] = shared

    raw_meta = updated.get("_meta")
    meta = dict(raw_meta) if isinstance(raw_meta, dict) else {}
    if str(meta.get("currentUserId") or "").strip() in target_user_ids:
        meta.pop("currentUserId", None)
    if _normalize_email(meta.get("currentUserEmail")) == _normalize_email(email):
        meta.pop("currentUserEmail", None)
    updated["_meta"] = meta

    return updated, {
        "userBuckets": len(target_bucket_keys),
        "requests": len(deleted_request_ids),
        "matches": len(deleted_match_ids),
        "threads": len(deleted_thread_ids),
    }


def _sanitize_mirrored_requests(
    raw_document: dict[str, Any],
    *,
    email: str,
    target_user_ids: set[str],
) -> tuple[dict[str, Any], int]:
    normalized_email = _normalize_email(email)
    updated: dict[str, Any] = {}
    deleted_buckets = 0

    for key, raw_value in raw_document.items():
        if key == "lastSyncedAt":
            continue
        if not isinstance(raw_value, dict):
            updated[key] = raw_value
            continue

        requester_email = _normalize_email(raw_value.get("requesterEmail"))
        requester_id = str(raw_value.get("requesterId") or "").strip()
        if (
            (normalized_email and _normalize_email(key) == normalized_email)
            or (normalized_email and requester_email == normalized_email)
            or requester_id in target_user_ids
        ):
            deleted_buckets += 1
            continue
        updated[key] = copy.deepcopy(raw_value)

    updated["lastSyncedAt"] = firestore.SERVER_TIMESTAMP
    return updated, deleted_buckets


def delete_user_data(uid: str, email: str) -> dict[str, int]:
    """Permanently delete the account's Firestore profile and activity data."""
    normalized_uid = str(uid or "").strip()
    if not normalized_uid:
        raise ValueError("A user ID is required for account deletion.")

    normalized_email = _normalize_email(email)
    db = firestore.client()
    global_ref = db.collection(_GLOBAL_APP_STATE_COLLECTION).document(
        _GLOBAL_APP_STATE_DOCUMENT
    )
    global_snapshot = global_ref.get()
    deletion_counts = {
        "userBuckets": 0,
        "requests": 0,
        "matches": 0,
        "threads": 0,
    }
    target_user_ids = {normalized_uid, f"user_{normalized_uid}"}

    if global_snapshot.exists:
        global_document = global_snapshot.to_dict() or {}
        raw_database = global_document.get("database")
        if isinstance(raw_database, dict):
            target_user_ids, _ = _target_identity(
                raw_database,
                uid=normalized_uid,
                email=normalized_email,
            )
            sanitized_database, deletion_counts = (
                sanitize_database_for_account_deletion(
                    raw_database,
                    uid=normalized_uid,
                    email=normalized_email,
                )
            )
            # update() replaces the whole map; set(merge=True) would deep-merge
            # it and keep the removed user bucket and _meta keys.
            global_update: dict[str, Any] = {
                "database": sanitized_database,
                "lastSyncedAt": firestore.SERVER_TIMESTAMP,
            }
            if (
                str(global_document.get("currentUserId") or "").strip()
                in target_user_ids
            ):
                global_update["currentUserId"] = firestore.DELETE_FIELD
            global_ref.update(global_update)

    mirrored_ref = db.collection(_MIRRORED_REQUESTS_COLLECTION).document(
        _MIRRORED_REQUESTS_DOCUMENT
    )
    mirrored_snapshot = mirrored_ref.get()
    mirrored_buckets = 0
    if mirrored_snapshot.exists:
        sanitized_mirrored, mirrored_buckets = _sanitize_mirrored_requests(
            mirrored_snapshot.to_dict() or {},
            email=normalized_email,
            target_user_ids=target_user_ids,
        )
        mirrored_ref.set(sanitized_mirrored)

    tracker_collection = db.collection(_TRACKER_COLLECTION)
    tracker_refs = {
        tracker_collection.document(f"email_{normalized_email}")
        if normalized_email
        else tracker_collection.document(f"uid_{normalized_uid}")
    }
    if normalized_email:
        tracker_refs.update(
            snapshot.reference
            for snapshot in tracker_collection.where(
                "authEmail",
                "==",
                normalized_email,
            ).stream()
        )

    deleted_trackers = 0
    deleted_paths: set[str] = set()
    for tracker_ref in tracker_refs:
        path = str(tracker_ref.path)
        if path in deleted_paths:
            continue
        db.recursive_delete(tracker_ref)
        deleted_paths.add(path)
        deleted_trackers += 1

    return {
        **deletion_counts,
        "mirroredRequestBuckets": mirrored_buckets,
        "trackerDocuments": deleted_trackers,
    }
