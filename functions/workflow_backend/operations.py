from __future__ import annotations

import copy
from typing import Any

from .constants import HELPER_BROADCAST_LIMIT, REQUESTER_SUGGESTION_LIMIT
from .errors import WorkflowError
from .utils import _clamp_int, _copy_string_list, _first_name, _now_iso


class WorkflowOperationsMixin:
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
            'visibility': str(payload.get('visibility', 'restricted')).strip()
            or 'restricted',
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
        draft_request['safetyCheckInRequired'] = self.is_high_risk_request(
            draft_request
        )

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
                'category': str(
                    payload.get('category', updated_request.get('category', ''))
                ).strip(),
                'urgency': str(
                    payload.get('urgency', updated_request.get('urgency', 'medium'))
                ).strip(),
                'location': str(payload.get('location', '')).strip(),
                'preferredTime': str(payload.get('preferredTime', '')).strip(),
                'visibility': str(
                    payload.get(
                        'visibility', updated_request.get('visibility', 'restricted')
                    )
                ).strip(),
                'attachmentLabel': attachment_label,
                'emotionalSupportMode': bool(payload.get('emotionalSupportMode', False)),
                'requiresHomeVisit': bool(payload.get('requiresHomeVisit', False)),
                'lateNightSupport': bool(payload.get('lateNightSupport', False)),
                'moneyRelated': bool(payload.get('moneyRelated', False)),
                'emergencyOverride': bool(payload.get('emergencyOverride', False)),
            }
        )
        updated_request['safetyCheckInRequired'] = self.is_high_risk_request(
            updated_request
        )
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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
            self.sync_suggested_matches_for_request(
                updated_request, helper_candidates
            )

        self.replace_request(updated_request)
        return {'requestId': request_id}

    def delete_help_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request could not be deleted.', status_code=404)
        if request.get('requesterId') != self.current_user_id or request.get(
            'acceptedHelperId'
        ):
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

        self.requests = [
            candidate for candidate in self.requests if candidate.get('id') != request_id
        ]
        self.matches = [
            match for match in self.matches if match.get('requestId') != request_id
        ]
        self.threads = [
            thread for thread in self.threads if thread.get('requestId') != request_id
        ]
        self.messages = [
            message
            for message in self.messages
            if message.get('threadId') not in removed_thread_ids
        ]
        self.reviews = [
            review
            for review in self.reviews
            if review.get('matchId') not in removed_match_ids
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
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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

    def request_helper_for_my_request(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        helper_id = str(payload.get('helperId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request was not found.', status_code=404)
        if request.get('requesterId') != self.current_user_id or self.is_closed_request(
            request
        ):
            raise WorkflowError(
                'This helper could not be requested for that request.',
                status_code=409,
            )
        if request.get('acceptedHelperId') == helper_id:
            return {'matched': True, 'requestId': request_id, 'helperId': helper_id}
        if request.get('acceptedHelperId') and request.get('acceptedHelperId') != helper_id:
            raise WorkflowError(
                'This request already has a different helper assigned.',
                status_code=409,
            )

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
            raise WorkflowError(
                'The selected helper no longer qualifies for this request.',
                status_code=409,
            )

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

    def volunteer_for_help_request(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('This request was not found.', status_code=404)
        if request.get('requesterId') == self.current_user_id or self.is_closed_request(
            request
        ):
            raise WorkflowError(
                'This request is no longer available for matching.',
                status_code=409,
            )
        if request.get('acceptedHelperId') == self.current_user_id:
            return {
                'matched': True,
                'requestId': request_id,
                'helperId': self.current_user_id,
            }
        if request.get('acceptedHelperId') and request.get('acceptedHelperId') != self.current_user_id:
            raise WorkflowError(
                'This request is no longer available for matching.',
                status_code=409,
            )

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
            raise WorkflowError(
                'This request is no longer available for matching.',
                status_code=409,
            )

        self.confirm_match(
            request=request,
            helper=helper,
            action_actor_id=self.current_user_id,
            action_label='Helper confirmed availability and accepted the request',
            opener_message='I am available and willing to help with this request. Let us coordinate here.',
            match_candidate=match_candidate,
        )
        return {
            'matched': True,
            'requestId': request_id,
            'helperId': self.current_user_id,
        }

    def start_request_work(self, payload: dict[str, Any]) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError(
                'This request could not be moved to in progress.', status_code=404
            )
        if not self.can_current_user_start_request(request):
            raise WorkflowError(
                'This request could not be moved to in progress.', status_code=409
            )

        now = _now_iso()
        updated_request = copy.deepcopy(request)
        updated_request['status'] = 'inProgress'
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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

    def confirm_request_completion(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError('Completion could not be updated.', status_code=404)
        if not self.can_current_user_confirm_request_completion(request):
            raise WorkflowError('Completion could not be updated.', status_code=409)

        now = _now_iso()
        requester_confirmed = (
            True
            if request.get('requesterId') == self.current_user_id
            else bool(request.get('requesterCompletionConfirmed', False))
        )
        helper_confirmed = (
            True
            if request.get('acceptedHelperId') == self.current_user_id
            else bool(request.get('helperCompletionConfirmed', False))
        )
        fully_completed = requester_confirmed and helper_confirmed

        updated_request = copy.deepcopy(request)
        updated_request['status'] = 'completed' if fully_completed else 'inProgress'
        updated_request['requesterCompletionConfirmed'] = requester_confirmed
        updated_request['helperCompletionConfirmed'] = helper_confirmed
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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
            accepted_match['completedAt'] = (
                now if fully_completed else accepted_match.get('completedAt')
            )

        other_participant = self.other_participant_for_request(request)
        if other_participant is not None:
            self.notifications.insert(
                0,
                {
                    'id': self.next_id('notification', self.notifications),
                    'userId': other_participant.get('id'),
                    'type': 'helpCompleted' if fully_completed else 'adminUpdate',
                    'title': 'Help marked complete'
                    if fully_completed
                    else 'Completion confirmation pending',
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

    def submit_review_for_request(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
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
        feedback = (
            str(payload.get('feedback', '')).strip()
            or 'No written feedback provided.'
        )
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
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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

    def submit_participant_safety_report(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
        request_id = str(payload.get('requestId', '')).strip()
        request = self.find_request(request_id)
        if request is None:
            raise WorkflowError(
                'Safety report could not be submitted.', status_code=404
            )
        reported_user = self.other_participant_for_request(request)
        reason = str(payload.get('reason', '')).strip()
        if reported_user is None or not reason:
            raise WorkflowError(
                'Safety report could not be submitted.', status_code=409
            )

        now = _now_iso()
        details = (
            str(payload.get('details', '')).trim()
            if hasattr(str(payload.get('details', '')), 'trim')
            else str(payload.get('details', '')).strip()
        )
        report_id = self.next_id('report', self.reports)
        report = {
            'id': report_id,
            'reporterId': self.current_user_id,
            'targetType': 'user',
            'targetId': reported_user.get('id'),
            'reason': reason,
            'details': f"Request {request.get('title', 'the request')}: {details}"
            if details
            else f"Reported from request {request.get('title', 'the request')}.",
            'status': 'open',
            'createdAt': now,
            'assignedModeratorId': None,
        }
        self.reports.insert(0, report)

        updated_request = copy.deepcopy(request)
        updated_request['safetyCheckInRequired'] = True
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
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
            raise WorkflowError(
                'Account report could not be submitted.', status_code=409
            )

        reported_user = self.find_user(user_id)
        if reported_user is None:
            raise WorkflowError(
                'Account report could not be submitted.', status_code=404
            )

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
            updated_request['actionLog'] = copy.deepcopy(
                updated_request.get('actionLog', [])
            )
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
            raise WorkflowError(
                'You are not allowed to send a message to this thread.',
                status_code=403,
            )

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