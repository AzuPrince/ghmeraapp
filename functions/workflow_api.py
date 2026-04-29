from __future__ import annotations

import copy
from datetime import datetime, timezone
from typing import Any

RECIPROCITY_FLOOR = -5
REQUESTER_SUGGESTION_LIMIT = 3
HELPER_BROADCAST_LIMIT: int | None = None
MINUTES_PER_DAY = 24 * 60
BLOCKED_RESTRICTION_STATUSES = {'suspended', 'banned'}
HIGH_RISK_CATEGORIES = {'childcare', 'elderlySupport', 'emergencySupport'}
CATEGORY_LABELS = {
    'errands': 'Errands',
    'transportation': 'Transportation',
    'studyHelp': 'Study help',
    'technicalSupport': 'Technical support',
    'emotionalSupport': 'Emotional support',
    'prayerSupport': 'Prayer / spiritual support',
    'childcare': 'Childcare',
    'elderlySupport': 'Elderly support',
    'movingHelp': 'Moving help',
    'informationAdvice': 'Information / advice',
    'foodSupport': 'Food support',
    'emergencySupport': 'Emergency non-medical support',
}
RELATED_CATEGORIES = {
    'errands': {'transportation', 'foodSupport', 'movingHelp'},
    'transportation': {'errands', 'elderlySupport', 'foodSupport'},
    'studyHelp': {'technicalSupport', 'informationAdvice'},
    'technicalSupport': {'studyHelp', 'informationAdvice'},
    'emotionalSupport': {'prayerSupport', 'informationAdvice'},
    'prayerSupport': {'emotionalSupport'},
    'childcare': {'emotionalSupport', 'foodSupport'},
    'elderlySupport': {'transportation', 'errands', 'emotionalSupport'},
    'movingHelp': {'errands', 'transportation'},
    'informationAdvice': {
        'studyHelp',
        'technicalSupport',
        'emotionalSupport',
    },
    'foodSupport': {'errands', 'transportation'},
    'emergencySupport': {'transportation', 'elderlySupport', 'errands'},
}


class WorkflowError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def apply_workflow_operation(
    body: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any] | None]:
    if not isinstance(body, dict):
        raise WorkflowError('Invalid workflow payload.')

    operation = str(body.get('operation', '')).strip()
    raw_database = _as_map(body.get('database'))
    current_user_id = str(body.get('currentUserId', '')).strip()
    payload = _as_map(body.get('payload'))

    if not operation:
        raise WorkflowError('Missing workflow operation.')
    if not raw_database:
        raise WorkflowError('Missing app-state database payload.')

    state = WorkflowState(raw_database=raw_database, current_user_id=current_user_id)
    handler_name = {
        'create_help_request': 'create_help_request',
        'update_help_request': 'update_help_request',
        'delete_help_request': 'delete_help_request',
        'cancel_accepted_request': 'cancel_accepted_request',
        'request_helper_for_my_request': 'request_helper_for_my_request',
        'volunteer_for_help_request': 'volunteer_for_help_request',
        'start_request_work': 'start_request_work',
        'confirm_request_completion': 'confirm_request_completion',
        'submit_review_for_request': 'submit_review_for_request',
        'submit_participant_safety_report': 'submit_participant_safety_report',
        'report_user_account': 'report_user_account',
        'send_message': 'send_message',
    }.get(operation)

    if handler_name is None:
        raise WorkflowError(f'Unsupported workflow operation: {operation}')

    handler = getattr(state, handler_name)
    result = handler(payload)
    return state.to_raw_database(), result


