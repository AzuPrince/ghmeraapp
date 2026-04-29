from __future__ import annotations

import copy
from typing import Any

from .errors import WorkflowError
from .matching import WorkflowMatchingMixin
from .operations import WorkflowOperationsMixin
from .utils import _as_map, _as_map_list


class WorkflowState(WorkflowOperationsMixin, WorkflowMatchingMixin):
    def __init__(self, raw_database: dict[str, Any], current_user_id: str):
        self.meta = _as_map(raw_database.get('_meta'))
        self.shared = _as_map(raw_database.get('_shared'))
        self.current_user_id = current_user_id or str(
            self.meta.get('currentUserId', '')
        ).strip()
        self.current_user_email = str(self.meta.get('currentUserEmail', '')).strip()
        self._bucket_key_by_user_id: dict[str, str] = {}

        self.users: list[dict[str, Any]] = []
        self.requests: list[dict[str, Any]] = []
        self.notifications: list[dict[str, Any]] = []
        self.mood_check_ins: list[dict[str, Any]] = []
        self.matches = _as_map_list(self.shared.get('matches'))
        self.threads = _as_map_list(self.shared.get('threads'))
        self.messages = _as_map_list(self.shared.get('messages'))
        self.reviews = _as_map_list(self.shared.get('reviews'))
        self.reports = _as_map_list(self.shared.get('reports'))
        self.support_circles = _as_map_list(self.shared.get('supportCircles'))

        for bucket_key, raw_bucket in raw_database.items():
            if str(bucket_key).startswith('_'):
                continue

            bucket = _as_map(raw_bucket)
            user = _as_map(bucket.get('user'))
            user_id = str(user.get('id', '')).strip()
            if not user_id:
                continue

            self._bucket_key_by_user_id[user_id] = str(bucket_key)
            self.users.append(user)
            self.requests.extend(_as_map_list(bucket.get('requests')))
            self.notifications.extend(_as_map_list(bucket.get('notifications')))
            self.mood_check_ins.extend(_as_map_list(bucket.get('moodCheckIns')))

        if not self.current_user_id and self.users:
            self.current_user_id = str(self.users[0].get('id', '')).strip()
        if not self.current_user_id:
            raise WorkflowError('Current user could not be resolved from app state.')

        self.meta['currentUserId'] = self.current_user_id

    def to_raw_database(self) -> dict[str, Any]:
        meta = copy.deepcopy(self.meta)
        meta['currentUserId'] = self.current_user_id
        if self.current_user_email:
            meta['currentUserEmail'] = self.current_user_email

        shared = copy.deepcopy(self.shared)
        shared['matches'] = copy.deepcopy(self.matches)
        shared['threads'] = copy.deepcopy(self.threads)
        shared['messages'] = copy.deepcopy(self.messages)
        shared['reviews'] = copy.deepcopy(self.reviews)
        shared['reports'] = copy.deepcopy(self.reports)
        shared['supportCircles'] = copy.deepcopy(self.support_circles)

        raw_database: dict[str, Any] = {
            '_meta': meta,
            '_shared': shared,
        }

        for user in self.users:
            user_id = str(user.get('id', '')).strip()
            if not user_id:
                continue

            bucket_key = self._bucket_key_by_user_id.get(
                user_id
            ) or self._bucket_key_for_user(user)
            raw_database[bucket_key] = {
                'user': copy.deepcopy(user),
                'requests': copy.deepcopy(
                    [
                        request
                        for request in self.requests
                        if request.get('requesterId') == user_id
                    ]
                ),
                'notifications': copy.deepcopy(
                    [
                        notification
                        for notification in self.notifications
                        if notification.get('userId') == user_id
                    ]
                ),
                'moodCheckIns': copy.deepcopy(
                    [
                        check_in
                        for check_in in self.mood_check_ins
                        if check_in.get('userId') == user_id
                    ]
                ),
            }

        return raw_database

    def current_user(self) -> dict[str, Any]:
        user = self.find_user(self.current_user_id)
        if user is None:
            raise WorkflowError('Current user was not found in app state.')
        return user

    def find_user(self, user_id: str) -> dict[str, Any] | None:
        for user in self.users:
            if user.get('id') == user_id:
                return user
        return None

    def find_request(self, request_id: str) -> dict[str, Any] | None:
        for request in self.requests:
            if request.get('id') == request_id:
                return request
        return None

    def find_thread(self, thread_id: str) -> dict[str, Any] | None:
        for thread in self.threads:
            if thread.get('id') == thread_id:
                return thread
        return None

    def accepted_match_for_request(
        self, request: dict[str, Any]
    ) -> dict[str, Any] | None:
        helper_id = str(request.get('acceptedHelperId') or '').strip()
        if not helper_id:
            return None

        for match in self.matches:
            if match.get('requestId') == request.get('id') and match.get('helperId') == helper_id:
                return match
        return None

    def other_participant_for_request(
        self, request: dict[str, Any]
    ) -> dict[str, Any] | None:
        if request.get('requesterId') == self.current_user_id:
            helper_id = str(request.get('acceptedHelperId') or '').strip()
            if not helper_id:
                return None
            return self.find_user(helper_id)

        return self.find_user(str(request.get('requesterId', '')).strip())

    def replace_request(self, updated_request: dict[str, Any]) -> None:
        request_id = updated_request.get('id')
        for index, request in enumerate(self.requests):
            if request.get('id') == request_id:
                self.requests[index] = updated_request
                return
        self.requests.insert(0, updated_request)

    def replace_user(self, updated_user: dict[str, Any]) -> None:
        user_id = updated_user.get('id')
        for index, user in enumerate(self.users):
            if user.get('id') == user_id:
                self.users[index] = updated_user
                return
        self.users.insert(0, updated_user)

    def next_id(self, prefix: str, items: list[dict[str, Any]]) -> str:
        existing_ids = {str(item.get('id', '')) for item in items}
        candidate = len(items) + 1
        while f'{prefix}_{candidate}' in existing_ids:
            candidate += 1
        return f'{prefix}_{candidate}'

    def _bucket_key_for_user(self, user: dict[str, Any]) -> str:
        email = str(user.get('email', '')).strip().lower()
        if email:
            return email
        return str(user.get('id', 'user')).strip() or 'user'