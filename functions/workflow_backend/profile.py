from __future__ import annotations

import copy
from typing import Any

from .errors import WorkflowError
from .utils import _as_map, _copy_string_list, _now_iso, _read_float

# Badges a member can claim for themselves. ID checks and trusted-helper
# status are granted by Ghmera, so they only ever come from the saved record.
CLIENT_GRANTABLE_BADGES = frozenset({'emailVerified', 'phoneVerified'})
NOTIFICATION_TYPES = frozenset(
    {
        'matchFound',
        'newMessage',
        'requestAccepted',
        'helpCompleted',
        'reportUpdate',
        'safetyAlert',
        'reciprocityWarning',
        'emotionalCheckInReminder',
        'adminUpdate',
    }
)
MOOD_LEVELS = frozenset({'good', 'okay', 'struggling', 'notOkay'})
SUPPORT_MOOD_LEVELS = frozenset({'struggling', 'notOkay'})
PRIVACY_SETTING_KEYS = (
    'showApproximateLocation',
    'sharePhoneAfterAcceptance',
    'shareEmailAfterAcceptance',
    'allowSupportCircleInvites',
    'allowMessageRequests',
)
RECIPROCITY_STATUSES = frozenset({'accepted', 'inProgress', 'completed'})
ACTIVE_REPORT_STATUSES = frozenset({'open', 'investigating'})
MAX_ID_LIST_LENGTH = 500
MAX_ADDED_NOTIFICATIONS = 5


def _clean_text(value: Any, max_length: int) -> str | None:
    if not isinstance(value, str):
        return None
    return value.strip()[:max_length]


def _clean_optional_text(value: Any, max_length: int) -> tuple[bool, str | None]:
    if value is None:
        return True, None
    text = _clean_text(value, max_length)
    return (text is not None), text


def _clean_string_list(value: Any) -> list[str] | None:
    if not isinstance(value, list):
        return None
    cleaned: list[str] = []
    for item in value:
        if not isinstance(item, str):
            return None
        text = item.strip()
        if text and text not in cleaned:
            cleaned.append(text)
    return cleaned[:MAX_ID_LIST_LENGTH]


def _clean_optional_number(
    value: Any, *, minimum: float, maximum: float
) -> tuple[bool, float | None]:
    if value is None:
        return True, None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False, None
    number = float(value)
    if not minimum <= number <= maximum:
        return False, None
    return True, number


def _clean_minute_of_day(value: Any) -> tuple[bool, int | None]:
    if value is None:
        return True, None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False, None
    minute = int(value)
    if not 0 <= minute < 24 * 60:
        return False, None
    return True, minute


def _clean_sessions(value: Any) -> list[dict[str, Any]] | None:
    if not isinstance(value, list):
        return None
    sessions: list[dict[str, Any]] = []
    for raw_session in value[:20]:
        if not isinstance(raw_session, dict):
            continue
        session_id = _clean_text(raw_session.get('id'), 120)
        label = _clean_text(raw_session.get('label'), 120)
        last_active = _clean_text(raw_session.get('lastActive'), 64)
        if not session_id or label is None or not last_active:
            continue
        sessions.append(
            {
                'id': session_id,
                'label': label,
                'lastActive': last_active,
                'isCurrent': raw_session.get('isCurrent') is True,
            }
        )
    return sessions


def _new_user_record(user_id: str, email: str) -> dict[str, Any]:
    return {
        'id': user_id,
        'fullName': 'Ghmera User',
        'email': email,
        'phone': None,
        'profilePhoto': None,
        'shortBio': '',
        'city': '',
        'area': '',
        'exactLatitude': None,
        'exactLongitude': None,
        'verificationBadges': [],
        'trustScore': 0,
        'availability': True,
        'availabilityStartMinuteOfDay': None,
        'availabilityEndMinuteOfDay': None,
        'helpCategoriesProvided': [],
        'helpCategoriesRequested': [],
        'serviceRadiusKm': 10,
        'helpGivenCount': 0,
        'helpReceivedCount': 0,
        'restrictionStatus': 'clear',
        'averageRating': 0,
        'completedHelpCount': 0,
        'receivedHelpCount': 0,
        'blockedUserIds': [],
        'mutedUserIds': [],
        'hiddenRequestIds': [],
        'usesDeviceLocation': True,
        'privacySettings': {
            'showApproximateLocation': True,
            'sharePhoneAfterAcceptance': False,
            'shareEmailAfterAcceptance': False,
            'allowSupportCircleInvites': True,
            'allowMessageRequests': True,
        },
        'twoFactorEnabled': False,
        'isAdmin': False,
        'vulnerableUser': False,
        'hasDisability': False,
        'adminOverrideReciprocity': False,
        'sessions': [],
        'trustFlags': [],
    }