class WorkflowState:
    def __init__(self, raw_database: dict[str, Any], current_user_id: str):
        self.meta = _as_map(raw_database.get('_meta'))
        self.shared = _as_map(raw_database.get('_shared'))
        self.current_user_id = current_user_id or str(self.meta.get('currentUserId', '')).strip()
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

            bucket_key = self._bucket_key_by_user_id.get(user_id) or self._bucket_key_for_user(user)
            raw_database[bucket_key] = {
                'user': copy.deepcopy(user),
                'requests': copy.deepcopy(
                    [request for request in self.requests if request.get('requesterId') == user_id]
                ),
                'notifications': copy.deepcopy(
                    [notification for notification in self.notifications if notification.get('userId') == user_id]
                ),
                'moodCheckIns': copy.deepcopy(
                    [check_in for check_in in self.mood_check_ins if check_in.get('userId') == user_id]
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

    def create_help_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        current_user = self.current_user()
        category = str(payload.get('category', '')).strip()
        emergency_override = bool(payload.get('emergencyOverride', False))
        exempt_request = emergency_override or category == 'emergencySupport'
        if not self.can_create_request() and not exempt_request:
            raise WorkflowError(
                'This account is on a reciprocity hold and cannot create a standard request right now.',
                status_code=409,
            )

        now = _now_iso()
        request_id = self.next_id('request', self.requests)
        attachment_label = str(payload.get('attachmentLabel', '')).strip() or None
        draft_request = {
            'id': request_id,
            'requesterId': self.current_user_id,
            'title': str(payload.get('title', '')).strip(),
            'description': str(payload.get('description', '')).strip(),
            'category': category,
            'urgency': str(payload.get('urgency', 'medium')).strip() or 'medium',
            'location': str(payload.get('location', '')).strip(),
            'preferredTime': str(payload.get('preferredTime', '')).strip(),
            'visibility': str(payload.get('visibility', 'restricted')).strip() or 'restricted',
            'attachmentLabel': attachment_label,
            'status': 'open',
            'createdAt': now,
            'acceptedHelperId': None,
            'emotionalSupportMode': bool(payload.get('emotionalSupportMode', False)),
            'requiresHomeVisit': bool(payload.get('requiresHomeVisit', False)),
            'lateNightSupport': bool(payload.get('lateNightSupport', False)),
            'moneyRelated': bool(payload.get('moneyRelated', False)),
            'emergencyOverride': emergency_override,
            'requesterCompletionConfirmed': False,
            'helperCompletionConfirmed': False,
            'contactConsentFromRequester': False,
            'contactConsentFromHelper': False,
            'safetyCheckInRequired': False,
            'suggestedHelperIds': [],
            'actionLog': [
                {
                    'actorId': self.current_user_id,
                    'action': 'Request created',
                    'createdAt': now,
                }
            ],
        }
        draft_request['safetyCheckInRequired'] = self.is_high_risk_request(draft_request)

        helper_candidates = self.rank_helpers(
            request=draft_request,
            requester=current_user,
            users=self.users,
            limit=HELPER_BROADCAST_LIMIT,
        )

        request = copy.deepcopy(draft_request)
        request['status'] = 'matching' if helper_candidates else 'open'
        request['suggestedHelperIds'] = [
            candidate['helper']['id']
            for candidate in helper_candidates[:REQUESTER_SUGGESTION_LIMIT]
        ]
        if helper_candidates:
            request['actionLog'].append(
                {
                    'actorId': self.current_user_id,
                    'action': 'Matching engine ranked '
                    f'{len(helper_candidates)} eligible helpers and shared the top '
                    f'{min(len(helper_candidates), REQUESTER_SUGGESTION_LIMIT)} suggestions',
                    'createdAt': now,
                }
            )

        self.requests.insert(0, request)
        self.sync_suggested_matches_for_request(request, helper_candidates)
        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': self.current_user_id,
                'type': 'matchFound' if helper_candidates else 'adminUpdate',
                'title': 'Helpers found for your new request'
                if helper_candidates
                else 'Request submitted for broadcast',
                'message': 'The matching engine found '
                f'{len(helper_candidates)} helper candidates right away.'
                if helper_candidates
                else 'Your request is live and will be broadcast to eligible helpers.',
                'createdAt': now,
                'isRead': False,
            },
        )
        return {'requestId': request_id}

    def update_help_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None or request.get('requesterId') != self.current_user_id:
            raise WorkflowError('This request could not be updated.', status_code=404)

        now = _now_iso()
        attachment_label = str(payload.get('attachmentLabel', '')).strip() or None
        updated_request = copy.deepcopy(request)
        updated_request.update(
            {
                'title': str(payload.get('title', '')).strip(),
                'description': str(payload.get('description', '')).strip(),
                'category': str(payload.get('category', updated_request.get('category', ''))).strip(),
                'urgency': str(payload.get('urgency', updated_request.get('urgency', 'medium'))).strip(),
                'location': str(payload.get('location', '')).strip(),
                'preferredTime': str(payload.get('preferredTime', '')).strip(),
                'visibility': str(payload.get('visibility', updated_request.get('visibility', 'restricted'))).strip(),
                'attachmentLabel': attachment_label,
                'emotionalSupportMode': bool(payload.get('emotionalSupportMode', False)),
                'requiresHomeVisit': bool(payload.get('requiresHomeVisit', False)),
                'lateNightSupport': bool(payload.get('lateNightSupport', False)),
                'moneyRelated': bool(payload.get('moneyRelated', False)),
                'emergencyOverride': bool(payload.get('emergencyOverride', False)),
            }
        )
        updated_request['safetyCheckInRequired'] = self.is_high_risk_request(updated_request)
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Requester updated request details',
                'createdAt': now,
            }
        )

        if not updated_request.get('acceptedHelperId'):
            helper_candidates = self.rank_helpers(
                request=updated_request,
                requester=self.current_user(),
                users=self.users,
                limit=HELPER_BROADCAST_LIMIT,
            )
            updated_request['status'] = 'matching' if helper_candidates else 'open'
            updated_request['suggestedHelperIds'] = [
                candidate['helper']['id']
                for candidate in helper_candidates[:REQUESTER_SUGGESTION_LIMIT]
            ]
            if helper_candidates:
                updated_request['actionLog'].append(
                    {
                        'actorId': self.current_user_id,
                        'action': 'Matching engine refreshed '
                        f'{len(helper_candidates)} eligible helpers and the top '
                        f'{min(len(helper_candidates), REQUESTER_SUGGESTION_LIMIT)} suggestions',
                        'createdAt': now,
                    }
                )
            self.sync_suggested_matches_for_request(updated_request, helper_candidates)

        self.replace_request(updated_request)
        return {'requestId': request_id}

    def delete_help_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request could not be deleted.', status_code=404)
        if request.get('requesterId') != self.current_user_id or request.get('acceptedHelperId'):
            raise WorkflowError('Only unmatched requests can be deleted.', status_code=409)

        removed_match_ids = {
            str(match.get('id', ''))
            for match in self.matches
            if match.get('requestId') == request_id
        }
        removed_thread_ids = {
            str(thread.get('id', ''))
            for thread in self.threads
            if thread.get('requestId') == request_id
        }

        self.requests = [candidate for candidate in self.requests if candidate.get('id') != request_id]
        self.matches = [match for match in self.matches if match.get('requestId') != request_id]
        self.threads = [thread for thread in self.threads if thread.get('requestId') != request_id]
        self.messages = [
            message for message in self.messages if message.get('threadId') not in removed_thread_ids
        ]
        self.reviews = [
            review for review in self.reviews if review.get('matchId') not in removed_match_ids
        ]
        self.reports = [
            report
            for report in self.reports
            if not (
                report.get('targetType') == 'request'
                and report.get('targetId') == request_id
            )
        ]

        current_user = self.current_user()
        hidden_request_ids = [
            item
            for item in _copy_string_list(current_user.get('hiddenRequestIds'))
            if item != request_id
        ]
        updated_user = copy.deepcopy(current_user)
        updated_user['hiddenRequestIds'] = hidden_request_ids
        self.replace_user(updated_user)

        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': self.current_user_id,
                'type': 'adminUpdate',
                'title': 'Request deleted',
                'message': f"{request.get('title', 'This request')} was removed from your requests.",
                'createdAt': _now_iso(),
                'isRead': False,
            },
        )
        return {'deleted': True}

    def cancel_accepted_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request could not be canceled.', status_code=404)
        if (
            request.get('requesterId') != self.current_user_id
            or not request.get('acceptedHelperId')
            or request.get('status') in {'completed', 'canceled'}
        ):
            raise WorkflowError('This request could not be canceled.', status_code=409)

        now = _now_iso()
        updated_request = copy.deepcopy(request)
        updated_request['status'] = 'canceled'
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Requester canceled the accepted help request',
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        for index, match in enumerate(self.matches):
            if match.get('requestId') != request_id:
                continue
            if match.get('status') in {'completed', 'disputed'}:
                continue
            updated_match = copy.deepcopy(match)
            updated_match['status'] = 'declined'
            self.matches[index] = updated_match

        helper_id = str(request.get('acceptedHelperId', '')).strip()
        current_user = self.current_user()
        if helper_id:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': helper_id,
                    'type': 'adminUpdate',
                    'title': 'Request canceled',
                    'message': f"{current_user.get('fullName', 'A requester')} canceled {request.get('title', 'the request')}. The request is now closed.",
                    'createdAt': now,
                    'isRead': False,
                },
            )

        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': self.current_user_id,
                'type': 'adminUpdate',
                'title': 'Request canceled',
                'message': f"{request.get('title', 'This request')} was canceled and removed from active help.",
                'createdAt': now,
                'isRead': False,
            },
        )
        return {'canceled': True}

    def request_helper_for_my_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        helper_id = str(payload.get('helperId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request was not found.', status_code=404)
        if request.get('requesterId') != self.current_user_id or self.is_closed_request(request):
            raise WorkflowError('This helper could not be requested for that request.', status_code=409)
        if request.get('acceptedHelperId') == helper_id:
            return {'matched': True, 'requestId': request_id, 'helperId': helper_id}
        if request.get('acceptedHelperId') and request.get('acceptedHelperId') != helper_id:
            raise WorkflowError('This request already has a different helper assigned.', status_code=409)

        helper = self.find_user(helper_id)
        if helper is None:
            raise WorkflowError('The selected helper was not found.', status_code=404)

        match_candidate = self.score_helper(
            request=request,
            requester=self.current_user(),
            helper=helper,
            allow_urgency_fallback=False,
        )
        if match_candidate is None:
            raise WorkflowError('The selected helper no longer qualifies for this request.', status_code=409)

        self.confirm_match(
            request=request,
            helper=helper,
            action_actor_id=self.current_user_id,
            action_label='Requester selected '
            f"{helper.get('fullName', 'a helper')} from potential helpers and matching was confirmed",
            opener_message='Hi '
            f"{_first_name(helper.get('fullName'))}, I requested a match for this help request.",
            match_candidate=match_candidate,
        )
        return {'matched': True, 'requestId': request_id, 'helperId': helper_id}

    def volunteer_for_help_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request was not found.', status_code=404)
        if request.get('requesterId') == self.current_user_id or self.is_closed_request(request):
            raise WorkflowError('This request is no longer available for matching.', status_code=409)
        if request.get('acceptedHelperId') == self.current_user_id:
            return {'matched': True, 'requestId': request_id, 'helperId': self.current_user_id}
        if request.get('acceptedHelperId') and request.get('acceptedHelperId') != self.current_user_id:
            raise WorkflowError('This request is no longer available for matching.', status_code=409)

        helper = self.current_user()
        requester = self.find_user(str(request.get('requesterId', '')).strip())
        if requester is None:
            raise WorkflowError('The requester could not be resolved.', status_code=404)

        match_candidate = self.score_helper(
            request=request,
            requester=requester,
            helper=helper,
            allow_urgency_fallback=False,
        )
        if match_candidate is None:
            raise WorkflowError('This request is no longer available for matching.', status_code=409)

        self.confirm_match(
            request=request,
            helper=helper,
            action_actor_id=self.current_user_id,
            action_label='Helper confirmed availability and accepted the request',
            opener_message='I am available and willing to help with this request. Let us coordinate here.',
            match_candidate=match_candidate,
        )
        return {'matched': True, 'requestId': request_id, 'helperId': self.current_user_id}

    def start_request_work(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request could not be moved to in progress.', status_code=404)
        if not self.can_current_user_start_request(request):
            raise WorkflowError('This request could not be moved to in progress.', status_code=409)

        now = _now_iso()
        updated_request = copy.deepcopy(request)
        updated_request['status'] = 'inProgress'
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Requester marked the help session as in progress'
                if request.get('requesterId') == self.current_user_id
                else 'Helper marked the help session as in progress',
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        accepted_match = self.accepted_match_for_request(request)
        if accepted_match is not None:
            accepted_match['status'] = 'inProgress'

        other_participant = self.other_participant_for_request(request)
        if other_participant is not None:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': other_participant.get('id'),
                    'type': 'adminUpdate',
                    'title': 'Help is now in progress',
                    'message': f"{self.current_user().get('fullName', 'A participant')} marked {request.get('title', 'this request')} as in progress.",
                    'createdAt': now,
                    'isRead': False,
                },
            )
        return {'started': True, 'requestId': request_id}

    def confirm_request_completion(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('Completion could not be updated.', status_code=404)
        if not self.can_current_user_confirm_request_completion(request):
            raise WorkflowError('Completion could not be updated.', status_code=409)

        now = _now_iso()
        requester_confirmed = (
            True if request.get('requesterId') == self.current_user_id else bool(request.get('requesterCompletionConfirmed', False))
        )
        helper_confirmed = (
            True if request.get('acceptedHelperId') == self.current_user_id else bool(request.get('helperCompletionConfirmed', False))
        )
        fully_completed = requester_confirmed and helper_confirmed

        updated_request = copy.deepcopy(request)
        updated_request['status'] = 'completed' if fully_completed else 'inProgress'
        updated_request['requesterCompletionConfirmed'] = requester_confirmed
        updated_request['helperCompletionConfirmed'] = helper_confirmed
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Completion was confirmed and the request was closed'
                if fully_completed
                else 'Requester confirmed they received the help'
                if request.get('requesterId') == self.current_user_id
                else 'Helper confirmed they completed the help',
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        accepted_match = self.accepted_match_for_request(request)
        if accepted_match is not None:
            accepted_match['status'] = 'completed' if fully_completed else 'inProgress'
            accepted_match['completedAt'] = now if fully_completed else accepted_match.get('completedAt')

        other_participant = self.other_participant_for_request(request)
        if other_participant is not None:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': other_participant.get('id'),
                    'type': 'helpCompleted' if fully_completed else 'adminUpdate',
                    'title': 'Help marked complete' if fully_completed else 'Completion confirmation pending',
                    'message': f"{self.current_user().get('fullName', 'A participant')} confirmed {request.get('title', 'the request')} is complete. You can now leave a review."
                    if fully_completed
                    else f"{self.current_user().get('fullName', 'A participant')} marked {request.get('title', 'the request')} as complete. Confirm when you are done so the request can close.",
                    'createdAt': now,
                    'isRead': False,
                },
            )

        helper_id = str(request.get('acceptedHelperId') or '').strip()
        if fully_completed and helper_id:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': request.get('requesterId'),
                    'type': 'helpCompleted',
                    'title': 'Request completed',
                    'message': f"{request.get('title', 'This request')} was closed after both participants confirmed completion.",
                    'createdAt': now,
                    'isRead': False,
                },
            )
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': helper_id,
                    'type': 'helpCompleted',
                    'title': 'Help completed',
                    'message': f"{request.get('title', 'This request')} was closed after both participants confirmed completion.",
                    'createdAt': now,
                    'isRead': False,
                },
            )
        return {'confirmed': True, 'requestId': request_id}

    def submit_review_for_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('Review could not be submitted.', status_code=404)
        if not self.can_current_user_submit_review_for_request(request):
            raise WorkflowError('Review could not be submitted.', status_code=409)

        accepted_match = self.accepted_match_for_request(request)
        reviewee = self.other_participant_for_request(request)
        if accepted_match is None or reviewee is None:
            raise WorkflowError('Review could not be submitted.', status_code=409)

        now = _now_iso()
        feedback = str(payload.get('feedback', '')).strip() or 'No written feedback provided.'
        review_id = self.next_id('review', self.reviews)
        review = {
            'id': review_id,
            'matchId': accepted_match.get('id'),
            'reviewerId': self.current_user_id,
            'revieweeId': reviewee.get('id'),
            'helpfulness': _clamp_int(payload.get('helpfulness'), 1, 5),
            'respectfulness': _clamp_int(payload.get('respectfulness'), 1, 5),
            'safety': _clamp_int(payload.get('safety'), 1, 5),
            'reliability': _clamp_int(payload.get('reliability'), 1, 5),
            'accuracy': _clamp_int(payload.get('accuracy'), 1, 5),
            'feedback': feedback,
            'createdAt': now,
            'flaggedSuspicious': _clamp_int(payload.get('safety'), 1, 5) <= 2
            or _clamp_int(payload.get('respectfulness'), 1, 5) <= 2
            or _clamp_int(payload.get('reliability'), 1, 5) <= 2,
        }
        self.reviews.insert(0, review)

        updated_request = copy.deepcopy(request)
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Submitted a post-help review',
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)
        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': reviewee.get('id'),
                'type': 'adminUpdate',
                'title': 'New review received',
                'message': f"{self.current_user().get('fullName', 'A participant')} left a review after {request.get('title', 'the request')}.",
                'createdAt': now,
                'isRead': False,
            },
        )
        return {'reviewId': review_id}

    def submit_participant_safety_report(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('Safety report could not be submitted.', status_code=404)
        reported_user = self.other_participant_for_request(request)
        reason = str(payload.get('reason', '')).strip()
        if reported_user is None or not reason:
            raise WorkflowError('Safety report could not be submitted.', status_code=409)

        now = _now_iso()
        details = str(payload.get('details', '')).trim() if hasattr(str(payload.get('details', '')), 'trim') else str(payload.get('details', '')).strip()
        report_id = self.next_id('report', self.reports)
        report = {
            'id': report_id,
            'reporterId': self.current_user_id,
            'targetType': 'user',
            'targetId': reported_user.get('id'),
            'reason': reason,
            'details': f"Request {request.get('title', 'the request')}: {details}" if details else f"Reported from request {request.get('title', 'the request')}.",
            'status': 'open',
            'createdAt': now,
            'assignedModeratorId': None,
        }
        self.reports.insert(0, report)

        updated_request = copy.deepcopy(request)
        updated_request['safetyCheckInRequired'] = True
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': self.current_user_id,
                'action': 'Reported '
                f"{reported_user.get('fullName', 'this user')} to moderators for a safety concern",
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        for index, thread in enumerate(self.threads):
            if thread.get('requestId') != request_id:
                continue
            updated_thread = copy.deepcopy(thread)
            updated_thread['flaggedSafetyConcern'] = True
            self.threads[index] = updated_thread

        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': self.current_user_id,
                'type': 'safetyAlert',
                'title': 'Safety report submitted',
                'message': f"Your report about {reported_user.get('fullName', 'this user')} was sent to moderators.",
                'createdAt': now,
                'isRead': False,
            },
        )
        return {'reportId': report_id}

    def report_user_account(self, payload: dict[str, Any]) -> dict[str, Any]:
        user_id = str(payload.get('userId', '')).strip()
        reason = str(payload.get('reason', '')).strip()
        request_id = str(payload.get('requestId', '')).strip()
        if not reason or user_id == self.current_user_id:
            raise WorkflowError('Account report could not be submitted.', status_code=409)

        reported_user = self.find_user(user_id)
        if reported_user is None:
            raise WorkflowError('Account report could not be submitted.', status_code=404)

        request = self.find_request(request_id) if request_id else None
        now = _now_iso()
        details = str(payload.get('details', '')).strip()
        report_id = self.next_id('report', self.reports)
        if not details:
            if request is None:
                details = 'Reported from the account action menu.'
            else:
                details = f"Reported from request {request.get('title', 'the request')}."
        elif request is not None:
            details = f"Request {request.get('title', 'the request')}: {details}"

        report = {
            'id': report_id,
            'reporterId': self.current_user_id,
            'targetType': 'user',
            'targetId': reported_user.get('id'),
            'reason': reason,
            'details': details,
            'status': 'open',
            'createdAt': now,
            'assignedModeratorId': None,
        }
        self.reports.insert(0, report)

        if request is not None:
            updated_request = copy.deepcopy(request)
            updated_request['safetyCheckInRequired'] = True
            updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
            updated_request['actionLog'].append(
                {
                    'actorId': self.current_user_id,
                    'action': 'Reported '
                    f"{reported_user.get('fullName', 'this user')} from the request action menu",
                    'createdAt': now,
                }
            )
            self.replace_request(updated_request)

        self.notifications.insert(
            0,
            {
                'id': self.next_id('notification', self.notifications),
                'userId': self.current_user_id,
                'type': 'safetyAlert',
                'title': 'Account report submitted',
                'message': f"Your report about {reported_user.get('fullName', 'this user')} was sent to moderators.",
                'createdAt': now,
                'isRead': False,
            },
        )
        return {'reportId': report_id}

    def send_message(self, payload: dict[str, Any]) -> dict[str, Any]:
        thread_id = str(payload.get('threadId', '')).strip()
        content = str(payload.get('content', '')).strip()
        if not content:
            raise WorkflowError('Message content is empty.', status_code=409)

        thread = self.find_thread(thread_id)
        if thread is None:
            raise WorkflowError('Message thread was not found.', status_code=404)
        participant_ids = _copy_string_list(thread.get('participantIds'))
        if self.current_user_id not in participant_ids:
            raise WorkflowError('You are not allowed to send a message to this thread.', status_code=403)

        now = _now_iso()
        message_id = self.next_id('message', self.messages)
        self.messages.append(
            {
                'id': message_id,
                'threadId': thread_id,
                'senderId': self.current_user_id,
                'content': content,
                'createdAt': now,
                'flaggedSafetyConcern': False,
            }
        )
        thread['lastMessageAt'] = now
        return {'messageId': message_id}

    def can_create_request(self) -> bool:
        current_user = self.current_user()
        if self.can_bypass_reciprocity(current_user):
            return True
        return self.help_balance(current_user) >= RECIPROCITY_FLOOR

    def can_bypass_reciprocity(self, user: dict[str, Any]) -> bool:
        return bool(user.get('vulnerableUser')) or bool(user.get('hasDisability')) or bool(user.get('adminOverrideReciprocity'))

    def help_balance(self, user: dict[str, Any]) -> int:
        return _read_int(user.get('helpGivenCount')) - _read_int(user.get('helpReceivedCount'))

    def is_current_user_participant_for_request(self, request: dict[str, Any]) -> bool:
        return request.get('requesterId') == self.current_user_id or request.get('acceptedHelperId') == self.current_user_id

    def has_current_user_confirmed_request_completion(self, request: dict[str, Any]) -> bool:
        if request.get('requesterId') == self.current_user_id:
            return bool(request.get('requesterCompletionConfirmed', False))
        if request.get('acceptedHelperId') == self.current_user_id:
            return bool(request.get('helperCompletionConfirmed', False))
        return False

    def can_current_user_start_request(self, request: dict[str, Any]) -> bool:
        return (
            self.is_current_user_participant_for_request(request)
            and bool(request.get('acceptedHelperId'))
            and request.get('status') == 'accepted'
        )

    def can_current_user_confirm_request_completion(self, request: dict[str, Any]) -> bool:
        return (
            self.is_current_user_participant_for_request(request)
            and bool(request.get('acceptedHelperId'))
            and request.get('status') in {'accepted', 'inProgress'}
            and not self.has_current_user_confirmed_request_completion(request)
        )

    def has_current_user_submitted_review_for_request(self, request: dict[str, Any]) -> bool:
        accepted_match = self.accepted_match_for_request(request)
        if accepted_match is None:
            return False
        for review in self.reviews:
            if review.get('matchId') == accepted_match.get('id') and review.get('reviewerId') == self.current_user_id:
                return True
        return False

    def can_current_user_submit_review_for_request(self, request: dict[str, Any]) -> bool:
        return (
            self.is_current_user_participant_for_request(request)
            and request.get('status') == 'completed'
            and bool(request.get('acceptedHelperId'))
            and not self.has_current_user_submitted_review_for_request(request)
        )

    def is_closed_request(self, request: dict[str, Any]) -> bool:
        return request.get('status') in {'completed', 'canceled'}

    def is_high_risk_request(self, request: dict[str, Any]) -> bool:
        return (
            str(request.get('category', '')).strip() in HIGH_RISK_CATEGORIES
            or bool(request.get('requiresHomeVisit', False))
            or bool(request.get('lateNightSupport', False))
            or bool(request.get('moneyRelated', False))
        )

    def sync_suggested_matches_for_request(
        self,
        request: dict[str, Any],
        candidates: list[dict[str, Any]],
    ) -> None:
        request_id = request.get('id')
        self.matches = [
            match
            for match in self.matches
            if not (
                match.get('requestId') == request_id
                and match.get('status') not in {'accepted', 'inProgress', 'completed'}
            )
        ]

        for index, candidate in reversed(list(enumerate(candidates))):
            self.matches.insert(
                0,
                {
                    'id': self.next_id('match', self.matches),
                    'requesterId': request.get('requesterId'),
                    'helperId': candidate['helper'].get('id'),
                    'requestId': request_id,
                    'status': 'broadcast'
                    if candidate.get('isFallbackCandidate') or index >= REQUESTER_SUGGESTION_LIMIT
                    else 'suggested',
                    'score': candidate.get('score', 0),
                    'reasons': copy.deepcopy(candidate.get('reasons', [])),
                    'acceptedAt': None,
                    'completedAt': None,
                },
            )

    def confirm_match(
        self,
        request: dict[str, Any],
        helper: dict[str, Any],
        action_actor_id: str,
        action_label: str,
        opener_message: str,
        match_candidate: dict[str, Any],
    ) -> None:
        now = _now_iso()
        request_id = request.get('id')
        helper_id = helper.get('id')

        existing_match = None
        for match in self.matches:
            if match.get('requestId') == request_id and match.get('helperId') == helper_id:
                existing_match = match
                break

        if existing_match is None:
            self.matches.insert(
                0,
                {
                    'id': self.next_id('match', self.matches),
                    'requesterId': request.get('requesterId'),
                    'helperId': helper_id,
                    'requestId': request_id,
                    'status': 'accepted',
                    'score': match_candidate.get('score', 0),
                    'reasons': copy.deepcopy(match_candidate.get('reasons', [])),
                    'acceptedAt': now,
                    'completedAt': None,
                },
            )
        else:
            existing_match['status'] = 'accepted'
            existing_match['acceptedAt'] = now
            existing_match['score'] = match_candidate.get('score', 0)
            existing_match['reasons'] = copy.deepcopy(match_candidate.get('reasons', []))

        for match in self.matches:
            if match.get('requestId') != request_id or match.get('helperId') == helper_id:
                continue
            if match.get('status') in {'accepted', 'inProgress', 'completed'}:
                continue
            match['status'] = 'declined'

        updated_request = copy.deepcopy(request)
        suggested_helper_ids = set(_copy_string_list(updated_request.get('suggestedHelperIds')))
        suggested_helper_ids.add(str(helper_id))
        updated_request['status'] = 'accepted'
        updated_request['acceptedHelperId'] = helper_id
        updated_request['safetyCheckInRequired'] = self.is_high_risk_request(updated_request)
        updated_request['suggestedHelperIds'] = list(suggested_helper_ids)
        updated_request['actionLog'] = copy.deepcopy(updated_request.get('actionLog', []))
        updated_request['actionLog'].append(
            {
                'actorId': action_actor_id,
                'action': action_label,
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        chat_thread = self.ensure_protected_chat_thread(request=updated_request, helper_id=str(helper_id), now=now)
        self.messages.append(
            {
                'id': self.next_id('message', self.messages),
                'threadId': chat_thread.get('id'),
                'senderId': action_actor_id,
                'content': opener_message,
                'createdAt': now,
                'flaggedSafetyConcern': False,
            }
        )

        requester = self.find_user(str(request.get('requesterId', '')).strip())
        if requester is not None:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': requester.get('id'),
                    'type': 'requestAccepted',
                    'title': f"Match confirmed for {request.get('title', 'this request')}",
                    'message': f"You are matched with {helper.get('fullName', 'a helper')}. Continue inside protected chat.",
                    'createdAt': now,
                    'isRead': False,
                },
            )
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': helper_id,
                    'type': 'matchFound',
                    'title': f"You were matched with {requester.get('fullName', 'a requester')}",
                    'message': f"A help match was confirmed for {request.get('title', 'this request')}. Continue inside protected chat.",
                    'createdAt': now,
                    'isRead': False,
                },
            )

    def ensure_protected_chat_thread(
        self,
        request: dict[str, Any],
        helper_id: str,
        now: str,
    ) -> dict[str, Any]:
        requester_id = str(request.get('requesterId', '')).strip()
        for index, thread in enumerate(self.threads):
            participants = _copy_string_list(thread.get('participantIds'))
            if (
                thread.get('requestId') == request.get('id')
                and requester_id in participants
                and helper_id in participants
            ):
                updated_thread = copy.deepcopy(thread)
                updated_thread['lastMessageAt'] = now
                updated_thread['messageRequestPending'] = False
                updated_thread['flaggedSafetyConcern'] = bool(thread.get('flaggedSafetyConcern', False)) or self.is_high_risk_request(request)
                self.threads[index] = updated_thread
                return updated_thread

        new_thread = {
            'id': self.next_id('thread', self.threads),
            'requestId': request.get('id'),
            'participantIds': [requester_id, helper_id],
            'createdAt': now,
            'lastMessageAt': now,
            'messageRequestPending': False,
            'blockedByIds': [],
            'mutedByIds': [],
            'contactSharedByIds': [],
            'flaggedSafetyConcern': self.is_high_risk_request(request),
        }
        self.threads.insert(0, new_thread)
        return new_thread

    def rank_helpers(
        self,
        request: dict[str, Any],
        requester: dict[str, Any],
        users: list[dict[str, Any]],
        limit: int | None = HELPER_BROADCAST_LIMIT,
    ) -> list[dict[str, Any]]:
        strict_candidates = self.rank_candidates(
            request=request,
            requester=requester,
            users=users,
            allow_urgency_fallback=False,
        )
        if strict_candidates or not self.allows_urgency_fallback(request):
            return strict_candidates[:limit]

        relaxed_candidates = self.rank_candidates(
            request=request,
            requester=requester,
            users=users,
            allow_urgency_fallback=True,
        )
        return relaxed_candidates[:limit]

    def rank_candidates(
        self,
        request: dict[str, Any],
        requester: dict[str, Any],
        users: list[dict[str, Any]],
        allow_urgency_fallback: bool,
    ) -> list[dict[str, Any]]:
        candidates = []
        for helper in users:
            candidate = self.score_helper(
                request=request,
                requester=requester,
                helper=helper,
                allow_urgency_fallback=allow_urgency_fallback,
            )
            if candidate is not None:
                candidates.append(candidate)

        candidates.sort(
            key=lambda candidate: (
                -float(candidate.get('score', 0)),
                -float(candidate['helper'].get('trustScore', 0)),
                -_read_int(candidate['helper'].get('completedHelpCount')),
            )
        )
        return candidates

    def score_helper(
        self,
        request: dict[str, Any],
        requester: dict[str, Any],
        helper: dict[str, Any],
        allow_urgency_fallback: bool,
    ) -> dict[str, Any] | None:
        is_assigned_helper = request.get('acceptedHelperId') == helper.get('id')

        if self.is_closed_request(request) or helper.get('id') == requester.get('id'):
            return None
        if request.get('acceptedHelperId') and not is_assigned_helper:
            return None
        if not self.can_users_interact(requester, helper):
            return None
        if not is_assigned_helper and not self.is_active_helper(helper):
            return None
        if not is_assigned_helper and self.is_high_risk_request(request) and not self.is_high_risk_qualified(helper):
            return None

        category = str(request.get('category', '')).strip()
        provided_categories = _copy_string_list(helper.get('helpCategoriesProvided'))
        direct_category_match = category in provided_categories
        related_category = self.first_related_category_match(helper, category)
        emotional_support_fit = bool(request.get('emotionalSupportMode')) and self.supports_emotional_support(helper)
        fallback_urgency_fit = (
            not direct_category_match
            and related_category is None
            and not emotional_support_fit
            and allow_urgency_fallback
            and self.allows_urgency_fallback(request)
        )

        if (
            not is_assigned_helper
            and not direct_category_match
            and related_category is None
            and not emotional_support_fit
            and not fallback_urgency_fit
        ):
            return None

        score = 0.0
        reasons: list[str] = []
        if is_assigned_helper:
            score += 30
            reasons.append('Already accepted as the active helper for this request')

        if direct_category_match:
            score += 38
            reasons.append(
                f"Direct {CATEGORY_LABELS.get(category, category).lower()} match"
            )
        elif related_category is not None:
            score += 20
            reasons.append(
                'Related experience in '
                f"{CATEGORY_LABELS.get(related_category, related_category).lower()}"
            )

        if emotional_support_fit:
            score += 18
            reasons.append('Profile is set up for emotional or prayer support')
        if fallback_urgency_fit:
            score += 12
            reasons.append('Available for urgent community support')

        same_city = self.matches_location(helper.get('city'), requester.get('city')) or self.matches_location(helper.get('city'), request.get('location'))
        same_area = self.matches_location(helper.get('area'), requester.get('area')) or self.matches_location(helper.get('area'), request.get('location'))
        if same_city:
            score += 12
            city = str(helper.get('city', '')).strip()
            if city:
                reasons.append(f'Based in {city}')
        if same_area:
            score += 8
            area = str(helper.get('area', '')).strip()
            if area:
                reasons.append(f'Near {area}')

        service_radius = _read_float(helper.get('serviceRadiusKm'), 10)
        score += max(0.0, min(service_radius, 25.0)) / 2
        if service_radius >= 10:
            reasons.append(f'Covers {service_radius:.0f} km service radius')

        trust_score = _read_float(helper.get('trustScore'), 0)
        score += trust_score * 0.32
        if trust_score >= 85:
            reasons.append(f'{trust_score:.0f} trust score')

        average_rating = _read_float(helper.get('averageRating'), 0)
        score += average_rating * 5
        if average_rating >= 4:
            reasons.append(f'{average_rating:.1f} average rating')

        completed_help_count = _read_int(helper.get('completedHelpCount'))
        score += min(max(completed_help_count, 0), 20) * 0.6
        if completed_help_count >= 5:
            reasons.append(f'{completed_help_count} completed help requests')

        if self.trusted_helper(helper):
            score += 10
            reasons.append('Trusted helper badge')
        elif self.id_verified(helper):
            score += 6
            reasons.append('ID verified')

        if self.phone_verified(helper):
            score += 2
        if self.email_verified(helper):
            score += 1
        if bool(request.get('requiresHomeVisit')) and self.id_verified(helper):
            score += 8
            reasons.append('Verified for home-visit safety')
        if bool(request.get('lateNightSupport')) and (self.trusted_helper(helper) or self.id_verified(helper)):
            score += 6
            reasons.append('Better suited for late-night coordination')
        if bool(request.get('moneyRelated')) and self.id_verified(helper):
            score += 8
            reasons.append('Verified for money-related support')

        if _read_int(helper.get('helpGivenCount')) > _read_int(helper.get('helpReceivedCount')):
            score += 4
            reasons.append('Usually gives more support than they request')

        return {
            'helper': helper,
            'score': max(0.0, min(score, 99.0)),
            'reasons': self.dedupe_reasons(reasons),
            'isFallbackCandidate': fallback_urgency_fit,
        }

    def can_users_interact(self, requester: dict[str, Any], helper: dict[str, Any]) -> bool:
        requester_blocked = _copy_string_list(requester.get('blockedUserIds'))
        helper_blocked = _copy_string_list(helper.get('blockedUserIds'))
        helper_id = str(helper.get('id', '')).strip()
        requester_id = str(requester.get('id', '')).strip()
        if helper_id in requester_blocked or requester_id in helper_blocked:
            return False

        return (
            str(helper.get('restrictionStatus', 'clear')) not in BLOCKED_RESTRICTION_STATUSES
            and str(requester.get('restrictionStatus', 'clear')) not in BLOCKED_RESTRICTION_STATUSES
        )

    def is_active_helper(self, helper: dict[str, Any]) -> bool:
        return self.is_user_available(helper)

    def is_user_available(self, user: dict[str, Any]) -> bool:
        if not bool(user.get('availability', True)):
            return False

        start = _read_int(user.get('availabilityStartMinuteOfDay', -1))
        end = _read_int(user.get('availabilityEndMinuteOfDay', -1))
        if start < 0 or end < 0:
            return True
        if start >= MINUTES_PER_DAY or end >= MINUTES_PER_DAY:
            return True
        if start == end:
            return True

        now = datetime.now()
        minute_of_day = now.hour * 60 + now.minute
        if start < end:
            return start <= minute_of_day < end
        return minute_of_day >= start or minute_of_day < end

    def is_high_risk_qualified(self, helper: dict[str, Any]) -> bool:
        return self.id_verified(helper) or self.trusted_helper(helper)

    def supports_emotional_support(self, helper: dict[str, Any]) -> bool:
        provided_categories = _copy_string_list(helper.get('helpCategoriesProvided'))
        return 'emotionalSupport' in provided_categories or 'prayerSupport' in provided_categories

    def first_related_category_match(
        self, helper: dict[str, Any], category: str
    ) -> str | None:
        related_categories = RELATED_CATEGORIES.get(category)
        if related_categories is None:
            return None

        for candidate in _copy_string_list(helper.get('helpCategoriesProvided')):
            if candidate in related_categories:
                return candidate
        return None

    def allows_urgency_fallback(self, request: dict[str, Any]) -> bool:
        return request.get('urgency') == 'high' or request.get('category') == 'emergencySupport'

    def matches_location(self, left: Any, right: Any) -> bool:
        normalized_left = _normalize_text(left)
        normalized_right = _normalize_text(right)
        if not normalized_left or not normalized_right:
            return False
        return (
            normalized_left == normalized_right
            or normalized_left in normalized_right
            or normalized_right in normalized_left
        )

    def dedupe_reasons(self, reasons: list[str]) -> list[str]:
        seen: set[str] = set()
        unique_reasons: list[str] = []
        for reason in reasons:
            normalized_reason = reason.strip()
            if not normalized_reason or normalized_reason in seen:
                continue
            seen.add(normalized_reason)
            unique_reasons.append(normalized_reason)
            if len(unique_reasons) == 5:
                break
        return unique_reasons

    def trusted_helper(self, user: dict[str, Any]) -> bool:
        return 'trustedHelper' in _copy_string_list(user.get('verificationBadges'))

    def id_verified(self, user: dict[str, Any]) -> bool:
        return 'idVerified' in _copy_string_list(user.get('verificationBadges'))

    def email_verified(self, user: dict[str, Any]) -> bool:
        return 'emailVerified' in _copy_string_list(user.get('verificationBadges'))

    def phone_verified(self, user: dict[str, Any]) -> bool:
        return 'phoneVerified' in _copy_string_list(user.get('verificationBadges'))

    def _bucket_key_for_user(self, user: dict[str, Any]) -> str:
        email = str(user.get('email', '')).strip().lower()
        if email:
            return email
        return str(user.get('id', 'user')).strip() or 'user'


def _as_map(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    return {str(key): copy.deepcopy(item) for key, item in value.items()}


def _as_map_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    result: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, dict):
            result.append(_as_map(item))
    return result


def _copy_string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_int(value: Any, fallback: int = 0) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return fallback


def _read_float(value: Any, fallback: float = 0.0) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value))
    except (TypeError, ValueError):
        return fallback


def _clamp_int(value: Any, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, _read_int(value, minimum)))


def _first_name(full_name: Any) -> str:
    parts = str(full_name or '').strip().split()
    return parts[0] if parts else 'there'


def _normalize_text(value: Any) -> str:
    return str(value or '').strip().lower()