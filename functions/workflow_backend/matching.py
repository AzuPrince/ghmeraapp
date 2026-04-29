from __future__ import annotations

import copy
from datetime import datetime
from typing import Any

from .constants import (
    BLOCKED_RESTRICTION_STATUSES,
    CATEGORY_LABELS,
    HELPER_BROADCAST_LIMIT,
    HIGH_RISK_CATEGORIES,
    MINUTES_PER_DAY,
    RECIPROCITY_FLOOR,
    RELATED_CATEGORIES,
    REQUESTER_SUGGESTION_LIMIT,
)
from .utils import (
    _copy_string_list,
    _first_name,
    _normalize_text,
    _now_iso,
    _read_float,
    _read_int,
)


class WorkflowMatchingMixin:
    def can_create_request(self) -> bool:
        current_user = self.current_user()
        if self.can_bypass_reciprocity(current_user):
            return True
        return self.help_balance(current_user) >= RECIPROCITY_FLOOR

    def can_bypass_reciprocity(self, user: dict[str, Any]) -> bool:
        return bool(user.get('vulnerableUser')) or bool(
            user.get('hasDisability')
        ) or bool(user.get('adminOverrideReciprocity'))

    def help_balance(self, user: dict[str, Any]) -> int:
        return _read_int(user.get('helpGivenCount')) - _read_int(
            user.get('helpReceivedCount')
        )

    def is_current_user_participant_for_request(
        self, request: dict[str, Any]
    ) -> bool:
        return request.get('requesterId') == self.current_user_id or request.get(
            'acceptedHelperId'
        ) == self.current_user_id

    def has_current_user_confirmed_request_completion(
        self, request: dict[str, Any]
    ) -> bool:
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

    def can_current_user_confirm_request_completion(
        self, request: dict[str, Any]
    ) -> bool:
        return (
            self.is_current_user_participant_for_request(request)
            and bool(request.get('acceptedHelperId'))
            and request.get('status') in {'accepted', 'inProgress'}
            and not self.has_current_user_confirmed_request_completion(request)
        )

    def has_current_user_submitted_review_for_request(
        self, request: dict[str, Any]
    ) -> bool:
        accepted_match = self.accepted_match_for_request(request)
        if accepted_match is None:
            return False
        for review in self.reviews:
            if review.get('matchId') == accepted_match.get(
                'id'
            ) and review.get('reviewerId') == self.current_user_id:
                return True
        return False

    def can_current_user_submit_review_for_request(
        self, request: dict[str, Any]
    ) -> bool:
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
                    if candidate.get('isFallbackCandidate')
                    or index >= REQUESTER_SUGGESTION_LIMIT
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
        suggested_helper_ids = set(
            _copy_string_list(updated_request.get('suggestedHelperIds'))
        )
        suggested_helper_ids.add(str(helper_id))
        updated_request['status'] = 'accepted'
        updated_request['acceptedHelperId'] = helper_id
        updated_request['safetyCheckInRequired'] = self.is_high_risk_request(
            updated_request
        )
        updated_request['suggestedHelperIds'] = list(suggested_helper_ids)
        updated_request['actionLog'] = copy.deepcopy(
            updated_request.get('actionLog', [])
        )
        updated_request['actionLog'].append(
            {
                'actorId': action_actor_id,
                'action': action_label,
                'createdAt': now,
            }
        )
        self.replace_request(updated_request)

        chat_thread = self.ensure_protected_chat_thread(
            request=updated_request,
            helper_id=str(helper_id),
            now=now,
        )
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
                updated_thread['flaggedSafetyConcern'] = bool(
                    thread.get('flaggedSafetyConcern', False)
                ) or self.is_high_risk_request(request)
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
        if (
            not is_assigned_helper
            and self.is_high_risk_request(request)
            and not self.is_high_risk_qualified(helper)
        ):
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
        if bool(request.get('lateNightSupport')) and (
            self.trusted_helper(helper) or self.id_verified(helper)
        ):
            score += 6
            reasons.append('Better suited for late-night coordination')
        if bool(request.get('moneyRelated')) and self.id_verified(helper):
            score += 8
            reasons.append('Verified for money-related support')

        if _read_int(helper.get('helpGivenCount')) > _read_int(
            helper.get('helpReceivedCount')
        ):
            score += 4
            reasons.append('Usually gives more support than they request')

        return {
            'helper': helper,
            'score': max(0.0, min(score, 99.0)),
            'reasons': self.dedupe_reasons(reasons),
            'isFallbackCandidate': fallback_urgency_fit,
        }

    def can_users_interact(
        self, requester: dict[str, Any], helper: dict[str, Any]
    ) -> bool:
        requester_blocked = _copy_string_list(requester.get('blockedUserIds'))
        helper_blocked = _copy_string_list(helper.get('blockedUserIds'))
        helper_id = str(helper.get('id', '')).strip()
        requester_id = str(requester.get('id', '')).strip()
        if helper_id in requester_blocked or requester_id in helper_blocked:
            return False

        return (
            str(helper.get('restrictionStatus', 'clear'))
            not in BLOCKED_RESTRICTION_STATUSES
            and str(requester.get('restrictionStatus', 'clear'))
            not in BLOCKED_RESTRICTION_STATUSES
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
        return request.get('urgency') == 'high' or request.get(
            'category'
        ) == 'emergencySupport'

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