def merge_client_user_record(
    stored_user: dict[str, Any] | None,
    client_user: dict[str, Any],
    *,
    user_id: str,
    email: str,
) -> dict[str, Any]:
    """Apply the fields a member may edit about themselves to their record.

    Identity, moderation status, admin flags, Ghmera-granted badges and
    reputation figures always come from the saved record. Fields with the
    wrong type are ignored so one bad client can't break everyone's app.
    """
    merged = (
        copy.deepcopy(stored_user)
        if stored_user is not None
        else _new_user_record(user_id, email)
    )
    merged['id'] = user_id
    if stored_user is None or not str(merged.get('email') or '').strip():
        merged['email'] = email

    full_name = _clean_text(client_user.get('fullName'), 80)
    if full_name:
        merged['fullName'] = full_name
    for key, max_length in (('shortBio', 500), ('city', 120), ('area', 160)):
        if key in client_user:
            text = _clean_text(client_user.get(key), max_length)
            if text is not None:
                merged[key] = text
    for key, max_length in (('phone', 40), ('profilePhoto', 2048)):
        if key in client_user:
            valid, text = _clean_optional_text(client_user.get(key), max_length)
            if valid:
                merged[key] = text or None
    for key, (minimum, maximum) in (
        ('exactLatitude', (-90.0, 90.0)),
        ('exactLongitude', (-180.0, 180.0)),
    ):
        if key in client_user:
            valid, number = _clean_optional_number(
                client_user.get(key), minimum=minimum, maximum=maximum
            )
            if valid:
                merged[key] = number
    for key in (
        'availability',
        'usesDeviceLocation',
        'twoFactorEnabled',
        'vulnerableUser',
        'hasDisability',
    ):
        if isinstance(client_user.get(key), bool):
            merged[key] = client_user[key]
    for key in ('availabilityStartMinuteOfDay', 'availabilityEndMinuteOfDay'):
        if key in client_user:
            valid, minute = _clean_minute_of_day(client_user.get(key))
            if valid:
                merged[key] = minute
    if 'serviceRadiusKm' in client_user:
        valid, radius = _clean_optional_number(
            client_user.get('serviceRadiusKm'), minimum=0, maximum=500
        )
        if valid and radius is not None:
            merged['serviceRadiusKm'] = radius
    for key in (
        'helpCategoriesProvided',
        'helpCategoriesRequested',
        'blockedUserIds',
        'mutedUserIds',
        'hiddenRequestIds',
    ):
        if key in client_user:
            values = _clean_string_list(client_user.get(key))
            if values is not None:
                merged[key] = [value for value in values if value != user_id]
    raw_privacy = client_user.get('privacySettings')
    if isinstance(raw_privacy, dict):
        privacy = _as_map(merged.get('privacySettings'))
        for key in PRIVACY_SETTING_KEYS:
            if isinstance(raw_privacy.get(key), bool):
                privacy[key] = raw_privacy[key]
        merged['privacySettings'] = privacy
    if 'sessions' in client_user:
        sessions = _clean_sessions(client_user.get('sessions'))
        if sessions is not None:
            merged['sessions'] = sessions
    client_badges = _clean_string_list(client_user.get('verificationBadges'))
    if client_badges is not None:
        stored_badges = _copy_string_list(merged.get('verificationBadges'))
        badges = [
            badge for badge in stored_badges if badge not in CLIENT_GRANTABLE_BADGES
        ]
        badges.extend(
            badge
            for badge in client_badges
            if badge in CLIENT_GRANTABLE_BADGES and badge not in badges
        )
        merged['verificationBadges'] = badges
    return merged


def clean_client_notification(
    raw_notification: Any, *, user_id: str
) -> dict[str, Any] | None:
    if not isinstance(raw_notification, dict):
        return None
    notification_type = str(raw_notification.get('type') or '').strip()
    title = _clean_text(raw_notification.get('title'), 120)
    message = _clean_text(raw_notification.get('message'), 500)
    if notification_type not in NOTIFICATION_TYPES or not title or message is None:
        return None
    return {
        'userId': user_id,
        'type': notification_type,
        'title': title,
        'message': message,
        'isRead': raw_notification.get('isRead') is True,
    }


class WorkflowProfileMixin:
    """Changes a member makes to their own data and their own safety tools."""

    def sync_my_profile(self, payload: dict[str, Any]) -> dict[str, Any]:
        client_user = payload.get('user')
        if not isinstance(client_user, dict):
            raise WorkflowError('Missing profile details.')
        client_user_id = str(client_user.get('id') or '').strip()
        if client_user_id and client_user_id != self.current_user_id:
            raise WorkflowError(
                'You can only update your own profile.', status_code=403
            )

        current_user = self.current_user()
        merged = merge_client_user_record(
            current_user,
            client_user,
            user_id=self.current_user_id,
            email=str(current_user.get('email') or self.current_user_email),
        )
        self.replace_user(merged)

        raw_notifications = payload.get('addNotifications')
        added_ids: list[str] = []
        if isinstance(raw_notifications, list):
            for raw_notification in raw_notifications[:MAX_ADDED_NOTIFICATIONS]:
                notification = clean_client_notification(
                    raw_notification, user_id=self.current_user_id
                )
                if notification is None:
                    continue
                added_ids.append(self.add_own_notification(notification))
        return {'userId': self.current_user_id, 'notificationIds': added_ids}

    def add_own_notification(self, notification: dict[str, Any]) -> str:
        notification_id = self.next_id('notification', self.notifications)
        self.notifications.insert(
            0,
            {
                'id': notification_id,
                'createdAt': _now_iso(),
                **notification,
                'userId': self.current_user_id,
            },
        )
        return notification_id

    def update_my_notifications(self, payload: dict[str, Any]) -> dict[str, Any]:
        read_ids = set(_copy_string_list(payload.get('readIds')))
        unread_ids = set(_copy_string_list(payload.get('unreadIds')))
        delete_ids = set(_copy_string_list(payload.get('deleteIds')))
        mark_all_read = payload.get('markAllRead') is True
        clear_all = payload.get('clearAll') is True

        changed = 0
        remaining: list[dict[str, Any]] = []
        for notification in self.notifications:
            if notification.get('userId') != self.current_user_id:
                remaining.append(notification)
                continue
            notification_id = str(notification.get('id') or '')
            if clear_all or notification_id in delete_ids:
                changed += 1
                continue
            if notification_id in unread_ids:
                changed += notification.get('isRead') is not False
                notification['isRead'] = False
            elif mark_all_read or notification_id in read_ids:
                changed += notification.get('isRead') is not True
                notification['isRead'] = True
            remaining.append(notification)
        self.notifications = remaining
        return {'changed': changed}

    def record_mood(self, payload: dict[str, Any]) -> dict[str, Any]:
        mood_level = str(payload.get('moodLevel') or '').strip()
        if mood_level not in MOOD_LEVELS:
            raise WorkflowError('Choose how you are feeling.')

        needs_support = mood_level in SUPPORT_MOOD_LEVELS
        now = _now_iso()
        check_in_id = self.next_id('mood', self.mood_check_ins)
        self.mood_check_ins.insert(
            0,
            {
                'id': check_in_id,
                'userId': self.current_user_id,
                'moodLevel': mood_level,
                'createdAt': now,
                'note': 'Support options surfaced automatically.'
                if needs_support
                else 'Community wellness check-in completed.',
            },
        )
        if needs_support:
            mood_label = 'struggling' if mood_level == 'struggling' else 'not okay'
            self.add_own_notification(
                {
                    'type': 'emotionalCheckInReminder',
                    'title': 'Support options are ready',
                    'message': f'You marked yourself as {mood_label}. Emotional '
                    'support requests and support circles are now highlighted.',
                    'isRead': False,
                }
            )
        return {'moodCheckInId': check_in_id}

    def block_user(self, payload: dict[str, Any]) -> dict[str, Any]:
        user_id = str(payload.get('userId') or '').strip()
        request_id = str(payload.get('requestId') or '').strip()
        if not user_id or user_id == self.current_user_id:
            raise WorkflowError('You cannot block this account.')
        blocked_user = self.find_user(user_id)
        if blocked_user is None:
            raise WorkflowError('That account was not found.', status_code=404)

        current_user = copy.deepcopy(self.current_user())
        blocked_ids = _copy_string_list(current_user.get('blockedUserIds'))
        hidden_ids = _copy_string_list(current_user.get('hiddenRequestIds'))
        changed = False
        if user_id not in blocked_ids:
            blocked_ids.append(user_id)
            changed = True
        if request_id and request_id not in hidden_ids:
            hidden_ids.append(request_id)
            changed = True
        for thread in self.threads:
            participants = _copy_string_list(thread.get('participantIds'))
            blocked_by = _copy_string_list(thread.get('blockedByIds'))
            if (
                self.current_user_id in participants
                and user_id in participants
                and self.current_user_id not in blocked_by
            ):
                thread['blockedByIds'] = [*blocked_by, self.current_user_id]
                changed = True

        if changed:
            current_user['blockedUserIds'] = blocked_ids
            current_user['hiddenRequestIds'] = hidden_ids
            self.replace_user(current_user)
            self.add_own_notification(
                {
                    'type': 'safetyAlert',
                    'title': 'Account blocked',
                    'message': f"You blocked {blocked_user.get('fullName', 'this member')}. "
                    'Their requests will no longer appear to you.',
                    'isRead': False,
                }
            )
        return {'blocked': True, 'changed': changed}

    def unblock_user(self, payload: dict[str, Any]) -> dict[str, Any]:
        user_id = str(payload.get('userId') or '').strip()
        if not user_id or user_id == self.current_user_id:
            raise WorkflowError('You cannot unblock this account.')

        current_user = copy.deepcopy(self.current_user())
        blocked_ids = _copy_string_list(current_user.get('blockedUserIds'))
        changed = user_id in blocked_ids
        for thread in self.threads:
            participants = _copy_string_list(thread.get('participantIds'))
            blocked_by = _copy_string_list(thread.get('blockedByIds'))
            if (
                self.current_user_id in participants
                and user_id in participants
                and self.current_user_id in blocked_by
            ):
                thread['blockedByIds'] = [
                    blocker for blocker in blocked_by if blocker != self.current_user_id
                ]
                changed = True
        if user_id in blocked_ids:
            current_user['blockedUserIds'] = [
                blocked for blocked in blocked_ids if blocked != user_id
            ]
            self.replace_user(current_user)
        return {'unblocked': True, 'changed': changed}

    def set_support_circle_membership(
        self, payload: dict[str, Any]
    ) -> dict[str, Any]:
        circle_id = str(payload.get('circleId') or '').strip()
        is_member = payload.get('member')
        if not isinstance(is_member, bool):
            raise WorkflowError('Choose whether to join or leave this circle.')
        for circle in self.support_circles:
            if circle.get('id') != circle_id:
                continue
            members = [
                member
                for member in _copy_string_list(circle.get('memberIds'))
                if member != self.current_user_id
            ]
            if is_member:
                members.append(self.current_user_id)
            circle['memberIds'] = members
            return {'circleId': circle_id, 'member': is_member}
        raise WorkflowError('That support circle was not found.', status_code=404)

    def delete_message(self, payload: dict[str, Any]) -> dict[str, Any]:
        thread_id = str(payload.get('threadId') or '').strip()
        message_id = str(payload.get('messageId') or '').strip()
        for index, message in enumerate(self.messages):
            if message.get('id') != message_id or message.get('threadId') != thread_id:
                continue
            if message.get('senderId') != self.current_user_id:
                raise WorkflowError(
                    'You can only delete your own messages.', status_code=403
                )
            del self.messages[index]
            return {'deleted': True, 'messageId': message_id}
        raise WorkflowError('That message was not found.', status_code=404)

    def sync_derived_user_metrics(self) -> None:
        """Recompute reputation figures from requests, reviews and reports."""
        for index, user in enumerate(self.users):
            user_id = user.get('id')
            help_given = help_received = completed = received_completed = 0
            for request in self.requests:
                helper_id = request.get('acceptedHelperId')
                status = request.get('status')
                if not helper_id or status not in RECIPROCITY_STATUSES:
                    continue
                if helper_id == user_id:
                    help_given += 1
                    completed += status == 'completed'
                if request.get('requesterId') == user_id:
                    help_received += 1
                    received_completed += status == 'completed'

            ratings = [
                sum(
                    _read_float(review.get(key))
                    for key in (
                        'helpfulness',
                        'respectfulness',
                        'safety',
                        'reliability',
                        'accuracy',
                    )
                )
                / 5
                for review in self.reviews
                if review.get('revieweeId') == user_id
            ]
            average_rating = sum(ratings) / len(ratings) if ratings else 0
            active_reports = sum(
                1
                for report in self.reports
                if report.get('targetType') == 'user'
                and report.get('targetId') == user_id
                and report.get('status') in ACTIVE_REPORT_STATUSES
            )
            suspicious_reviews = sum(
                1
                for review in self.reviews
                if review.get('revieweeId') == user_id
                and review.get('flaggedSuspicious') is True
            )
            badges = set(_copy_string_list(user.get('verificationBadges')))
            blocked_count = len(_copy_string_list(user.get('blockedUserIds')))
            muted_count = len(_copy_string_list(user.get('mutedUserIds')))

            trust_flags = []
            if 'trustedHelper' in badges:
                trust_flags.append('Trusted helper badge')
            if 'idVerified' in badges:
                trust_flags.append('ID verified')
            if 'phoneVerified' in badges:
                trust_flags.append('Phone verified')
            if completed >= 5:
                trust_flags.append(f'{completed} completed help records')
            if average_rating >= 4:
                trust_flags.append(f'{average_rating:.1f} average review')
            if active_reports > 0:
                trust_flags.append(
                    f"{active_reports} active safety report{'' if active_reports == 1 else 's'}"
                )
            if suspicious_reviews > 0:
                trust_flags.append(
                    f"{suspicious_reviews} suspicious review flag{'' if suspicious_reviews == 1 else 's'}"
                )
            if blocked_count:
                trust_flags.append(
                    f"{blocked_count} blocked account safeguard{'' if blocked_count == 1 else 's'}"
                )
            if muted_count:
                trust_flags.append(
                    f"{muted_count} muted conversation safeguard{'' if muted_count == 1 else 's'}"
                )

            trust_score = 0.0
            if (
                average_rating > 0
                or completed > 0
                or help_given > 0
                or help_received > 0
                or active_reports > 0
                or suspicious_reviews > 0
            ):
                if average_rating > 0:
                    trust_score += (average_rating / 5) * 55
                trust_score += min(max(completed, 0), 20) * 1.5
                if help_given > 0 or help_received > 0:
                    trust_score += min(max(help_given - help_received, -5), 10) * 1.2
                if 'emailVerified' in badges:
                    trust_score += 6
                if 'phoneVerified' in badges:
                    trust_score += 8
                if 'idVerified' in badges:
                    trust_score += 10
                if 'trustedHelper' in badges:
                    trust_score += 10
                trust_score -= active_reports * 12
                trust_score -= suspicious_reviews * 8
                trust_score -= blocked_count * 1.5
                trust_score -= muted_count * 0.5
                trust_score = float(min(max(trust_score, 0), 99))

            updated = dict(user)
            updated.update(
                {
                    'helpGivenCount': help_given,
                    'helpReceivedCount': help_received,
                    'completedHelpCount': completed,
                    'receivedHelpCount': received_completed,
                    'averageRating': average_rating,
                    'trustScore': trust_score,
                    'trustFlags': trust_flags,
                }
            )
            if updated != user:
                self.users[index] = updated
